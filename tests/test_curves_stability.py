"""Stability tests for curve implementations.

Lock-in exact outputs for fixed inputs so that any change in curve code
(optimizations, refactors) is detected. Run with PYTHONPATH=src.

Note: Full keccak-style optimization (no Python in hot path, flattened state,
load64/store64) does not apply directly to curves: secp256k1 and Ed25519 use
Python integers for modular arithmetic. Achieving that level would require
C bignums (limbs) or linking libsecp256k1 / similar. The curve modules use
the same Cython directives (boundscheck=False, etc.) for consistency.
"""

from __future__ import annotations

import pytest

from picocrypto import (
    ed25519_public_key,
    ed25519_sign,
    ed25519_verify,
    keccak256,
    privkey_to_address,
    privkey_to_pubkey,
    recover_pubkey,
    sign_recoverable,
)

# --- secp256k1: locked-in outputs for fixed inputs (captured from current impl) ---
SECP_PRIV = bytes.fromhex(
    "0000000000000000000000000000000000000000000000000000000000000001"
)
SECP_MSG_HASH = bytes.fromhex(
    "2339863461be3f2dbbc5f995c5bf6953ee73f6437f37b0b44de4e67088bcd4c2"
)  # keccak256(b"message to sign")
SECP_PUB_EXPECTED = bytes.fromhex(
    "0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
    "483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"
)
SECP_ADDR_EXPECTED = "0x7d6e99bb8abf8cc013bb0e912d0b176596fe7b88"
SECP_R_EXPECTED = (
    2780594367940990599170980534274032790046949652926240393108138259367820360119
)
SECP_S_EXPECTED = (
    14011065033942443886443251798395993059168771109101043339243150874103607391952
)
SECP_V_EXPECTED = 28

# --- Ed25519: RFC 8032 test vector (already in test_crypto; repeated for stability) ---
ED25519_SECRET = bytes.fromhex(
    "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
)
ED25519_PUBLIC_EXPECTED = bytes.fromhex(
    "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
)
ED25519_MSG = b""
ED25519_SIG_EXPECTED = bytes.fromhex(
    "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155"
    "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
)


def test_secp256k1_privkey_to_pubkey_stable() -> None:
    """Exact pubkey for fixed privkey must not change."""
    assert privkey_to_pubkey(SECP_PRIV) == SECP_PUB_EXPECTED


def test_secp256k1_privkey_to_address_stable() -> None:
    """Exact address for fixed privkey must not change."""
    assert privkey_to_address(SECP_PRIV) == SECP_ADDR_EXPECTED


def test_secp256k1_sign_recoverable_stable() -> None:
    """Exact (r, s, v) for fixed privkey and message must not change."""
    r, s, v = sign_recoverable(SECP_PRIV, SECP_MSG_HASH)
    assert r == SECP_R_EXPECTED
    assert s == SECP_S_EXPECTED
    assert v == SECP_V_EXPECTED


def test_secp256k1_recover_pubkey_stable() -> None:
    """Recovered pubkey must match expected and equal privkey_to_pubkey."""
    r, s, v = sign_recoverable(SECP_PRIV, SECP_MSG_HASH)
    recid = v - 27
    recovered = recover_pubkey(SECP_MSG_HASH, r, s, recid)
    assert recovered == SECP_PUB_EXPECTED
    assert recovered == privkey_to_pubkey(SECP_PRIV)


def test_secp256k1_msg_hash_consistent() -> None:
    """SECP_MSG_HASH must equal keccak256(b'message to sign') (used by stability tests)."""
    assert SECP_MSG_HASH == keccak256(b"message to sign")


def test_ed25519_public_key_stable() -> None:
    """Ed25519 public key for RFC 8032 test secret must not change."""
    assert ed25519_public_key(ED25519_SECRET) == ED25519_PUBLIC_EXPECTED


def test_ed25519_sign_stable() -> None:
    """Ed25519 signature for RFC 8032 test vector must not change."""
    assert ed25519_sign(ED25519_MSG, ED25519_SECRET) == ED25519_SIG_EXPECTED


def test_ed25519_verify_stable() -> None:
    """Ed25519 verify must accept the RFC 8032 (message, sig, pub) triple."""
    assert (
        ed25519_verify(ED25519_MSG, ED25519_SIG_EXPECTED, ED25519_PUBLIC_EXPECTED)
        is True
    )
