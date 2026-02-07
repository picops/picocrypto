# cython: language_level=3
"""Declarations for msgpack_pack_v3."""

from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t

cdef void _append_byte(bytearray buf, uint8_t b) except *
cdef void _append_bytes_fast(bytearray buf, const uint8_t* data, Py_ssize_t size) except *
cdef void _write_header_uint16(bytearray buf, uint8_t tag, uint16_t val) except *
cdef void _write_header_uint32(bytearray buf, uint8_t tag, uint32_t val) except *
cdef void _pack_int_optimized(object obj, bytearray buf) except *
cdef void _pack_str_or_bytes_combined(bytearray buf, const uint8_t* s_ptr, Py_ssize_t n) except *
cdef void _write_list_header(bytearray buf, Py_ssize_t n) except *
cdef void _write_dict_header(bytearray buf, Py_ssize_t n) except *

cdef void _msgpack_pack_dict(dict obj, bytearray buf) except *
cdef void _msgpack_pack_list(object obj, bytearray buf) except *
cdef void _msgpack_pack_obj(object obj, bytearray buf) except *

cpdef bytes msgpack_pack(object obj)
