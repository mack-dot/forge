"""Check artifact identity and recorded outcomes, not program semantics."""
from pathlib import Path
import base64
import hashlib
import json
import subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-dafny-frontend-20261104'
SRC = TC / 'dafny'
CAKE = ROOT / '.toolchain/experiments/refund-cakeml-20261104/cakeml'
read = lambda p: json.loads(p.read_text())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

expected = {
    'git-init': 0, 'git-fetch': 0, 'git-checkout': 0, 'git-identity': 0,
    'git-integrity': 0, 'sdk-metadata': 0, 'sdk-download': 0,
    'sdk-extract': 0, 'sdk-info': 0, 'frontend-build': 0,
    'frontend-version': 0, 'source-export': 4, 'source-export-0002': 4,
    'solver-version': 0, 'source-export-0003': 1, 'source-repeat': 1,
    'example': 0, 'module-control': 1, 'module-free-diagnostic': 1,
}
for name, code in expected.items():
    assert read(OUT / name / 'result.json')['actual_exit'] == code, name
for name in ['source-export', 'source-export-0002']:
    assert 'Z3 is not found' in (OUT / name / 'stdout.log').read_text()
for name in ['source-export-0003', 'source-repeat', 'module-control']:
    text = (OUT / name / 'stdout.log').read_text()
    assert 'Unsupported Concat2Iterator`1' in text and 'Bake.cs:line 24' in text
assert 'Unsupported ResolvedOpcode: Iff' in (OUT / 'module-free-diagnostic/stdout.log').read_text()
for name in ['FlatCore.sexp', 'FlatCore-repeat.sexp', 'named-module-control.sexp', 'module-free-diagnostic.sexp']:
    assert not (OUT / name).exists(), name
assert (OUT / 'upstream-plus-one.sexp').stat().st_size > 0

source = ROOT / 'proposals/refund-executable-feasibility/unicode-20261104/transport/FlatCore.dfy'
assert sha(source) == 'a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d'
diag = read(OUT / 'module-free-diagnostic.json')
assert diag['removed_prefix'].encode() + (OUT / 'module-free-diagnostic.dfy').read_bytes() + diag['removed_suffix'].encode() == source.read_bytes()
example_path = 'compiler/dafny/examples/plus_one.dfy'
example = subprocess.check_output(['git', 'show', 'cd9155694c16831373ab695a670794f23282ed62:' + example_path], cwd=CAKE)
assert example == (CAKE / example_path).read_bytes()
assert (OUT / 'named-module-control.dfy').read_bytes() == b'module NamedControl {\n' + example + b'\n}\n'
assert not subprocess.check_output(['git', 'diff', '--name-only'], cwd=SRC)
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=SRC, text=True).strip()
tree = subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], cwd=SRC, text=True).strip()
assert head == '6eb1ed63544a2e22c151db9b575f4308b8f329b0'
build = read(OUT / 'build-identities-0002.json')
assert build['source_tree'] == tree
for name, digest in {**build['locks'], **build['output_files']}.items():
    assert sha(SRC / name) == digest, name
packages = {}
for file in (OUT / 'dependency-locks').rglob('packages.lock.json'):
    for target in read(file)['dependencies'].values():
        for name, item in target.items():
            if item['type'].lower() == 'project':
                continue
            version = item['resolved']
            package = TC / 'nuget-packages' / name.lower() / version / (name.lower() + '.' + version + '.nupkg')
            actual = base64.b64encode(hashlib.sha512(package.read_bytes()).digest()).decode()
            assert actual == item['contentHash'], str(package)
            packages[name + '/' + version] = actual

baseline = read(ROOT / 'results/refund-native-audit-2026-11-04/attempt-0001/baseline.json')
for name, digest in baseline['protected'].items():
    assert sha(ROOT / name) == digest, name
assert sha(ROOT / 'FORGE_MISSION.md') == baseline['mission_sha256']
native = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native) == 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
result = {
    'actual_exit': 0, 'recorded_exits': expected, 'frontend_commit': head, 'frontend_tree': tree,
    'flat_source_sha256': sha(source), 'source_unchanged': True,
    'native_sha256': sha(native), 'protected_files_unchanged': len(baseline['protected']),
    'output_files_checked': len(build['output_files']), 'dependency_locks_checked': len(build['locks']),
    'nuget_package_archive_hashes': packages, 'nuget_packages_checked': len(packages),
    'dependency_identity_scope': 'Consistency with captured locks, not authenticated producer identity. Build reports skipped NuGet signature verification.',
    'source_to_model_binding': 'NOT_ESTABLISHED',
    'exact_source_export': 'UNSUPPORTED', 'HOL_parse_and_equivalence': 'NOT RUN',
    'end_to_end': False,
}
assert not (OUT / 'readback.json').exists()
(OUT / 'readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if k != 'nuget_package_archive_hashes'}))
