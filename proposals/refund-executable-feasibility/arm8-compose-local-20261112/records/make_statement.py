"""Emit the HOL premise text for the 24 code bytes, read from the exact native executable.

Usage: python3 -I -B make_statement.py   (prints JSON with the SML fragments and identities)
"""
from pathlib import Path
import hashlib, json

EXE = Path('/Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund')
NATIVE = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
FFIREAD_OFFSET, FFIREAD_BYTES = 151920, 112
BRANCH = 151980            # tbnz w0,#31 ; VM 0x1000251ac
OFFSETS = [0, 1, 2, 3] + list(range(24, 44))
data = EXE.read_bytes()
assert hashlib.sha256(data).hexdigest() == NATIVE
fragment = data[FFIREAD_OFFSET:FFIREAD_OFFSET + FFIREAD_BYTES]
assert hashlib.sha256(fragment).hexdigest() == 'ec5f3b8045a2d7038e8645acd7bd72a001bddc75ab24b7fd913c4d36cc163bf4'
words = {off: data[BRANCH + off:BRANCH + off + 4][::-1].hex() for off in (0, 24, 28, 32, 36, 40)}
assert list(words.values()) == ['37f800c0', '52800028', '39000268', 'a9417bfd', 'a8c24ff4', 'd65f03c0']
term = lambda off: 's.MEM s.PC' if off == 0 else 's.MEM (s.PC + %dw)' % off
code = ' /\\\n  '.join('%s = %dw' % (term(off), data[BRANCH + off]) for off in OFFSETS)
separate = ' /\\\n  '.join('s.REG 19w <> s.PC + %dw' % off for off in range(32, 44))
print(json.dumps({'native_sha256': NATIVE, 'file_offset_of_branch': BRANCH, 'vm_address_of_branch': hex(0x100000000 + BRANCH),
                  'words': words, 'code_premise': code, 'separation_premise': separate}, indent=1))
