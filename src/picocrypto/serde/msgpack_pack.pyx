"""Minimal msgpack pack (dict, list, str, int, bool). Cython implementation. Preserves dict order."""

from cpython.bytearray cimport PyByteArray_AS_STRING, PyByteArray_Resize
from cpython.bytes cimport (PyBytes_AS_STRING, PyBytes_FromStringAndSize,
                            PyBytes_GET_SIZE)
from libc.stdint cimport (int8_t, int16_t, int32_t, int64_t, uint8_t, uint16_t,
                          uint32_t, uint64_t)
from libc.string cimport memcpy


cdef inline void _ensure_capacity(bytearray buf, Py_ssize_t needed) except *:
    """Ensure buffer has enough capacity, pre-allocate to reduce resizing."""
    cdef Py_ssize_t current_len = len(buf)
    cdef Py_ssize_t new_size = current_len + needed
    cdef Py_ssize_t capacity = len(buf)
    
    if new_size > capacity:
        # Grow by 1.5x to amortize allocations
        if new_size < capacity * 3 // 2:
            new_size = capacity * 3 // 2
        PyByteArray_Resize(buf, new_size)
        PyByteArray_Resize(buf, current_len)  # Reset to actual size


cdef inline void _append_byte(bytearray buf, uint8_t b) except *:
    buf.append(b)


cdef inline void _append_bytes(bytearray buf, const uint8_t* data, Py_ssize_t size) except *:
    """Append bytes efficiently."""
    cdef Py_ssize_t old_size = len(buf)
    PyByteArray_Resize(buf, old_size + size)
    memcpy(PyByteArray_AS_STRING(buf) + old_size, data, size)


cdef inline void _pack_uint16_be(bytearray buf, uint16_t val) except *:
    """Pack 16-bit big-endian integer."""
    cdef uint8_t tmp[2]
    tmp[0] = (val >> 8) & 0xFF
    tmp[1] = val & 0xFF
    _append_bytes(buf, tmp, 2)


cdef inline void _pack_uint32_be(bytearray buf, uint32_t val) except *:
    """Pack 32-bit big-endian integer."""
    cdef uint8_t tmp[4]
    tmp[0] = (val >> 24) & 0xFF
    tmp[1] = (val >> 16) & 0xFF
    tmp[2] = (val >> 8) & 0xFF
    tmp[3] = val & 0xFF
    _append_bytes(buf, tmp, 4)


cdef inline void _pack_uint64_be(bytearray buf, uint64_t val) except *:
    """Pack 64-bit big-endian integer."""
    cdef uint8_t tmp[8]
    tmp[0] = (val >> 56) & 0xFF
    tmp[1] = (val >> 48) & 0xFF
    tmp[2] = (val >> 40) & 0xFF
    tmp[3] = (val >> 32) & 0xFF
    tmp[4] = (val >> 24) & 0xFF
    tmp[5] = (val >> 16) & 0xFF
    tmp[6] = (val >> 8) & 0xFF
    tmp[7] = val & 0xFF
    _append_bytes(buf, tmp, 8)


