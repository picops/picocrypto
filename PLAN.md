# Curves performance: development plan

Rough order of impact vs effort. API and behavior stay the same; only the implementation behind the curves changes.

---

## Phase 0: Already in place

- [x] **Cython** – `cdef`/`cpdef`, `cdef inline` on hot helpers (`_point_add`, `_point_mul`, etc.).
- [x] **Compiler directives** – `boundscheck=False`, `wraparound=False`, `cdivision=True`, `infer_types=True`.
- [x] **Build** – Picolib-style (`get_cython_build_dir`), `-O3`, `-march=native`.

No action; baseline is set.

---

## Phase 1: Profile and small cleanups (low effort, small gain)

**Goal:** Know where time goes, then trim obvious overhead.

### Step 1.1 – Profile

1. Run a profiler (e.g. **py-spy**, **cProfile**) on:
   - secp256k1: `sign_recoverable` (and key derivation if used).
   - Ed25519: `ed25519_sign`, `ed25519_verify`.
2. Measure where time is spent:
   - `% _P` / `% _N` (field/scalar mod).
   - `_point_add` / `_point_mul`.
   - `keccak256`, hashlib.
   - `.to_bytes` / `.hex()`, bytes concatenation.
3. Record the top N hotspots and % of time; use this to decide what to optimize first.

**Deliverable:** Profiling report or notes (e.g. in `benchmarks/` or `docs/`) with main hotspots.

### Step 1.2 – Fewer Python objects in hot loops

1. In the innermost curve loops, avoid creating **tuples** for point coordinates where possible.
2. Options: return/pass points via a **small `cdef class`** or **C struct** (still using Python ints for coordinates).
3. Keep the same math; only change how points are passed/returned.

**Effort:** Low. **Gain:** Modest.

### Step 1.3 – Trim Python API usage in the hot path

1. Reduce repeated **`int.from_bytes`** / **`.to_bytes`** where buffers can be reused or sizes are fixed.
2. Reduce **`bytes([0x04]) + ...`** and **`.hex()`** where minimal concatenation or prebuilt constants suffice.
3. Prefer reuse and fewer allocations over one-off convenience calls.

**Effort:** Low. **Gain:** Incremental.

---

## Phase 2: C helpers for field arithmetic (medium effort, high gain)

**Goal:** Move heavy mod work out of Python ints; keep current API and structure.

### Step 2.1 – Limb-based mod in C

1. **Representation:** Field elements as fixed limbs (e.g. 8× `uint32_t` or 4× `uint64_t` for 256-bit).
2. **Implement in C** (new C file or Cython `cdef extern` to C):
   - **mod add/sub** for the curve prime.
   - **mod mul** (and optionally **Montgomery form** for secp256k1).
   - **mod inverse** (e.g. extended GCD or Fermat in Montgomery form).
3. Use curve-specific reduction where applicable (e.g. secp256k1: `p = 2^256 - 2^32 - 977`; Ed25519: `p = 2^255 - 19`).

**Reference:** `examples/limbs_example.pyx` for limb layout and add.

### Step 2.2 – Call C from Cython

1. At the **boundary:** convert Python int → limbs when entering the hot path; convert limbs → Python int when returning.
2. **Inside the hot path:** run point add, scalar mul, and mod inverse using the C limb routines only (no Python ints in the inner loops).
3. Keep existing function signatures and public API; only the implementation of field ops (and thus point ops) changes.

**Effort:** Medium. **Gain:** Large (often order of magnitude on point add/mul and mod inverse).

---

## Phase 3: Full limb-based or C library backend (high effort, max gain)

Choose one direction (or do C lib first, then optional full limb-based later).

### Option A – Full limb-based in Cython/C

1. Represent **scalars and point coordinates as limbs** everywhere in the hot path.
2. Implement **group ops** (point add, scalar mul) and **field ops** in C or in Cython with typed memoryviews.
3. No Python ints in inner loops; optional **nogil** for parallelism.
4. Most control and potential performance; most implementation work.

**Effort:** High. **Gain:** Very high.

### Option B – C library backend

1. **secp256k1:** Use **libsecp256k1** via `cdef extern` or ctypes/cffi.
2. **Ed25519:** Use **libsodium** or **Ed25519-dalek** (or similar) for sign/verify and keygen.
3. Expose the **same Python API** (e.g. `privkey_to_pubkey`, `sign_recoverable`, `ed25519_sign`, `ed25519_verify`); implementation becomes a thin wrapper around the C API.
4. Handle **dependency and packaging** (optional backends, or required native libs).

**Effort:** Medium (per curve). **Gain:** Very high; easiest path to near-native speed.

---

## Phase 4: Parallelism

1. **Single sign/verify** – Largely sequential; little to parallelize inside one call.
2. **Batch** – For many sign/verify operations, run them in parallel (e.g. `concurrent.futures`, multiple processes or threads).
3. **Real benefit** from parallelism appears when the backend can run **without the GIL** (C lib or nogil Cython). With current Python-int code, batch parallelism still helps but is limited by the GIL.

**Step:** Add batch helpers or document batch usage once a nogil/C backend exists (Phase 2 or 3).

---

## Phase 5: Other HPC-style ideas (optional, after limbs or C lib)

- **SIMD** – Only after limb-based C: use AVX2 (or similar) for limb add/sub/mul in the field layer.
- **Fixed-base tables** – Precompute windowed tables for scalar multiplication by the standard generator to speed up repeated “multiply by G” (e.g. in signing); cost is code size and memory.
- **nogil** – Only useful when the hot path uses C/limb backend (no Python objects in inner loops).

---

## Summary: what to do next

| Direction | Effort | Gain | Notes |
|-----------|--------|------|--------|
| **Phase 1** – Profile + small cleanups | Low | Small | Do first; confirms where time goes. |
| **Phase 2** – C helpers for mod mul/inv (limbs) | Medium | High | Best next step for “still Cython, no C lib”. |
| **Phase 3B** – libsecp256k1 + libsodium (or similar) | Medium | Very high | Easiest path to max speed; optional backends. |
| **Phase 3A** – Full limb-based backend | High | Very high | Full control, no new deps; most work. |
| **Phase 4** – Parallelism (batch) | Low–Medium | Depends on backend | Meaningful once GIL-free backend exists. |
| **Phase 5** – SIMD / fixed-base / nogil | Medium–High | Extra on top of limbs | After Phase 2 or 3. |

**Recommended sequence:**

1. **Phase 1** – Profile, then small cleanups (struct/class for points, trim `.to_bytes`/concat).
2. **Phase 2** – Add C/limb-based field arithmetic; keep API, swap implementation.
3. **Phase 3** – Either optional C lib backends (3B) or full limb-based (3A), depending on dependency vs control preference.
4. **Phase 4–5** – Parallelism and SIMD/tables as needed after a fast backend is in place.

All of this can be done without changing the current curve API or behavior, only the implementation behind it.
