"""Observation only: count direct ARM64 B/BL words in the exact native code
whose target lies in the entry area below the code start.

This is a hand-written field extraction for one instruction class. It is not
the L3 model and proves nothing. The HOL case install-site-0001 checks the one
word that targets the installer entry against the published model.

Usage: python3 -I -B scan_entry_branches.py
"""
from pathlib import Path
import hashlib, json

EXE = Path('/Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund')
NATIVE = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
CODE = '3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb'
START, LENGTH, FFI_OFFSET = 16592, 130436, 16
data = EXE.read_bytes()
assert hashlib.sha256(data).hexdigest() == NATIVE
code = data[START:START + LENGTH]
assert hashlib.sha256(code).hexdigest() == CODE
hits = {}
for i in range(0, LENGTH - 3, 4):
    w = int.from_bytes(code[i:i + 4], 'little')
    if (w >> 26) in (0b000101, 0b100101):
        imm = w & 0x3FFFFFF
        if imm & 0x2000000:
            imm -= 1 << 26
        target = i + imm * 4
        if target < 0:
            hits.setdefault(target, []).append({'code_offset': i, 'file_offset': START + i, 'word': '%08x' % w,
                                                'bytes': list(code[i:i + 4])})
names = {-FFI_OFFSET: 'halt entry', -2 * FFI_OFFSET: 'install entry'}
report = {'native_sha256': NATIVE, 'code_sha256': CODE, 'code_file_offset': START, 'code_bytes': LENGTH,
          'targets': {str(t): {'entry': names.get(t, 'entry index %d' % ((-t) // FFI_OFFSET - 3)), 'count': len(v),
                               'sites': v[:4]} for t, v in sorted(hits.items(), reverse=True)},
          'scope': 'Observation. Hand-written B/BL field extraction; not a proof; indirect branches not analysed.'}
print(json.dumps(report, indent=1))
