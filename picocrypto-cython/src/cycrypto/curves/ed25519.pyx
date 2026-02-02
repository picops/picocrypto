"""Ed25519 (RFC 8032): key generation, sign, verify."""

import hashlib

cdef object _P = 2**255 - 19
cdef object _L = 2**252 + 27742317777372353535851937790883648493
cdef object _D = (-121665 * pow(121666, _P - 2, _P)) % _P

cdef inline object _modp_inv(object x):
    return pow(x, _P - 2, _P)

cdef object _sha512_modq(bytes data):
    h = hashlib.sha512(data).digest()
    return int.from_bytes(h, "little") % _L

cdef object _recover_x(object y, int sign):
    if y >= _P:
        return None
    x2 = (y * y - 1) * _modp_inv(_D * y * y + 1) % _P
    if x2 == 0:
        return 0 if sign == 0 else None
    x = pow(x2, (_P + 3) // 8, _P)
    if (x * x - x2) % _P != 0:
        x = x * pow(2, (_P - 1) // 4, _P) % _P
    if (x * x - x2) % _P != 0:
        return None
    if (x & 1) != sign:
        x = (_P - x) % _P
    return x

cdef object _Gy = (4 * _modp_inv(5)) % _P
cdef object _Gx = _recover_x(_Gy, 0)
cdef tuple _G
if _Gx is None:
    raise RuntimeError("Ed25519 base point x recovery failed")
_G = (_Gx, _Gy, 1, (_Gx * _Gy) % _P)

cdef inline tuple _point_add(tuple P, tuple Q):
    A = (P[1] - P[0]) * (Q[1] - Q[0]) % _P
    B = (P[1] + P[0]) * (Q[1] + Q[0]) % _P
    C = (2 * P[3] * Q[3] * _D) % _P
    D = (2 * P[2] * Q[2]) % _P
    E = (B - A) % _P
    F = (D - C) % _P
    G = (D + C) % _P
    H = (B + A) % _P
    return (E * F % _P, G * H % _P, F * G % _P, E * H % _P)

cdef inline tuple _point_mul(object s, tuple P):
    s = s % _L
    Q = (0, 1, 1, 0)
    while s > 0:
        if s & 1:
            Q = _point_add(Q, P)
        P = _point_add(P, P)
        s >>= 1
    return Q

cdef inline bint _point_equal(tuple P, tuple Q):
    if (P[0] * Q[2] - Q[0] * P[2]) % _P != 0:
        return False
    if (P[1] * Q[2] - Q[1] * P[2]) % _P != 0:
        return False
    return True

cdef inline bytes _point_compress(tuple P):
    zinv = _modp_inv(P[2])
    x = P[0] * zinv % _P
    y = P[1] * zinv % _P
    return (y | ((x & 1) << 255)).to_bytes(32, "little")

cdef object _point_decompress(bytes s):
    if len(s) != 32:
        return None
    y = int.from_bytes(s, "little")
    sign = y >> 255
    y = y & ((1 << 255) - 1)
    x = _recover_x(y, sign)
    if x is None:
        return None
    return (x, y, 1, (x * y) % _P)

cdef tuple _secret_expand(bytes secret):
    if len(secret) != 32:
        raise ValueError("Ed25519 secret must be 32 bytes")
    h = hashlib.sha512(secret).digest()
    a = int.from_bytes(h[:32], "little")
    a = a & ((1 << 254) - 8)
    a = a | (1 << 254)
    return (a, h[32:64])

cpdef bytes ed25519_public_key(bytes seed):
    a, _ = _secret_expand(seed)
    return _point_compress(_point_mul(a, _G))

cpdef bytes ed25519_sign(bytes message, bytes seed):
    a, prefix = _secret_expand(seed)
    A_enc = _point_compress(_point_mul(a, _G))
    r = _sha512_modq(prefix + message)
    R = _point_mul(r, _G)
    R_enc = _point_compress(R)
    h = _sha512_modq(R_enc + A_enc + message)
    s = (r + h * a) % _L
    return R_enc + s.to_bytes(32, "little")

cpdef bint ed25519_verify(bytes message, bytes signature, bytes public_key):
    if len(signature) != 64 or len(public_key) != 32:
        return False
    A = _point_decompress(public_key)
    if A is None:
        return False
    R_enc = signature[:32]
    S_raw = signature[32:]
    R = _point_decompress(R_enc)
    if R is None:
        return False
    s = int.from_bytes(S_raw, "little")
    if s >= _L:
        return False
    h = _sha512_modq(R_enc + public_key + message)
    sB = _point_mul(s, _G)
    hA = _point_mul(h, A)
    R_plus_hA = _point_add(R, hA)
    return _point_equal(sB, R_plus_hA)
