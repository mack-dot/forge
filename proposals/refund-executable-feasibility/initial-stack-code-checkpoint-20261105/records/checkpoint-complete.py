"""Check recorded bytes and exits. This does not run or accept a new proof."""
from pathlib import Path
import hashlib
import json
import subprocess

R = Path('/Users/mackianni/forge')
W = Path('/private/tmp/forge-readiness-docs-20261103')
H = Path(__file__).resolve().parent
O = R / 'results/refund-initial-stack-code-2026-11-05/attempt-0001'
TC = R / '.toolchain/experiments/refund-cakeml-20261104'
P = Path('proposals/refund-executable-feasibility/initial-stack-code-checkpoint-20261105')
sha_bytes = lambda b: hashlib.sha256(b).hexdigest()
sha = lambda p: sha_bytes(p.read_bytes())
baseline = json.loads((O / 'baseline.json').read_text())

def git(cwd, *args):
    return subprocess.check_output(['git', '-C', str(cwd), *args])

assert git(W, 'rev-parse', 'HEAD').decode().strip() == baseline['base_commit']
assert not git(W, 'status', '--porcelain')
for group, root in [('workspace', R), ('worktree', W)]:
    for name in ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md']:
        assert (root / name).read_bytes() == (H / 'before' / group / name).read_bytes()
    assert '## U314 ' not in (root / 'unsure.md').read_text()
    assert sha(root / 'FORGE_MISSION.md') == baseline['mission_sha256']
    if root == R:
        for name, digest in baseline['protected'].items():
            assert sha(root / name) == digest, (group, name)
    else:
        paths = git(W, 'ls-tree', '-r', '--name-only', baseline['base_commit'], '--', 'spec', 'spec.lock', 'policy', 'gate').decode().splitlines()
        for name in paths:
            assert sha(root / name) == sha_bytes(git(W, 'show', baseline['base_commit'] + ':' + name)), (group, name)

cake_commit = git(TC / 'cakeml', 'rev-parse', 'HEAD').decode().strip()
hol_commit = git(TC / 'HOL', 'rev-parse', 'HEAD').decode().strip()
assert cake_commit == 'cd9155694c16831373ab695a670794f23282ed62'
assert hol_commit == '9783a49979c94c401ff8c0e51b2eefae7ea95ae3'
for name, digest in baseline['source_hashes'].items():
    assert sha(O / 'upstream' / name) == digest
    assert sha(TC / 'cakeml' / name) == digest
    assert sha_bytes(git(TC / 'cakeml', 'show', cake_commit + ':' + name)) == digest

prior = Path(baseline['prior_packet'])
for root in [R, W]:
    assert sha(root / prior / 'MANIFEST.json') == baseline['prior_manifest_sha256']
manifest = json.loads((W / prior / 'MANIFEST.json').read_text())
assert len(manifest) == baseline['prior_members']
for name, digest in manifest.items():
    for root in [R, W]:
        assert sha(root / prior / name) == digest
    assert sha_bytes(git(W, 'show', baseline['base_commit'] + ':' + str(prior / name))) == digest

native = R / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native) == baseline['native_sha256']
heap = TC / 'cakeml/misc/cakeml-heap'
heap_hash = sha(heap)
assert heap_hash == '36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'
cases = []
sources = ['code.sml', 'code-less.sml', 'code-numeric.sml']
failures = ['refund_word_labels', 'DECIDE', 'FIRST_ASSUM']
for index, (source, reason) in enumerate(zip(sources, failures), 1):
    name = f'code-{index:04d}'
    case = O / name
    record = json.loads((case / 'command.json').read_text())
    assert record['actual_exit'] == 1 and record['completion_marker'] is False
    assert record['source_sha256'] == sha(case / 'proof.sml') == sha(O / source)
    assert record['heap_sha256'] == heap_hash
    assert reason in (case / 'stderr.log').read_text()
    assert record['objects'] == {}, 'Unexpected new proof exports'
    output = (case / 'stdout.log').read_text()
    assert 'RUNTIME_PROOF_COMPLETE' not in output
    saved = [line for line in output.splitlines() if line.startswith('Saved theorem')]
    assert len(saved) == (1 if index == 1 else 3)
    for parent, objects in record['imported_objects'].items():
        parent_record = json.loads((O / parent / 'command.json').read_text())
        assert parent_record['actual_exit'] == 0 and parent_record['completion_marker']
        assert objects == parent_record['objects']
        for path, digest in objects.items():
            assert sha(O / parent / path) == sha(case / parent / path) == digest
    cases.append(dict(name=name, source=source, source_sha256=record['source_sha256'],
                      actual_exit=1, wall_seconds=record['wall_seconds'],
                      failure=reason, saved_in_process=saved,
                      completed_theory_export=False))

raw_files = {str(p.relative_to(O)): sha(p) for p in sorted(O.rglob('*')) if p.is_file()}
assert len(raw_files) == 96
for root in [R, W]:
    dest = root / P / 'records'
    assert not dest.exists()
    dest.mkdir(parents=True)
    for name, digest in raw_files.items():
        target = dest / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((O / name).read_bytes())
        assert sha(target) == digest

result = dict(actual_exit=0, check='Recorded-byte checkpoint; no new HOL execution',
              base_commit=baseline['base_commit'], cake_commit=cake_commit,
              hol_commit=hol_commit, heap_sha256=heap_hash,
              source_pin_count=len(baseline['source_hashes']),
              protected_file_count=len(baseline['protected']),
              prior_members_per_copy=len(manifest),
              prior_manifest_sha256=baseline['prior_manifest_sha256'],
              mission_sha256=baseline['mission_sha256'], native_sha256=sha(native),
              raw_file_count=len(raw_files), raw_files=raw_files, cases=cases,
              latest_completed_validation='U313', retained_initializer_conditions=15,
              proposed_fourteen_condition_claim='NOT_ESTABLISHED',
              new_proof_import_repeat_controls='NOT RUN', end_to_end=False)
(H / 'checkpoint.json').write_text(json.dumps(result, indent=2) + '\n')
for root in [R, W]:
    for name in ['checkpoint.py', 'checkpoint-preparation-failures.json', 'checkpoint-complete.py', 'checkpoint.json']:
        (root / P / 'records' / name).write_bytes((H / name).read_bytes())
print(json.dumps({k: v for k, v in result.items() if k not in ['raw_files', 'cases']}))
