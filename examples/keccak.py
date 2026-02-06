"""
Simple Keccak-256 usage. Uses whatever implementation is exposed as keccak256
(e.g. set in picocrypto.hashes: keccak or keccak_cy).

Run from repo root: PYTHONPATH=src python benchmarks/example_keccak.py
"""

import os
import sys

if getattr(sys, "frozen", False) is False:
    _root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    _src = os.path.join(_root, "src")
    if _src not in sys.path:
        sys.path.insert(0, _src)

from picocrypto.hashes import keccak256

# Single name: when you choose implementation, that is what keccak256 points to
digest = keccak256(b"hello")
print("keccak256(b'hello') =", digest.hex())

# Typical use: hash message for signing
msg = b"message to sign"
h = keccak256(msg)
print("keccak256(msg)      =", h.hex())
