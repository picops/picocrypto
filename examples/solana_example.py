#!/usr/bin/env python3
"""Example: Solana-style crypto (Ed25519)."""

from picocrypto import ed25519_public_key, ed25519_sign, ed25519_verify

seed = bytes(31) + bytes([1])
pubkey = ed25519_public_key(seed)
message = b"Hello, Solana"
signature = ed25519_sign(message, seed)
ok = ed25519_verify(message, signature, pubkey)
print("Ed25519 public key:", pubkey.hex()[:32] + "...")
print("Verify:", ok)
