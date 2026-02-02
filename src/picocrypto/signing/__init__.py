"""Signing schemas: EIP-712 (Ethereum), BIP-137 (signed messages)."""

from .bip137 import (
    bip137_sign_message,
    bip137_signed_message_hash,
    bip137_verify_message,
)
from .eip712 import eip712_hash_agent_message, eip712_hash_full_message

__all__: tuple[str, ...] = (
    "bip137_sign_message",
    "bip137_signed_message_hash",
    "bip137_verify_message",
    "eip712_hash_agent_message",
    "eip712_hash_full_message",
)
