"""Audit the exact whole-program result, entry refusal and dependency records."""
import hashlib
import json
from pathlib import Path

out = Path(__file__).resolve().parent
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
positive = json.loads((out / 'proof-whole-0001/command.json').read_text())
repeat = json.loads((out / 'proof-whole-repeat/command.json').read_text())
negative = json.loads((out / 'proof-whole-substituted-entry/command.json').read_text())
matrix = json.loads((out / 'whole-acceptance-matrix.json').read_text())
assert matrix['actual_exit'] == 0 and all(r['passed'] for r in matrix['results'])
assert positive['actual_exit'] == repeat['actual_exit'] == 0
assert negative['actual_exit'] == 1 and not negative['object_sha256']
assert len(positive['object_sha256']) == 6
assert positive['object_sha256'] == repeat['object_sha256']
assert positive['source_sha256'] == repeat['source_sha256']
assert sha(out / 'forge_refundWholeProgScript.sml') == positive['source_sha256']
for name, record in [('whole-0001',positive),('whole-repeat',repeat),('whole-substituted-entry',negative)]:
    directory = out / ('proof-' + name)
    assert sha(directory / 'forge_refundWholeProgScript.sml') == record['source_sha256']
    for member, expected in record['object_sha256'].items():
        assert sha(directory / 'objects' / member) == expected
failure = (out / 'proof-whole-substituted-entry/theory.log').read_text()
assert 'SOME refund_dispatch_v = SOME refund_main_v' in failure
assert 'unsolved goals' in failure
assert 'prove_sem_thm: done' not in failure
log = (out / 'proof-whole-repeat/theory.log').read_text()
for name in ['refund_whole_prog_spec','refund_request_whole_prog_spec','refund_semantics']:
    assert 'FORGE_THEOREM ' + name + '\n' in log
assert 'wfcl cl ∧ wfFS fs ∧ STD_streams fs' in log
assert log.count('FORGE_HYPOTHESES 0') == 3
lines = (out / 'closure-audit.log').read_text().splitlines()
parents = [x for x in lines if x.startswith('FORGE_PARENT ')]
tags = [x for x in lines if x.startswith('FORGE_TAG ')]
axioms = [x for x in lines if x.startswith('FORGE_CLOSURE_AXIOM ')]
assert len(parents) == 243
assert set(axioms) == {'FORGE_CLOSURE_AXIOM bool.SELECT_AX',
    'FORGE_CLOSURE_AXIOM bool.INFINITY_AX','FORGE_CLOSURE_AXIOM bool.ETA_AX',
    'FORGE_CLOSURE_AXIOM bool.BOOL_CASES_AX'}
assert all(t.endswith('hypotheses=0') for t in tags)
assert all(set(filter(None,t.split(' oracles=')[1].split(' axioms=')[0].split(','))) <= {'DISK_THM'} for t in tags)
snapshot = json.loads((out / 'dependency-snapshot.json').read_text())
assert snapshot['actual_exit'] == 0 and len(snapshot['theories']) == 242
for files in snapshot['theories'].values():
    for record in files.values():
        assert sha(Path(record['path'])) == record['sha256'], record['path']
for path, digest in snapshot['core_files'].items():
    assert sha(Path(path)) == digest, path
assert json.loads((out / 'closure-audit-command.json').read_text())['actual_exit'] == 0
result = dict(actual_exit=0, positive=positive, repeat=repeat, negative=negative,
              entry_refusal='SOME refund_dispatch_v = SOME refund_main_v is unproved',
              closure_nodes=len(parents), exported_theorem_tags=len(tags), axioms=axioms,
              dependency_filesets=len(snapshot['theories']), end_to_end=False,
              assurance='Whole-program source semantics under explicit stdin, command-line and filesystem premises',
              native_execution='NOT RUN', authenticated_admission='NOT RUN')
(out / 'whole-readback.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['actual_exit','closure_nodes','exported_theorem_tags','dependency_filesets','entry_refusal','end_to_end']}))
