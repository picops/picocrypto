# cython: language_level=3
"""Cython declarations for picocrypto.curves: Ed25519 and secp256k1."""

from .ed25519 cimport ed25519_public_key, ed25519_sign, ed25519_verify
from .secp256k1 cimport (privkey_to_address, privkey_to_pubkey, recover_pubkey,
                         sign_recoverable)
