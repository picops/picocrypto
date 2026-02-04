# cython: language_level=3
"""Declarations for picocrypto.serde.msgpack_pack_cy."""

cdef void _msgpack_pack_obj(object obj, bytearray buf) except *

cpdef bytes msgpack_pack(object obj)
