from pathlib import Path
import hashlib
import json

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
PARENT = OUT.parent / 'attempt-0007'
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'

def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def save(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2) + '\n')

previous = json.loads((PARENT / 'dependency-snapshot.json').read_text())
inputs = dict(previous['input_files'])
inputs.update({str(PARENT / 'stdio-0003' / rel): value
               for rel, value in previous['new_theory_files'].items()})
for path, value in inputs.items():
    assert sha(path) == value, path

exits = {
    'extraction-0001': 1, 'extraction-0002': 1, 'extraction-0003': 0,
    'basis-0001': 1, 'basis-diagnostic': 0, 'basis-0002': 0,
    'basis-repeat': 0, 'import-audit': 0, 'wrong-final-fs': 1,
    'initialization-inspection': 0,
    'initial-heap-0001': 1, 'initial-heap-0002': 1,
    'initial-heap-diagnostic': 0, 'initial-heap-0003': 1,
    'initial-heap-diagnostic-0002': 0, 'projection-0001': 0,
    'initial-heap-0004': 1, 'initial-heap-diagnostic-0003': 0,
    'initial-heap-0005': 0, 'concrete-0001': 0, 'concrete-repeat': 0,
    'wrong-main': 1, 'final-import': 0, 'wrong-premise': 1,
}
records = {}
for name, expected in exits.items():
    record = json.loads((OUT / name / 'command.json').read_text())
    assert record['actual_exit'] == expected, name
    records[name] = record
    for rel, value in record.get('object_sha256', {}).items():
        assert sha(OUT / name / rel) == value, (name, rel)
    if 'source_sha256' in record:
        assert sha(record['argv'][-1]) == record['source_sha256'], name
    if 'audit_source_sha256' in record:
        assert sha(OUT / name / 'audit.sml') == record['audit_source_sha256'], name
for first, repeat in [('basis-0002', 'basis-repeat'), ('concrete-0001', 'concrete-repeat')]:
    assert records[first]['object_sha256'] == records[repeat]['object_sha256']
    assert len(records[first]['object_sha256']) == 4
    assert records[first]['source_sha256'] == records[repeat]['source_sha256']
for name in ['wrong-final-fs', 'wrong-main', 'wrong-premise']:
    assert not records[name]['completion_marker'], name
    assert not records[name].get('object_sha256'), name
assert 'refund_error_basis_semantics' in (OUT / 'wrong-final-fs/stderr.log').read_text()
assert 'no solution found' in (OUT / 'wrong-final-fs/stderr.log').read_text()
assert 'refund_error_program_identity' in (OUT / 'wrong-main/stderr.log').read_text()
assert 'not alpha-equivalent' in (OUT / 'wrong-main/stderr.log').read_text()
assert 'Exact initialized exception statement mismatch' in (OUT / 'wrong-premise/stderr.log').read_text()

positive = records['concrete-0001']
assert sha(OUT / 'accepted-concrete.sml') == positive['source_sha256']
assert sha(OUT / 'expected-final.sml') == records['final-import']['expected_source_sha256']
assert sha(OUT / 'expected-wrong-premise.sml') == records['wrong-premise']['expected_source_sha256']
log = (OUT / 'final-import/stdout.log').read_text()
assert records['final-import']['completion_marker']
assert 'EXACT_EXPECTED_STATEMENT true' in log and 'FINAL_IMPORT_COMPLETE' in log
assert 'EXACT_CLOSED_PROGRAM_IDENTITY_CHECKED' in log
for marker in ['IMPORTED_THEOREM ', 'IMPORTED_ORACLES DISK_THM',
               'IMPORTED_HYPOTHESES 0', 'IMPORTED_TAGGED_AXIOMS 0']:
    assert log.count(marker) == 9, marker
nodes, axioms = {}, []
for line in log.splitlines():
    if line.startswith('CLOSURE_NODE '):
        name, parents = line.removeprefix('CLOSURE_NODE ').split(':', 1)
        assert name not in nodes
        nodes[name] = parents.split(',') if parents else []
    if line.startswith('CLOSURE_AXIOM '):
        axioms.append(line.removeprefix('CLOSURE_AXIOM '))
