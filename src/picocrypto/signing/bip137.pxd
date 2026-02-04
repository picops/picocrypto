# cython: language_level=3
"""Declarations for picocrypto.signing.bip137 (Cython)."""

cpdef bytes bip137_signed_message_hash(bytes message)
cpdef bytes bip137_sign_message(bytes privkey, bytes message)
cpdef bint bip137_verify_message(bytes message, object signature_b64, bytes pubkey) noexcept
