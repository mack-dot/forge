"""Check saved evidence and unchanged inputs. This does not rerun a proof."""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path('/Users/mackianni/forge')
out = Path(__file__).resolve().parent
docs = Path('/private/tmp/forge-readiness-docs-20261103')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
records = {}
for name, code in [('wire-0001', 0), ('stdio-0001', 1),
                   ('stdio-0002', 1), ('stdio-0003', 1)]:
    directory = out / ('proof-' + name)
    record = json.loads((directory / 'command.json').read_text())
    assert record['actual_exit'] == code, name
    source = 'forge_refundWireProgScript.sml' if name.startswith('wire') else 'forge_refundStdioProgScript.sml'
    assert sha(directory / source) == record['source_sha256'], name
    for member, expected in record['object_sha256'].items():
        assert sha(directory / 'objects' / member) == expected, member
    assert len(record['object_sha256']) == (6 if code == 0 else 0), name
    if code:
        assert 'Tactic failure proving "refund_main_valid"' in (directory / 'theory.log').read_text(), name
    assert record['end_to_end'] is False and record['native_refund_claim'] is False
    records[name] = record
assert sha(out / 'forge_refundWireProgScript.sml') == records['wire-0001']['source_sha256']
assert sha(out / 'forge_refundStdioProgScript.sml') == records['stdio-0003']['source_sha256']
log = (out / 'proof-wire-0001/theory.log').read_text()
theorems = ['refund_run_wire_valid', 'refund_render_fields_roundtrip',
            'refund_run_wire_decode_error', 'refund_run_wire_trailing',
            'refund_run_wire_malformed', 'refund_dispatch_valid', 'refund_dispatch_error']
for theorem in theorems:
    assert 'FORGE_THEOREM ' + theorem + '\n' in log, theorem
assert log.count('FORGE_HYPOTHESES 0') == len(theorems)
diagnostics = {}
for name, code in [('stdio-diagnostic', 1), ('stdio-diagnostic-0002', 1),
                   ('stdio-diagnostic-0003', 1), ('stdio-diagnostic-0004', 0)]:
    record = json.loads((out / (name + '-command.json')).read_text())
    assert record['actual_exit'] == code, name
    diagnostics[name] = record
baseline = json.loads((root / 'results/refund-caller-2026-11-04/attempt-0001/original-inputs-postflight.json').read_text())
for name, expected in baseline['input_sha256'].items():
    assert sha(root / name) == expected, name
tc = root / '.toolchain/experiments/refund-cakeml-20261104'
parent = tc / 'cakeml/compiler/dafny/forge_refundProg_experiment'
assert sha(parent / 'forge_refundProgScript.sml') == records['wire-0001']['parent_source_sha256']
assert sha(parent / '.hol/objs/forge_refundProgTheory.dat') == records['wire-0001']['parent_data_sha256']
tracked = {}
for name, head in [('cakeml', 'cd9155694c16831373ab695a670794f23282ed62'),
                   ('HOL', '9783a49979c94c401ff8c0e51b2eefae7ea95ae3')]:
    argv = ['git', '-C', str(tc / name), 'diff', '--quiet', 'HEAD']
    child = subprocess.run(argv)
    assert child.returncode == 0, name
    actual_head = subprocess.check_output(['git', '-C', str(tc / name), 'rev-parse', 'HEAD'], text=True).strip()
    assert actual_head == head, name
    tracked[name] = dict(argv=argv, actual_exit=child.returncode, head=actual_head)
assert (root / 'unsure.md').read_bytes().startswith((out / 'journal-before.md').read_bytes())
assert sha(root / 'FORGE_MISSION.md') == '7bb18eb90435b6c9ca16e93ae31624ec422bdfff05fb6a51ad71c8e9756df08c'
for name in ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md', 'FORGE_MISSION.md']:
    assert (root / name).read_bytes() == (docs / name).read_bytes(), name
rules_records = json.loads((out / 'github-protections.json').read_text())
assert [r['actual_exit'] for r in rules_records] == [0, 0, 1, 0]
rules = json.loads(rules_records[0]['output'])
assert {r['type'] for r in rules} == {'deletion', 'non_fast_forward', 'required_linear_history', 'pull_request'}
rule = next(r for r in rules if r['type'] == 'pull_request')['parameters']
assert rule['required_approving_review_count'] == 1 and rule['require_code_owner_review']
assert rule['require_last_push_approval'] and rule['dismiss_stale_reviews_on_push']
assert '404' in rules_records[2]['output']
result = dict(actual_exit=0, proof_records=records, diagnostic_records=diagnostics,
              protected_inputs=len(baseline['input_sha256']), tracked_sources=tracked,
              wire_theorems=theorems, saved_rules_checked=True,
              proof_rerun=False, remote_refreshed=False, end_to_end=False,
              whole_program_io='NOT_ESTABLISHED', wire_repeat='NOT RUN',
              wire_adversarial_controls='NOT RUN', wire_closure_audit='NOT RUN')
(out / 'readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: result[k] for k in ('actual_exit', 'protected_inputs', 'wire_theorems',
                                      'whole_program_io', 'proof_rerun', 'end_to_end')}))
