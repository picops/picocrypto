"""
Benchmark msgpack pack (serde default and msgpack_pack_2).
Compares time per call and peak memory (tracemalloc) per run.

Timing uses multiple runs and median for more consistent results; warmup reduces
cold-cache effects. Use --iter, --warmup, --runs to tune.

Run from repo root:

  PYTHONPATH=src python benchmarks/msgpack.py
  PYTHONPATH=src python benchmarks/msgpack.py --impl v2,v3
  PYTHONPATH=src python benchmarks/msgpack.py --iter 5000 --runs 7   # slower, more stable

Or after pip install -e .:

  python benchmarks/msgpack.py
"""

from __future__ import annotations

import argparse
import gc
import os
import sys
import time
import tracemalloc

_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_src = os.path.join(_root, "src")
if _src not in sys.path:
    sys.path.insert(0, _src)


def _load_implementations() -> list[tuple[str, str, object]]:
    """(id, label, msgpack_pack callable). Order defines baseline (first) for speedup/ratio."""
    impls: list[tuple[str, str, object]] = []

    def _try_loader(modname: str, label: str, id_: str):
        try:
            mod = __import__(modname, fromlist=["msgpack_pack"])
            fn = getattr(mod, "msgpack_pack", None)
            impls.append((id_, label, fn))
        except Exception:
            impls.append((id_, label, None))

    # Serde default (msgpack_pack)
    _try_loader("picocrypto.serde.msgpack_pack", "serde (default)", "cy")
    # msgpack_pack_2
    _try_loader("picocrypto.serde.msgpack_pack_2", "msgpack_pack_2", "v2")
    return impls


# Sample payloads: various shapes and sizes
SAMPLES: list[tuple[object, str]] = [
    (None, "null"),
    (42, "int"),
    (True, "bool"),
    ("hello", "str short"),
    (b"bytes", "bytes"),
    ({"a": 1, "b": 2}, "dict 2"),
    ([1, 2, 3], "list 3"),
    ({"k": "v", "n": 0, "b": True}, "dict mixed"),
    (list(range(100)), "list 100"),
    ({"x": "y" * 50}, "dict str val"),
    ([{"i": i} for i in range(20)], "list of dicts"),
]

N_TIME = 2000
N_MEM = 500
WARMUP_DEFAULT = 200
TIMING_RUNS_DEFAULT = 5


