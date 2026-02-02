"""
Ed25519 (RFC 8032): key generation, sign, verify. For Solana and other Ed25519 stacks.
Pure Python using stdlib hashlib.sha512; can be cythonized later.
"""

from __future__ import annotations

import hashlib

# Field prime p = 2^255 - 19
_P = 2**255 - 19
# Group order L (order of base point)
_L = 2**252 + 27742317777372353535851937790883648493
# Curve constant d = -121665/121666 (mod p)
_D = (-121665 * pow(121666, _P - 2, _P)) % _P


def _modp_inv(x: int) -> int:
    return pow(x, _P - 2, _P)


def _sha512_modq(data: bytes) -> int:
    """SHA-512(data) interpreted as little-endian integer mod L."""
    h = hashlib.sha512(data).digest()
    return int.from_bytes(h, "little") % _L


def _recover_x(y: int, sign: int) -> int | None:
    """Recover x from y and sign bit; return None if no square root."""
    if y >= _P:
        return None
    x2 = (y * y - 1) * _modp_inv(_D * y * y + 1) % _P
    if x2 == 0:
        return 0 if sign == 0 else None
    x = pow(x2, (_P + 3) // 8, _P)
    if (x * x - x2) % _P != 0:
        x = x * pow(2, (_P - 1) // 4, _P) % _P
    if (x * x - x2) % _P != 0:
        return None
    if (x & 1) != sign:
        x = (_P - x) % _P
    return x


# Base point: y = 4/5, x = recover_x(y, 0)
_Gy = (4 * _modp_inv(5)) % _P
_Gx = _recover_x(_Gy, 0)
assert _Gx is not None

# Extended homogeneous (X, Y, Z, T) with x = X/Z, y = Y/Z, x*y = T/Z
_G = (_Gx, _Gy, 1, (_Gx * _Gy) % _P)


def _point_add(
    P: tuple[int, int, int, int], Q: tuple[int, int, int, int]
) -> tuple[int, int, int, int]:
    """Add two points in extended coordinates (RFC 8032 5.1.4)."""
    A = (P[1] - P[0]) * (Q[1] - Q[0]) % _P
    B = (P[1] + P[0]) * (Q[1] + Q[0]) % _P
    C = (2 * P[3] * Q[3] * _D) % _P
    D = (2 * P[2] * Q[2]) % _P
    E, F, G, H = (B - A) % _P, (D - C) % _P, (D + C) % _P, (B + A) % _P
    return (E * F % _P, G * H % _P, F * G % _P, E * H % _P)


def _point_mul(s: int, P: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    """Scalar multiplication s*P."""
    s = s % _L
    Q = (0, 1, 1, 0)
    while s > 0:
        if s & 1:
            Q = _point_add(Q, P)
        P = _point_add(P, P)
        s >>= 1
    return Q


def _point_equal(P: tuple[int, int, int, int], Q: tuple[int, int, int, int]) -> bool:
    """Return True iff P and Q represent the same Edwards point (extended coords)."""
    if (P[0] * Q[2] - Q[0] * P[2]) % _P != 0:
        return False
    if (P[1] * Q[2] - Q[1] * P[2]) % _P != 0:
        return False
    return True


def _point_compress(P: tuple[int, int, int, int]) -> bytes:
    """Encode point P (extended coords) to 32-byte compressed form (y + sign bit of x)."""
    zinv = _modp_inv(P[2])
    x = P[0] * zinv % _P
    y = P[1] * zinv % _P
    return (y | ((x & 1) << 255)).to_bytes(32, "little")


def _point_decompress(s: bytes) -> tuple[int, int, int, int] | None:
    """Decode 32-byte compressed point to extended coords (X, Y, Z, T); None if invalid."""
    if len(s) != 32:
        return None
    y = int.from_bytes(s, "little")
    sign = y >> 255
    y &= (1 << 255) - 1
    x = _recover_x(y, sign)
    if x is None:
        return None
    return (x, y, 1, (x * y) % _P)


def _secret_expand(secret: bytes) -> tuple[int, bytes]:
    """Expand 32-byte secret to scalar a and 32-byte prefix. RFC 8032 5.1.5."""
    if len(secret) != 32:
        raise ValueError("Ed25519 secret must be 32 bytes")
    h = hashlib.sha512(secret).digest()
    a = int.from_bytes(h[:32], "little")
    a &= (1 << 254) - 8
    a |= 1 << 254
    return (a, h[32:64])


def ed25519_public_key(seed: bytes) -> bytes:
    """
    Ed25519 public key (32 bytes) from 32-byte seed.

    Args:
        seed: 32-byte secret seed.

    Returns:
        32-byte compressed public key.
    """
    a, _ = _secret_expand(seed)
    return _point_compress(_point_mul(a, _G))


def ed25519_sign(message: bytes, seed: bytes) -> bytes:
    """
    Ed25519 signature (64 bytes) of message under 32-byte seed. RFC 8032 5.1.6.

    Args:
        message: Arbitrary bytes to sign.
        seed: 32-byte secret seed.

    Returns:
        64-byte signature (R || S).
    """
    a, prefix = _secret_expand(seed)
    A_enc = _point_compress(_point_mul(a, _G))
    r = _sha512_modq(prefix + message)
    R = _point_mul(r, _G)
    R_enc = _point_compress(R)
    h = _sha512_modq(R_enc + A_enc + message)
    s = (r + h * a) % _L
    return R_enc + s.to_bytes(32, "little")


def ed25519_verify(message: bytes, signature: bytes, public_key: bytes) -> bool:
    """
    Verify Ed25519 signature. RFC 8032 5.1.7.

    Args:
        message: Original message bytes.
        signature: 64-byte signature (R || S).
        public_key: 32-byte compressed public key.

    Returns:
        True iff signature is valid.
    """
    if len(signature) != 64 or len(public_key) != 32:
        return False
    A = _point_decompress(public_key)
    if A is None:
        return False
    R_enc = signature[:32]
    S_raw = signature[32:]
    R = _point_decompress(R_enc)
    if R is None:
        return False
    s = int.from_bytes(S_raw, "little")
    if s >= _L:
        return False
    h = _sha512_modq(R_enc + public_key + message)
    sB = _point_mul(s, _G)
    hA = _point_mul(h, A)
    R_plus_hA = _point_add(R, hA)
    return _point_equal(sB, R_plus_hA)


__all__: tuple[str, ...] = (
    "ed25519_public_key",
    "ed25519_sign",
    "ed25519_verify",
)
