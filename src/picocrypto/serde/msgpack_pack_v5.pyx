"""msgpack pack v3: truly optimized. Preserves dict order."""

from cpython.bytearray cimport PyByteArray_AS_STRING, PyByteArray_Resize
from cpython.bytes cimport PyBytes_AS_STRING, PyBytes_GET_SIZE
from cpython.dict cimport PyDict_Next
from cpython.list cimport PyList_GET_ITEM, PyList_GET_SIZE
from cpython.ref cimport PyObject
from libc.stdint cimport int64_t, uint8_t, uint16_t, uint32_t, uint64_t
from libc.string cimport memcpy


# Type cache
cdef object DICT_TYPE = dict
cdef object LIST_TYPE = list
cdef object TUPLE_TYPE = tuple
cdef object STR_TYPE = str
cdef object BYTES_TYPE = bytes
cdef object BYTEARRAY_TYPE = bytearray
cdef object INT_TYPE = int
cdef object BOOL_TYPE = bool


cdef inline bint _is_type(object obj, object typ):
    """Exact type check."""
    return type(obj) is typ


# Keep your original fast append - it's already optimized!
cdef inline void _append_byte(bytearray buf, uint8_t b) except *:
    buf.append(b)


# Optimized: single resize + memcpy for multi-byte sequences
cdef inline void _append_bytes_fast(bytearray buf, const uint8_t* data, Py_ssize_t size) except *:
    """Single resize + memcpy (faster than repeated appends)."""
    cdef Py_ssize_t old_size = len(buf)
    PyByteArray_Resize(buf, old_size + size)
    memcpy(PyByteArray_AS_STRING(buf) + old_size, data, size)


# Direct write variants for headers (avoid stack temp array)
cdef inline void _write_header_uint16(bytearray buf, uint8_t tag, uint16_t val) except *:
    """Write tag + uint16 big-endian directly."""
    cdef Py_ssize_t old_size = len(buf)
    PyByteArray_Resize(buf, old_size + 3)
    cdef uint8_t* ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + old_size
    ptr[0] = tag
    ptr[1] = (val >> 8) & 0xFF
    ptr[2] = val & 0xFF


cdef inline void _write_header_uint32(bytearray buf, uint8_t tag, uint32_t val) except *:
    """Write tag + uint32 big-endian directly."""
    cdef Py_ssize_t old_size = len(buf)
    PyByteArray_Resize(buf, old_size + 5)
    cdef uint8_t* ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + old_size
    ptr[0] = tag
    ptr[1] = (val >> 24) & 0xFF
    ptr[2] = (val >> 16) & 0xFF
    ptr[3] = (val >> 8) & 0xFF
    ptr[4] = val & 0xFF


# Keep your excellent fused int implementation - it's already great!
ctypedef fused int_type:
    int
    long
    long long


cdef void _pack_fused_int(int_type val, bytearray buf) except *:
    """Your original optimized version - already excellent!"""
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
    _pack_fused_int(<long long>obj, buf)


# OPTIMIZATION: Single resize for str/bytes header+data
cdef inline void _pack_str_or_bytes_combined(bytearray buf, const uint8_t* s_ptr, Py_ssize_t n) except *:
    """Single resize: header + data together."""
    cdef uint8_t* ptr
    cdef Py_ssize_t old_size = len(buf)
    cdef Py_ssize_t total

    if n <= 31:
        total = 1 + n
        PyByteArray_Resize(buf, old_size + total)
        ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + old_size
        ptr[0] = <uint8_t>(0xA0 | n)
        memcpy(ptr + 1, s_ptr, n)
    elif n <= 0xFFFF:
        total = 3 + n
        PyByteArray_Resize(buf, old_size + total)
        ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + old_size
        ptr[0] = 0xDA
        ptr[1] = (n >> 8) & 0xFF
        ptr[2] = n & 0xFF
        memcpy(ptr + 3, s_ptr, n)
    else:
        total = 5 + n
        PyByteArray_Resize(buf, old_size + total)
        ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + old_size
        ptr[0] = 0xDB
        ptr[1] = (n >> 24) & 0xFF
        ptr[2] = (n >> 16) & 0xFF
        ptr[3] = (n >> 8) & 0xFF
        ptr[4] = n & 0xFF
        memcpy(ptr + 5, s_ptr, n)


