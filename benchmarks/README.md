# Benchmarks

- **Curves:** Compare cycrypto (Cython) vs picocrypto (pure Python):  
  `PYTHONPATH=src:../picocrypto/src python benchmarks/bench_curves.py`
- **Keccak-256:** Compare pure Python vs Cython implementation:  
  `PYTHONPATH=src python benchmarks/bench_keccak.py`  
  (Requires built `keccak` extension in hashes.)
- **msgpack pack:** Compare pure Python vs Cython implementation:  
  `PYTHONPATH=src python benchmarks/bench_msgpack.py`  
  (Requires built `msgpack_pack` extension in serde.)
- **Signing (BIP-137, EIP-712):** Compare pure Python vs Cython implementation:  
  `PYTHONPATH=src python benchmarks/bench_signing.py`  
  (Requires built `bip137` / `eip712` extensions in signing.)

## Example

- **Keccak:** Uses whatever implementation is exposed as `keccak256` in `picocrypto.hashes`:  
  `PYTHONPATH=src python benchmarks/example_keccak.py`

## Profiling

See [PROFILING_EXAMPLES.md](PROFILING_EXAMPLES.md) for cProfile, py-spy, and Scalene.

- cProfile: `PYTHONPATH=src python benchmarks/profile_curves.py -n 20`
- py-spy (native stack): `PYTHONPATH=src py-spy record -o pyspy.svg --native -- python benchmarks/profile_curves.py --workload-only -n 15`
- Scalene: `PYTHONPATH=src scalene run benchmarks/profile_curves.py --workload-only -n 20`
