"""
Benchmark signing: pure Python (_bip137, _eip712) vs Cython (bip137_cy, eip712_cy).
Compares time per call and peak memory (tracemalloc) per run.

Run from repo root:

  PYTHONPATH=src python benchmarks/bench_signing.py

Or after pip install -e .:

  python benchmarks/bench_signing.py
"""

from __future__ import annotations

import os
import sys
import time
import tracemalloc

_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_src = os.path.join(_root, "src")
if _src not in sys.path:
    sys.path.insert(0, _src)

from picocrypto.signing._bip137 import bip137_sign_message as bip137_sign_py
from picocrypto.signing._bip137 import bip137_signed_message_hash as bip137_hash_py
from picocrypto.signing._bip137 import bip137_verify_message as bip137_verify_py
from picocrypto.signing._eip712 import eip712_hash_agent_message as eip712_agent_py
from picocrypto.signing._eip712 import eip712_hash_full_message as eip712_full_py

try:
    from picocrypto.signing.bip137 import bip137_sign_message as bip137_sign_cy
    from picocrypto.signing.bip137 import bip137_signed_message_hash as bip137_hash_cy
    from picocrypto.signing.bip137 import bip137_verify_message as bip137_verify_cy
    from picocrypto.signing.eip712 import eip712_hash_agent_message as eip712_agent_cy
    from picocrypto.signing.eip712 import eip712_hash_full_message as eip712_full_cy

    HAS_CY = True
except ImportError:
    HAS_CY = False

from picocrypto import privkey_to_pubkey

N_TIME = 500
N_MEM = 200
PRIV = bytes(31) + bytes([1])
PUB = privkey_to_pubkey(PRIV)
MSG = b"bench message for BIP-137"
EIP712_DOMAIN = {
    "name": "A",
    "version": "1",
    "chainId": 1,
    "verifyingContract": "0x" + "00" * 20,
}
EIP712_FULL = {
    "domain": EIP712_DOMAIN,
    "types": {
        "Mail": [
            {"name": "from", "type": "address"},
            {"name": "message", "type": "string"},
        ]
    },
    "primaryType": "Mail",
    "message": {"from": "0x" + "00" * 20, "message": "hello"},
}


def _time_per_call(fn, *args, n: int = N_TIME, **kwargs) -> float:
    for _ in range(20):
        fn(*args, **kwargs)
    start = time.perf_counter()
    for _ in range(n):
        fn(*args, **kwargs)
    return (time.perf_counter() - start) / n


def _peak_kb(fn, *args, n: int = N_MEM, **kwargs) -> float:
    tracemalloc.start()
    if hasattr(tracemalloc, "reset_peak"):
        tracemalloc.reset_peak()
    for _ in range(n):
        fn(*args, **kwargs)
    _, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    return peak / 1024.0


def main() -> None:
    if not HAS_CY:
        print(
            "Cython signing not available (bip137 / eip712 extensions not built). Run: make build install"
        )
        sys.exit(1)

    print("Benchmark: signing  pure Python vs Cython")
    print("  (_bip137 / _eip712 vs bip137 / eip712 Cython)")
    print()

    # Sanity
    h_py = bip137_hash_py(MSG)
    h_cy = bip137_hash_cy(MSG)
    assert h_py == h_cy
    sig_py = bip137_sign_py(PRIV, MSG)
    sig_cy = bip137_sign_cy(PRIV, MSG)
    assert bip137_verify_py(MSG, sig_cy, PUB) and bip137_verify_cy(MSG, sig_py, PUB)
    full_py = eip712_full_py(EIP712_FULL)
    full_cy = eip712_full_cy(EIP712_FULL)
    assert full_py == full_cy
    agent_py = eip712_agent_py(EIP712_DOMAIN, "0x" + "11" * 20, bytes(32))
    agent_cy = eip712_agent_cy(EIP712_DOMAIN, "0x" + "11" * 20, bytes(32))
    assert agent_py == agent_cy
    print("  Sanity check: same outputs.")
    print()

    print(f"  n = {N_TIME} (time), {N_MEM} (memory)")
    print()

    # BIP-137
    print("  --- BIP-137 ---")
    t_py = _time_per_call(bip137_hash_py, MSG, n=N_TIME) * 1000
    t_cy = _time_per_call(bip137_hash_cy, MSG, n=N_TIME) * 1000
    print(
        f"  bip137_signed_message_hash  Python {t_py:.4f} ms  Cython {t_cy:.4f} ms  -> {t_py/t_cy:.2f}x"
    )
    t_py = _time_per_call(bip137_sign_py, PRIV, MSG, n=N_TIME) * 1000
    t_cy = _time_per_call(bip137_sign_cy, PRIV, MSG, n=N_TIME) * 1000
    print(
        f"  bip137_sign_message          Python {t_py:.4f} ms  Cython {t_cy:.4f} ms  -> {t_py/t_cy:.2f}x"
    )
    t_py = _time_per_call(bip137_verify_py, MSG, sig_py, PUB, n=N_TIME) * 1000
    t_cy = _time_per_call(bip137_verify_cy, MSG, sig_py, PUB, n=N_TIME) * 1000
    print(
        f"  bip137_verify_message        Python {t_py:.4f} ms  Cython {t_cy:.4f} ms  -> {t_py/t_cy:.2f}x"
    )
    print()

    # EIP-712
    print("  --- EIP-712 ---")
    t_py = _time_per_call(eip712_full_py, EIP712_FULL, n=N_TIME) * 1000
    t_cy = _time_per_call(eip712_full_cy, EIP712_FULL, n=N_TIME) * 1000
    print(
        f"  eip712_hash_full_message     Python {t_py:.4f} ms  Cython {t_cy:.4f} ms  -> {t_py/t_cy:.2f}x"
    )
    t_py = (
        _time_per_call(
            eip712_agent_py, EIP712_DOMAIN, "0x" + "11" * 20, bytes(32), n=N_TIME
        )
        * 1000
    )
    t_cy = (
        _time_per_call(
            eip712_agent_cy, EIP712_DOMAIN, "0x" + "11" * 20, bytes(32), n=N_TIME
        )
        * 1000
    )
    print(
        f"  eip712_hash_agent_message    Python {t_py:.4f} ms  Cython {t_cy:.4f} ms  -> {t_py/t_cy:.2f}x"
    )
    print()

    # Memory
    print("  --- Peak memory (KiB) ---")
    m_py = _peak_kb(bip137_sign_py, PRIV, MSG, n=N_MEM)
    m_cy = _peak_kb(bip137_sign_cy, PRIV, MSG, n=N_MEM)
    print(
        f"  bip137_sign_message   Python {m_py:.2f}  Cython {m_cy:.2f}  ratio {m_py/m_cy:.2f}x"
    )
    m_py = _peak_kb(eip712_full_py, EIP712_FULL, n=N_MEM)
    m_cy = _peak_kb(eip712_full_cy, EIP712_FULL, n=N_MEM)
    print(
        f"  eip712_hash_full      Python {m_py:.2f}  Cython {m_cy:.2f}  ratio {m_py/m_cy:.2f}x"
    )


if __name__ == "__main__":
    main()
