# cython: language_level=3
"""Declarations for picocrypto.signing.eip712 (Cython)."""

cpdef bytes eip712_hash_full_message(object full_message)
cpdef bytes eip712_hash_agent_message(object domain, str source, bytes connection_id)
