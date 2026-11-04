from pathlib import Path
import hashlib
import json

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
PARENT = OUT.parent / 'attempt-0006'

def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

previous = json.loads((PARENT / 'dependency-snapshot.json').read_text())
inputs = dict(previous['imported_files'])
inputs.update({str(PARENT / 'export-0002' / rel): value for rel, value in previous['new_theory_files'].items()})
for path, value in inputs.items():
    assert sha(path) == value, path
exits = {'determ-0001': 0, 'stdio-0001': 1, 'clock-diagnostic': 1,
         'clock-diagnostic-0002': 0, 'stdio-0002': 1, 'stdio-diagnostic': 0,
         'stdio-0003': 0, 'stdio-repeat': 0, 'wrong-empty-trace': 1, 'import-audit': 0}
records = {}
for name, expected in exits.items():
    rec = json.loads((OUT / name / 'command.json').read_text())
    assert rec['actual_exit'] == expected, name
    records[name] = rec
    for rel, value in rec.get('object_sha256', {}).items():
        assert sha(OUT / name / rel) == value, (name, rel)
    if 'source_sha256' in rec:
        assert sha(rec['argv'][-1]) == rec['source_sha256'], name
positive = records['stdio-0003']
repeat = records['stdio-repeat']
assert positive['object_sha256'] == repeat['object_sha256']
assert len(positive['object_sha256']) == 4
assert positive['source_sha256'] == repeat['source_sha256']
assert records['import-audit']['completion_marker']
assert not records['wrong-empty-trace']['completion_marker']
assert not records['wrong-empty-trace']['object_sha256']
negative_log = (OUT / 'wrong-empty-trace/stderr.log').read_text()
assert 'refund_error_stdio_semantics' in negative_log and 'no solution found' in negative_log
log = (OUT / 'import-audit/stdout.log').read_text()
assert 'EXACT_EXPECTED_STATEMENT true' in log and 'IMPORT_AUDIT_COMPLETE' in log
for marker in ['IMPORTED_THEOREM ', 'IMPORTED_ORACLES DISK_THM', 'IMPORTED_HYPOTHESES 0', 'IMPORTED_TAGGED_AXIOMS 0']:
    assert log.count(marker) == 7, marker
nodes, axioms = {}, []
for line in log.splitlines():
    if line.startswith('CLOSURE_NODE '):
        name, parents = line.removeprefix('CLOSURE_NODE ').split(':', 1)
        assert name not in nodes
        nodes[name] = parents.split(',') if parents else []
    if line.startswith('CLOSURE_AXIOM '):
        axioms.append(line.removeprefix('CLOSURE_AXIOM '))
assert set(nodes) == set(previous['parent_nodes']) | {'forge_refundRejectSemantics'}
assert set(axioms) == set(previous['foundation_axioms'])
baseline = json.loads((OUT.parent / 'attempt-0001/baseline.json').read_text())
for rel, value in baseline['protected'].items():
    assert sha(ROOT / rel) == value, rel
assert sha(ROOT / 'FORGE_MISSION.md') == baseline['mission_sha256']
append = json.loads((PARENT / 'journal-append-U282.json').read_text())
assert hashlib.sha256((ROOT / 'unsure.md').read_bytes()[:append['journal_prefix_bytes']]).hexdigest() == append['journal_prefix_sha256']
native = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native) == 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
snapshot = {'actual_exit': 0, 'closure_nodes': nodes, 'foundation_axioms': axioms,
            'input_files': inputs, 'new_theory_files': positive['object_sha256'],
            'source_sha256': positive['source_sha256'],
            'trust': 'HOL logic/kernel, Poly/ML, loader, host and cached parent proof data remain trusted; no clean independent full-chain replay',
            'end_to_end': False}
(OUT / 'dependency-snapshot.json').write_text(json.dumps(snapshot, indent=2) + '\n')
result = {'actual_exit': 0, 'commands': exits, 'input_files_checked': len(inputs),
          'closure_nodes': len(nodes), 'theorems_checked': 7, 'identical_exports': 4,
          'protected_files_unchanged': len(baseline['protected']),
          'source_sha256': positive['source_sha256'], 'data_sha256': positive['object_sha256']['.hol/objs/forge_refundRejectSemanticsTheory.dat'],
          'native_sha256': sha(native), 'end_to_end': False}
(OUT / 'readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
