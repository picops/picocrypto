# Conventions

## File naming: `_{algo}.py` vs `{algo}.{extension}`

- **`_{algo}.py`** – Pure Python implementation (fallback when the Cython extension is not built, or for benchmarks/tests).
- **`{algo}.pyx` / `{algo}.pxd` / `{algo}.pyi`** – Cython implementation. This is the one used by default in the future; when built, it is imported as `.{algo}`.

So the Cython module uses the **public** name (`bip137`, `eip712`, `keccak`, `msgpack_pack`); the Python version uses the **private** name (`_bip137`, `_eip712`, `_keccak`, `_msgpack_pack`).

**By package:**

- **hashes:** `keccak.pyx` = Cython (default); `_keccak.py` = pure Python.
- **serde:** `msgpack_pack.pyx` = Cython (default); `_msgpack_pack.py` = pure Python.
- **signing:** `bip137.pyx`, `eip712.pyx` = Cython (default); `_bip137.py`, `_eip712.py` = pure Python. Package `__init__.py` does `try: from .bip137 import ... except ImportError: from ._bip137 import ...` (same for eip712).
- **curves:** Cython only (`ed25519.pyx`, `secp256k1.pyx`); no `_` Python fallback.
