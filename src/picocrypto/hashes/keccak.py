"""
Keccak-256 (multirate padding, 256-bit output). Pure Python; can be cythonized later.
"""

from __future__ import annotations

from functools import reduce
from operator import xor

_ROUND_CONSTANTS = [
    0x0000000000000001,
    0x0000000000008082,
    0x800000000000808A,
    0x8000000080008000,
    0x000000000000808B,
    0x0000000080000001,
    0x8000000080008081,
    0x8000000000008009,
    0x000000000000008A,
    0x0000000000000088,
    0x0000000080008009,
    0x000000008000000A,
    0x000000008000808B,
    0x800000000000008B,
    0x8000000000008089,
    0x8000000000008003,
    0x8000000000008002,
    0x8000000000000080,
    0x000000000000800A,
    0x800000008000000A,
    0x8000000080008081,
    0x8000000000008080,
    0x0000000080000001,
    0x8000000080008008,
]

_ROTATION = [
    [0, 1, 62, 28, 27],
    [36, 44, 6, 55, 20],
    [3, 10, 43, 25, 39],
    [41, 45, 15, 21, 8],
    [18, 2, 61, 56, 14],
]


def _rol64(v: int, n: int) -> int:
    """Rotate 64-bit value v left by n bits (mod 64)."""
    n = n % 64
    return ((v << n) | (v >> (64 - n))) & 0xFFFFFFFFFFFFFFFF


def _keccak_f(state: list[list[int]]) -> None:
    """Keccak-f permutation; updates state in place (24 rounds)."""
    for rc in _ROUND_CONSTANTS:
        # theta
        c = [reduce(xor, state[x]) for x in range(5)]
        d = [_rol64(c[(x + 1) % 5], 1) ^ c[(x - 1) % 5] for x in range(5)]
        for x in range(5):
            for y in range(5):
                state[x][y] ^= d[x]
        # rho and pi
        b = [[0] * 5 for _ in range(5)]
        for x in range(5):
            for y in range(5):
                b[y][(2 * x + 3 * y) % 5] = _rol64(state[x][y], _ROTATION[y][x])
        # chi
        for x in range(5):
            for y in range(5):
                state[x][y] = b[x][y] ^ ((~b[(x + 1) % 5][y]) & b[(x + 2) % 5][y])
        # iota
        state[0][0] ^= rc


def keccak256(data: bytes) -> bytes:
    """
    Keccak-256 hash (256-bit output, multirate padding).

    Args:
        data: Input bytes (any length).

    Returns:
        32-byte digest.
    """
    rate_bytes = 1088 // 8  # 136
    lanes_per_block = rate_bytes // 8  # 17
    state = [[0] * 5 for _ in range(5)]
    lane_bytes = 8
    if len(data) % rate_bytes != 0 or len(data) == 0:
        padlen = rate_bytes - (len(data) % rate_bytes)
        if padlen == 0:
            padlen = rate_bytes
        data = data + bytes([0x01] + [0x00] * (padlen - 2) + [0x80])
    for block_start in range(0, len(data), rate_bytes):
        for i in range(lanes_per_block):
            off = block_start + i * lane_bytes
            x, y = i % 5, i // 5
            state[x][y] ^= int.from_bytes(data[off : off + lane_bytes], "little")
        _keccak_f(state)
    out = bytearray()
    while len(out) < 32:
        for y in range(5):
            for x in range(5):
                out.extend(state[x][y].to_bytes(lane_bytes, "little"))
                if len(out) >= 32:
                    return bytes(out[:32])
        _keccak_f(state)
    return bytes(out[:32])


__all__: tuple[str, ...] = ("keccak256",)
