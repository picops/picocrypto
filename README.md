# Picocrypto
Cryptography tools implemented in Cython (curves: secp256k1, Ed25519).

## Build
```bash
make build
make install
```

## uv
Create venv and install from lockfile, then build and editable install:
```bash
make sync        # uv sync --extra dev (creates .venv, installs deps)
make install-uv  # sync + build + uv pip install -e . --no-build-isolation
```
Update lockfile after changing dependencies: `make lock`.

## PyPI build (sdist + wheel)
`make dist` (sync + build). Output in `dist/`.

## Test
```bash
PYTHONPATH=src python -m pytest tests/ -v
```
Or with uv: `uv run pytest tests/ -v` (after `make sync` or `make install-uv`).

## Benchmarks and profiling
See `benchmarks/README.md` and `benchmarks/PROFILING_EXAMPLES.md`.