def _time_per_call_median(
    fn: object,
    payload: object,
    n: int,
    warmup: int = WARMUP_DEFAULT,
    runs: int = TIMING_RUNS_DEFAULT,
    disable_gc: bool = True,
) -> tuple[float, float]:
    """
    Return (median time per call in seconds, std in seconds) for more consistent timing.
    Runs warmup, then `runs` timing loops of `n` iterations each; median of per-run
    mean time is used to reduce impact of outliers (GC, scheduling).
    """
    for _ in range(warmup):
        fn(payload)
    run_times: list[float] = []
    was_enabled = gc.isenabled()
    if disable_gc:
        gc.disable()
    try:
        for _ in range(runs):
            start = time.perf_counter()
            for _ in range(n):
                fn(payload)
            elapsed = time.perf_counter() - start
            run_times.append(elapsed / n)
    finally:
        if disable_gc and was_enabled:
            gc.enable()
    run_times.sort()
    median = run_times[runs // 2]
    mean = sum(run_times) / runs
    variance = sum((t - mean) ** 2 for t in run_times) / runs
    std = variance**0.5
    return median, std


def _peak_memory_kb(fn: object, payload: object, n: int) -> float:
    tracemalloc.start()
    if hasattr(tracemalloc, "reset_peak"):
        tracemalloc.reset_peak()
    for _ in range(n):
        fn(payload)
    _current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    return peak / 1024.0


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Benchmark msgpack_pack implementations"
    )
    parser.add_argument(
        "--impl",
        default="all",
        metavar="IDS",
        help="Comma-separated impl ids to run (e.g. cy,v2,v3) or 'all' (default)",
    )
    parser.add_argument(
        "--iter",
        type=int,
        default=N_TIME,
        metavar="N",
        help=f"Iterations per timing run (default {N_TIME}); higher = more stable",
    )
    parser.add_argument(
        "--warmup",
        type=int,
        default=WARMUP_DEFAULT,
        metavar="N",
        help=f"Warmup iterations before each timing run (default {WARMUP_DEFAULT})",
    )
    parser.add_argument(
        "--runs",
        type=int,
        default=TIMING_RUNS_DEFAULT,
        metavar="N",
        help=f"Number of timing runs per impl/payload; median is used (default {TIMING_RUNS_DEFAULT})",
    )
    parser.add_argument(
        "--no-disable-gc",
        action="store_true",
        help="Do not disable GC during timing (can make results noisier)",
    )
    parser.add_argument(
        "--show-std",
        action="store_true",
        help="Show ± std in time table (spread across runs)",
    )
    args = parser.parse_args()
    n_time = max(1, args.iter)
    warmup = max(0, args.warmup)
    runs = max(1, args.runs)
    disable_gc = not args.no_disable_gc
    show_std = args.show_std

    all_impls = _load_implementations()
    if args.impl.strip().lower() == "all":
        impls = [(i, label, fn) for i, label, fn in all_impls if fn is not None]
    else:
        requested = {s.strip().lower() for s in args.impl.split(",") if s.strip()}
        impls = [
            (i, label, fn)
            for i, label, fn in all_impls
            if i in requested and fn is not None
        ]

    if not impls:
        print(
            "No implementations available or selected. Check --impl and that extensions are built."
        )
        sys.exit(1)

    ids = [x[0] for x in impls]
    labels = [x[1] for x in impls]
    fns = [x[2] for x in impls]
    baseline_fn = fns[0]
    baseline_label = labels[0]

    print("Benchmark: msgpack_pack implementations")
    print("  " + ", ".join(labels))
    print(
        f"  Timing: n={n_time}, warmup={warmup}, runs={runs} (median), disable_gc={disable_gc}"
    )
    print()

    # Sanity: same output across all
    for payload, sample_label in SAMPLES[:5]:
        ref = baseline_fn(payload)
        for impl_id, impl_label, fn in impls:
            if fn is baseline_fn:
                continue
            got = fn(payload)
            assert (
                ref == got
            ), f"{sample_label} [{impl_label}]: mismatch {ref!r} vs {got!r}"
    print("  Sanity check: same bytes for sample payloads.")
    print()

    # --- Time ---
    col_width = 14 if show_std else 12
    header = f"  {'payload':<16} {'n':<6}"
    for label in labels:
        header += f" {label[: col_width - 4]:<{col_width}}"
    print("  --- Time per call (ms, median over runs) ---")
    print(header)
    print("  " + "-" * (24 + len(labels) * (col_width + 1)))
    time_results: list[list[float]] = []
    time_stds: list[list[float]] = []  # per-cell std in ms
    for payload, sample_label in SAMPLES:
        row_medians: list[float] = []
        row_stds: list[float] = []
        for fn in fns:
            median_sec, std_sec = _time_per_call_median(
                fn, payload, n_time, warmup=warmup, runs=runs, disable_gc=disable_gc
            )
            row_medians.append(median_sec * 1000)
            row_stds.append(std_sec * 1000)
        time_results.append(row_medians)
        time_stds.append(row_stds)
        row_str = f"  {sample_label:<16} {n_time:<6}"
        for i, t in enumerate(row_medians):
            if show_std:
                row_str += f" {t:.4f}±{row_stds[i]:.4f}"
            else:
                row_str += f" {t:<{col_width}.4f}"
        print(row_str)
    print()

    # --- Memory ---
    print("  --- Peak memory (KiB) during run ---")
    print(header)
    print("  " + "-" * (24 + len(labels) * (col_width + 1)))
    mem_results: list[list[float]] = []
    for payload, sample_label in SAMPLES:
        n = N_MEM
        row_mem = []
        for fn in fns:
            row_mem.append(_peak_memory_kb(fn, payload, n))
        mem_results.append(row_mem)
        mem_baseline = row_mem[0]
        row_str = f"  {sample_label:<16} {n:<6}"
        for m in row_mem:
            row_str += f" {m:<{col_width}.2f}"
        print(row_str)
    print()

    # --- Summary ---
    n_payloads = len(SAMPLES)
    print("  --- Summary ---")
    for idx, (impl_id, impl_label, _) in enumerate(impls):
        avg_time_ms = sum(time_results[r][idx] for r in range(n_payloads)) / n_payloads
        avg_mem_kb = sum(mem_results[r][idx] for r in range(n_payloads)) / n_payloads
        speedup_vs_baseline = (
            sum(time_results[r][0] / time_results[r][idx] for r in range(n_payloads))
            / n_payloads
            if idx > 0
            else 1.0
        )
        mem_ratio = (
            sum(mem_results[r][0] / mem_results[r][idx] for r in range(n_payloads))
            / n_payloads
            if idx > 0
            else 1.0
        )
        print(
            f"  [{impl_id}] {impl_label}: avg {avg_time_ms:.4f} ms, {avg_mem_kb:.2f} KiB",
            end="",
        )
        if idx > 0:
            print(
                f"  | speedup vs baseline: {speedup_vs_baseline:.2f}x  mem ratio: {mem_ratio:.2f}x"
            )
        else:
            print("  (baseline)")


if __name__ == "__main__":
    main()
