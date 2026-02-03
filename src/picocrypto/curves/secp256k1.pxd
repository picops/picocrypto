# cython: language_level=3
# Declarations for cycrypto.curves.secp256k1
cpdef bytes privkey_to_pubkey(bytes privkey)
cpdef bytes recover_pubkey(bytes msg_hash, object r, object s, int recid)
cpdef tuple sign_recoverable(bytes privkey, bytes msg_hash)
cpdef str privkey_to_address(bytes privkey)
