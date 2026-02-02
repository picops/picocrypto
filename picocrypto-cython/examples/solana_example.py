#!/usr/bin/env python3
"""Example: Solana-style crypto (Ed25519)."""

from cycrypto import ed25519_public_key, ed25519_sign, ed25519_verify

seed = bytes(31) + bytes([1])
pubkey = ed25519_public_key(seed)
signature = ed25519_sign(b"Hello, Solana", seed)
print("Verify:", ed25519_verify(b"Hello, Solana", signature, pubkey))
