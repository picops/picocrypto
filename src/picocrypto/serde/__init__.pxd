# cython: language_level=3
"""Declarations for picocrypto.serde."""

from .msgpack_pack cimport msgpack_pack
from .msgpack_pack_2 cimport msgpack_pack as msgpack_pack_2

__all__: tuple[str, ...] = ("msgpack_pack", "msgpack_pack_2")
