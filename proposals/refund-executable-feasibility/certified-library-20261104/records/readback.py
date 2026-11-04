"""Validate saved proof commands and hashes; does not replace HOL checking."""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path('/Users/mackianni/forge')
out = Path(__file__).resolve().parent
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
matrix = json.loads((out / 'acceptance-matrix.json').read_text())
assert matrix['actual_exit'] == 0 and all(x['passed'] for x in matrix['results'])
expected = {'library-0001': 1, 'library-0002': 1, 'library-0003': 1,
            'library-0004': 1, 'library-0005': 0,
            'altered-amount': 1, 'swapped-wrapper-ids': 1, 'repeat': 0}
records = {}
for name, code in expected.items():
    directory = out / ('proof-' + name)
    record = json.loads((directory / 'command.json').read_text())
    assert record['actual_exit'] == code, name
    assert sha(directory / 'forge_refundCertifiedProgScript.sml') == record['source_sha256'], name
    for member, expected_sha in record['object_sha256'].items():
        assert sha(directory / 'objects' / member) == expected_sha, member
    if code:
        assert not record['object_sha256'], name
    records[name] = record
assert records['library-0005']['object_sha256'] == records['repeat']['object_sha256']
assert len(records['repeat']['object_sha256']) == 6
assert sha(out / 'forge_refundCertifiedProgScript.sml') == records['repeat']['source_sha256']
baseline = json.loads((root / 'results/refund-caller-2026-11-04/attempt-0001/original-inputs-postflight.json').read_text())
for name, expected_sha in baseline['input_sha256'].items():
    assert sha(root / name) == expected_sha, name
tc = root / '.toolchain/experiments/refund-cakeml-20261104'
parent = tc / 'cakeml/compiler/dafny/forge_refundProg_experiment'
assert sha(parent / 'forge_refundProgScript.sml') == records['repeat']['parent_source_sha256']
assert sha(parent / '.hol/objs/forge_refundProgTheory.dat') == records['repeat']['parent_data_sha256']
tracked = {}
for name, expected_head in [('cakeml', 'cd9155694c16831373ab695a670794f23282ed62'),
                            ('HOL', '9783a49979c94c401ff8c0e51b2eefae7ea95ae3')]:
    child = subprocess.run(['git', '-C', str(tc / name), 'diff', '--quiet', 'HEAD'])
    assert child.returncode == 0
    tracked[name] = {'actual_exit': child.returncode,
                     'head': subprocess.check_output(['git', '-C', str(tc / name), 'rev-parse', 'HEAD'], text=True).strip()}
    assert tracked[name]['head'] == expected_head
closure_command = json.loads((out / 'closure-audit-command.json').read_text())
assert closure_command['actual_exit'] == 0
lines = (out / 'closure-audit.log').read_text().splitlines()
parents = [x for x in lines if x.startswith('FORGE_PARENT ')]
axioms = [x for x in lines if x.startswith('FORGE_CLOSURE_AXIOM ')]
tags = [x for x in lines if x.startswith('FORGE_TAG ')]
assert len(axioms) == 4, axioms
assert all(x.endswith('hypotheses=0') for x in tags), tags
for line in tags:
    oracles = line.split(' oracles=', 1)[1].split(' axioms=', 1)[0]
    assert set(filter(None, oracles.split(','))) <= {'DISK_THM'}, line
assert any(x.startswith('FORGE_TAG refund_fields_original_method ') for x in tags)
assert any(x.startswith('FORGE_TAG refund_verified_spec ') for x in tags)
assert (root / 'unsure.md').read_bytes().startswith((out / 'journal-before.md').read_bytes())
result = dict(actual_exit=0, records=records, protected_inputs=len(baseline['input_sha256']),
              tracked_sources=tracked, closure_nodes=len(parents), own_theorem_tags=tags,
              closure_axioms=axioms, end_to_end=False,
              caveat='Fresh own proof/repeat; fresh imported closure inspection is not a replay of every upstream source or an independent human review.')
(out / 'readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: result[k] for k in ('actual_exit', 'protected_inputs', 'closure_nodes', 'closure_axioms', 'end_to_end')}))
