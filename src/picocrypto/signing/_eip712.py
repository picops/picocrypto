"""
EIP-712 typed-data hashing. Matches eth_account encode_typed_data for API compatibility.
"""

from __future__ import annotations

from ..hashes import keccak256

_EIP712_SOLIDITY_TYPES = frozenset(
    {
        "string",
        "bytes",
        "bool",
        "address",
        "uint8",
        "uint16",
        "uint24",
        "uint32",
        "uint40",
        "uint48",
        "uint56",
        "uint64",
        "uint72",
        "uint80",
        "uint88",
        "uint96",
        "uint104",
        "uint112",
        "uint120",
        "uint128",
        "uint136",
        "uint144",
        "uint152",
        "uint160",
        "uint168",
        "uint176",
        "uint184",
        "uint192",
        "uint200",
        "uint208",
        "uint216",
        "uint224",
        "uint232",
        "uint240",
        "uint248",
        "uint256",
        "int8",
        "int16",
        "int24",
        "int32",
        "int40",
        "int48",
        "int56",
        "int64",
        "int72",
        "int80",
        "int88",
        "int96",
        "int104",
        "int112",
        "int120",
        "int128",
        "int136",
        "int144",
        "int152",
        "int160",
        "int168",
        "int176",
        "int184",
        "int192",
        "int200",
        "int208",
        "int216",
        "int224",
        "int232",
        "int240",
        "int248",
        "int256",
        "bytes1",
        "bytes2",
        "bytes3",
        "bytes4",
        "bytes5",
        "bytes6",
        "bytes7",
        "bytes8",
        "bytes9",
        "bytes10",
        "bytes11",
        "bytes12",
        "bytes13",
        "bytes14",
        "bytes15",
        "bytes16",
        "bytes17",
        "bytes18",
        "bytes19",
        "bytes20",
        "bytes21",
        "bytes22",
        "bytes23",
        "bytes24",
        "bytes25",
        "bytes26",
        "bytes27",
        "bytes28",
        "bytes29",
        "bytes30",
        "bytes31",
        "bytes32",
    }
)


def _eip712_find_type_dependencies(
    type_name: str,
    types: dict[str, list[dict[str, str]]],
    results: set[str] | None = None,
) -> set[str]:
    """Collect all type names that type_name depends on (recursive)."""
    if results is None:
        results = set()
    type_name = type_name.split("[")[0].strip()  # core type
    if type_name in _EIP712_SOLIDITY_TYPES or type_name in results:
        return results
    if type_name not in types:
        raise ValueError(f"Type {type_name!r} not in types")
    results.add(type_name)
    for field in types[type_name]:
        _eip712_find_type_dependencies(field["type"], types, results)
    return results


def _eip712_encode_type(type_name: str, types: dict[str, list[dict[str, str]]]) -> str:
    """Encode type and its dependencies as string (e.g. 'Mail(address from,string message)')."""
    deps = _eip712_find_type_dependencies(type_name, types)
    if type_name in deps:
        deps = deps - {type_name}
    deps = [type_name] + sorted(deps)
    out = []
    for tn in deps:
        fields = types[tn]
        parts = [f"{f['type']} {f['name']}" for f in fields]
        out.append(f"{tn}({','.join(parts)})")
    return "".join(out)


def _eip712_hash_type(type_name: str, types: dict[str, list[dict[str, str]]]) -> bytes:
    """Keccak-256 of encoded type string (type hash)."""
    return keccak256(_eip712_encode_type(type_name, types).encode("utf-8"))


def _eip712_encode_field(
    types: dict[str, list[dict[str, str]]],
    name: str,
    type_: str,
    value: object,
) -> bytes:
    """Encode one EIP-712 field to 32 bytes (matches eth_account encode_field)."""
    core_type = type_.split("[")[0].strip()
    if core_type in types:
        if value is None:
            return b"\x00" * 32
        return _eip712_hash_struct(core_type, types, value)
    if type_ in ("string", "bytes") and value is None:
        return b"\x00" * 32
    if value is None:
        raise ValueError(f"Missing value for field {name!r} of type {type_!r}")
    if type_ == "bool":
        falsy = {"False", "false", "0"}
        val = bool(value and value not in falsy)
        return (1 if val else 0).to_bytes(32, "big")
    if type_.startswith("bytes"):
        if not isinstance(value, bytes):
            if isinstance(value, str):
                value = (
                    bytes.fromhex(value[2:])
                    if value.startswith("0x")
                    else value.encode("utf-8")
                )
            else:
                value = (
                    (value or 0).to_bytes(32, "big")
                    if isinstance(value, int)
                    else bytes(value)
                )
        value = bytes(value)
        if type_ == "bytes":
            return keccak256(value)
        return value.ljust(32, b"\x00")[:32]
    if type_ == "string":
        b = value.encode("utf-8") if isinstance(value, str) else bytes(value)
        return keccak256(b)
    if type_.startswith(("int", "uint")):
        if isinstance(value, str):
            value = int(value, 16 if value.startswith("0x") else 10)
        v = int(value)
        if v < 0 and type_.startswith("uint"):
            v = 0
        return v.to_bytes(32, "big", signed=(type_.startswith("int")))
    if type_ == "address":
        if isinstance(value, str):
            value = value[2:] if value.startswith("0x") else value
            value = bytes.fromhex(value)
        value = bytes(value)[:20]
        return value.rjust(32, b"\x00")
    raise ValueError(f"Unsupported EIP-712 type {type_!r}")


