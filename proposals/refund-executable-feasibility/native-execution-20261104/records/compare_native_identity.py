"""Compare this refund artifact using existing HOL output and Apple metadata tools.

This is a byte comparison and integrity control, not a Mach-O semantics proof.
"""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

BASE = Path(__file__).resolve().parent
OUT = BASE / 'identity-0001'
OUT.mkdir(exist_ok=False)
EXPECTED = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def run(name, argv, cwd=OUT):
    result = subprocess.run(argv, cwd=cwd, capture_output=True)
    (OUT / (name + '.stdout')).write_bytes(result.stdout)
    (OUT / (name + '.stderr')).write_bytes(result.stderr)
    record = {'argv': argv, 'cwd': str(cwd), 'actual_exit': result.returncode}
    (OUT / (name + '.json')).write_text(json.dumps(record, indent=2) + '\n')
    return result

assert json.loads((BASE / 'extraction-0002/command.json').read_text())['actual_exit'] == 0
code = (BASE / 'compiled-extraction/code.bin').read_bytes()
nums = [int(n) for n in (BASE / 'compiled-extraction/data.nums').read_text().splitlines()]
assert len(code) == 130436 and len(nums) == 2531
assert all(0 <= n < 2**64 for n in nums)
data = b''.join(n.to_bytes(8, 'little') for n in nums)
(OUT / 'expected-bitmaps.bin').write_bytes(data)
checks = []
manifest = {}
for index, name in enumerate(['native-build-0001', 'native-repeat-0001']):
    source = BASE / name
    local = OUT / ('copy-' + str(index))
    local.mkdir()
    exe = local / 'refund'
    assert sha(source / 'refund') == EXPECTED
    shutil.copy2(source / 'refund', exe)
    assert sha(exe) == EXPECTED
    tag = 'copy-' + str(index)
    syms = run(tag + '-nm', ['/usr/bin/nm', '-nm', str(exe)])
    layout = run(tag + '-otool', ['/usr/bin/otool', '-l', str(exe)])
    assert syms.returncode == layout.returncode == 0
    symbols = syms.stdout.decode()
    sections = layout.stdout.decode()
    def address(symbol):
        matches = re.findall(r'^([0-9a-f]+)\s+.*\s' + re.escape(symbol) + r'$', symbols, re.M)
        assert len(matches) == 1, symbol
        return int(matches[0], 16)
    def section(name, segment):
        matches = re.findall(r'sectname ' + name + r'\s+segname ' + segment +
                             r'\s+addr (0x[0-9a-f]+)\s+size (0x[0-9a-f]+)\s+offset (\d+)', sections)
        assert len(matches) == 1
        addr, size, offset = matches[0]
        return int(addr, 16), int(size, 16), int(offset)
    text_addr, text_size, text_offset = section('__text', '__TEXT')
    data_addr, data_size, data_offset = section('__data', '__DATA')
    start, end = address('cake_main'), address('_cake_codebuffer_begin')
    bitmap_start, bitmap_end = address('cake_bitmaps'), address('_cake_bitmaps_buffer_begin')
    assert end - start == len(code)
    assert bitmap_end - bitmap_start == len(data)
    assert text_addr <= start < end <= text_addr + text_size
    assert data_addr <= bitmap_start < bitmap_end <= data_addr + data_size
    code_offset = text_offset + start - text_addr
    bitmap_offset = data_offset + bitmap_start - data_addr
    contents = exe.read_bytes()
    observed_code = contents[code_offset:code_offset + len(code)]
    observed_data = contents[bitmap_offset:bitmap_offset + len(data)]
    (local / 'compiled-code.bin').write_bytes(observed_code)
    (local / 'compiled-bitmaps.bin').write_bytes(observed_data)
    assert observed_code == code, name + ': compiled code differs'
    assert observed_data == data, name + ': compiled bitmaps differ'
    verify = run(tag + '-codesign-verify', ['/usr/bin/codesign', '--verify', '--strict', '--verbose=2', str(exe)])
    display = run(tag + '-codesign-display', ['/usr/bin/codesign', '--display', '--verbose=4', str(exe)])
    assert verify.returncode == display.returncode == 0
    signature = display.stderr.decode()
    assert 'Signature=adhoc' in signature
    assert 'CDHash=7c0eef4687359f32f0f393e9063a96024fd4229d\n' in signature
    assert sha(exe) == EXPECTED
    record = {'build': name, 'executable_sha256': sha(exe), 'code_file_offset': code_offset,
              'bitmap_file_offset': bitmap_offset, 'code_bytes': len(code), 'bitmap_words': len(nums),
              'code_sha256': sha(local / 'compiled-code.bin'),
              'bitmap_sha256': sha(local / 'compiled-bitmaps.bin'),
              'signature_verify_actual_exit': verify.returncode,
              'code_matches_hol': True, 'bitmaps_match_hol': True}
    checks.append(record)
    for p in source.rglob('*'):
        if p.is_file():
            manifest[str(p)] = sha(p)

# This damaged copy is never executed or signed. It tests the existing digest
# and platform signature checks against one changed byte in compiled code.
mutant = OUT / 'mutated-refund'
mutant_bytes = bytearray((OUT / 'copy-0/refund').read_bytes())
offset = checks[0]['code_file_offset']
mutant_bytes[offset] ^= 1
mutant.write_bytes(mutant_bytes)
mutant.chmod(0o755)
(OUT / 'approved.sha256').write_text(EXPECTED + '  mutated-refund\n')
digest = run('mutant-shasum', ['/usr/bin/shasum', '-a', '256', '-c', 'approved.sha256'])
signature = run('mutant-codesign', ['/usr/bin/codesign', '--verify', '--strict', '--verbose=2', str(mutant)])
assert digest.returncode == 1 and b'FAILED' in digest.stdout
assert signature.returncode != 0 and b'invalid signature' in signature.stderr.lower()

# A separate system SHA tool checks all producer build members and native records.
for folder in ['native-cases-0001', 'native-cases-repeat', 'compiled-extraction', 'extraction-0002']:
    for p in (BASE / folder).rglob('*'):
        if p.is_file():
            manifest[str(p)] = sha(p)
for p in [BASE / 'link-result.json', BASE / 'native-repeat-readback.json']:
    manifest[str(p)] = sha(p)
(OUT / 'chain.sha256').write_text(''.join(digest + '  ' + name + '\n' for name, digest in sorted(manifest.items())))
system_hash = run('chain-shasum', ['/usr/bin/shasum', '-a', '256', '-c', 'chain.sha256'])
assert system_hash.returncode == 0
result = {'actual_exit': 0, 'builds': checks, 'checked_files': len(manifest),
          'mutant_sha256': sha(mutant), 'mutated_file_offset': offset,
          'mutant_digest_actual_exit': digest.returncode,
          'mutant_signature_actual_exit': signature.returncode,
          'system_hash_actual_exit': system_hash.returncode,
          'scope': 'Exact file-byte identity; standard-tool metadata and signature checks. No loader or execution proof.',
          'independent_environment': False, 'end_to_end': False}
(OUT / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
