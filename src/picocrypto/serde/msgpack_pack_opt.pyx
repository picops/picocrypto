"""msgpack pack v2: optimized Cython (single resize + direct writes for ints). Preserves dict order."""

from cpython.bytearray cimport PyByteArray_AS_STRING, PyByteArray_Resize
from cpython.bytes cimport PyBytes_AS_STRING, PyBytes_GET_SIZE
from cpython.dict cimport PyDict_Next
from cpython.ref cimport PyObject
from libc.stdint cimport int64_t, uint8_t, uint16_t, uint32_t, uint64_t
from libc.string cimport memcpy

# Compile-time specialization: compiler generates optimized version per C int type
ctypedef fused int_type:
    int
    long
    long long

# Type cache for faster checks than isinstance
cdef object DICT_TYPE = dict
cdef object LIST_TYPE = list
cdef object TUPLE_TYPE = tuple
cdef object STR_TYPE = str
cdef object BYTES_TYPE = bytes
cdef object BYTEARRAY_TYPE = bytearray
cdef object INT_TYPE = int
cdef object BOOL_TYPE = bool


cdef inline bint _is_type(object obj, object typ):
    """Exact type check (faster than isinstance when no subclasses)."""
    return type(obj) is typ


cdef inline void _ensure_capacity(bytearray buf, Py_ssize_t needed) except *:
    cdef Py_ssize_t current_len = len(buf)
    cdef Py_ssize_t new_size = current_len + needed
    cdef Py_ssize_t capacity = len(buf)
    if new_size > capacity:
        if new_size < capacity * 3 // 2:
            new_size = capacity * 3 // 2
        PyByteArray_Resize(buf, new_size)
        PyByteArray_Resize(buf, current_len)


cdef inline void _append_byte(bytearray buf, uint8_t b) except *:
    buf.append(b)


cdef inline void _append_bytes(bytearray buf, const uint8_t* data, Py_ssize_t size) except *:
    cdef Py_ssize_t old_size = len(buf)
    PyByteArray_Resize(buf, old_size + size)
    memcpy(PyByteArray_AS_STRING(buf) + old_size, data, size)


cdef inline void _pack_uint16_be(bytearray buf, uint16_t val) except *:
    cdef uint8_t tmp[2]
    tmp[0] = (val >> 8) & 0xFF
    tmp[1] = val & 0xFF
    _append_bytes(buf, tmp, 2)


cdef inline void _pack_uint32_be(bytearray buf, uint32_t val) except *:
    cdef uint8_t tmp[4]
    tmp[0] = (val >> 24) & 0xFF
    tmp[1] = (val >> 16) & 0xFF
    tmp[2] = (val >> 8) & 0xFF
    tmp[3] = val & 0xFF
    _append_bytes(buf, tmp, 4)


cdef inline void _pack_uint64_be(bytearray buf, uint64_t val) except *:
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


cdef void _pack_fused_int(int_type val, bytearray buf) except *:
    """Compile-time specialized: one version per C int type (int, long, long long)."""
    cdef int64_t ival = val
    cdef uint8_t* ptr
    cdef Py_ssize_t old_size
    cdef int bytes_needed
    cdef uint64_t uval

    if 0 <= ival <= 0x7F or (-32 <= ival < 0):
        bytes_needed = 1
    elif (ival >= -0x80 and ival < -32) or (0x80 <= ival <= 0xFF):
        bytes_needed = 2
    elif (ival >= -0x8000 and ival < -0x80) or (0x100 <= ival <= 0xFFFF):
        bytes_needed = 3
    elif (ival >= -0x80000000 and ival < -0x8000) or (0x10000 <= ival <= 0xFFFFFFFF):
        bytes_needed = 5
    else:
        bytes_needed = 9

    old_size = len(buf)
    PyByteArray_Resize(buf, old_size + bytes_needed)
    ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + old_size

    if 0 <= ival <= 0x7F:
        ptr[0] = <uint8_t>ival
    elif -32 <= ival < 0:
        ptr[0] = <uint8_t>((256 + ival) & 0xFF)
    elif ival > 0:
        uval = <uint64_t>ival
        if uval <= 0xFF:
            ptr[0] = 0xCC
            ptr[1] = <uint8_t>uval
        elif uval <= 0xFFFF:
            ptr[0] = 0xCD
            ptr[1] = (uval >> 8) & 0xFF
            ptr[2] = uval & 0xFF
        elif uval <= 0xFFFFFFFF:
            ptr[0] = 0xCE
            ptr[1] = (uval >> 24) & 0xFF
            ptr[2] = (uval >> 16) & 0xFF
            ptr[3] = (uval >> 8) & 0xFF
            ptr[4] = uval & 0xFF
        else:
            ptr[0] = 0xCF
            ptr[1] = (uval >> 56) & 0xFF
            ptr[2] = (uval >> 48) & 0xFF
            ptr[3] = (uval >> 40) & 0xFF
            ptr[4] = (uval >> 32) & 0xFF
            ptr[5] = (uval >> 24) & 0xFF
            ptr[6] = (uval >> 16) & 0xFF
            ptr[7] = (uval >> 8) & 0xFF
            ptr[8] = uval & 0xFF
    else:
        if ival >= -0x80:
            ptr[0] = 0xD0
            ptr[1] = <uint8_t>((256 + ival) & 0xFF)
        elif ival >= -0x8000:
            uval = <uint64_t>(0x10000 + ival) & 0xFFFF
            ptr[0] = 0xD1
            ptr[1] = (uval >> 8) & 0xFF
            ptr[2] = uval & 0xFF
        elif ival >= -0x80000000:
            uval = <uint64_t>(0x100000000 + ival) & 0xFFFFFFFF
            ptr[0] = 0xD2
            ptr[1] = (uval >> 24) & 0xFF
            ptr[2] = (uval >> 16) & 0xFF
            ptr[3] = (uval >> 8) & 0xFF
            ptr[4] = uval & 0xFF
        else:
            uval = <uint64_t>(0x10000000000000000 + ival) & 0xFFFFFFFFFFFFFFFF
            ptr[0] = 0xD3
            ptr[1] = (uval >> 56) & 0xFF
            ptr[2] = (uval >> 48) & 0xFF
            ptr[3] = (uval >> 40) & 0xFF
            ptr[4] = (uval >> 32) & 0xFF
            ptr[5] = (uval >> 24) & 0xFF
            ptr[6] = (uval >> 16) & 0xFF
            ptr[7] = (uval >> 8) & 0xFF
            ptr[8] = uval & 0xFF


