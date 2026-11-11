from pathlib import Path
import hashlib, json

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1048576), b''):
            h.update(chunk)
    return h.hexdigest()
def save(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2) + '\n')

frozen = json.loads((OUT / 'inputs.json').read_text())
for path, value in frozen['input_files'].items():
    assert sha(path) == value, path
exits = {'inspect-0001': 0, 'proof-0001': 0, 'repeat': 0,
         'import-0001': 0, 'wrong-code': 1, 'missing-space': 1, 'short-trace': 1}
records = {}
for name, code in exits.items():
    rec = json.loads((OUT / name / 'command.json').read_text())
    assert rec['actual_exit'] == code, name
    assert sha(OUT / name / 'proof.sml') == rec['source_sha256'], name
    for rel, value in rec['objects'].items():
        assert sha(OUT / name / rel) == value, (name, rel)
    records[name] = rec
assert records['proof-0001']['objects'] == records['repeat']['objects']
assert len(records['proof-0001']['objects']) == 4
assert records['proof-0001']['source_sha256'] == records['repeat']['source_sha256'] == sha(OUT / 'accepted.sml')
own = json.loads((OUT / 'accepted-inputs.json').read_text())
assert own['objects'] == records['proof-0001']['objects']
for rel, value in own['objects'].items():
    assert sha(OUT / 'accepted' / rel) == value
for name in ['wrong-code', 'missing-space', 'short-trace']:
    assert not records[name]['completion_marker'] and not records[name]['objects']
    assert 'Exact statement mismatch: refund_error_compiled_precise' in (OUT / name / 'stderr.log').read_text()
log = (OUT / 'import-0001/stdout.log').read_text()
assert records['import-0001']['completion_marker'] and 'EXACT_EXPECTED_STATEMENTS true' in log
for marker in ['IMPORTED_THEOREM ', 'IMPORTED_ORACLES DISK_THM', 'IMPORTED_HYPOTHESES 0', 'IMPORTED_TAGGED_AXIOMS 0']:
    assert log.count(marker) == 2, marker
nodes, axioms = {}, []
for line in log.splitlines():
    if line.startswith('CLOSURE_NODE '):
        name, parents = line.removeprefix('CLOSURE_NODE ').split(':', 1)
        assert name not in nodes
        nodes[name] = parents.split(',') if parents else []
    if line.startswith('CLOSURE_AXIOM '):
        axioms.append(line.removeprefix('CLOSURE_AXIOM '))
assert set(nodes) == set(frozen['source_closure']) | set(frozen['compiler_closure']) | {'forge_refundRejectCompiled'}
assert set(axioms) == set(frozen['foundation_axioms'])
for name in nodes:
    if name not in ['min', 'forge_refundRejectCompiled']:
        assert any(Path(p).name == name + 'Theory.dat' for p in frozen['input_files']), name
baseline = json.loads((OUT.parent / 'attempt-0001/baseline.json').read_text())
for rel, value in baseline['protected'].items():
    assert sha(ROOT / rel) == value, rel
assert sha(ROOT / 'FORGE_MISSION.md') == baseline['mission_sha256']
append = json.loads((OUT.parent / 'attempt-0008/journal-append-U286.json').read_text())
journal = (ROOT / 'unsure.md').read_bytes()
assert hashlib.sha256(journal[:append['journal_prefix_bytes']]).hexdigest() == append['journal_prefix_sha256']
assert hashlib.sha256(journal[append['journal_prefix_bytes']:append['journal_prefix_bytes'] + append['appended_bytes']]).hexdigest() == append['appended_sha256']
packets = {}
for name in frozen['checked_parent_packets']:
    p = ROOT / 'proposals/refund-executable-feasibility' / name
    m = json.loads((p / 'MANIFEST.json').read_text())
    files = m['files'] if 'files' in m else m
    for rel, value in files.items():
        assert sha(p / rel) == value, (name, rel)
    packets[name] = len(files)
chain = json.loads((OUT.parent / 'attempt-0004/chain-inputs-0001/manifest.json').read_text())
for path, value in chain.items():
    assert sha(path) == value, path
native = json.loads((OUT / 'native-readback/result.json').read_text())
assert native['actual_exit'] == 0
assert all(r['actual_exit'] == 0 for r in json.loads((OUT / 'native-readback/commands.json').read_text()))
snapshot = {'actual_exit': 0, 'closure_nodes': nodes, 'foundation_axioms': axioms,
            'input_files': frozen['input_files'], 'new_theory_files': own['objects'],
            'source_sha256': own['source_sha256'],
            'trust': 'HOL logic/kernel, PolyML, loader, host and cached parents; same-host readback is not independent clean full-chain replay.',
            'end_to_end': False}
save('dependency-snapshot.json', snapshot)
result = {'actual_exit': 0, 'commands': exits, 'closure_nodes': len(nodes),
          'parent_file_bindings': len(frozen['input_files']), 'exact_statements': 2,
          'identical_exports': 4, 'foundation_axioms': axioms,
          'protected_files_unchanged': len(baseline['protected']),
          'parent_packet_members': packets, 'historical_chain_files_checked': len(chain),
          'standard_native_checksum_members': native['standard_checksum_members'],
          'existing_signature_verification_exits': [0, 0],
          'source_sha256': own['source_sha256'],
          'data_sha256': own['objects']['.hol/objs/forge_refundRejectCompiledTheory.dat'],
          'native_sha256': native['existing_builds'][0]['executable_sha256'],
          'independent_environment': False, 'end_to_end': False}
save('readback.json', result)
print(json.dumps(result, indent=2))
