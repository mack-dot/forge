"""Validate actual I/O build and mutation records; no proof acceptance shortcut."""
import hashlib
import json
from pathlib import Path
import subprocess

out = Path(__file__).resolve().parent
root = Path('/Users/mackianni/forge')
tc = root / '.toolchain/experiments/refund-cakeml-20261104'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
matrices = {}
records = {}
for kind in ['wire', 'stdio']:
    matrix = json.loads((out / (kind + '-acceptance-matrix.json')).read_text())
    assert matrix['actual_exit'] == 0 and all(r['passed'] for r in matrix['results'])
    for result in matrix['results']:
        name = result['case']
        directory = out / ('proof-' + name)
        record = json.loads((directory / 'command.json').read_text())
        assert result['actual_exit'] == record['actual_exit'] == result['expected_exit']
        source = 'forge_refundWireProgScript.sml' if kind == 'wire' else 'forge_refundStdioProgScript.sml'
        assert sha(directory / source) == record['source_sha256']
        for member, digest in record['object_sha256'].items():
            assert sha(directory / 'objects' / member) == digest
        if result['expected_exit'] == 1:
            assert not record['object_sha256']
            assert 'Tactic failure proving "' + result['theorem'] + '"' in (directory / 'theory.log').read_text()
        else:
            assert len(record['object_sha256']) == 6
        records[name] = record
    matrices[kind] = matrix
prior_wire = json.loads((root / 'results/refund-wire-library-2026-11-04/attempt-0001/proof-wire-0001/command.json').read_text())
stdio = json.loads((out / 'proof-stdio-0004/command.json').read_text())
assert stdio['actual_exit'] == 0
assert prior_wire['object_sha256'] == records['wire-repeat']['object_sha256']
assert stdio['object_sha256'] == records['stdio-repeat']['object_sha256']
for theory, positive in [('forge_refundWireProg', prior_wire), ('forge_refundStdioProg', stdio)]:
    work = tc / 'cakeml/compiler/dafny' / (theory + '_experiment')
    assert sha(work / (theory + 'Script.sml')) == positive['source_sha256']
    assert sha(out / (theory + 'Script.sml')) == positive['source_sha256']
    for member, digest in positive['object_sha256'].items():
        assert sha(work / '.hol/objs' / member) == digest
baseline = json.loads((root / 'results/refund-caller-2026-11-04/attempt-0001/original-inputs-postflight.json').read_text())
for path, digest in baseline['input_sha256'].items():
    assert sha(root / path) == digest, path
old = tc / 'cakeml/compiler/dafny/forge_refundProg_experiment'
assert sha(old / 'forge_refundProgScript.sml') == stdio['parent_source_sha256']
assert sha(old / '.hol/objs/forge_refundProgTheory.dat') == stdio['parent_data_sha256']
tracked = {}
for name, expected in [('cakeml', 'cd9155694c16831373ab695a670794f23282ed62'),
                       ('HOL', '9783a49979c94c401ff8c0e51b2eefae7ea95ae3')]:
    child = subprocess.run(['git', '-C', str(tc / name), 'diff', '--quiet', 'HEAD'])
    assert child.returncode == 0
    head = subprocess.check_output(['git', '-C', str(tc / name), 'rev-parse', 'HEAD'], text=True).strip()
    assert head == expected
    tracked[name] = dict(head=head, tracked_diff_exit=child.returncode)
assert (root / 'unsure.md').read_bytes().startswith((out / 'journal-before.md').read_bytes())
result = dict(actual_exit=0, matrices=matrices, positive_stdio=stdio,
              protected_inputs=len(baseline['input_sha256']), tracked_sources=tracked,
              five_negative_reasons_checked=True, six_exports_repeated_each=True,
              stage=None, end_to_end=False, native_execution='NOT RUN',
              caveat='Local proof builds and controls. No fresh whole-program result is claimed by this readback.')
(out / 'io-readback.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['actual_exit','protected_inputs','five_negative_reasons_checked','six_exports_repeated_each','end_to_end']}))
