"""Elliptic-curve crypto: secp256k1 (Ethereum/Bitcoin), Ed25519 (Solana etc.)."""

from .ed25519 import ed25519_public_key, ed25519_sign, ed25519_verify
from .secp256k1 import (privkey_to_address, privkey_to_pubkey, recover_pubkey,
                        sign_recoverable)

__all__: tuple[str, ...] = (
    "ed25519_public_key",
    "ed25519_sign",
    "ed25519_verify",
    "privkey_to_address",
    "privkey_to_pubkey",
    "recover_pubkey",
    "sign_recoverable",
)
