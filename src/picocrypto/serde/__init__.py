"""Serialization / deserialization (serde): msgpack pack and future formats."""

from .msgpack_pack import msgpack_pack

__all__: tuple[str, ...] = ("msgpack_pack",)
