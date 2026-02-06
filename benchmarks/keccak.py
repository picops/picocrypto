"""
Benchmark Keccak-256: pure Python (keccak) vs Cython (keccak_cy).
Compares time per call and peak memory (tracemalloc) per run.

Run from repo root:

  PYTHONPATH=src python benchmarks/bench_keccak.py

Or after pip install -e .:

  python benchmarks/bench_keccak.py
"""

from __future__ import annotations

import os
import sys
import time
import tracemalloc

# Prefer repo src on path so we use local code
_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_src = os.path.join(_root, "src")
if _src not in sys.path:
    sys.path.insert(0, _src)

from picocrypto.hashes import keccak256 as keccak256_cy
from picocrypto.hashes._keccak import keccak256 as keccak256_py

# Sample payloads (bytes); kept small so benchmark stays fast
SAMPLES = [
    (b"", "empty"),
    (b"hello", "short"),
    (b"x" * 64, "64 B"),
    (b"x" * 256, "256 B"),
    (b"x" * 1024, "1 KiB"),
]

N_TIME = 5000
N_MEM = 2000  # iterations for memory run


# Fewer iterations for larger payloads so run stays quick
def _n_time(data_len: int) -> int:
    if data_len <= 256:
        return 5000
    if data_len <= 1024:
        return 1000
    return max(100, 5000 // (1 + data_len // 1024))


def _n_mem(data_len: int) -> int:
    if data_len <= 256:
        return 2000
    if data_len <= 1024:
        return 500
    return max(100, 2000 // (1 + data_len // 1024))


def _time_per_call(fn, data: bytes, n: int = N_TIME, warmup: int = 50) -> float:
    for _ in range(warmup):
        fn(data)
    start = time.perf_counter()
    for _ in range(n):
        fn(data)
    return (time.perf_counter() - start) / n


def _peak_memory_kb(fn, data: bytes, n: int = N_MEM) -> float:
    """Peak traced memory (KiB) during n calls. Resets peak before run if available."""
    tracemalloc.start()
    if hasattr(tracemalloc, "reset_peak"):
        tracemalloc.reset_peak()
    for _ in range(n):
        fn(data)
    current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    return peak / 1024.0


def main() -> None:
    print("Benchmark: Keccak-256  pure Python vs Cython")
    print("  (keccak.keccak256 vs keccak_cy.keccak256)")
    print()

    # Sanity: same digest
    msg = b"test"
    a = keccak256_py(msg)
    b = keccak256_cy(msg)
    assert a == b, f"digest mismatch: {a.hex()} vs {b.hex()}"
    print(f"  Sanity check: both give {a.hex()[:32]}...")
    print()

    print("  Time/memory: iterations scale down for larger payloads.")
    print()

    # --- Time ---
    print("  --- Time per call (ms) ---")
    print(
        f"  {'size':<10} {'n':<8} {'Python (ms)':<14} {'Cython (ms)':<14} {'speedup':<10}"
    )
    print("  " + "-" * 58)
    time_results: list[tuple[str, float, float, float]] = []
    for data, label in SAMPLES:
        n = _n_time(len(data))
        t_py = _time_per_call(keccak256_py, data, n=n) * 1000
        t_cy = _time_per_call(keccak256_cy, data, n=n) * 1000
        speedup = t_py / t_cy if t_cy > 0 else 0
        time_results.append((label, t_py, t_cy, speedup))
        print(f"  {label:<10} {n:<8} {t_py:<14.4f} {t_cy:<14.4f} {speedup:.2f}x")
    print()

    # --- Memory ---
    print("  --- Peak memory (KiB) during run ---")
    print(
        f"  {'size':<10} {'n':<8} {'Python (KiB)':<14} {'Cython (KiB)':<14} {'ratio':<10}"
    )
    print("  " + "-" * 58)
    mem_results: list[tuple[str, float, float, float]] = []
    for data, label in SAMPLES:
        n = _n_mem(len(data))
        mem_py = _peak_memory_kb(keccak256_py, data, n=n)
        mem_cy = _peak_memory_kb(keccak256_cy, data, n=n)
        ratio = mem_py / mem_cy if mem_cy > 0 else 0
        mem_results.append((label, mem_py, mem_cy, ratio))
        print(f"  {label:<10} {n:<8} {mem_py:<14.2f} {mem_cy:<14.2f} {ratio:.2f}x")
    print()

    # --- Summary ---
    avg_speedup = sum(r[3] for r in time_results) / len(time_results)
    avg_mem_ratio = sum(r[3] for r in mem_results) / len(mem_results)
    print("  --- Summary ---")
    print(f"  Average time speedup (Cython vs Python): {avg_speedup:.2f}x")
    print(f"  Average memory ratio (Python/Cython):   {avg_mem_ratio:.2f}x")
    print()


if __name__ == "__main__":
    main()
