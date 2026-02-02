"""
secp256k1 (Bitcoin/Ethereum curve): key derivation, ECDSA sign, public key recovery.
"""

from __future__ import annotations

from ..hashes import keccak256

_P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
_Gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
_Gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8


def _mod_inv(a: int, n: int) -> int:
    """Modular inverse via extended gcd."""
    if a < 0:
        a = (a % n + n) % n
    t, r = 0, n
    new_t, new_r = 1, a
    while new_r:
        q = r // new_r
        t, new_t = new_t, t - q * new_t
        r, new_r = new_r, r - q * new_r
    if r != 1:
        raise ValueError("no inverse")
    return t % n


def _point_add(px: int, py: int, qx: int, qy: int) -> tuple[int, int]:
    """Add two secp256k1 points in affine coords; (0,0) is identity. Returns (rx, ry)."""
    if (px, py) == (0, 0):
        return (qx, qy)
    if (qx, qy) == (0, 0):
        return (px, py)
    if px == qx:
        if py == qy:
            lam = (3 * px * px) * _mod_inv(2 * py, _P) % _P
        else:
            return (0, 0)
    else:
        lam = (qy - py) * _mod_inv(qx - px, _P) % _P
    rx = (lam * lam - px - qx) % _P
    ry = (lam * (px - rx) - py) % _P
    return (rx, ry)


def _point_mul(d: int, x: int, y: int) -> tuple[int, int]:
    """Scalar multiplication d * (x, y) on secp256k1; returns (rx, ry)."""
    d = d % _N
    rx, ry = 0, 0
    while d:
        if d & 1:
            rx, ry = _point_add(rx, ry, x, y)
        x, y = _point_add(x, y, x, y)
        d >>= 1
    return (rx, ry)


def privkey_to_pubkey(privkey: bytes) -> bytes:
    """
    Derive uncompressed public key (65 bytes: 0x04 || x || y) from 32-byte private key.

    Args:
        privkey: 32-byte secp256k1 private key.

    Returns:
        65-byte uncompressed public key.
    """
    if len(privkey) != 32:
        raise ValueError("privkey must be 32 bytes")
    d = int.from_bytes(privkey, "big")
    if d == 0 or d >= _N:
        raise ValueError("invalid privkey")
    x, y = _point_mul(d, _Gx, _Gy)
    return bytes([0x04]) + x.to_bytes(32, "big") + y.to_bytes(32, "big")


def _recover_pubkey_from_sig(
    msg_hash: bytes, r: int, s: int, recid: int
) -> tuple[int, int]:
    """Recover public key from (r, s, recid). recid 0,1: x=r; recid 2,3: x=r+n; recid&1 selects y parity."""
    r_scalar = r % _N
    if recid & 2:
        if r + _N >= _P:
            raise ValueError("recid 2/3 but r+n >= p")
        x = (r + _N) % _P
    else:
        x = r % _P
    rhs = (x * x * x + 7) % _P
    y_cand = pow(rhs, (_P + 1) // 4, _P)
    if (y_cand * y_cand) % _P != rhs:
        raise ValueError("no square root")
    if (recid & 1) != (y_cand & 1):
        y_cand = (_P - y_cand) % _P
    r_inv = _mod_inv(r_scalar, _N)
    z = int.from_bytes(msg_hash, "big") % _N
    u1 = (-z * r_inv) % _N
    u2 = (s * r_inv) % _N
    g_mul = _point_mul(u1, _Gx, _Gy)
    r_mul = _point_mul(u2, x, y_cand)
    qx, qy = _point_add(g_mul[0], g_mul[1], r_mul[0], r_mul[1])
    if (qx, qy) == (0, 0):
        raise ValueError("recovered point at infinity")
    return (qx, qy)


def recover_pubkey(msg_hash: bytes, r: int, s: int, recid: int) -> bytes:
    """
    Recover uncompressed public key (65 bytes) from ECDSA signature (msg_hash, r, s, recid).

    Args:
        msg_hash: 32-byte message hash that was signed.
        r, s: Signature components (scalars).
        recid: Recovery id (0–3) indicating which public key.

    Returns:
        65-byte uncompressed public key.
    """
    if len(msg_hash) != 32:
        raise ValueError("msg_hash must be 32 bytes")
    qx, qy = _recover_pubkey_from_sig(msg_hash, r, s, recid)
    return bytes([0x04]) + qx.to_bytes(32, "big") + qy.to_bytes(32, "big")


def sign_recoverable(privkey: bytes, msg_hash: bytes) -> tuple[int, int, int]:
    """
    ECDSA sign with recovery id; returns (r, s, v) with v in {27, 28}. Deterministic k from msg+key.

    Args:
        privkey: 32-byte private key.
        msg_hash: 32-byte message hash to sign.

    Returns:
        (r, s, v) where v is 27 or 28 for Ethereum-style recovery.
    """
    if len(privkey) != 32 or len(msg_hash) != 32:
        raise ValueError("privkey and msg_hash must be 32 bytes")
    z = int.from_bytes(msg_hash, "big")
    d = int.from_bytes(privkey, "big") % _N
    k_cand = 1 + (z + d) % (_N - 2)
    for attempt in range(256):
        k = (k_cand + attempt) % _N
        if k == 0:
            continue
        if k >= _N:
            continue
        kx, _ = _point_mul(k, _Gx, _Gy)
        r = kx % _N
        if r == 0:
            continue
        k_inv = _mod_inv(k, _N)
        s = (k_inv * (z + r * d)) % _N
        if s == 0:
            continue
        if s > _N // 2:
            s = _N - s
        our_pub = privkey_to_pubkey(privkey)
        our_addr = "0x" + keccak256(our_pub)[12:].hex()
        for recid in range(4):
            try:
                rec = _recover_pubkey_from_sig(msg_hash, r, s, recid)
                rec_pub = (
                    bytes([0x04])
                    + rec[0].to_bytes(32, "big")
                    + rec[1].to_bytes(32, "big")
                )
                addr_rec = "0x" + keccak256(rec_pub)[12:].hex()
                if addr_rec.lower() == our_addr.lower():
                    return (r, s, 27 + recid)
            except Exception:
                pass
    raise ValueError(
        "sign_recoverable: could not produce valid signature (recovery never matched our address)"
    )


def privkey_to_address(privkey: bytes) -> str:
    """
    Ethereum address (0x + 40 hex) from 32-byte private key.

    Args:
        privkey: 32-byte secp256k1 private key.

    Returns:
        "0x" plus 40 hex chars (keccak256(pubkey)[12:32]).
    """
    pub = privkey_to_pubkey(privkey)
    return "0x" + keccak256(pub)[12:].hex()


__all__: tuple[str, ...] = (
    "privkey_to_address",
    "privkey_to_pubkey",
    "recover_pubkey",
    "sign_recoverable",
)
