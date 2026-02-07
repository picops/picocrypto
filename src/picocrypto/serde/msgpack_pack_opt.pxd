# cython: language_level=3
"""Declarations for picocrypto.serde.msgpack_pack_2."""

from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t

cdef void _ensure_capacity(bytearray buf, Py_ssize_t needed) except *
cdef void _append_byte(bytearray buf, uint8_t b) except *
cdef void _append_bytes(bytearray buf, const uint8_t* data, Py_ssize_t size) except *
cdef void _pack_uint16_be(bytearray buf, uint16_t val) except *
cdef void _pack_uint32_be(bytearray buf, uint32_t val) except *
cdef void _pack_uint64_be(bytearray buf, uint64_t val) except *

cdef void _msgpack_pack_obj(object obj, bytearray buf) except *

cpdef bytes msgpack_pack(object obj)
