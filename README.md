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

## PyPI build and publish
- **Build:** `make dist` (sync + build). Output in `dist/`.
- **Publish (CI):** Push a tag `v*` (e.g. `v0.0.1`) → GitHub Actions builds and publishes to PyPI. Configure [Trusted Publishing](https://docs.pypi.org/trusted-publishers/) on PyPI once (owner, repo `picocrypto`, workflow `publish.yml`).
- **Publish (manual):** `make dist` then `make upload` (uses `twine upload dist/*`; set PyPI token via `TWINE_USERNAME=__token__` and `TWINE_PASSWORD=pypi-...` or `~/.pypirc`).

## Test
```bash
PYTHONPATH=src python -m pytest tests/ -v
```
Or with uv: `uv run pytest tests/ -v` (after `make sync` or `make install-uv`).

## Benchmarks and profiling
See `benchmarks/README.md` and `benchmarks/PROFILING_EXAMPLES.md`.
