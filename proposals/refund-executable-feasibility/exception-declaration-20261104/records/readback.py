import hashlib
import json
from pathlib import Path

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent

def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

baseline = json.loads((ROOT / 'results/refund-native-audit-2026-11-04/attempt-0001/baseline.json').read_text())
previous = json.loads((ROOT / 'results/refund-stdio-composition-2026-11-04/attempt-0001/dependency-snapshot.json').read_text())
checked = {}
for entries in previous['theories'].values():
    for record in entries.values():
        assert digest(record['path']) == record['sha256'], record['path']
        checked[record['path']] = record['sha256']
for path, expected in previous['core_files'].items():
    assert digest(path) == expected, path
    checked[path] = expected
for path, expected in baseline['protected'].items():
    assert digest(ROOT / path) == expected, path
assert digest(ROOT / 'FORGE_MISSION.md') == baseline['mission_sha256']
journal = (ROOT / 'unsure.md').read_bytes()
assert hashlib.sha256(journal[:baseline['unsure_bytes']]).hexdigest() == baseline['unsure_prefix_sha256']
old_heaps = {
    ROOT / 'results/refund-exception-bridge-2026-11-04/attempt-0001/proof-0003/prior-outputs/forge_refundRejectProof.refund_call_main_exception.dumpedheap': 'f2259ffdcf601395356c439b0b33a1cf63d2cf4f9edabb2ccb3abb669d424ed1',
    ROOT / '.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/forge_refundRejectProof_experiment/forge_refundRejectProof.refund_call_main_exception.dumpedheap': '7357572346bb83f5c807a96aa226a4e87160693d3a14c958c09bcf37d237034c',
}
for path, expected in old_heaps.items():
    assert digest(path) == expected, path
native = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert digest(native) == 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
expected_exits = {'direct-0001': 1, 'direct-0002': 1, 'diagnostic-rewrite': 0,
    'direct-0003': 0, 'export-0001': 1, 'export-0002': 0,
    'wrong-result-0001': 1, 'export-repeat': 0, 'import-audit': 1,
    'import-audit-0002': 0}
records = {}
for name, expected in expected_exits.items():
    record = json.loads((OUT / name / 'command.json').read_text())
    assert record['actual_exit'] == expected, name
    records[name] = record
    for rel, value in record.get('object_sha256', {}).items():
        assert digest(OUT / name / rel) == value, (name, rel)
positive = records['export-0002']
repeat = records['export-repeat']
assert positive['object_sha256'] == repeat['object_sha256']
assert len(positive['object_sha256']) == 4
assert positive['source_sha256'] == repeat['source_sha256']
for name in ['export-0002', 'export-repeat']:
    assert digest(OUT / name / 'export-proof.sml') == positive['source_sha256']
    assert records[name]['completion_marker'] and not records[name]['saved_failure_heap_used']
assert not records['wrong-result-0001']['completion_marker']
assert not records['wrong-result-0001']['object_sha256']
text = (OUT / 'import-audit-0002/stdout.log').read_text()
for marker in ['IMPORT_AUDIT_COMPLETE', 'EXACT_EXPECTED_STATEMENT true',
               'IMPORTED_HYPOTHESES 0', 'IMPORTED_TAGGED_AXIOMS 0', 'IMPORTED_ORACLES DISK_THM']:
    assert marker in text, marker
nodes = {}
axioms = []
for line in text.splitlines():
    if line.startswith('CLOSURE_NODE '):
        node, parents = line.removeprefix('CLOSURE_NODE ').split(':', 1)
        assert node not in nodes
        nodes[node] = parents.split(',') if parents else []
    if line.startswith('CLOSURE_AXIOM '):
        axioms.append(line.removeprefix('CLOSURE_AXIOM '))
assert set(nodes) == set(previous['theories']) | set(previous['kernel_seed_theories']) | {'forge_refundRejectDirect'}
assert set(axioms) == {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
snapshot = {'actual_exit': 0, 'loaded_theory_nodes': len(nodes), 'parent_nodes': nodes,
    'imported_files': checked, 'new_theory_files': positive['object_sha256'],
    'foundation_axioms': axioms, 'source_sha256': positive['source_sha256'],
    'scope': 'Same-host fresh proof, repeat and import; cached parent closure. Not clean independent upstream replay.',
    'end_to_end': False}
(OUT / 'dependency-snapshot.json').write_text(json.dumps(snapshot, indent=2) + '\n')
result = {'actual_exit': 0, 'commands': expected_exits, 'old_dependency_files_checked': len(checked),
    'closure_nodes': len(nodes), 'identical_export_files': 4,
    'protected_files_unchanged': len(baseline['protected']), 'old_failed_heaps_unchanged': 2,
    'native_sha256': digest(native), 'mission_sha256': baseline['mission_sha256'],
    'end_to_end': False}
(OUT / 'readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
