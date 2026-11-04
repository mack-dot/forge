"""Check saved experiment identities. This does not check a behavioral proof."""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path('/Users/mackianni/forge')
out = Path(__file__).resolve().parent
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
attempts = {}
for name in ('construct', 'construct-0002'):
    directory = out / ('proof-' + name)
    record = json.loads((directory / 'command.json').read_text())
    assert record['actual_exit'] == 1
    assert record['object_sha256'] == {}
    assert sha(directory / 'forge_refundNormProgScript.sml') == record['source_sha256']
    assert 'Signal 2' in (directory / 'build.log').read_text()
    assert 'FORGE_NORMALISED_AST_READY' not in (directory / 'theory.log').read_text()
    attempts[name] = record
assert 'FORGE_INPUT_READY' in (out / 'proof-construct-0002/theory.log').read_text()
baseline = json.loads((root / 'results/refund-caller-2026-11-04/attempt-0001/original-inputs-postflight.json').read_text())
for name, expected in baseline['input_sha256'].items():
    assert sha(root / name) == expected, name
tc = root / '.toolchain/experiments/refund-cakeml-20261104'
parent = tc / 'cakeml/compiler/dafny/forge_refundProg_experiment'
record = attempts['construct-0002']
assert sha(parent / 'forge_refundProgScript.sml') == record['parent_source_sha256']
assert sha(parent / '.hol/objs/forge_refundProgTheory.dat') == record['parent_data_sha256']
pins = {}
for tree, expected in [('cakeml', 'cd9155694c16831373ab695a670794f23282ed62'),
                       ('HOL', '9783a49979c94c401ff8c0e51b2eefae7ea95ae3')]:
    actual = subprocess.check_output(['git', '-C', str(tc / tree), 'rev-parse', 'HEAD'], text=True).strip()
    assert actual == expected
    result = subprocess.run(['git', '-C', str(tc / tree), 'diff', '--quiet', 'HEAD'])
    assert result.returncode == 0
    pins[tree] = {'head': actual, 'tracked_diff_exit': result.returncode}
packets = {}
for name in ('tail-guard-20261104', 'native-io-20261104', 'native-audit-20261104'):
    directory = root / 'proposals/refund-executable-feasibility' / name
    manifest = json.loads((directory / 'SHA256.json').read_text())
    for member, expected in manifest['files'].items():
        assert sha(directory / member) == expected, member
    packets[name] = len(manifest['files'])
mission = root / 'FORGE_MISSION.md'
attachment = Path('/Users/mackianni/.codex/attachments/5d8ba0a7-729f-43d7-9010-d02363c2c01e/pasted-text-1.txt')
assert mission.read_bytes() == attachment.read_bytes()
assert (root / 'unsure.md').read_bytes().startswith((out / 'journal-before.md').read_bytes())
result = dict(actual_exit=0, purpose='Saved-record and identity validation only',
              command=['python3', '-B', str(out / 'validate_records.py')],
              attempts=attempts, protected_input_count=len(baseline['input_sha256']),
              checked_packets=packets, toolchain=pins, mission_sha256=sha(mission),
              prior_journal_bytes=len((out / 'journal-before.md').read_bytes()),
              candidate_constructed=False, behavior_established=False, end_to_end=False)
(out / 'records-validation.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: result[k] for k in ('actual_exit', 'protected_input_count', 'checked_packets', 'candidate_constructed', 'end_to_end')}))
