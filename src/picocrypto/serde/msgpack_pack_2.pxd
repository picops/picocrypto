# cython: language_level=3
"""Declarations for optimized msgpack_pack with direct writes."""

from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t

# Direct write helpers (require GIL: use PyByteArray_AS_STRING)
cdef void _write_byte(bytearray buf, uint8_t b, Py_ssize_t* pos)
cdef void _write_uint16_be(bytearray buf, uint16_t val, Py_ssize_t* pos)
cdef void _write_uint32_be(bytearray buf, uint32_t val, Py_ssize_t* pos)
cdef void _write_uint64_be(bytearray buf, uint64_t val, Py_ssize_t* pos)
cdef void _write_bytes(bytearray buf, const uint8_t* data, Py_ssize_t size, Py_ssize_t* pos)

# Ensure buffer capacity
cdef void _ensure_space(bytearray buf, Py_ssize_t pos, Py_ssize_t needed) except *

# Pack functions
cdef void _pack_int_direct(object obj, bytearray buf, Py_ssize_t* pos) except *
cdef void _pack_str_direct(object obj, bytearray buf, Py_ssize_t* pos) except *
cdef void _pack_bytes_direct(object obj, bytearray buf, Py_ssize_t* pos) except *
cdef void _pack_list_direct(object obj, bytearray buf, Py_ssize_t* pos) except *
cdef void _pack_dict_direct(dict obj, bytearray buf, Py_ssize_t* pos) except *

cdef void _msgpack_pack_obj(object obj, bytearray buf, Py_ssize_t* pos) except *

cpdef bytes msgpack_pack(object obj)
