# Plan: HPC via Python extensions

Goal: improve performance of picocrypto using compiled extensions while keeping the same public API and, where practical, a pure-Python fallback. No API changes.

---

## 1. Hot paths (candidates for acceleration)

| Area | Module | Bottlenecks | Priority |
|------|--------|-------------|----------|
| **Hashes** | `hashes/keccak.py` | `keccak256`, `_keccak_f`, inner loops over state | **High** – used by secp256k1, EIP-712, addresses |
| **Curves** | `curves/secp256k1.py` | `_point_add`, `_point_mul`, `_mod_inv`, big-int arithmetic | **High** – sign, verify, recover |
| **Curves** | `curves/ed25519.py` | `_point_add`, `_point_mul`, field ops, SHA-512 (already C via stdlib) | **Medium** – smaller scope than secp256k1 |
| **Serde** | `serde/msgpack_pack.py` | `_msgpack_pack_obj`, type dispatch, buffer writes | **Low** – only if large-payload serialization matters |

Signing modules (`signing/eip712.py`, `signing/bip137.py`) are thin orchestration; speed gains come from hashes and curves.

---

## 2. Extension options (no code change yet – choose later)

| Approach | Pros | Cons |
|----------|------|------|
| **Cython** (translate existing .py → .pyx) | Same logic, gradual typing, project already has Cython in build | Need to maintain .pyx; big-int still Python unless we use C types / custom limb representation |
| **Cython + C helpers** | Keccak/field ops in small C files called from Cython; max control | More build surface (C + Cython) |
| **ctypes/cffi bindings** | Bind to libsecp256k1, libsodium (Ed25519), existing C Keccak; minimal code in Python | New deps, packaging of C libs or wheels, less control over algorithm details |
| **Rust + PyO3** | One extension module, fast crypto crates (e.g. `sha3`, `k256`, `ed25519-dalek`) | Second language, separate crate, build toolchain |
| **Numba** | Decorate hot functions, JIT | Weak for big-int and complex structs; better for arrays; not a natural fit here |

**Recommendation for plan:** assume **Cython-first** for hashes and curves (keeps one codebase, aligns with current build). Optionally add **optional C lib bindings** (e.g. libsecp256k1) as a separate phase if we need maximum curve performance and accept the dependency.

---

## 3. Development phases (order to follow later)

### Phase 0 – Baseline (before any extension)

- Add a small **benchmark** script or pytest plugin that measures:
  - `keccak256` (e.g. 1 MiB input, 10k small inputs).
  - `sign_recoverable` / `recover_pubkey` (e.g. 1000 sign/recover cycles).
  - `ed25519_sign` / `ed25519_verify` (e.g. 1000 sign/verify cycles).
- Record results (time, throughput) as baseline in PLAN.md or `bench/` so we can compare after each phase.

### Phase 1 – Hashes (Keccak-256)

- **Target:** `hashes/keccak.py` → Cython or C.
- **Options:**
  - **1a.** Add `hashes/keccak.pyx` (or `hashes/keccak_cy.pyx`) with the same algorithm; use `try: from .keccak_cy import keccak256 except ImportError: from .keccak import keccak256` in `hashes/__init__.py` so pure Python remains fallback when extension is not built.
  - **1b.** Or convert `keccak.py` to `keccak.pyx` and ship a pre-built wheel; pure Python only in sdist / if build skipped.
- **Build:** Ensure `setuptools` compiles the `.pyx` (already using Cython in pyproject.toml); add `Extension` in `setup.py` or `[tool.setuptools.packages]` / `[tool.cython]` as needed.
- **Validation:** Existing tests must pass; benchmark Phase 0 vs Phase 1 and document speedup.

### Phase 2 – Curves: secp256k1

