"""Collect exact published sources and result records for a premise audit."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
CAKE = TC / 'cakeml'
COMMIT = 'cd9155694c16831373ab695a670794f23282ed62'
FILES = [
    'compiler/backend/proofs/backendProofScript.sml',
    'compiler/backend/semantics/targetSemScript.sml',
    'compiler/backend/arm8/proofs/arm8_configProofScript.sml',
    'compiler/backend/arm8/arm8_configScript.sml',
    'compiler/encoders/arm8/arm8_targetScript.sml',
    'compiler/encoders/asm/asmPropsScript.sml',
    'semantics/proofs/semanticsPropsScript.sml',
    'basis/basis_ffiScript.sml', 'basis/basis_ffi.c',
    'basis/CommandLineProofScript.sml', 'basis/clFFIScript.sml',
    'basis/fsFFIPropsScript.sml', 'basis/TextIOProofScript.sml',
]
records = {}
for name in FILES:
    source = CAKE / name
    blob = subprocess.check_output(['git', 'show', COMMIT + ':' + name], cwd=CAKE)
    assert blob == source.read_bytes(), name
    target = OUT / 'upstream' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        assert target.read_bytes() == blob
    else:
        target.write_bytes(blob)
    records[name] = {'sha256': hashlib.sha256(blob).hexdigest(),
                     'bytes': len(blob), 'commit': COMMIT}

compile_dir = ROOT / 'results/refund-arm8-compile-2026-11-04/attempt-0001'
native_dir = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004'
for base, prefix, members in [
    (compile_dir, 'compiler', [
        'forge_refundArm8ProofScript.sml', 'compile-repeat/command.json',
        'closure-readback-0002.json']),
    (native_dir, 'native', ['identity-0001/result.json',
                          'extraction-0002/command.json']),
]:
    for member in members:
        target = OUT / 'records' / prefix / member
        target.parent.mkdir(parents=True, exist_ok=True)
        assert not target.exists()
        shutil.copyfile(base / member, target)

commands = []
for repo in [CAKE, TC / 'HOL']:
    argv = ['git', 'diff', '--exit-code', '--']
    child = subprocess.run(argv, cwd=repo, capture_output=True)
    assert child.returncode == 0
    commands.append({'argv': argv, 'cwd': str(repo), 'actual_exit': child.returncode})
result = {'actual_exit': 0, 'upstream_source_files': records,
          'commands': commands,
          'scope': 'Pinned-source and record identities only. No semantic premise discharged.',
          'end_to_end': False}
target = OUT / 'source-inspection.json'
assert not target.exists()
target.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'actual_exit': 0, 'source_files': len(records),
                  'tracked_diff_exits': [c['actual_exit'] for c in commands]}))