cdef void _msgpack_pack_obj(object obj, bytearray buf) except *:
    cdef Py_ssize_t n
    cdef int64_t ival
    cdef uint64_t uval
    cdef bytes s
    cdef const uint8_t* s_ptr
    cdef uint8_t tmp[9]  # Max header size
    cdef Py_ssize_t tmp_idx
    
    if obj is None:
        _append_byte(buf, 0xC0)
        return
    
    # Fast path for bool (check before int since bool is subclass of int)
    if isinstance(obj, bool):
        _append_byte(buf, 0xC3 if obj else 0xC2)
        return
    
    # Integer packing (baseline: append-based)
    if isinstance(obj, int):
        ival = obj
        if 0 <= ival <= 0x7F:
            _append_byte(buf, <uint8_t>ival)
            return
        if -32 <= ival < 0:
            _append_byte(buf, <uint8_t>((256 + ival) & 0xFF))
            return
        if ival > 0:
            uval = <uint64_t>ival
            if uval <= 0xFF:
                tmp[0] = 0xCC
                tmp[1] = <uint8_t>uval
                _append_bytes(buf, tmp, 2)
            elif uval <= 0xFFFF:
                tmp[0] = 0xCD
                _append_byte(buf, tmp[0])
                _pack_uint16_be(buf, <uint16_t>uval)
            elif uval <= 0xFFFFFFFF:
                _append_byte(buf, 0xCE)
                _pack_uint32_be(buf, <uint32_t>uval)
            else:
                _append_byte(buf, 0xCF)
                _pack_uint64_be(buf, uval)
            return
        if ival >= -0x80:
            tmp[0] = 0xD0
            tmp[1] = <uint8_t>((256 + ival) & 0xFF)
            _append_bytes(buf, tmp, 2)
        elif ival >= -0x8000:
            tmp[0] = 0xD1
            _append_byte(buf, tmp[0])
            _pack_uint16_be(buf, <uint16_t>((0x10000 + ival) & 0xFFFF))
        elif ival >= -0x80000000:
            _append_byte(buf, 0xD2)
            _pack_uint32_be(buf, <uint32_t>((0x100000000 + ival) & 0xFFFFFFFF))
        else:
            _append_byte(buf, 0xD3)
            _pack_uint64_be(buf, <uint64_t>((0x10000000000000000 + ival) & 0xFFFFFFFFFFFFFFFF))
        return
    
    # String packing
    if isinstance(obj, str):
        s = obj.encode("utf-8")
        n = PyBytes_GET_SIZE(s)
        s_ptr = <const uint8_t*>PyBytes_AS_STRING(s)
        
        if n <= 31:
            _append_byte(buf, <uint8_t>(0xA0 | n))
        elif n <= 0xFFFF:
            tmp[0] = 0xDA
            _append_byte(buf, tmp[0])
            _pack_uint16_be(buf, <uint16_t>n)
        else:
            _append_byte(buf, 0xDB)
            _pack_uint32_be(buf, <uint32_t>n)
        
        _append_bytes(buf, s_ptr, n)
        return
    
    # Bytes packing
    if isinstance(obj, (bytes, bytearray)):
        s = bytes(obj)
        n = PyBytes_GET_SIZE(s)
        s_ptr = <const uint8_t*>PyBytes_AS_STRING(s)
        
        if n <= 31:
            _append_byte(buf, <uint8_t>(0xA0 | n))
        elif n <= 0xFFFF:
            tmp[0] = 0xDA
            _append_byte(buf, tmp[0])
            _pack_uint16_be(buf, <uint16_t>n)
        else:
            _append_byte(buf, 0xDB)
            _pack_uint32_be(buf, <uint32_t>n)
        
        _append_bytes(buf, s_ptr, n)
        return
    
    # List/tuple packing
    if isinstance(obj, (list, tuple)):
        n = len(obj)
        
        if n <= 15:
            _append_byte(buf, <uint8_t>(0x90 | n))
        elif n <= 0xFFFF:
            tmp[0] = 0xDC
            _append_byte(buf, tmp[0])
            _pack_uint16_be(buf, <uint16_t>n)
        else:
            _append_byte(buf, 0xDD)
            _pack_uint32_be(buf, <uint32_t>n)
        
        for x in obj:
            _msgpack_pack_obj(x, buf)
        return
    
    # Dict packing
    if isinstance(obj, dict):
        n = len(obj)
        
        if n <= 15:
            _append_byte(buf, <uint8_t>(0x80 | n))
        elif n <= 0xFFFF:
            tmp[0] = 0xDE
            _append_byte(buf, tmp[0])
            _pack_uint16_be(buf, <uint16_t>n)
        else:
            _append_byte(buf, 0xDF)
            _pack_uint32_be(buf, <uint32_t>n)
        
        for k, v in obj.items():
            _msgpack_pack_obj(k, buf)
            _msgpack_pack_obj(v, buf)
        return
    
    raise TypeError(f"msgpack pack: unsupported type {type(obj)}")


cpdef bytes msgpack_pack(object obj):
    """Pack obj to msgpack bytes. Supports dict, list, str, int, bool, bytes, None."""
    cdef bytearray buf = bytearray()
    _msgpack_pack_obj(obj, buf)
    return bytes(buf)