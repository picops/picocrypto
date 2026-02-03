# cython: language_level=3
# Declarations for cycrypto.curves.ed25519
cpdef bytes ed25519_public_key(bytes seed)
cpdef bytes ed25519_sign(bytes message, bytes seed)
cpdef bint ed25519_verify(bytes message, bytes signature, bytes public_key)
