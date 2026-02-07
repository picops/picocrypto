"""
Benchmark msgpack pack: pure Python (msgpack_pack) vs Cython (msgpack_pack_cy).
Compares time per call and peak memory (tracemalloc) per run.

Run from repo root:

  PYTHONPATH=src python benchmarks/bench_msgpack.py

Or after pip install -e .:

  python benchmarks/bench_msgpack.py
"""

from __future__ import annotations

import os
import sys
import time
import tracemalloc

_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_src = os.path.join(_root, "src")
if _src not in sys.path:
    sys.path.insert(0, _src)

from picocrypto.serde import msgpack_pack as msgpack_pack_cy
from picocrypto.serde.msgpack_pack_2 import msgpack_pack as msgpack_pack_py

if msgpack_pack_py is None:
    print(
        "msgpack_pack_py not available (extension not built). Run: make build install"
    )
    sys.exit(1)

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


def _n_time(_payload: object) -> int:
    return N_TIME


def _n_mem(_payload: object) -> int:
    return N_MEM


def _time_per_call(fn, payload: object, n: int, warmup: int = 20) -> float:
    for _ in range(warmup):
        fn(payload)
    start = time.perf_counter()
    for _ in range(n):
        fn(payload)
    return (time.perf_counter() - start) / n


def _peak_memory_kb(fn, payload: object, n: int) -> float:
    tracemalloc.start()
    if hasattr(tracemalloc, "reset_peak"):
        tracemalloc.reset_peak()
    for _ in range(n):
        fn(payload)
    _current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    return peak / 1024.0


def main() -> None:
    print("Benchmark: msgpack_pack  pure Python vs Cython")
    print("  (msgpack_pack.msgpack_pack vs msgpack_pack_cy.msgpack_pack)")
    print()

    # Sanity: same output
    for payload, label in SAMPLES[:5]:
        a = msgpack_pack_py(payload)
        b = msgpack_pack_cy(payload)
        assert a == b, f"{label}: mismatch {a!r} vs {b!r}"
    print("  Sanity check: same bytes for sample payloads.")
    print()

    print("  Time/memory: iterations scale per payload.")
    print()

    # --- Time ---
    print("  --- Time per call (ms) ---")
    print(
        f"  {'payload':<16} {'n':<6} {'Python (ms)':<14} {'Cython (ms)':<14} {'speedup':<10}"
    )
    print("  " + "-" * 64)
    time_results: list[tuple[str, float, float, float]] = []
    for payload, label in SAMPLES:
        n = _n_time(payload)
        t_py = _time_per_call(msgpack_pack_py, payload, n) * 1000
        t_cy = _time_per_call(msgpack_pack_cy, payload, n) * 1000
        speedup = t_py / t_cy if t_cy > 0 else 0
        time_results.append((label, t_py, t_cy, speedup))
        print(f"  {label:<16} {n:<6} {t_py:<14.4f} {t_cy:<14.4f} {speedup:.2f}x")
    print()

    # --- Memory ---
    print("  --- Peak memory (KiB) during run ---")
    print(
        f"  {'payload':<16} {'n':<6} {'Python (KiB)':<14} {'Cython (KiB)':<14} {'ratio':<10}"
    )
    print("  " + "-" * 64)
    mem_results: list[tuple[str, float, float, float]] = []
    for payload, label in SAMPLES:
        n = _n_mem(payload)
        mem_py = _peak_memory_kb(msgpack_pack_py, payload, n)
        mem_cy = _peak_memory_kb(msgpack_pack_cy, payload, n)
        ratio = mem_py / mem_cy if mem_cy > 0 else 0
        mem_results.append((label, mem_py, mem_cy, ratio))
        print(f"  {label:<16} {n:<6} {mem_py:<14.2f} {mem_cy:<14.2f} {ratio:.2f}x")
    print()

    # --- Summary ---
    avg_speedup = sum(r[3] for r in time_results) / len(time_results)
    avg_mem_ratio = sum(r[3] for r in mem_results) / len(mem_results)
    print("  --- Summary ---")
    print(f"  Average time speedup (Cython vs Python): {avg_speedup:.2f}x")
    print(f"  Average memory ratio (Python/Cython):   {avg_mem_ratio:.2f}x")


if __name__ == "__main__":
    main()
