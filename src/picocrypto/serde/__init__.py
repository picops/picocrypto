"""Serialization: msgpack pack."""

from .msgpack_pack import msgpack_pack
from .msgpack_pack_2 import msgpack_pack as msgpack_pack_2

__all__: tuple[str, ...] = ("msgpack_pack", "msgpack_pack_2")
