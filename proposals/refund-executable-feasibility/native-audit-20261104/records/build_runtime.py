"""Compile the unchanged published C runtime for a local ARM64 feasibility check.

This creates a runtime object only. It does not compile or prove refund behavior.
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
SOURCE = ROOT / '.toolchain/experiments/refund-cakeml-20261104/cakeml/basis/basis_ffi.c'
CLANG = Path('/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang')
SDK = Path('/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk').resolve()
baseline = json.loads((OUT / 'baseline.json').read_text())

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

assert sha(SOURCE) == baseline['upstream_files']['basis/basis_ffi.c']
records = []
for case in ['runtime-build-0002', 'runtime-repeat-0002']:
    work = OUT / case
    work.mkdir(exist_ok=False)
    shutil.copyfile(SOURCE, work / 'basis_ffi.c')
    argv = [str(CLANG), '-arch', 'arm64', '-isysroot', str(SDK), '-O2', '-MD', '-MF', 'basis_ffi.d',
            '-c', 'basis_ffi.c', '-o', 'basis_ffi.o']
    result = subprocess.run(argv, cwd=work, capture_output=True)
    (work / 'stdout.log').write_bytes(result.stdout)
    (work / 'stderr.log').write_bytes(result.stderr)
    record = {'argv': argv, 'cwd': str(work), 'actual_exit': result.returncode,
              'source_sha256': sha(work / 'basis_ffi.c'), 'clang_sha256': sha(CLANG),
              'sdk_settings_sha256': sha(SDK / 'SDKSettings.json'),
              'scope': 'Unchanged published C runtime object only',
              'native_refund_proved': False, 'end_to_end': False}
    if result.returncode == 0:
        record['object_sha256'] = sha(work / 'basis_ffi.o')
    (work / 'command.json').write_text(json.dumps(record, indent=2) + '\n')
    records.append(record)
    print(json.dumps(record), flush=True)
    if result.returncode:
        print(result.stderr.decode(errors='replace'))
        raise SystemExit(result.returncode)
assert records[0]['object_sha256'] == records[1]['object_sha256']
(OUT / 'runtime-build-result.json').write_text(json.dumps({
    'actual_exit': 0, 'commands': records, 'objects_identical': True,
    'classification': 'BUILD_REPRODUCED_NOT_BEHAVIOR_PROVED',
    'native_refund_proved': False, 'end_to_end': False}, indent=2) + '\n')
