# cython: language_level=3
# cython: boundscheck=False
# cython: wraparound=False
# cython: cdivision=True
# cython: initializedcheck=False
# cython: nonecheck=False
# cython: overflowcheck=False
# cython: embedsignature=False
# cython: always_allow_keywords=False
"""Keccak-256 (multirate padding, 256-bit output). Optimized Cython implementation."""

from libc.string cimport memcpy, memset
from libc.stdint cimport uint64_t, uint8_t

# Round constants
cdef uint64_t RC[24]
RC[0] = 0x0000000000000001
RC[1] = 0x0000000000008082
RC[2] = 0x800000000000808A
RC[3] = 0x8000000080008000
RC[4] = 0x000000000000808B
RC[5] = 0x0000000080000001
RC[6] = 0x8000000080008081
RC[7] = 0x8000000000008009
RC[8] = 0x000000000000008A
RC[9] = 0x0000000000000088
RC[10] = 0x0000000080008009
RC[11] = 0x000000008000000A
RC[12] = 0x000000008000808B
RC[13] = 0x800000000000008B
RC[14] = 0x8000000000008089
RC[15] = 0x8000000000008003
RC[16] = 0x8000000000008002
RC[17] = 0x8000000000000080
RC[18] = 0x000000000000800A
RC[19] = 0x800000008000000A
RC[20] = 0x8000000080008081
RC[21] = 0x8000000000008080
RC[22] = 0x0000000080000001
RC[23] = 0x8000000080008008

# Rotation offsets - flattened for better access
cdef int ROT[25]
ROT[0] = 0   # ROT[0][0]
ROT[1] = 1   # ROT[0][1]
ROT[2] = 62  # ROT[0][2]
ROT[3] = 28  # ROT[0][3]
ROT[4] = 27  # ROT[0][4]
ROT[5] = 36  # ROT[1][0]
ROT[6] = 44  # ROT[1][1]
ROT[7] = 6   # ROT[1][2]
ROT[8] = 55  # ROT[1][3]
ROT[9] = 20  # ROT[1][4]
ROT[10] = 3  # ROT[2][0]
ROT[11] = 10 # ROT[2][1]
ROT[12] = 43 # ROT[2][2]
ROT[13] = 25 # ROT[2][3]
ROT[14] = 39 # ROT[2][4]
ROT[15] = 41 # ROT[3][0]
ROT[16] = 45 # ROT[3][1]
ROT[17] = 15 # ROT[3][2]
ROT[18] = 21 # ROT[3][3]
ROT[19] = 8  # ROT[3][4]
ROT[20] = 18 # ROT[4][0]
ROT[21] = 2  # ROT[4][1]
ROT[22] = 61 # ROT[4][2]
ROT[23] = 56 # ROT[4][3]
ROT[24] = 14 # ROT[4][4]


# Inline rotation - compiler should optimize this well
cdef inline uint64_t rol64(uint64_t v, int n) noexcept nogil:
    """64-bit left rotation. Compiler should use ROL instruction."""
    return (v << n) | (v >> (64 - n))


# Load 64-bit little-endian - optimized version
cdef inline uint64_t load64_le(const uint8_t* p) noexcept nogil:
    """Load 64-bit value from little-endian byte array."""
    return (<uint64_t>p[0]) | \
           (<uint64_t>p[1] << 8) | \
           (<uint64_t>p[2] << 16) | \
           (<uint64_t>p[3] << 24) | \
           (<uint64_t>p[4] << 32) | \
           (<uint64_t>p[5] << 40) | \
           (<uint64_t>p[6] << 48) | \
           (<uint64_t>p[7] << 56)


# Store 64-bit little-endian
cdef inline void store64_le(uint8_t* p, uint64_t v) noexcept nogil:
    """Store 64-bit value to little-endian byte array."""
    p[0] = <uint8_t>(v & 0xFF)
    p[1] = <uint8_t>((v >> 8) & 0xFF)
    p[2] = <uint8_t>((v >> 16) & 0xFF)
    p[3] = <uint8_t>((v >> 24) & 0xFF)
    p[4] = <uint8_t>((v >> 32) & 0xFF)
    p[5] = <uint8_t>((v >> 40) & 0xFF)
    p[6] = <uint8_t>((v >> 48) & 0xFF)
    p[7] = <uint8_t>((v >> 56) & 0xFF)