# OPTIMIZATION: Direct header write for lists
cdef inline void _write_list_header(bytearray buf, Py_ssize_t n) except *:
    """Write list header with single resize."""
    cdef uint8_t* ptr
    cdef Py_ssize_t old_size

    if n <= 15:
        _append_byte(buf, <uint8_t>(0x90 | n))
    elif n <= 0xFFFF:
        old_size = len(buf)
        PyByteArray_Resize(buf, old_size + 3)
        ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + old_size
        ptr[0] = 0xDC
        ptr[1] = (n >> 8) & 0xFF
        ptr[2] = n & 0xFF
    else:
        old_size = len(buf)
        PyByteArray_Resize(buf, old_size + 5)
        ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + old_size
        ptr[0] = 0xDD
        ptr[1] = (n >> 24) & 0xFF
        ptr[2] = (n >> 16) & 0xFF
        ptr[3] = (n >> 8) & 0xFF
        ptr[4] = n & 0xFF


# OPTIMIZATION: Direct header write for dicts  
cdef inline void _write_dict_header(bytearray buf, Py_ssize_t n) except *:
    """Write dict header with single resize."""
    cdef uint8_t* ptr
    cdef Py_ssize_t old_size

    if n <= 15:
        _append_byte(buf, <uint8_t>(0x80 | n))
    elif n <= 0xFFFF:
        old_size = len(buf)
        PyByteArray_Resize(buf, old_size + 3)
        ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + old_size
        ptr[0] = 0xDE
        ptr[1] = (n >> 8) & 0xFF
        ptr[2] = n & 0xFF
    else:
        old_size = len(buf)
        PyByteArray_Resize(buf, old_size + 5)
        ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + old_size
        ptr[0] = 0xDF
        ptr[1] = (n >> 24) & 0xFF
        ptr[2] = (n >> 16) & 0xFF
        ptr[3] = (n >> 8) & 0xFF
        ptr[4] = n & 0xFF


cdef void _msgpack_pack_dict(dict obj, bytearray buf) except *:
    """Pack dict using PyDict_Next."""
    cdef Py_ssize_t n = len(obj)
    cdef Py_ssize_t pos = 0
    cdef PyObject* key_ptr = NULL
    cdef PyObject* value_ptr = NULL
    cdef object key, value

    _write_dict_header(buf, n)

    while PyDict_Next(obj, &pos, &key_ptr, &value_ptr):
        key = <object>key_ptr
        value = <object>value_ptr
        _msgpack_pack_obj(key, buf)
        _msgpack_pack_obj(value, buf)


cdef void _msgpack_pack_list(object obj, bytearray buf) except *:
    """Pack list/tuple with fast access."""
    cdef Py_ssize_t n = len(obj)
    cdef Py_ssize_t i

    _write_list_header(buf, n)

    # Fast path for lists
    if _is_type(obj, LIST_TYPE):
        for i in range(n):
            _msgpack_pack_obj(<object>PyList_GET_ITEM(obj, i), buf)
    else:
        # Tuple or other
        for item in obj:
            _msgpack_pack_obj(item, buf)


cdef void _msgpack_pack_obj(object obj, bytearray buf) except *:
    cdef bytes s
    cdef const uint8_t* s_ptr
    cdef Py_ssize_t n

    if obj is None:
        _append_byte(buf, 0xC0)
        return
    
    # Bool before int (bool is int subclass)
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
        _pack_str_or_bytes_combined(buf, s_ptr, n)
        return
    
    if _is_type(obj, BYTES_TYPE) or _is_type(obj, BYTEARRAY_TYPE):
        s = bytes(obj)
        n = PyBytes_GET_SIZE(s)
        s_ptr = <const uint8_t*>PyBytes_AS_STRING(s)
        _pack_str_or_bytes_combined(buf, s_ptr, n)
        return
    
    if _is_type(obj, LIST_TYPE) or _is_type(obj, TUPLE_TYPE):
        _msgpack_pack_list(obj, buf)
        return
    
    if _is_type(obj, DICT_TYPE):
        _msgpack_pack_dict(obj, buf)
        return
    
    raise TypeError(f"msgpack pack: unsupported type {type(obj)}")


cpdef bytes msgpack_pack(object obj):
    """Pack obj to msgpack bytes (v4: back to basics that work)."""
    cdef bytearray buf = bytearray()
    _msgpack_pack_obj(obj, buf)
    return bytes(buf)