- **Target:** `curves/secp256k1.py` – point add, point mul, mod inverse, and everything needed for `sign_recoverable`, `recover_pubkey`, `privkey_to_pubkey`, `privkey_to_address`.
- **Options:**
  - **2a.** Cythonize the same Python logic (typed variables, C-sized ints where possible; big-int will still be Python objects unless we introduce a limb-based C representation).
  - **2b.** Optional binding to **libsecp256k1** (e.g. ctypes/cffi): implement the same Python function names in a `curves/secp256k1_native.py` that calls the C library; use try/except in `curves/__init__.py` to prefer native and fall back to pure Python.
- **Validation:** All existing curve/signing tests pass; benchmark sign/recover and key derivation.

### Phase 3 – Curves: Ed25519

- **Target:** `curves/ed25519.py` – field arithmetic, point ops, sign/verify.
- **Options:**
  - **3a.** Cythonize current logic (same idea as secp256k1).
  - **3b.** Optional binding to **libsodium** or **PyNaCl** (or a small C Ed25519 lib): same pattern as secp256k1 – native module with fallback.
- **Validation:** Existing Ed25519 tests; benchmark sign/verify.

### Phase 4 – Serde (optional)

- **Target:** `serde/msgpack_pack.py` only if benchmarks show it as a bottleneck (e.g. huge nested structures).
- **Action:** Either Cythonize `_msgpack_pack_obj` and buffer handling, or leave as-is.
- **Validation:** Serde tests; benchmark pack throughput if implemented.

### Phase 5 – CI and packaging

- **CI:** Build the extension(s) in the CI environment (install Cython, compiler); run the full test suite and, if present, the benchmark script.
- **Packaging:** Ensure wheels ship the compiled extension for the supported platforms; sdists can ship Cython source and compile on install.
- **Docs:** In README or CONTRIBUTING, note that building from source requires a C compiler and Cython; optional C libs only if we add bindings.

---

## 4. File layout (to adopt when implementing)

- **Hashes**
  - Keep: `hashes/keccak.py` (pure Python, always present).
  - Add (Phase 1): `hashes/keccak.pyx` or `hashes/keccak_cy.pyx`; `hashes/__init__.py` does try/except to prefer compiled `keccak256` and fall back to `keccak.py`.
- **Curves**
  - Keep: `curves/secp256k1.py`, `curves/ed25519.py` (pure Python).
  - Add (Phase 2/3): either `.pyx` variants or `curves/secp256k1_native.py` / `curves/ed25519_native.py` that wrap C libs; `curves/__init__.py` tries native then fallback.
- **Serde**
  - Unchanged unless Phase 4 is done; then optional `serde/msgpack_pack.pyx` with same try/except pattern in `serde/__init__.py`.
- **Signing**
  - No extension; they keep calling hashes and curves via the same public API.

---

## 5. Testing and compatibility

- **Behavior:** All existing tests must pass with the extension enabled and, where fallback exists, with the extension disabled (e.g. rename or don’t build the .pyx to force pure Python).
- **Output:** Extension and pure Python must produce identical digests/signatures/addresses; add a small test that runs the same inputs through both and compares (e.g. via an env var or a temporary code path that forces pure Python when extension is present).
- **Python versions:** Stick to the project’s `requires-python` (e.g. >=3.13); build wheels for the same range.

---

## 6. Success criteria (before closing the plan)

- [ ] Phase 0: Baseline benchmarks documented.
- [ ] Phase 1: Keccak-256 extension built and used when available; benchmark shows clear speedup; tests pass with and without extension.
- [ ] Phase 2: secp256k1 accelerated (Cython or libsecp256k1); tests and benchmarks pass.
- [ ] Phase 3: Ed25519 accelerated if planned; same as Phase 2.
- [ ] Phase 4: Serde only if justified by benchmarks.
- [ ] Phase 5: CI builds extensions and runs tests; wheels include the extension where intended.

---

## 7. Out of scope (for this plan)

- Changing the public API or adding new crypto primitives.
- Supporting Python versions below the project’s minimum.
- Implementing unpack/decoding in serde (separate feature).
- Cryptographic side-channel hardening (can be a later, separate plan).
