"""Check saved HOL outcomes and fixture/dependency identities; not a proof checker."""
import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = Path('/Users/mackianni/forge')

def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

commands = {}
for name, expected in [('direct-0001', 1), ('direct-0002', 0), ('direct-repeat', 0),
                       ('malformed-0002', 0), ('negative-amount', 1), ('negative-ids', 1),
                       ('closure', 1), ('closure-0002', 0)]:
    record = json.loads((OUT / name / 'command.json').read_text())
    assert record['actual_exit'] == expected, (name, record)
    commands[name] = record

assert 'TAUT_PROVE' in (OUT / 'direct-0001/stderr.log').read_text()
assert 'has not been declared' in (OUT / 'closure/stdout.log').read_text()
cases = json.loads((OUT.parent / 'attempt-0001/native-corpus/cases.json').read_text())
assert len(cases) == 22
frozen = json.loads((OUT / 'direct-0002/wire-sha256.json').read_text())
assert len(frozen) == 44
repeat = json.loads((OUT / 'direct-repeat/wire-sha256.json').read_text())
for name, digest in frozen.items():
    assert repeat[name] == digest
    for base in ['direct-0002/wire', 'direct-repeat/wire', 'wire']:
        assert sha(OUT / base / name) == digest
for name in ['direct-0002', 'direct-repeat']:
    log = (OUT / name / 'stdout.log').read_text()
    assert 'FIXTURE_BATCH_COMPLETE 22\n' in log
    assert log.count('FIXTURE_THEOREM ') == 88
    for case in cases:
        for kind in ['fields', 'wire', 'stdin', 'stdout']:
            assert log.count('FIXTURE_THEOREM ' + case['name'] + ':' + kind + '\n') == 1
    assert commands[name]['source_sha256'] == sha(OUT / 'fixtures.sml')
for name in ['negative-amount', 'negative-ids']:
    assert 'FIXTURE_THEOREM ' not in (OUT / name / 'stdout.log').read_text()
    assert 'EQT_ELIM' in (OUT / name / 'stderr.log').read_text()
    assert not (OUT / name / 'wire').exists()

malformed = json.loads((OUT / 'malformed-cases.json').read_text())
malformed_log = (OUT / 'malformed-0002/stdout.log').read_text()
assert len(malformed) == 6 and malformed_log.count('FIXTURE_THEOREM ') == 12
assert 'MALFORMED_BATCH_COMPLETE 6\n' in malformed_log
for c in malformed:
    assert 'FIXTURE_THEOREM ' + c['name'] + ':error\n' in malformed_log
    assert (OUT / 'wire' / (c['name'] + '.stdin')).is_file()

closure = (OUT / 'closure-0002/stdout.log').read_text()
assert 'FIXTURE_CLOSURE_COMPLETE\n' in closure
nodes = {}
for line in closure.splitlines():
    if line.startswith('FIXTURE_PARENT '):
        name, parents = line[len('FIXTURE_PARENT '):].split(':', 1)
        assert name not in nodes
        nodes[name] = parents.split(',') if parents else []
assert len(nodes) == 229
assert all(p in nodes for parents in nodes.values() for p in parents)
axioms = [line.removeprefix('FIXTURE_AXIOM ') for line in closure.splitlines() if line.startswith('FIXTURE_AXIOM ')]
assert set(axioms) == {'bool.SELECT_AX', 'bool.INFINITY_AX', 'bool.ETA_AX', 'bool.BOOL_CASES_AX'}
tags = [line for line in closure.splitlines() if line.startswith('FIXTURE_TAG ')]
assert tags and all('oracles=DISK_THM axioms= hypotheses=0' in line for line in tags)
snapshot_path = ROOT / 'results/refund-stdio-composition-2026-11-04/attempt-0001/dependency-io-snapshot.json'
snapshot = json.loads(snapshot_path.read_text())
dependencies = {}
for name in nodes:
    if name == 'min':
        continue
    records = snapshot['theories'][name]
    for record in records.values():
        assert sha(Path(record['path'])) == record['sha256'], record['path']
    dependencies[name] = records
for path, digest in snapshot['core_files'].items():
    assert sha(Path(path)) == digest

baseline = json.loads((OUT.parent / 'attempt-0001/baseline.json').read_text())
for name, digest in baseline['protected'].items():
    assert sha(ROOT / name) == digest
assert sha(ROOT / 'FORGE_MISSION.md') == baseline['mission_sha256']
assert hashlib.sha256((ROOT / 'unsure.md').read_bytes()[:baseline['unsure_bytes']]).hexdigest() == baseline['unsure_prefix_sha256']

manifest = {p.name: sha(p) for p in sorted((OUT / 'wire').iterdir())}
assert len(manifest) == 50
(OUT / 'wire-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(OUT / 'dependency-readback.json').write_text(json.dumps({
    'actual_exit': 0, 'closure_nodes': nodes, 'axioms': axioms,
    'theories': dependencies, 'core_files': snapshot['core_files'],
    'prior_snapshot_sha256': sha(snapshot_path),
    'scope': 'Fresh wire closure inspection and current byte readback; upstream proof sources were not independently replayed',
}, indent=2) + '\n')
result = {'actual_exit': 0, 'typed_cases': 22, 'malformed_cases': 6,
          'fresh_evaluation_theorems': 100, 'repeated_typed_wire_files': 44,
          'wire_file_count': len(manifest), 'closure_node_count': len(nodes),
          'theory_file_sets': len(dependencies), 'wire_theorem_tags': len(tags),
          'negative_exits': [commands[n]['actual_exit'] for n in ['negative-amount', 'negative-ids']],
          'protected_files_checked': len(baseline['protected']),
          'native_execution': 'NOT_RUN', 'end_to_end': False,
          'remaining': ['exact compiler artifact', 'native error path', 'runtime/OS I/O relation',
                        'Unicode/source/model assurance binding', 'independent native correspondence']}
(OUT / 'readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