cdef inline void _pack_int_optimized(object obj, bytearray buf) except *:
    """Entry from Python int: delegate to fused specialized implementation."""
    _pack_fused_int(<long long>obj, buf)


cdef inline void _pack_str_or_bytes_direct(bytearray buf, const uint8_t* s_ptr, Py_ssize_t n) except *:
    """Single resize + direct header write + memcpy for str/bytes payload (no repeated bounds checks)."""
    cdef uint8_t* ptr
    cdef Py_ssize_t old_size
    cdef Py_ssize_t header_size
    cdef Py_ssize_t total

    if n <= 31:
        header_size = 1
    elif n <= 0xFFFF:
        header_size = 3
    else:
        header_size = 5
    total = header_size + n
    old_size = len(buf)
    PyByteArray_Resize(buf, old_size + total)
    ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + old_size

    if header_size == 1:
        ptr[0] = <uint8_t>(0xA0 | n)
    elif header_size == 3:
        ptr[0] = 0xDA
        ptr[1] = (n >> 8) & 0xFF
        ptr[2] = n & 0xFF
    else:
        ptr[0] = 0xDB
        ptr[1] = (n >> 24) & 0xFF
        ptr[2] = (n >> 16) & 0xFF
        ptr[3] = (n >> 8) & 0xFF
        ptr[4] = n & 0xFF
    memcpy(ptr + header_size, s_ptr, n)


cdef void _msgpack_pack_dict(dict obj, bytearray buf) except *:
    """Pack dict using PyDict_Next for faster iteration."""
    cdef Py_ssize_t n = len(obj)
    cdef Py_ssize_t pos = 0
    cdef PyObject* key_ptr = NULL
    cdef PyObject* value_ptr = NULL
    cdef object key
    cdef object value

    if n <= 15:
        _append_byte(buf, <uint8_t>(0x80 | n))
    elif n <= 0xFFFF:
        _append_byte(buf, 0xDE)
        _pack_uint16_be(buf, <uint16_t>n)
    else:
        _append_byte(buf, 0xDF)
        _pack_uint32_be(buf, <uint32_t>n)

    while PyDict_Next(obj, &pos, &key_ptr, &value_ptr):
        key = <object>key_ptr
        value = <object>value_ptr
        _msgpack_pack_obj(key, buf)
        _msgpack_pack_obj(value, buf)


cdef void _msgpack_pack_obj(object obj, bytearray buf) except *:
    cdef Py_ssize_t n
    cdef bytes s
    cdef const uint8_t* s_ptr
    cdef uint8_t tmp[9]

    if obj is None:
        _append_byte(buf, 0xC0)
        return
    if _is_type(obj, BOOL_TYPE):
        _append_byte(buf, 0xC3 if obj else 0xC2)
        return
    if _is_type(obj, INT_TYPE):
        _pack_int_optimized(obj, buf)
        return
    if _is_type(obj, STR_TYPE):
        s = obj.encode("utf-8")
        n = PyBytes_GET_SIZE(s)
        s_ptr = <const uint8_t*>PyBytes_AS_STRING(s)
        _pack_str_or_bytes_direct(buf, s_ptr, n)
        return
    if _is_type(obj, BYTES_TYPE) or _is_type(obj, BYTEARRAY_TYPE):
        s = bytes(obj)
        n = PyBytes_GET_SIZE(s)
        s_ptr = <const uint8_t*>PyBytes_AS_STRING(s)
        _pack_str_or_bytes_direct(buf, s_ptr, n)
        return
    if _is_type(obj, LIST_TYPE) or _is_type(obj, TUPLE_TYPE):
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
    if _is_type(obj, DICT_TYPE):
        _msgpack_pack_dict(obj, buf)
        return
    raise TypeError(f"msgpack pack: unsupported type {type(obj)}")


cpdef bytes msgpack_pack(object obj):
    """Pack obj to msgpack bytes (v2: optimized int packing)."""
    cdef bytearray buf = bytearray()
    _msgpack_pack_obj(obj, buf)
    return bytes(buf)
