"""Preserve a local proof checkpoint. This is not a proof checker."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path('/Users/mackianni/forge')
WT = Path('/private/tmp/forge-readiness-docs-20261103')
HERE = Path(__file__).resolve().parent
RAW = ROOT / 'results/refund-stack-initialization-2026-11-05/attempt-0001'
REL = Path('proposals/refund-executable-feasibility/stack-initialization-checkpoint-20261105')
PRIOR = Path('proposals/refund-executable-feasibility/word-oracle-validation-20261105')
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def read(p):
    return json.loads(p.read_text())

def main():
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
            assert '## U306 ' not in p.read_text()
            dest = HERE / 'before' / name / file
            dest.parent.mkdir(parents=True, exist_ok=True)
            if dest.exists():
                assert dest.read_bytes() == p.read_bytes()
            else:
                shutil.copyfile(p, dest)
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
    final = read(RAW / 'init-0007/command.json')
    assert digest(TC / 'cakeml/misc/cakeml-heap') == final['heap_sha256']
    cases = {}
    imported_files = 0
    for name, expected_exit in [(f'init-{i:04d}', int(i != 7)) for i in range(1, 8)] + [('bitmap-diagnostic', 0)]:
        case = RAW / name
        d = read(case / 'command.json')
        assert d['actual_exit'] == expected_exit
        assert digest(case / 'proof.sml') == d['source_sha256']
        for parent, members in d.get('imported_objects', {}).items():
            for path, expected in members.items():
                local = case / parent / path
                assert digest(local) == expected, str(local)
                assert digest(RAW / parent / path) == expected
                imported_files += 1
        cases[name] = {'actual_exit': d['actual_exit'], 'wall_seconds': d['wall_seconds'],
                       'completion_marker': d['completion_marker'], 'source_sha256': d['source_sha256']}
    log = (RAW / 'init-0007/stdout.log').read_text()
    assert final['actual_exit'] == 0 and final['completion_marker']
    for marker in ['ATOMIC_HYPOTHESES 9', 'REMAINING_ANTECEDENTS 8', 'RUNTIME_PROOF_COMPLETE']:
        assert marker in log
    claims = ['refund_stack_gc', 'refund_stack_store', 'refund_stack_compiler',
              'refund_stack_initialized_single_epoch']
    assert [line.removeprefix('CHECKED ') for line in log.splitlines() if line.startswith('CHECKED ')] == claims
    assert len(final['objects']) == 4
    for path, expected in final['objects'].items():
        assert digest(RAW / 'init-0007' / path) == expected
    captured = {str(p.relative_to(RAW)): digest(p) for p in sorted(RAW.rglob('*')) if p.is_file()}
    result = {
        'actual_exit': 0, 'scope': 'documentation checkpoint and byte identity; no new HOL execution',
        'base_commit': head, 'before_docs': before,
        'prior_manifest_sha256': base['prior_manifest_sha256'], 'prior_members_per_copy': len(prior),
        'protected_members': len(base['protected']), 'upstream_sources': len(base['source_hashes']),
        'toolchain_pins': pins, 'mission_sha256': base['mission_sha256'], 'native_sha256': digest(native),
        'recorded_cases': cases, 'imported_files_checked': imported_files,
        'final_exports': final['objects'], 'reported_antecedents': 8,
        'reported_claims': claims, 'captured_files': captured,
        'repeat': 'NOT RUN', 'fresh_exact_import': 'NOT RUN',
        'negative_controls': 'NOT RUN', 'independent_full_chain_replay': 'NOT RUN',
        'physical_applicability': 'NOT_ESTABLISHED', 'end_to_end': False,
    }
    (HERE / 'checkpoint-readback.json').write_text(json.dumps(result, indent=2) + '\n')
    for root in (ROOT, WT):
        records = root / REL / 'records'
        shutil.copytree(RAW, records)
        for path, expected in captured.items():
            assert digest(records / path) == expected
        shutil.copyfile(HERE / 'checkpoint-readback.json', records / 'checkpoint-readback.json')
        shutil.copyfile(Path(__file__), records / 'checkpoint.py')
    print(json.dumps({'actual_exit': 0, 'captured_files': len(captured),
                      'prior_members_per_copy': len(prior), 'imported_files_checked': imported_files,
                      'final_exports': 4, 'reported_antecedents': 8}))

if __name__ == '__main__':
    main()
