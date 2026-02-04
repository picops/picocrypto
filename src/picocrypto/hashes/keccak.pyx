"""Keccak-256 (multirate padding, 256-bit output). Cython implementation."""

# Declarations in keccak.pxd; module-private data and implementations here.
cdef uint64_t _RC[24]
_RC[0] = 0x0000000000000001
_RC[1] = 0x0000000000008082
_RC[2] = 0x800000000000808A
_RC[3] = 0x8000000080008000
_RC[4] = 0x000000000000808B
_RC[5] = 0x0000000080000001
_RC[6] = 0x8000000080008081
_RC[7] = 0x8000000000008009
_RC[8] = 0x000000000000008A
_RC[9] = 0x0000000000000088
_RC[10] = 0x0000000080008009
_RC[11] = 0x000000008000000A
_RC[12] = 0x000000008000808B
_RC[13] = 0x800000000000008B
_RC[14] = 0x8000000000008089
_RC[15] = 0x8000000000008003
_RC[16] = 0x8000000000008002
_RC[17] = 0x8000000000000080
_RC[18] = 0x000000000000800A
_RC[19] = 0x800000008000000A
_RC[20] = 0x8000000080008081
_RC[21] = 0x8000000000008080
_RC[22] = 0x0000000080000001
_RC[23] = 0x8000000080008008

cdef int _ROT[5][5]
_ROT[0][0], _ROT[0][1], _ROT[0][2], _ROT[0][3], _ROT[0][4] = 0, 1, 62, 28, 27
_ROT[1][0], _ROT[1][1], _ROT[1][2], _ROT[1][3], _ROT[1][4] = 36, 44, 6, 55, 20
_ROT[2][0], _ROT[2][1], _ROT[2][2], _ROT[2][3], _ROT[2][4] = 3, 10, 43, 25, 39
_ROT[3][0], _ROT[3][1], _ROT[3][2], _ROT[3][3], _ROT[3][4] = 41, 45, 15, 21, 8
_ROT[4][0], _ROT[4][1], _ROT[4][2], _ROT[4][3], _ROT[4][4] = 18, 2, 61, 56, 14


cdef uint64_t _rol64(uint64_t v, int n) noexcept nogil:
    n = n % 64
    return (v << n) | (v >> (64 - n))


cdef void _keccak_f(uint64_t state[5][5]) noexcept nogil:
    cdef uint64_t c[5]
    cdef uint64_t d[5]
    cdef uint64_t b[5][5]
    cdef int r, x, y
    for r in range(24):
        for x in range(5):
            c[x] = state[x][0] ^ state[x][1] ^ state[x][2] ^ state[x][3] ^ state[x][4]
        for x in range(5):
            d[x] = _rol64(c[(x + 1) % 5], 1) ^ c[(x + 4) % 5]
        for x in range(5):
            for y in range(5):
                state[x][y] ^= d[x]
        for x in range(5):
            for y in range(5):
                b[y][(2 * x + 3 * y) % 5] = _rol64(state[x][y], _ROT[y][x])
        for x in range(5):
            for y in range(5):
                state[x][y] = b[x][y] ^ ((~b[(x + 1) % 5][y]) & b[(x + 2) % 5][y])
        state[0][0] ^= _RC[r]


cpdef bytes keccak256(bytes data):
    """Keccak-256 (multirate padding, 256-bit digest)."""
    cdef int rate_bytes = 136  # 1088 // 8
    cdef int lane_bytes = 8
    cdef int lanes_per_block = 17  # rate_bytes // 8
    cdef int padlen
    cdef bytes padded
    cdef int block_start
    cdef int i
    cdef uint64_t state[5][5]
    cdef int x, y
    cdef uint64_t lane
    cdef bytearray out

    if len(data) % rate_bytes != 0 or len(data) == 0:
        padlen = rate_bytes - (len(data) % rate_bytes)
        if padlen == 0:
            padlen = rate_bytes
        padded = data + bytes([0x01] + [0x00] * (padlen - 2) + [0x80])
    else:
        padded = data

    for x in range(5):
        for y in range(5):
            state[x][y] = 0

    for block_start in range(0, len(padded), rate_bytes):
        for i in range(lanes_per_block):
            x = i % 5
            y = i // 5
            lane = <uint64_t>int.from_bytes(
                padded[block_start + i * lane_bytes : block_start + (i + 1) * lane_bytes],
                "little",
            )
            state[x][y] ^= lane
        _keccak_f(state)

    out = bytearray(32)
    for i in range(4):
        lane = state[i][0]
        for y in range(8):
            out[i * 8 + y] = (lane >> (y * 8)) & 0xFF
    return bytes(out)
