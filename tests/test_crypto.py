"""Minimal pytest tests for cycrypto."""

import pytest

from cycrypto import (
    bip137_sign_message,
    bip137_signed_message_hash,
    bip137_verify_message,
    ed25519_public_key,
    ed25519_sign,
    ed25519_verify,
    eip712_hash_agent_message,
    eip712_hash_full_message,
    keccak256,
    privkey_to_address,
    privkey_to_pubkey,
    sign_recoverable,
)

KECCAK256_EMPTY = bytes.fromhex(
    "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
)


def test_keccak256_empty() -> None:
    assert keccak256(b"") == KECCAK256_EMPTY


def test_keccak256_output_length() -> None:
    assert len(keccak256(b"hello")) == 32
    assert len(keccak256(b"x" * 200)) == 32


def test_keccak256_deterministic() -> None:
    assert keccak256(b"same input") == keccak256(b"same input")


def test_privkey_to_pubkey() -> None:
    priv = bytes(31) + bytes([1])
    pub = privkey_to_pubkey(priv)
    assert len(pub) == 65
    assert pub[0] == 0x04


def test_privkey_to_address() -> None:
    priv = bytes(31) + bytes([1])
    addr = privkey_to_address(priv)
    assert addr.startswith("0x")
    assert len(addr) == 42


def test_sign_recoverable() -> None:
    priv = bytes(31) + bytes([1])
    msg_hash = keccak256(b"message to sign")
    r, s, v = sign_recoverable(priv, msg_hash)
    assert isinstance(r, int) and isinstance(s, int) and isinstance(v, int)
    assert v in (27, 28)


def test_eip712_hash_full_message() -> None:
    full = {
        "domain": {
            "name": "Test",
            "version": "1",
            "chainId": 1,
            "verifyingContract": "0x" + "00" * 20,
        },
        "types": {
            "Mail": [
                {"name": "from", "type": "address"},
                {"name": "message", "type": "string"},
            ]
        },
        "primaryType": "Mail",
        "message": {"from": "0x" + "00" * 20, "message": "hello"},
    }
    assert len(eip712_hash_full_message(full)) == 32


def test_eip712_hash_agent_message() -> None:
    domain = {
        "name": "A",
        "version": "1",
        "chainId": 1,
        "verifyingContract": "0x" + "00" * 20,
    }
    assert len(eip712_hash_agent_message(domain, "0x" + "11" * 20, bytes(32))) == 32


ED25519_TEST1_SECRET = bytes.fromhex(
    "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
)
ED25519_TEST1_PUBLIC = bytes.fromhex(
    "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
)
ED25519_TEST1_MSG = b""
ED25519_TEST1_SIG = bytes.fromhex(
    "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155"
    "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
)


def test_ed25519_public_key() -> None:
    assert ed25519_public_key(ED25519_TEST1_SECRET) == ED25519_TEST1_PUBLIC


def test_ed25519_sign_verify() -> None:
    sig = ed25519_sign(ED25519_TEST1_MSG, ED25519_TEST1_SECRET)
    assert sig == ED25519_TEST1_SIG
    assert ed25519_verify(ED25519_TEST1_MSG, sig, ED25519_TEST1_PUBLIC) is True


def test_ed25519_verify_rejects_tampered() -> None:
    assert ed25519_verify(b"x", ED25519_TEST1_SIG, ED25519_TEST1_PUBLIC) is False
    assert (
        ed25519_verify(ED25519_TEST1_MSG, bytes(63) + b"\x00", ED25519_TEST1_PUBLIC)
        is False
    )


def test_bip137_signed_message_hash() -> None:
    h = bip137_signed_message_hash(b"hello")
    assert len(h) == 32


def test_bip137_sign_verify() -> None:
    privkey = bytes(31) + bytes([1])
    pubkey = privkey_to_pubkey(privkey)
    sig_b64 = bip137_sign_message(privkey, b"test message")
    assert bip137_verify_message(b"test message", sig_b64, pubkey) is True
    assert bip137_verify_message(b"wrong", sig_b64, pubkey) is False
