"""Read back exact evidence inputs; do not rerun proofs or infer semantic links."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent / 'chain-inputs-0001'
OUT.mkdir(exist_ok=False)
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
RES = ROOT / 'results'
manifest = {}

def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def check(p, expected=None):
    p = Path(p)
    digest = sha(p)
    manifest[str(p)] = digest
    assert expected is None or digest == expected, str(p)
    return digest

def read(p):
    check(p)
    return json.loads(p.read_text())

baseline = read(RES / 'refund-native-audit-2026-11-04/attempt-0001/baseline.json')
for name, digest in baseline['protected'].items():
    check(ROOT / name, digest)
check(ROOT / 'FORGE_MISSION.md', baseline['mission_sha256'])
assert hashlib.sha256((ROOT / 'unsure.md').read_bytes()[:baseline['unsure_bytes']]).hexdigest() == baseline['unsure_prefix_sha256']
compile_root = RES / 'refund-arm8-compile-2026-11-04/attempt-0001'
compile_records = []
for name in ['compile-0001', 'compile-repeat']:
    p = compile_root / name
    r = read(p / 'command.json')
    assert r['actual_exit'] == 0
    check(p / 'forge_refundArm8CompileScript.sml', r['source_sha256'])
    check(p / 'refund.S', r['assembly_sha256'])
    for n, digest in r['object_sha256'].items():
        check(p / 'objects' / n, digest)
    compile_records.append(r)
assert compile_records[0]['object_sha256'] == compile_records[1]['object_sha256']
assert compile_records[0]['assembly_sha256'] == compile_records[1]['assembly_sha256']
whole = compile_records[0]['whole_program']
for name in ['proof-whole-0001', 'proof-whole-repeat']:
    p = RES / 'refund-stdio-composition-2026-11-04/attempt-0001' / name
    r = read(p / 'command.json')
    assert r['actual_exit'] == 0 and r['object_sha256'] == whole['object_sha256']
    check(p / 'forge_refundWholeProgScript.sml', whole['source_sha256'])
    for n, digest in r['object_sha256'].items():
        check(p / 'objects' / n, digest)
for theory, source_key, data_key in [
    ('forge_refundCertifiedProg', 'verified_library_source_sha256', 'verified_library_data_sha256'),
    ('forge_refundWireProg', 'wire_source_sha256', 'wire_data_sha256'),
    ('forge_refundStdioProg', 'stdio_source_sha256', 'stdio_data_sha256')]:
    p = TC / 'cakeml/compiler/dafny' / (theory + '_experiment')
    check(p / (theory + 'Script.sml'), whole[source_key])
    check(p / '.hol/objs' / (theory + 'Theory.dat'), whole[data_key])

# Recheck the reported compilation closure, while retaining DISK_THM trust.
closure = read(compile_root / 'dependency-snapshot-0002.json')
closure_files = 0
for group in closure['theories'].values():
    for item in group.values():
        check(item['path'], item['sha256'])
        closure_files += 1
read(compile_root / 'closure-readback-0002.json')

unicode_root = RES / 'refund-unicode-2026-11-04/attempt-0001'
for name in ['proof-final', 'proof-repeat']:
    p = unicode_root / name
    r = read(p / 'command.json')
    assert r['actual_exit'] == 0
    check(p / 'UnicodeRelation.dfy', r['source_sha256'])
    check(p / 'transport/spec/refund/RefundSpec.dfy', baseline['protected']['spec/refund/RefundSpec.dfy'])

runtime = RES / 'refund-native-audit-2026-11-04/attempt-0001'
dependencies = read(runtime / 'runtime-dependencies.json')
for name, digest in dependencies['dependency_sha256'].items():
    check(name, digest)
for index, name in enumerate(['runtime-build-0002', 'runtime-repeat-0002']):
    r = read(runtime / name / 'command.json')
    assert r['actual_exit'] == 0
    check(runtime / name / 'basis_ffi.c', r['source_sha256'])
    check(runtime / name / 'basis_ffi.o', r['object_sha256'])
    native = OUT.parent / ['native-build-0001', 'native-repeat-0001'][index]
    check(native / 'basis_ffi.o', r['object_sha256'])
    check(r['argv'][0], r['clang_sha256'])
    check(Path(r['argv'][4]) / 'SDKSettings.json', r['sdk_settings_sha256'])

pins = {'cakeml': 'cd9155694c16831373ab695a670794f23282ed62',
        'HOL': '9783a49979c94c401ff8c0e51b2eefae7ea95ae3',
        'polyml': '4557554077078decce4ce5f90da00a713cfc32e4'}
for name, pin in pins.items():
    argv = ['git', '-C', str(TC / name), 'rev-parse', 'HEAD']
    p = subprocess.run(argv, capture_output=True)
    assert p.returncode == 0 and p.stdout.decode().strip() == pin
    (OUT / (name + '-pin.json')).write_text(json.dumps({'argv': argv, 'actual_exit': p.returncode, 'commit': pin}, indent=2) + '\n')

sources = list(baseline['upstream_files']) + [
    'compiler/backend/semantics/targetSemScript.sml',
    'compiler/backend/semantics/targetPropsScript.sml',
    'compiler/backend/proofs/lab_to_targetProofScript.sml',
    'compiler/backend/arm8/proofs/arm8_configProofScript.sml',
    'compiler/encoders/arm8/arm8_targetScript.sml',
    'characteristic/cfMainScript.sml', 'characteristic/cfAppScript.sml',
    'basis/basis_ffiScript.sml', 'semantics/semanticsScript.sml']
for name in sources:
    p = TC / 'cakeml' / name
    actual = check(p, baseline['upstream_files'].get(name))
    argv = ['git', '-C', str(TC / 'cakeml'), 'show', pins['cakeml'] + ':' + name]
    git = subprocess.run(argv, capture_output=True)
    assert git.returncode == 0 and hashlib.sha256(git.stdout).hexdigest() == actual
    dst = OUT / 'pinned-sources' / name
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(git.stdout)

failed = RES / 'refund-exception-bridge-2026-11-04/attempt-0001'
for name in ['proof-0001', 'proof-0002', 'proof-0003']:
    r = read(failed / name / 'command.json')
    assert r['actual_exit'] == 1 and not r['object_sha256']
    check(failed / name / 'forge_refundRejectProofScript.sml', r['source_sha256'])
    check(failed / name / 'build.log')
for name in ['diagnostic-0001', 'diagnostic-0002']:
    r = read(failed / (name + '-command.json'))
    assert r['actual_exit'] == 1
    check(failed / (name + '.sml'), r['source_sha256'])
    check(failed / (name + '.log'))

# Named implicit link inputs are fingerprinted now. The ld file-read closure
# and the dyld shared-cache implementation were not captured at link/run time.
xcode = Path('/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain')
for p in [xcode / 'usr/bin/ld', xcode / 'usr/lib/libLTO.dylib',
          xcode / 'usr/lib/clang/17/lib/darwin/libclang_rt.osx.a']:
    check(p)
native_sha = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
cases = 0
for name in ['native-cases-0001', 'native-cases-repeat']:
    r = read(OUT.parent / name / 'result.json')
    assert r['actual_exit'] == 0 and r['observed_case_count'] == 28
    for c in r['cases']:
        assert c['executable_sha256'] == native_sha and c['actual_exit'] == 0
        p = OUT.parent / name / c['case']
        read(p / 'command.json')
        check(p / 'stdin.bin', c['stdin_sha256'])
        check(p / 'stdout.bin', c['stdout_sha256'])
        assert (p / 'stderr.bin').read_bytes() == b''
        check(p / 'stderr.bin')
        cases += 1

(OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
result = {'actual_exit': 0, 'files_checked': len(manifest), 'closure_files_checked': closure_files,
          'compiler_closure_nodes': closure['loaded_theory_nodes'],
          'runtime_dependencies_checked': len(dependencies['dependency_sha256']),
          'native_process_records_checked': cases, 'protected_files_checked': len(baseline['protected']),
          'pinned_upstream_sources_checked': len(sources), 'original_exception_failures_checked': 5,
          'cross_logic_semantic_bridge': 'NOT_ESTABLISHED',
          'dynamic_loader_and_library_identity': 'NOT_ESTABLISHED',
          'independent_clean_source_replay': 'NOT_RUN', 'end_to_end': False}
(OUT / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