# Keccak-f[1600] permutation - state row-major: state[x][y] = state[x*5+y] (match C 2D layout)
cdef void keccak_f1600(uint64_t* state) noexcept nogil:
    """Keccak-f[1600] permutation; state[x][y] at flat index x*5+y."""
    cdef uint64_t c[5]
    cdef uint64_t d[5]
    cdef uint64_t b[25]
    cdef int r, x, y, idx

    for r in range(24):
        for x in range(5):
            c[x] = state[x * 5] ^ state[x * 5 + 1] ^ state[x * 5 + 2] ^ state[x * 5 + 3] ^ state[x * 5 + 4]
        for x in range(5):
            d[x] = rol64(c[(x + 1) % 5], 1) ^ c[(x + 4) % 5]
        for idx in range(25):
            state[idx] ^= d[idx // 5]
        for x in range(5):
            for y in range(5):
                idx = x * 5 + y
                b[y * 5 + (2 * x + 3 * y) % 5] = rol64(state[idx], ROT[y * 5 + x])
        for x in range(5):
            for y in range(5):
                idx = x * 5 + y
                state[idx] = b[idx] ^ ((~b[((x + 1) % 5) * 5 + y]) & b[((x + 2) % 5) * 5 + y])
        state[0] ^= RC[r]


# Public API for other packages: same signatures as the original implementation
cdef uint64_t _rol64(uint64_t v, int n) noexcept nogil:
    """64-bit left rotation; n is reduced mod 64. Exposed for use from other packages."""
    n = n % 64
    return rol64(v, n)


cdef void _keccak_f(uint64_t state[5][5]) noexcept nogil:
    """Keccak-f[1600] permutation; state[x][y]. Exposed for use from other packages."""
    keccak_f1600(<uint64_t*>state)


cpdef bytes keccak256(bytes data):
    """Keccak-256 (multirate padding, 256-bit digest).

    Optimizations: flattened state, load64_le/store64_le, inline helpers,
    no Python object creation in hot path, memcpy/memset from libc.
    """
    cdef int RATE_BYTES = 136  # (1600 - 512) / 8
    cdef int LANES_PER_BLOCK = 17  # RATE_BYTES / 8

    cdef uint64_t state[25]
    cdef uint8_t temp[136]
    cdef const uint8_t* data_ptr = <const uint8_t*>(<char*>data)
    cdef size_t data_len = len(data)
    cdef size_t block_start
    cdef size_t remaining
    cdef int i
    cdef uint8_t output[32]
    cdef bytearray out_ba

    # Initialize state to zero
    memset(state, 0, 25 * sizeof(uint64_t))

    # Absorb full blocks (lane i -> state[x][y] with x=i%5, y=i//5 -> flat index x*5+y)
    block_start = 0
    while block_start + RATE_BYTES <= data_len:
        for i in range(LANES_PER_BLOCK):
            state[(i % 5) * 5 + (i // 5)] ^= load64_le(data_ptr + block_start + i * 8)
        keccak_f1600(state)
        block_start += RATE_BYTES

    # Padding - only add when there is remainder (or empty input)
    remaining = data_len - block_start

    if remaining == 0 and block_start == 0:
        # Empty input: one block 0x01 || 0x00* || 0x80
        memset(temp, 0, RATE_BYTES)
        temp[0] = 0x01
        temp[RATE_BYTES - 1] = 0x80
        for i in range(LANES_PER_BLOCK):
            state[(i % 5) * 5 + (i // 5)] ^= load64_le(temp + i * 8)
        keccak_f1600(state)
    elif remaining > 0:
        if <int>remaining == RATE_BYTES - 1:
            memcpy(temp, data_ptr + block_start, remaining)
            temp[remaining] = 0x01
            for i in range(LANES_PER_BLOCK):
                state[(i % 5) * 5 + (i // 5)] ^= load64_le(temp + i * 8)
            keccak_f1600(state)
            memset(temp, 0, RATE_BYTES)
            temp[0] = 0x80
            for i in range(LANES_PER_BLOCK):
                state[(i % 5) * 5 + (i // 5)] ^= load64_le(temp + i * 8)
            keccak_f1600(state)
        else:
            memset(temp, 0, RATE_BYTES)
            memcpy(temp, data_ptr + block_start, remaining)
            temp[remaining] = 0x01
            temp[RATE_BYTES - 1] |= 0x80
            for i in range(LANES_PER_BLOCK):
                state[(i % 5) * 5 + (i // 5)] ^= load64_le(temp + i * 8)
            keccak_f1600(state)

    # Squeeze: state[0][0]..state[3][0] -> indices 0, 5, 10, 15
    for i in range(4):
        store64_le(output + i * 8, state[i * 5])

    out_ba = bytearray(32)
    for i in range(32):
        out_ba[i] = output[i]
    return bytes(out_ba)
