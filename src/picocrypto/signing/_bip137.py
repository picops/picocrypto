"""
BIP-137: Signed messages (SHA256(message), ECDSA sign, header + r + s, base64).
"""

from __future__ import annotations

import base64
import hashlib

from ..curves import recover_pubkey, sign_recoverable


def bip137_signed_message_hash(message: bytes) -> bytes:
    """
    Hash used for BIP-137 message signing (single SHA-256 of message).

    Args:
        message: Raw message bytes to hash.

    Returns:
        32-byte SHA-256 digest.
    """
    return hashlib.sha256(message).digest()


def bip137_sign_message(privkey: bytes, message: bytes) -> bytes:
    """
    Sign message per BIP-137 (Bitcoin signed-message format).

    Args:
        privkey: 32-byte secp256k1 private key.
        message: Message bytes to sign.

    Returns:
        Base64-encoded 65-byte signature (1-byte header + 32 r + 32 s).
    """
    msg_hash = bip137_signed_message_hash(message)
    r, s, v = sign_recoverable(privkey, msg_hash)
    recid = v - 27
    header = (32 + recid) if recid < 3 else 31
    sig = bytes([header]) + r.to_bytes(32, "big") + s.to_bytes(32, "big")
    return base64.b64encode(sig)


def bip137_verify_message(
    message: bytes, signature_b64: bytes | str, pubkey: bytes
) -> bool:
    """
    Verify a BIP-137 signed message.

    Args:
        message: Original message bytes.
        signature_b64: Base64-encoded 65-byte signature.
        pubkey: 65-byte uncompressed public key to verify against.

    Returns:
        True iff the signature is valid for the message and pubkey.
    """
    try:
        sig = base64.b64decode(signature_b64)
    except Exception:
        return False
    if len(sig) != 65:
        return False
    header, r_bytes, s_bytes = sig[0], sig[1:33], sig[33:65]
    recid = header & 0x03
    r = int.from_bytes(r_bytes, "big")
    s = int.from_bytes(s_bytes, "big")
    msg_hash = bip137_signed_message_hash(message)
    try:
        recovered = recover_pubkey(msg_hash, r, s, recid)
        return recovered == pubkey
    except Exception:
        return False


__all__: tuple[str, ...] = (
    "bip137_sign_message",
    "bip137_signed_message_hash",
    "bip137_verify_message",
)