def _eip712_encode_data(
    type_name: str,
    types: dict[str, list[dict[str, str]]],
    data: dict[str, object],
) -> bytes:
    """Encode struct data as type_hash + concatenated 32-byte field encodings."""
    out = bytearray(_eip712_hash_type(type_name, types))
    for field in types[type_name]:
        enc = _eip712_encode_field(
            types, field["name"], field["type"], data.get(field["name"])
        )
        out += enc
    return bytes(out)


def _eip712_hash_struct(
    type_name: str,
    types: dict[str, list[dict[str, str]]],
    data: dict[str, object],
) -> bytes:
    """Keccak-256 of encoded struct (struct hash)."""
    return keccak256(_eip712_encode_data(type_name, types, data))


def _eip712_hash_domain_typed(domain_data: dict[str, object]) -> bytes:
    """Domain separator matching eth_account hash_domain (field order: name, version, chainId, verifyingContract)."""
    eip712_domain_map = {
        "name": {"name": "name", "type": "string"},
        "version": {"name": "version", "type": "string"},
        "chainId": {"name": "chainId", "type": "uint256"},
        "verifyingContract": {"name": "verifyingContract", "type": "address"},
        "salt": {"name": "salt", "type": "bytes32"},
    }
    for k in domain_data:
        if k not in eip712_domain_map:
            raise ValueError(f"Invalid domain key {k!r}")
    domain_types = {
        "EIP712Domain": [
            eip712_domain_map[k] for k in eip712_domain_map if k in domain_data
        ],
    }
    return _eip712_hash_struct("EIP712Domain", domain_types, domain_data)


def eip712_hash_full_message(full_message: dict) -> bytes:
    """
    EIP-712 hash to sign from full_message (domain, types, primaryType, message).

    Matches eth_account encode_typed_data(full_message=...) then keccak256(\\x19\\x01||header||body).

    Args:
        full_message: Dict with keys "domain", "types", "primaryType", "message".

    Returns:
        32-byte hash to sign (e.g. with sign_recoverable).
    """
    domain = full_message["domain"]
    types = full_message["types"]
    primary_type = full_message["primaryType"]
    message = full_message["message"]
    domain_sep = _eip712_hash_domain_typed(domain)
    struct_hash = _eip712_hash_struct(primary_type, types, message)
    return keccak256(b"\x19\x01" + domain_sep + struct_hash)


# --- Legacy helpers (same result for L1 Agent when types match) ---

_EIP712_DOMAIN_TYPEHASH = keccak256(
    b"EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
)
_AGENT_TYPEHASH = keccak256(b"Agent(string source,bytes32 connectionId)")


def _eip712_hash_domain(domain: dict) -> bytes:
    enc = bytearray()
    enc += keccak256(domain["name"].encode("utf-8"))
    enc += keccak256(domain["version"].encode("utf-8"))
    enc += int(domain["chainId"]).to_bytes(32, "big")
    addr = domain["verifyingContract"]
    if isinstance(addr, str):
        addr = addr[2:] if addr.startswith("0x") else addr
        addr = bytes.fromhex(addr)
    enc += addr.rjust(32, b"\x00")
    return keccak256(_EIP712_DOMAIN_TYPEHASH + bytes(enc))


def _eip712_hash_agent(message: dict) -> bytes:
    enc = bytearray()
    enc += keccak256(message["source"].encode("utf-8"))
    conn = message["connectionId"]
    conn = conn if isinstance(conn, bytes) else bytes(conn)
    enc += conn.ljust(32, b"\x00")[:32]
    return keccak256(_AGENT_TYPEHASH + bytes(enc))


def eip712_hash_agent_message(domain: dict, source: str, connection_id: bytes) -> bytes:
    """
    EIP-712 hash for Agent(source, connectionId) with given domain (legacy).

    Args:
        domain: EIP-712 domain (name, version, chainId, verifyingContract).
        source: Agent source string.
        connection_id: 32-byte connection id.

    Returns:
        32-byte hash to sign.
    """
    domain_sep = _eip712_hash_domain(domain)
    msg_hash = _eip712_hash_agent({"source": source, "connectionId": connection_id})
    return keccak256(b"\x19\x01" + domain_sep + msg_hash)


__all__: tuple[str, ...] = (
    "eip712_hash_agent_message",
    "eip712_hash_full_message",
)
