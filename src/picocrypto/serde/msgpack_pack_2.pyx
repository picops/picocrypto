"""msgpack pack: fully optimized with direct writes for all operations. Preserves dict order."""

from cpython.bytearray cimport PyByteArray_AS_STRING, PyByteArray_Resize
from cpython.bytes cimport PyBytes_AS_STRING, PyBytes_GET_SIZE
from cpython.dict cimport PyDict_Next
from cpython.list cimport PyList_GET_ITEM, PyList_GET_SIZE
from cpython.ref cimport PyObject
from libc.stdint cimport int64_t, uint8_t, uint16_t, uint32_t, uint64_t
from libc.string cimport memcpy


# Type cache for faster exact type checks
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


# ============================================================================
# Direct write primitives
# ============================================================================

cdef inline void _write_byte(bytearray buf, uint8_t b, Py_ssize_t* pos):
    """Write single byte at current position."""
    cdef uint8_t* ptr = <uint8_t*>PyByteArray_AS_STRING(buf)
    ptr[pos[0]] = b
    pos[0] += 1


cdef inline void _write_uint16_be(bytearray buf, uint16_t val, Py_ssize_t* pos):
    """Write 16-bit big-endian at current position."""
    cdef uint8_t* ptr = <uint8_t*>PyByteArray_AS_STRING(buf)
    ptr[pos[0]] = (val >> 8) & 0xFF
    ptr[pos[0] + 1] = val & 0xFF
    pos[0] += 2


cdef inline void _write_uint32_be(bytearray buf, uint32_t val, Py_ssize_t* pos):
    """Write 32-bit big-endian at current position."""
    cdef uint8_t* ptr = <uint8_t*>PyByteArray_AS_STRING(buf)
    ptr[pos[0]] = (val >> 24) & 0xFF
    ptr[pos[0] + 1] = (val >> 16) & 0xFF
    ptr[pos[0] + 2] = (val >> 8) & 0xFF
    ptr[pos[0] + 3] = val & 0xFF
    pos[0] += 4


cdef inline void _write_uint64_be(bytearray buf, uint64_t val, Py_ssize_t* pos):
    """Write 64-bit big-endian at current position."""
    cdef uint8_t* ptr = <uint8_t*>PyByteArray_AS_STRING(buf)
    ptr[pos[0]] = (val >> 56) & 0xFF
    ptr[pos[0] + 1] = (val >> 48) & 0xFF
    ptr[pos[0] + 2] = (val >> 40) & 0xFF
    ptr[pos[0] + 3] = (val >> 32) & 0xFF
    ptr[pos[0] + 4] = (val >> 24) & 0xFF
    ptr[pos[0] + 5] = (val >> 16) & 0xFF
    ptr[pos[0] + 6] = (val >> 8) & 0xFF
    ptr[pos[0] + 7] = val & 0xFF
    pos[0] += 8


cdef inline void _write_bytes(bytearray buf, const uint8_t* data, Py_ssize_t size, Py_ssize_t* pos):
    """Write raw bytes at current position."""
    cdef uint8_t* ptr = <uint8_t*>PyByteArray_AS_STRING(buf)
    memcpy(ptr + pos[0], data, size)
    pos[0] += size


# ============================================================================
# Buffer management
# ============================================================================

cdef inline void _ensure_space(bytearray buf, Py_ssize_t pos, Py_ssize_t needed) except *:
    """Ensure buffer has enough space, grow if needed."""
    cdef Py_ssize_t current_size = len(buf)
    cdef Py_ssize_t required = pos + needed
    cdef Py_ssize_t new_size

    if required > current_size:
        new_size = current_size * 3 // 2
        if new_size < required:
            new_size = required
        PyByteArray_Resize(buf, new_size)


# ============================================================================
# Optimized pack functions with direct writes
# ============================================================================

