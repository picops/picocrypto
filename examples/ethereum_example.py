#!/usr/bin/env python3
"""Example: Ethereum-style crypto (keccak256, secp256k1, EIP-712)."""

from picocrypto import (
    eip712_hash_full_message,
    keccak256,
    privkey_to_address,
    privkey_to_pubkey,
    sign_recoverable,
)

privkey = bytes(31) + bytes([1])
pubkey = privkey_to_pubkey(privkey)
address = privkey_to_address(privkey)
print("Ethereum address:", address)

msg_hash = keccak256(b"Hello, Ethereum")
r, s, v = sign_recoverable(privkey, msg_hash)
print("Signature (r, s, v):", hex(r), hex(s), v)

full_message = {
    "domain": {
        "name": "Example",
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
    "message": {"from": address, "message": "Hello from picocrypto"},
}
hash_to_sign = eip712_hash_full_message(full_message)
print("EIP-712 hash to sign:", hash_to_sign.hex()[:32] + "...")
