"""
Limb-based big-integer example for curves (reference only).

Shows how 256-bit field elements could be represented with C limbs
instead of Python int, for use in secp256k1/Ed25519-style code.
Not built by the package; for reference and as a template.
"""

cdef extern from "stdint.h":
    ctypedef unsigned long long uint64_t

# 256-bit value = 4 x 64-bit limbs (little-endian)
# X = limbs[0] + limbs[1]*2^64 + limbs[2]*2^128 + limbs[3]*2^192
cdef unsigned int NLIMBS = 4

# -----------------------------------------------------------------------------
# Addition: C = A + B (no modular reduction)
# -----------------------------------------------------------------------------
cdef void add_256(uint64_t c[4], uint64_t a[4], uint64_t b[4]) nogil:
    cdef uint64_t carry = 0
    cdef uint64_t t
    cdef int i
    for i in range(4):
        t = a[i] + carry
        carry = 1 if t < a[i] else 0
        c[i] = t + b[i]
        if c[i] < t:
            carry = 1

# -----------------------------------------------------------------------------
# Reduce modulo secp256k1 prime: p = 2^256 - 2^32 - 977
# After add/sub/mul we get up to 5 limbs; reduction brings back to 4.
# (Conceptual: full reduction would go here; this is a stub.)
# -----------------------------------------------------------------------------
cdef void reduce_secp256k1(uint64_t r[4], uint64_t t[5]) nogil:
    # Real impl: use the identity 2^256 ≡ 2^32 + 977 (mod p)
    # to reduce the high limb into the lower limbs, then subtract p
    # until result < p. Left as stub.
    r[0] = t[0]
    r[1] = t[1]
    r[2] = t[2]
    r[3] = t[3]

# -----------------------------------------------------------------------------
# Load Python int into limbs (little-endian, 32 bytes max)
# -----------------------------------------------------------------------------
cdef void limbs_from_int(uint64_t limbs[4], object val) except *:
    cdef bytes b = val.to_bytes(32, "little")
    limbs[0] = int.from_bytes(b[0:8], "little")
    limbs[1] = int.from_bytes(b[8:16], "little")
    limbs[2] = int.from_bytes(b[16:24], "little")
    limbs[3] = int.from_bytes(b[24:32], "little")

# -----------------------------------------------------------------------------
# Store limbs as Python int (for testing)
# -----------------------------------------------------------------------------
cdef object int_from_limbs(uint64_t limbs[4]):
    cdef object a = <object>limbs[0]
    cdef object b = <object>limbs[1]
    cdef object c = <object>limbs[2]
    cdef object d = <object>limbs[3]
    return a + (b << 64) + (c << 128) + (d << 192)

# -----------------------------------------------------------------------------
# Example: add two 256-bit integers (no mod) and return result as Python int
# -----------------------------------------------------------------------------
cpdef object limbs_add_example(object a, object b):
    cdef uint64_t a_limbs[4]
    cdef uint64_t b_limbs[4]
    cdef uint64_t c_limbs[4]
    limbs_from_int(a_limbs, a & ((1 << 256) - 1))
    limbs_from_int(b_limbs, b & ((1 << 256) - 1))
    add_256(c_limbs, a_limbs, b_limbs)
    return int_from_limbs(c_limbs)
