# Profiling examples: cProfile vs py-spy vs Scalene

Run from repo root with `PYTHONPATH=src`.

## 1. cProfile
```bash
PYTHONPATH=src python benchmarks/profile_curves.py -n 20
PYTHONPATH=src python benchmarks/profile_curves.py -n 20 -o curves && snakeviz curves.prof
```

## 2. py-spy (Python + C stack)
```bash
PYTHONPATH=src py-spy record -o pyspy.svg --native -- python benchmarks/profile_curves.py --workload-only -n 15
```
Open `pyspy.svg` in a browser.

## 3. Scalene (Python vs native + memory)
Scalene 2.x: `scalene run ...`
```bash
PYTHONPATH=src scalene run benchmarks/profile_curves.py --workload-only -n 20
PYTHONPATH=src scalene run --html --outfile scalene_report.html benchmarks/profile_curves.py --workload-only -n 20
```