cdef void _pack_int_direct(object obj, bytearray buf, Py_ssize_t* pos) except *:
    """Pack integer with single resize and direct writes."""
    cdef int64_t ival = obj
    cdef uint64_t uval
    cdef uint8_t* ptr
    cdef int bytes_needed
    
    # Calculate bytes needed
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
    
    # Ensure space and get pointer
    _ensure_space(buf, pos[0], bytes_needed)
    ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + pos[0]
    
    # Direct write based on value
    if 0 <= ival <= 0x7F:
        ptr[0] = <uint8_t>ival
        pos[0] += 1
    elif -32 <= ival < 0:
        ptr[0] = <uint8_t>((256 + ival) & 0xFF)
        pos[0] += 1
    elif ival > 0:
        uval = <uint64_t>ival
        if uval <= 0xFF:
            ptr[0] = 0xCC
            ptr[1] = <uint8_t>uval
            pos[0] += 2
        elif uval <= 0xFFFF:
            ptr[0] = 0xCD
            ptr[1] = (uval >> 8) & 0xFF
            ptr[2] = uval & 0xFF
            pos[0] += 3
        elif uval <= 0xFFFFFFFF:
            ptr[0] = 0xCE
            ptr[1] = (uval >> 24) & 0xFF
            ptr[2] = (uval >> 16) & 0xFF
            ptr[3] = (uval >> 8) & 0xFF
            ptr[4] = uval & 0xFF
            pos[0] += 5
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
            pos[0] += 9
    else:  # ival < 0
        if ival >= -0x80:
            ptr[0] = 0xD0
            ptr[1] = <uint8_t>((256 + ival) & 0xFF)
            pos[0] += 2
        elif ival >= -0x8000:
            uval = <uint64_t>(0x10000 + ival) & 0xFFFF
            ptr[0] = 0xD1
            ptr[1] = (uval >> 8) & 0xFF
            ptr[2] = uval & 0xFF
            pos[0] += 3
        elif ival >= -0x80000000:
            uval = <uint64_t>(0x100000000 + ival) & 0xFFFFFFFF
            ptr[0] = 0xD2
            ptr[1] = (uval >> 24) & 0xFF
            ptr[2] = (uval >> 16) & 0xFF
            ptr[3] = (uval >> 8) & 0xFF
            ptr[4] = uval & 0xFF
            pos[0] += 5
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
            pos[0] += 9


cdef void _pack_str_direct(object obj, bytearray buf, Py_ssize_t* pos) except *:
    """Pack string with single resize: header + data in one operation."""
    cdef bytes s = obj.encode("utf-8")
    cdef Py_ssize_t n = PyBytes_GET_SIZE(s)
    cdef const uint8_t* s_ptr = <const uint8_t*>PyBytes_AS_STRING(s)
    cdef uint8_t* ptr
    cdef Py_ssize_t header_size
    
    # Determine header size
    if n <= 31:
        header_size = 1
    elif n <= 0xFFFF:
        header_size = 3
    else:
        header_size = 5
    
    # Single resize for header + data
    _ensure_space(buf, pos[0], header_size + n)
    ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + pos[0]
    
    # Write header
    if header_size == 1:
        ptr[0] = <uint8_t>(0xA0 | n)
    elif header_size == 3:
        ptr[0] = 0xDA
        ptr[1] = (n >> 8) & 0xFF
        ptr[2] = n & 0xFF
    else:  # header_size == 5
        ptr[0] = 0xDB
        ptr[1] = (n >> 24) & 0xFF
        ptr[2] = (n >> 16) & 0xFF
        ptr[3] = (n >> 8) & 0xFF
        ptr[4] = n & 0xFF
    
    # Copy data directly after header
    memcpy(ptr + header_size, s_ptr, n)
    pos[0] += header_size + n


cdef void _pack_bytes_direct(object obj, bytearray buf, Py_ssize_t* pos) except *:
    """Pack bytes with single resize: header + data in one operation."""
    cdef bytes s = bytes(obj)
    cdef Py_ssize_t n = PyBytes_GET_SIZE(s)
    cdef const uint8_t* s_ptr = <const uint8_t*>PyBytes_AS_STRING(s)
    cdef uint8_t* ptr
    cdef Py_ssize_t header_size
    
    # Determine header size
    if n <= 31:
        header_size = 1
    elif n <= 0xFFFF:
        header_size = 3
    else:
        header_size = 5
    
    # Single resize for header + data
    _ensure_space(buf, pos[0], header_size + n)
    ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + pos[0]
    
    # Write header
    if header_size == 1:
        ptr[0] = <uint8_t>(0xA0 | n)
    elif header_size == 3:
        ptr[0] = 0xDA
        ptr[1] = (n >> 8) & 0xFF
        ptr[2] = n & 0xFF
    else:  # header_size == 5
        ptr[0] = 0xDB
        ptr[1] = (n >> 24) & 0xFF
        ptr[2] = (n >> 16) & 0xFF
        ptr[3] = (n >> 8) & 0xFF
        ptr[4] = n & 0xFF
    
    # Copy data directly after header
    memcpy(ptr + header_size, s_ptr, n)
    pos[0] += header_size + n


cdef void _pack_list_direct(object obj, bytearray buf, Py_ssize_t* pos) except *:
    """Pack list with direct header write."""
    cdef Py_ssize_t n = len(obj)
    cdef Py_ssize_t i
    cdef uint8_t* ptr
    cdef int header_size
    
    # Determine header size
    if n <= 15:
        header_size = 1
    elif n <= 0xFFFF:
        header_size = 3
    else:
        header_size = 5
    
    # Ensure space and write header directly
    _ensure_space(buf, pos[0], header_size)
    ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + pos[0]
    
    if header_size == 1:
        ptr[0] = <uint8_t>(0x90 | n)
        pos[0] += 1
    elif header_size == 3:
        ptr[0] = 0xDC
        ptr[1] = (n >> 8) & 0xFF
        ptr[2] = n & 0xFF
        pos[0] += 3
    else:  # header_size == 5
        ptr[0] = 0xDD
        ptr[1] = (n >> 24) & 0xFF
        ptr[2] = (n >> 16) & 0xFF
        ptr[3] = (n >> 8) & 0xFF
        ptr[4] = n & 0xFF
        pos[0] += 5
    
    # Pack elements
    if _is_type(obj, LIST_TYPE):
        # Fast path for lists using PyList_GET_ITEM
        for i in range(n):
            _msgpack_pack_obj(<object>PyList_GET_ITEM(obj, i), buf, pos)
    else:
        # Tuple or other sequence
        for item in obj:
            _msgpack_pack_obj(item, buf, pos)


