# Benchmarks

Compare **cycrypto** (Cython curves) vs **picocrypto** (pure Python): `PYTHONPATH=src:../picocrypto/src python benchmarks/bench_curves.py`

## Profiling

See [PROFILING_EXAMPLES.md](PROFILING_EXAMPLES.md) for cProfile, py-spy, and Scalene.

- cProfile: `PYTHONPATH=src python benchmarks/profile_curves.py -n 20`
- py-spy (native stack): `PYTHONPATH=src py-spy record -o pyspy.svg --native -- python benchmarks/profile_curves.py --workload-only -n 15`
- Scalene: `PYTHONPATH=src scalene run benchmarks/profile_curves.py --workload-only -n 20`
