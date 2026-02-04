"""Minimal msgpack pack (dict, list, str, int, bool). Cython implementation. Preserves dict order."""

cdef void _msgpack_pack_obj(object obj, bytearray buf) except *:
    if obj is None:
        buf.append(0xC0)
    elif isinstance(obj, bool):
        buf.append(0xC3 if obj else 0xC2)
    elif isinstance(obj, int):
        if 0 <= obj <= 0x7F:
            buf.append(obj)
        elif -32 <= obj < 0:
            buf.append((0x100 + obj) & 0xFF)
        elif 0x80 <= obj <= 0xFF:
            buf.extend((0xCC, obj & 0xFF))
        elif 0x100 <= obj <= 0xFFFF:
            buf.extend((0xCD, (obj >> 8) & 0xFF, obj & 0xFF))
        elif 0x10000 <= obj <= 0xFFFFFFFF:
            buf.append(0xCE)
            buf.extend(obj.to_bytes(4, "big"))
        elif 0x100000000 <= obj <= 0xFFFFFFFFFFFFFFFF:
            buf.append(0xCF)
            buf.extend(obj.to_bytes(8, "big"))
        elif obj < 0:
            if obj >= -0x80:
                buf.extend((0xD0, (0x100 + obj) & 0xFF))
            elif obj >= -0x8000:
                buf.extend(
                    (0xD1, ((0x10000 + obj) >> 8) & 0xFF, (0x10000 + obj) & 0xFF)
                )
            elif obj >= -0x80000000:
                buf.append(0xD2)
                buf.extend((0x100000000 + obj).to_bytes(4, "big"))
            else:
                buf.append(0xD3)
                buf.extend((0x10000000000000000 + obj).to_bytes(8, "big"))
        else:
            if obj <= 0xFF:
                buf.extend((0xCC, obj & 0xFF))
            elif obj <= 0xFFFF:
                buf.extend((0xCD, (obj >> 8) & 0xFF, obj & 0xFF))
            elif obj <= 0xFFFFFFFF:
                buf.append(0xCE)
                buf.extend(obj.to_bytes(4, "big"))
            else:
                buf.append(0xCF)
                buf.extend(obj.to_bytes(8, "big"))
    elif isinstance(obj, (bytes, bytearray)):
        s = bytes(obj)
        n = len(s)
        if n <= 31:
            buf.append(0xA0 | n)
        elif n <= 0xFFFF:
            buf.extend((0xDA, (n >> 8) & 0xFF, n & 0xFF))
        else:
            buf.extend((0xDB, (n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF))
        buf.extend(s)
    elif isinstance(obj, str):
        s = obj.encode("utf-8")
        n = len(s)
        if n <= 31:
            buf.append(0xA0 | n)
        elif n <= 0xFFFF:
            buf.extend((0xDA, (n >> 8) & 0xFF, n & 0xFF))
        else:
            buf.extend((0xDB, (n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF))
        buf.extend(s)
    elif isinstance(obj, (list, tuple)):
        n = len(obj)
        if n <= 15:
            buf.append(0x90 | n)
        elif n <= 0xFFFF:
            buf.extend((0xDC, (n >> 8) & 0xFF, n & 0xFF))
        else:
            buf.extend((0xDD, (n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF))
        for x in obj:
            _msgpack_pack_obj(x, buf)
    elif isinstance(obj, dict):
        n = len(obj)
        if n <= 15:
            buf.append(0x80 | n)
        elif n <= 0xFFFF:
            buf.extend((0xDE, (n >> 8) & 0xFF, n & 0xFF))
        else:
            buf.extend((0xDF, (n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF))
        for k, v in obj.items():
            _msgpack_pack_obj(k, buf)
            _msgpack_pack_obj(v, buf)
    else:
        raise TypeError(f"msgpack pack: unsupported type {type(obj)}")


cpdef bytes msgpack_pack(object obj):
    """Pack obj to msgpack bytes. Supports dict, list, str, int, bool, bytes, None."""
    cdef bytearray buf = bytearray()
    _msgpack_pack_obj(obj, buf)
    return bytes(buf)
