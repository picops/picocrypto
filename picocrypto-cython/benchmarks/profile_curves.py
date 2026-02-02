"""Profile curve hot paths (cycrypto) with cProfile. Run: PYTHONPATH=src python benchmarks/profile_curves.py. Use --workload-only for py-spy/scalene."""

from __future__ import annotations

import argparse
import cProfile
import os
import pstats
import sys

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_CY_SRC = os.path.join(_REPO_ROOT, "src")
if _CY_SRC not in sys.path:
    sys.path.insert(0, _CY_SRC)

import cycrypto.curves.secp256k1 as secp
import cycrypto.curves.ed25519 as ed
from cycrypto.hashes import keccak256

SECP_PRIV = bytes(31) + bytes([1])
MSG_HASH = keccak256(b"message to sign")
ED25519_SECRET = bytes.fromhex("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
ED25519_MSG = b"profile message for ed25519"


def run_secp256k1(n: int) -> None:
    for _ in range(n):
        secp.privkey_to_pubkey(SECP_PRIV)
    for _ in range(n):
        secp.privkey_to_address(SECP_PRIV)
    r, s, v = secp.sign_recoverable(SECP_PRIV, MSG_HASH)
    for _ in range(n):
        secp.recover_pubkey(MSG_HASH, r, s, v - 27)
    for _ in range(n):
        secp.sign_recoverable(SECP_PRIV, MSG_HASH)


def run_ed25519(n: int) -> None:
    for _ in range(n):
        ed.ed25519_public_key(ED25519_SECRET)
    sig = ed.ed25519_sign(ED25519_MSG, ED25519_SECRET)
    pub = ed.ed25519_public_key(ED25519_SECRET)
    for _ in range(n):
        ed.ed25519_verify(ED25519_MSG, sig, pub)
    for _ in range(n):
        ed.ed25519_sign(ED25519_MSG, ED25519_SECRET)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--secp256k1", action="store_true")
    ap.add_argument("--ed25519", action="store_true")
    ap.add_argument("-n", type=int, default=None)
    ap.add_argument("-o", "--output", metavar="FILE")
    ap.add_argument("--sort", default="cumtime", choices=("cumtime", "tottime", "calls", "name"))
    ap.add_argument("--workload-only", action="store_true", help="Just run workload (for py-spy/scalene)")
    args = ap.parse_args()
    if not args.secp256k1 and not args.ed25519:
        args.secp256k1 = args.ed25519 = True
    n_secp = args.n or 20
    n_ed = args.n or 50

    def run_all() -> None:
        if args.secp256k1:
            run_secp256k1(n_secp)
        if args.ed25519:
            run_ed25519(n_ed)

    if args.workload_only:
        run_all()
        return 0

    pr = cProfile.Profile()
    pr.enable()
    run_all()
    pr.disable()
    stats = pstats.Stats(pr)
    if args.output:
        out = args.output if args.output.endswith(".prof") else args.output + ".prof"
        stats.dump_stats(out)
        print(f"Profile saved to {out}")
    stats.strip_dirs()
    stats.sort_stats(args.sort)
    print("\n--- Top 50 by", args.sort, "---")
    stats.print_stats(50)
    print("\n--- Callers ---")
    stats.print_callers(15)
    return 0


if __name__ == "__main__":
    sys.exit(main())