assert set(nodes) == set(previous['closure_nodes']) | {'forge_refundRejectBasis'}
assert set(axioms) == set(previous['foundation_axioms'])
for name in nodes:
    if name not in ['min', 'forge_refundRejectBasis']:
        assert any(Path(p).name == name + 'Theory.dat' for p in inputs), name

libraries = json.loads((OUT / 'library-inputs.json').read_text())
for path, value in libraries.items():
    assert sha(path) == value, path
direct_macros = {}
for stem in ['ml_translatorLib', 'ml_progLib']:
    for suffix in ['.sml', '.sig']:
        p = TC / 'cakeml/translator' / (stem + suffix)
        direct_macros[str(p)] = sha(p)
    for suffix in ['.uo', '.ui']:
        p = TC / 'cakeml/translator/.hol/objs' / (stem + suffix)
        direct_macros[str(p)] = sha(p)

baseline = json.loads((OUT.parent / 'attempt-0001/baseline.json').read_text())
for rel, value in baseline['protected'].items():
    assert sha(ROOT / rel) == value, rel
assert sha(ROOT / 'FORGE_MISSION.md') == baseline['mission_sha256']
append = json.loads((PARENT / 'journal-append-U284.json').read_text())
assert hashlib.sha256((ROOT / 'unsure.md').read_bytes()[:append['journal_prefix_bytes']]).hexdigest() == append['journal_prefix_sha256']
native = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native) == 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
prior_packets = {}
for name in ['exception-declaration-20261104', 'exception-semantics-20261104']:
    packet = ROOT / 'proposals/refund-executable-feasibility' / name
    manifest = json.loads((packet / 'MANIFEST.json').read_text())
    for rel, value in manifest['files'].items():
        assert sha(packet / rel) == value, (name, rel)
    prior_packets[name] = len(manifest['files'])
failed_heaps = {
    str(ROOT / 'results/refund-exception-bridge-2026-11-04/attempt-0001/proof-0003/prior-outputs/forge_refundRejectProof.refund_call_main_exception.dumpedheap'):
        'f2259ffdcf601395356c439b0b33a1cf63d2cf4f9edabb2ccb3abb669d424ed1',
    str(TC / 'cakeml/compiler/dafny/forge_refundRejectProof_experiment/forge_refundRejectProof.refund_call_main_exception.dumpedheap'):
        '7357572346bb83f5c807a96aa226a4e87160693d3a14c958c09bcf37d237034c',
}
for path, value in failed_heaps.items():
    assert sha(path) == value, path

snapshot = {
    'actual_exit': 0, 'closure_nodes': nodes, 'foundation_axioms': axioms,
    'input_files': inputs, 'new_theory_files': positive['object_sha256'],
    'source_sha256': positive['source_sha256'], 'direct_macro_files': direct_macros,
    'failed_library_load_files': libraries, 'preserved_failed_heaps': failed_heaps,
    'trust': 'HOL logic/kernel, Poly/ML, loader, host and cached parent proof data. Direct macro hashes are not a complete dynamically loaded ML dependency closure. No independent clean full-chain replay.',
    'end_to_end': False,
}
save('dependency-snapshot.json', snapshot)
result = {
    'actual_exit': 0, 'commands': exits, 'input_files_checked': len(inputs),
    'closure_nodes': len(nodes), 'theorem_tags_checked': 9,
    'exact_final_statement_and_program_identity_checked': True,
    'identical_final_exports': 4, 'identical_intermediate_exports': 4,
    'direct_macro_files_hashed': len(direct_macros), 'foundation_axioms': axioms,
    'protected_files_unchanged': len(baseline['protected']),
    'prior_packet_members_checked': prior_packets,
    'source_sha256': positive['source_sha256'],
    'data_sha256': positive['object_sha256']['.hol/objs/forge_refundRejectBasisTheory.dat'],
    'native_sha256': sha(native), 'failed_heaps_preserved': len(failed_heaps),
    'end_to_end': False,
}
save('readback.json', result)
print(json.dumps(result, indent=2))
