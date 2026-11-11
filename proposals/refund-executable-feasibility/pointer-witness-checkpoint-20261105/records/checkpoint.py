"""Capture existing local evidence for documentation. This is not a proof checker."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path('/Users/mackianni/forge')
WT = Path('/private/tmp/forge-readiness-docs-20261103')
HERE = Path(__file__).resolve().parent
RAW = ROOT / 'results/refund-pointer-witness-2026-11-05/attempt-0001'
REL = Path('proposals/refund-executable-feasibility/pointer-witness-checkpoint-20261105')
PRIOR = Path('proposals/refund-executable-feasibility/stack-initialization-validation-20261105')
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def read(p):
    return json.loads(p.read_text())

base = read(RAW / 'baseline.json')
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=WT, text=True).strip()
assert head == base['base_commit']
assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=WT)
before = {}
for name, root in [('workspace', ROOT), ('worktree', WT)]:
    assert not (root / REL).exists()
    before[name] = {}
    for file in ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md']:
        p = root / file
        assert '## U308 ' not in p.read_text()
        saved = HERE / 'before' / name / file
        assert saved.read_bytes() == p.read_bytes(), ('concurrent documentation change', p)
        before[name][file] = {'sha256': digest(p), 'bytes': p.stat().st_size}
    assert digest(root / 'FORGE_MISSION.md') == base['mission_sha256']
    assert digest(root / PRIOR / 'manifest.json') == base['prior_manifest_sha256']
    prior = read(root / PRIOR / 'manifest.json')
    assert len(prior) == base['prior_members']
    for path, expected in prior.items():
        assert digest(root / PRIOR / path) == expected, path
for path, expected in base['protected'].items():
    assert digest(ROOT / path) == expected, path
native = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert digest(native) == base['native_sha256']
pins = {'cakeml': 'cd9155694c16831373ab695a670794f23282ed62',
        'HOL': '9783a49979c94c401ff8c0e51b2eefae7ea95ae3'}
for repo, pin in pins.items():
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=TC / repo, text=True).strip() == pin
    for args in (['git', 'diff', '--quiet'], ['git', 'diff', '--cached', '--quiet']):
        assert subprocess.run(args, cwd=TC / repo).returncode == 0
for path, expected in base['source_hashes'].items():
    assert digest(RAW / 'upstream' / path) == expected
    assert digest(TC / 'cakeml' / path) == expected
    published = subprocess.check_output(['git', 'show', pins['cakeml'] + ':' + path], cwd=TC / 'cakeml')
    assert hashlib.sha256(published).hexdigest() == expected

expected_cases = {
    'pointer-0001': (1, 'Pointer premise shape mismatch'),
    'pointer-0002': (1, 'Pointer premise shape mismatch'),
    'normalization-diagnostic': (0, 'POINTER_NORMALIZATION_DIAGNOSTIC_COMPLETE'),
    'pointer-0003': (0, 'RUNTIME_PROOF_COMPLETE'),
    'exact-import-0001': (1, 'unsolved goals'),
    'exact-import-0002': (1, 'unsolved goals'),
    'premise-diagnostic': (1, 'Value or constructor (map_index) has not been declared'),
}
cases = {}
imported_files = 0
for name, (expected_exit, marker) in expected_cases.items():
    case = RAW / name
    d = read(case / 'command.json')
    assert d['actual_exit'] == expected_exit
    source_name = 'audit.sml' if 'import_complete' in d else 'proof.sml'
    assert digest(case / source_name) == d['source_sha256']
    log = (case / 'stdout.log').read_text() + (case / 'stderr.log').read_text()
    assert marker in log, name
    assert digest(TC / 'cakeml/misc/cakeml-heap') == d['heap_sha256']
    for parent, members in d['imported_objects'].items():
        for path, expected in members.items():
            assert digest(case / parent / path) == expected
            assert digest(RAW / parent / path) == expected
            imported_files += 1
    if 'import_complete' in d:
        assert d['import_complete'] is False
        assert 'TRACE_IMPORT_COMPLETE' not in log
    cases[name] = {
        'actual_exit': d['actual_exit'], 'wall_seconds': d['wall_seconds'],
        'source_sha256': d['source_sha256'], 'observed_marker': marker,
        'command_record': str(Path(name) / 'command.json'),
    }
final = read(RAW / 'pointer-0003/command.json')
log = (RAW / 'pointer-0003/stdout.log').read_text()
assert final['completion_marker'] and 'REMAINING_ANTECEDENTS 7' in log
claims = ['refund_initializer_oracle_independence', 'refund_pointer_fixed_point',
          'refund_fixed_syntax_pointer_witness', 'refund_witnessed_single_epoch']
assert [line.removeprefix('CHECKED ') for line in log.splitlines() if line.startswith('CHECKED ')] == claims
assert len(final['objects']) == 4
for path, expected in final['objects'].items():
    assert digest(RAW / 'pointer-0003' / path) == expected
for name in ['exact-import-0001', 'exact-import-0002', 'premise-diagnostic']:
    log = (RAW / name / 'stdout.log').read_text()
    assert len([line for line in log.splitlines() if line.startswith('IMPORTED ')]) == 3
    assert 'KERNEL_PREMISES_EQUIVALENT true' not in log
for name in ['pointer-repeat', 'wrong-pointer', 'missing-prefix', 'missing-space']:
    assert not (RAW / name).exists(), ('unexpected later result; reassess checkpoint', name)
assert not (RAW / 'readback.json').exists()
assert not any(p.is_symlink() for p in RAW.rglob('*'))
captured = {str(p.relative_to(RAW)): digest(p) for p in sorted(RAW.rglob('*')) if p.is_file()}
result = {
    'actual_exit': 0, 'scope': 'documentation checkpoint and byte identity; no new HOL execution',
    'base_commit': head, 'before_docs': before,
    'prior_manifest_sha256': base['prior_manifest_sha256'], 'prior_members_per_copy': len(prior),
    'protected_members': len(base['protected']), 'upstream_sources': len(base['source_hashes']),
    'toolchain_pins': pins, 'mission_sha256': base['mission_sha256'], 'native_sha256': digest(native),
    'recorded_cases': cases, 'imported_files_checked': imported_files,
    'final_exports': final['objects'], 'reported_antecedents': 7,
    'reported_claims': claims, 'captured_files': captured,
    'repeat': 'NOT RUN', 'complete_premise_audit': 'NOT_ESTABLISHED',
    'fresh_import_actual_exits': [1, 1], 'negative_controls': 'NOT RUN',
    'new_closure_audit': 'NOT RUN', 'independent_full_chain_replay': 'NOT RUN',
    'physical_applicability': 'NOT_ESTABLISHED', 'end_to_end': False,
}
target = HERE / 'checkpoint-readback.json'
assert not target.exists()
target.write_text(json.dumps(result, indent=2) + '\n')
for root in (ROOT, WT):
    records = root / REL / 'records'
    shutil.copytree(RAW, records)
    for path, expected in captured.items():
        assert digest(records / path) == expected
    shutil.copyfile(target, records / target.name)
    shutil.copyfile(Path(__file__), records / 'checkpoint.py')
print(json.dumps({'actual_exit': 0, 'captured_files': len(captured),
                  'prior_members_per_copy': len(prior), 'imported_files_checked': imported_files,
                  'final_exports': 4, 'reported_antecedents': 7,
                  'complete_premise_audit': 'NOT_ESTABLISHED'}))
