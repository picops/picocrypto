# cycrypto
Cryptography tools implemented in Cython (curves: secp256k1, Ed25519).

## Build
```bash
make build
make install
```

## Test
```bash
PYTHONPATH=src python -m pytest tests/ -v
```

## Benchmarks and profiling
See `benchmarks/README.md` and `benchmarks/PROFILING_EXAMPLES.md`.
