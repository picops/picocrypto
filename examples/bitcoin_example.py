#!/usr/bin/env python3
"""Example: BIP-137 signed message (Bitcoin-style)."""

from picocrypto import (
    bip137_sign_message,
    bip137_signed_message_hash,
    bip137_verify_message,
    privkey_to_pubkey,
)

privkey = bytes(31) + bytes([1])
pubkey = privkey_to_pubkey(privkey)
print("Public key (65 bytes uncompressed):", pubkey.hex()[:32] + "...")

message = b"Hello, Bitcoin"
msg_hash = bip137_signed_message_hash(message)
print("Message hash (SHA-256):", msg_hash.hex()[:32] + "...")

sig_b64 = bip137_sign_message(privkey, message)
print("Signature (base64):", sig_b64[:44].decode() + "...")

ok = bip137_verify_message(message, sig_b64, pubkey)
print("Verify:", ok)
