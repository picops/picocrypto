"""BIP-137 signed messages. Cython implementation (used by default)."""

from cpython.bytes cimport PyBytes_AS_STRING, PyBytes_FromStringAndSize

from ..curves cimport recover_pubkey, sign_recoverable


cdef extern from "openssl/sha.h":
    unsigned char* SHA256(const unsigned char *data, size_t count, unsigned char *md)

cdef extern from "openssl/evp.h":
    int EVP_EncodeBlock(unsigned char *t, const unsigned char *f, int n)
    int EVP_DecodeBlock(unsigned char *t, const unsigned char *f, int n)


cpdef bytes bip137_signed_message_hash(bytes message):
    """SHA-256 of message (32 bytes). Uses OpenSSL libcrypto."""
    cdef size_t n = len(message)
    cdef const unsigned char* data = <const unsigned char*>PyBytes_AS_STRING(message)
    cdef unsigned char digest[32]
    SHA256(data, n, digest)
    return PyBytes_FromStringAndSize(<char*>digest, 32)


cpdef bytes bip137_sign_message(bytes privkey, bytes message):
    """Sign message per BIP-137; return base64-encoded 65-byte sig (header + r + s)."""
    cdef bytes msg_hash = bip137_signed_message_hash(message)
    cdef object r, s, v
    cdef int recid
    cdef int header
    cdef unsigned char sig[65]
    cdef unsigned char b64_buf[92]
    cdef int i
    cdef int b64_len
    r, s, v = sign_recoverable(privkey, msg_hash)
    recid = v - 27
    header = (32 + recid) if recid < 3 else 31
    sig[0] = header
    for i in range(32):
        sig[1 + i] = (r >> (8 * (31 - i))) & 0xFF
    for i in range(32):
        sig[33 + i] = (s >> (8 * (31 - i))) & 0xFF
    b64_len = EVP_EncodeBlock(b64_buf, sig, 65)
    return PyBytes_FromStringAndSize(<char*>b64_buf, b64_len)


cpdef bint bip137_verify_message(bytes message, object signature_b64, bytes pubkey) noexcept:
    """Verify BIP-137 signed message."""
    cdef bytes sig_b64
    cdef const unsigned char* b64_ptr
    cdef Py_ssize_t b64_len
    cdef unsigned char sig[66]
    cdef int dec_len
    cdef object r, s
    cdef int i
    cdef bytes msg_hash
    cdef bytes recovered
    if isinstance(signature_b64, str):
        sig_b64 = (<str>signature_b64).encode("ascii")
    elif isinstance(signature_b64, bytes):
        sig_b64 = <bytes>signature_b64
    else:
        return False
    b64_ptr = <const unsigned char*>PyBytes_AS_STRING(sig_b64)
    b64_len = len(sig_b64)
    dec_len = EVP_DecodeBlock(sig, b64_ptr, <int>b64_len)
    if dec_len < 65:
        return False
    recid = sig[0] & 0x03
    r = int.from_bytes(PyBytes_FromStringAndSize(<char*>&sig[1], 32), "big")
    s = int.from_bytes(PyBytes_FromStringAndSize(<char*>&sig[33], 32), "big")
    msg_hash = bip137_signed_message_hash(message)
    try:
        recovered = recover_pubkey(msg_hash, r, s, recid)
        return recovered == pubkey
    except Exception:
        return False
