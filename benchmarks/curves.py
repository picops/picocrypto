"""
Benchmark curve operations: cycrypto (Cython) vs picocrypto (pure Python).

Run from repo root with both packages on PYTHONPATH, e.g.:

  PYTHONPATH=src:../picocrypto/src python benchmarks/bench_curves.py

Or from this directory:

  PYTHONPATH=../src:../../picocrypto/src python bench_curves.py
"""

from __future__ import annotations

import os
import sys
import time

# Ensure both packages are importable: cycrypto from this repo, picocrypto from sibling.
_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_PICO_SRC = os.path.join(os.path.dirname(_REPO_ROOT), "picocrypto", "src")
_CY_SRC = os.path.join(_REPO_ROOT, "src")
for path in (_CY_SRC, _PICO_SRC):
    if path not in sys.path:
        sys.path.insert(0, path)

import picocrypto.curves.ed25519 as cy_ed
import picocrypto.curves.secp256k1 as cy_secp
from picocrypto.hashes import keccak256

try:
    import picocrypto.curves.ed25519 as py_ed
    import picocrypto.curves.secp256k1 as py_secp
except ImportError as e:
    print("picocrypto not found. Add sibling picocrypto to PYTHONPATH, e.g.:")
    print("  PYTHONPATH=src:../picocrypto/src python benchmarks/bench_curves.py")
    sys.exit(1)

# Shared test data (same for both libs)
SECP_PRIV = bytes(31) + bytes([1])
MSG_HASH = keccak256(b"message to sign")

ED25519_SECRET = bytes.fromhex(
    "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
)
ED25519_MSG = b"bench message for ed25519"


def _time_it(name: str, fn, *args, n: int = 200, **kwargs):
    # Warmup
    for _ in range(10):
        fn(*args, **kwargs)
    start = time.perf_counter()
    for _ in range(n):
        fn(*args, **kwargs)
    elapsed = time.perf_counter() - start
    return elapsed / n


def main() -> None:
    n = 100  # iterations for fast ops
    n_slow = 10  # iterations for sign_recoverable (slow in pure Python)
    print("Benchmark: cycrypto (Cython) vs picocrypto (pure Python)")
    print(f"  Iterations: {n} (fast ops), {n_slow} (sign_recoverable)")
    print()

    results: list[tuple[str, float, float]] = []

    # --- secp256k1 ---
    print("secp256k1")
    py_t = _time_it("privkey_to_pubkey", py_secp.privkey_to_pubkey, SECP_PRIV, n=n)
    cy_t = _time_it("privkey_to_pubkey", cy_secp.privkey_to_pubkey, SECP_PRIV, n=n)
    results.append(("privkey_to_pubkey", py_t, cy_t))
    print(
        f"  privkey_to_pubkey   picocrypto {py_t*1e3:.2f} ms  cycrypto {cy_t*1e3:.2f} ms  -> {py_t/cy_t:.2f}x"
    )

    py_t = _time_it("privkey_to_address", py_secp.privkey_to_address, SECP_PRIV, n=n)
    cy_t = _time_it("privkey_to_address", cy_secp.privkey_to_address, SECP_PRIV, n=n)
    results.append(("privkey_to_address", py_t, cy_t))
    print(
        f"  privkey_to_address  picocrypto {py_t*1e3:.2f} ms  cycrypto {cy_t*1e3:.2f} ms  -> {py_t/cy_t:.2f}x"
    )

    py_t = _time_it(
        "sign_recoverable", py_secp.sign_recoverable, SECP_PRIV, MSG_HASH, n=n_slow
    )
    cy_t = _time_it(
        "sign_recoverable", cy_secp.sign_recoverable, SECP_PRIV, MSG_HASH, n=n_slow
    )
    results.append(("sign_recoverable", py_t, cy_t))
    print(
        f"  sign_recoverable    picocrypto {py_t*1e3:.2f} ms  cycrypto {cy_t*1e3:.2f} ms  -> {py_t/cy_t:.2f}x"
    )

    # recover_pubkey: need (msg_hash, r, s, recid) from a valid sig
    r, s, v = cy_secp.sign_recoverable(SECP_PRIV, MSG_HASH)
    recid = v - 27
    py_t = _time_it(
        "recover_pubkey", py_secp.recover_pubkey, MSG_HASH, r, s, recid, n=n
    )
    cy_t = _time_it(
        "recover_pubkey", cy_secp.recover_pubkey, MSG_HASH, r, s, recid, n=n
    )
    results.append(("recover_pubkey", py_t, cy_t))
    print(
        f"  recover_pubkey      picocrypto {py_t*1e3:.2f} ms  cycrypto {cy_t*1e3:.2f} ms  -> {py_t/cy_t:.2f}x"
    )
    print()

    # --- Ed25519 ---
    print("Ed25519")
    py_t = _time_it("ed25519_public_key", py_ed.ed25519_public_key, ED25519_SECRET, n=n)
    cy_t = _time_it("ed25519_public_key", cy_ed.ed25519_public_key, ED25519_SECRET, n=n)
    results.append(("ed25519_public_key", py_t, cy_t))
    print(
        f"  ed25519_public_key  picocrypto {py_t*1e3:.2f} ms  cycrypto {cy_t*1e3:.2f} ms  -> {py_t/cy_t:.2f}x"
    )

    py_t = _time_it(
        "ed25519_sign", py_ed.ed25519_sign, ED25519_MSG, ED25519_SECRET, n=n
    )
    cy_t = _time_it(
        "ed25519_sign", cy_ed.ed25519_sign, ED25519_MSG, ED25519_SECRET, n=n
    )
    results.append(("ed25519_sign", py_t, cy_t))
    print(
        f"  ed25519_sign        picocrypto {py_t*1e3:.2f} ms  cycrypto {cy_t*1e3:.2f} ms  -> {py_t/cy_t:.2f}x"
    )

    py_pub = py_ed.ed25519_public_key(ED25519_SECRET)
    cy_sig = cy_ed.ed25519_sign(ED25519_MSG, ED25519_SECRET)
    py_t = _time_it(
        "ed25519_verify", py_ed.ed25519_verify, ED25519_MSG, cy_sig, py_pub, n=n
    )
    cy_t = _time_it(
        "ed25519_verify", cy_ed.ed25519_verify, ED25519_MSG, cy_sig, py_pub, n=n
    )
    results.append(("ed25519_verify", py_t, cy_t))
    print(
        f"  ed25519_verify      picocrypto {py_t*1e3:.2f} ms  cycrypto {cy_t*1e3:.2f} ms  -> {py_t/cy_t:.2f}x"
    )
    print()

    # Summary
    avg_speedup = sum(py_t / cy_t for _, py_t, cy_t in results) / len(results)
    print(f"Average speedup (cycrypto vs picocrypto): {avg_speedup:.2f}x")


if __name__ == "__main__":
    main()
