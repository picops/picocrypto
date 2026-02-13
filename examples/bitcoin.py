#!/usr/bin/env python3
"""Example: BIP-137 signed message (Bitcoin-style)."""

from picocrypto import (bip137_sign_message, bip137_verify_message,
                        privkey_to_pubkey)

privkey = bytes(31) + bytes([1])
pubkey = privkey_to_pubkey(privkey)
message = b"Hello, Bitcoin"
sig_b64 = bip137_sign_message(privkey, message)
print("Verify:", bip137_verify_message(message, sig_b64, pubkey))