cdef void _pack_dict_direct(dict obj, bytearray buf, Py_ssize_t* pos) except *:
    """Pack dict with direct header write and PyDict_Next iteration."""
    cdef Py_ssize_t n = len(obj)
    cdef Py_ssize_t dict_pos = 0
    cdef PyObject* key_ptr = NULL
    cdef PyObject* value_ptr = NULL
    cdef object key, value
    cdef uint8_t* ptr
    cdef int header_size
    
    # Determine header size
    if n <= 15:
        header_size = 1
    elif n <= 0xFFFF:
        header_size = 3
    else:
        header_size = 5
    
    # Ensure space and write header directly
    _ensure_space(buf, pos[0], header_size)
    ptr = <uint8_t*>PyByteArray_AS_STRING(buf) + pos[0]
    
    if header_size == 1:
        ptr[0] = <uint8_t>(0x80 | n)
        pos[0] += 1
    elif header_size == 3:
        ptr[0] = 0xDE
        ptr[1] = (n >> 8) & 0xFF
        ptr[2] = n & 0xFF
        pos[0] += 3
    else:  # header_size == 5
        ptr[0] = 0xDF
        ptr[1] = (n >> 24) & 0xFF
        ptr[2] = (n >> 16) & 0xFF
        ptr[3] = (n >> 8) & 0xFF
        ptr[4] = n & 0xFF
        pos[0] += 5
    
    # Pack key-value pairs using fast PyDict_Next
    while PyDict_Next(obj, &dict_pos, &key_ptr, &value_ptr):
        key = <object>key_ptr
        value = <object>value_ptr
        _msgpack_pack_obj(key, buf, pos)
        _msgpack_pack_obj(value, buf, pos)


# ============================================================================
# Main pack function
# ============================================================================

cdef void _msgpack_pack_obj(object obj, bytearray buf, Py_ssize_t* pos) except *:
    """Pack object with direct writes - no intermediate operations."""
    
    # None
    if obj is None:
        _ensure_space(buf, pos[0], 1)
        _write_byte(buf, 0xC0, pos)
        return
    
    # Bool (check before int since bool is int subclass)
    if _is_type(obj, BOOL_TYPE):
        _ensure_space(buf, pos[0], 1)
        _write_byte(buf, 0xC3 if obj else 0xC2, pos)
        return
    
    # Int - use optimized direct write
    if _is_type(obj, INT_TYPE):
        _pack_int_direct(obj, buf, pos)
        return
    
    # String - single resize for header + data
    if _is_type(obj, STR_TYPE):
        _pack_str_direct(obj, buf, pos)
        return
    
    # Bytes/bytearray - single resize for header + data
    if _is_type(obj, BYTES_TYPE) or _is_type(obj, BYTEARRAY_TYPE):
        _pack_bytes_direct(obj, buf, pos)
        return
    
    # List/tuple - direct header write
    if _is_type(obj, LIST_TYPE) or _is_type(obj, TUPLE_TYPE):
        _pack_list_direct(obj, buf, pos)
        return
    
    # Dict - direct header write with PyDict_Next
    if _is_type(obj, DICT_TYPE):
        _pack_dict_direct(obj, buf, pos)
        return
    
    raise TypeError(f"msgpack pack: unsupported type {type(obj)}")


cpdef bytes msgpack_pack(object obj):
    """
    Pack obj to msgpack bytes. 
    
    Fully optimized with:
    - Direct buffer writes (no intermediate operations)
    - Single resize per string/bytes (header + data together)
    - Position-based writing (no repeated appends)
    - Fast PyDict_Next iteration for dicts
    - Fast PyList_GET_ITEM access for lists
    - Exact type checks (faster than isinstance)
    
    Supports: dict, list, tuple, str, bytes, bytearray, int, bool, None
    Preserves dict order.
    """
    cdef bytearray buf = bytearray(1024)  # Pre-allocate reasonable size
    cdef Py_ssize_t pos = 0
    
    _msgpack_pack_obj(obj, buf, &pos)
    
    # Resize to actual used size and convert to bytes
    PyByteArray_Resize(buf, pos)
    return bytes(buf)
