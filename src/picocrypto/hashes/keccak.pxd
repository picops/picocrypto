# cython: language_level=3
"""Declarations for picocrypto.hashes.keccak."""

cdef extern from "stdint.h":
    ctypedef unsigned long long uint64_t

cdef uint64_t _rol64(uint64_t v, int n) noexcept nogil

cdef void _keccak_f(uint64_t state[5][5]) noexcept nogil

cpdef bytes keccak256(bytes data)
