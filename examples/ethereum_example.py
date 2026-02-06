#!/usr/bin/env python3
"""Example: Ethereum-style crypto (keccak256, secp256k1, EIP-712)."""

from picocrypto import (
    eip712_hash_full_message,
    keccak256,
    privkey_to_address,
    sign_recoverable,
)

privkey = bytes(31) + bytes([1])
address = privkey_to_address(privkey)
r, s, v = sign_recoverable(privkey, keccak256(b"Hello, Ethereum"))
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
    "message": {"from": address, "message": "Hello from cycrypto"},
}
print("EIP-712 hash:", eip712_hash_full_message(full_message).hex()[:32] + "...")
