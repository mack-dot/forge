"""Check actual recorded outcomes and identities; this is not a verifier."""
import hashlib
import json
from pathlib import Path

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def load(path):
    return json.loads(path.read_text())

expected = {'positive-0001': 2, 'positive-0002': 0, 'repeat-0001': 0,
            'negative-charge-empty': 4, 'negative-reason': 4,
            'negative-original-id': 4}
observations = {}
for case, code in expected.items():
    work = OUT / case
    record = load(work / 'command.json')
    assert record['actual_exit'] == code, case
    assert record['sources'] == {str(p.relative_to(work)): sha(p)
                                 for p in sorted(work.rglob('*.dfy'))}, case
    output = (work / 'stdout.log').read_text()
    if code == 0:
        assert '9 verified, 0 errors' in output and 'Warning:' not in output, case
    elif code == 4:
        assert 'Error: assertion might not hold' in output, case
        assert 'resource limit' not in output and 'timed out' not in output, case
    else:
        assert 'Compilation failed because warnings were found' in output, case
    observations[case] = {'actual_exit': code, 'reason_matched': True}

positive = load(OUT / 'positive-0002/command.json')
repeat = load(OUT / 'repeat-0001/command.json')
assert positive['sources'] == repeat['sources']
for name in ['stdout.log', 'stderr.log']:
    assert (OUT / 'positive-0002' / name).read_bytes() == (OUT / 'repeat-0001' / name).read_bytes()
audit = load(OUT / 'positive-0002/audit-command.json')
assert audit['actual_exit'] == 0
assert 'completed with 0 findings' in (OUT / 'positive-0002/audit.stdout').read_text()

baseline = load(OUT / 'baseline.json')
for path, digest in baseline['protected'].items():
    assert sha(ROOT / path) == digest, path
assert sha(ROOT / 'FORGE_MISSION.md') == baseline['mission_sha256']
assert hashlib.sha256((ROOT / 'unsure.md').read_bytes()[:baseline['unsure_bytes']]).hexdigest() == baseline['unsure_sha256']

result = {'actual_exit': 0, 'cases': observations, 'repeat_sources_identical': True,
          'repeat_verifier_output_identical': True, 'audit_exit': 0,
          'protected_input_count': len(baseline['protected']),
          'protected_inputs_unchanged': True, 'prior_unsure_prefix_unchanged': True,
          'concrete_codec_proved': False, 'native_refund_proved': False,
          'scope': 'Conditional source representation transport', 'end_to_end': False}
(OUT / 'validation.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
