"""BIP-137 signed messages. Cython implementation (used by default)."""

import base64
import hashlib

from ..curves cimport recover_pubkey, sign_recoverable


cpdef bytes bip137_signed_message_hash(bytes message):
    """SHA-256 of message (32 bytes)."""
    return hashlib.sha256(message).digest()


cpdef bytes bip137_sign_message(bytes privkey, bytes message):
    """Sign message per BIP-137; return base64-encoded 65-byte sig (header + r + s)."""
    cdef bytes msg_hash = bip137_signed_message_hash(message)
    cdef object r, s, v
    cdef int recid
    cdef int header
    r, s, v = sign_recoverable(privkey, msg_hash)
    recid = v - 27
    header = (32 + recid) if recid < 3 else 31
    return base64.b64encode(
        bytes([header]) + r.to_bytes(32, "big") + s.to_bytes(32, "big")
    )


cpdef bint bip137_verify_message(bytes message, object signature_b64, bytes pubkey) noexcept:
    """Verify BIP-137 signed message."""
    cdef bytes sig
    cdef int header
    cdef bytes r_bytes, s_bytes
    cdef object r, s
    cdef bytes msg_hash
    cdef bytes recovered
    try:
        sig = base64.b64decode(signature_b64)
    except Exception:
        return False
    if len(sig) != 65:
        return False
    header = sig[0]
    r_bytes = sig[1:33]
    s_bytes = sig[33:65]
    recid = header & 0x03
    r = int.from_bytes(r_bytes, "big")
    s = int.from_bytes(s_bytes, "big")
    msg_hash = bip137_signed_message_hash(message)
    try:
        recovered = recover_pubkey(msg_hash, r, s, recid)
        return recovered == pubkey
    except Exception:
        return False
