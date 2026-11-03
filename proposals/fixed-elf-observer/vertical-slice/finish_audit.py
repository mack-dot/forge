"""Record actual status-check execution and validate this audit's raw records."""
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path('/Users/mackianni/forge')
HERE = Path(__file__).resolve().parent
assert not (HERE / 'acceptance.json').exists()
consumer = json.loads((HERE / 'consumer-results.json').read_text())
assert len(consumer['cases']) == 3
for row in consumer['cases']:
    assert row['actual_exit'] == row['expected_exit']
    logs = HERE / 'consumer-runs' / row['case'] / 'commands' / 'commands.json'
    commands = json.loads(logs.read_text())
    signatures = [x for x in commands if 'verify-blob-attestation' in x['argv']]
    assert len(signatures) == 1 and signatures[0]['exit_code'] == 0
    assert row['result']['admitted'] is False and row['result']['controller_read'] is False
    row['actual_cosign_exit'] = signatures[0]['exit_code']

argv = ['python3', '-B', 'proposals/receipt-authentication-final/integration_exit.py',
        '--local-results', 'results/campaign-audit-2026-11-02/security',
        '--readiness', str(ROOT / 'results/owner-resume-commit-2026-11-03/attempt-0001/readiness-with-owner-report.json'),
        '--output', str(HERE / 'integration-exit.json')]
start = time.monotonic()
proc = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True)
(HERE / 'integration-exit-command.json').write_text(json.dumps({
    'argv': argv, 'cwd': str(ROOT), 'actual_exit': proc.returncode,
    'stdout': proc.stdout, 'stderr': proc.stderr, 'wall_seconds': time.monotonic() - start,
    'policy_changed': False, 'owner_backup_attestation_preserved': True}, indent=2) + '\n')
assert proc.returncode == 1
integration = json.loads((HERE / 'integration-exit.json').read_text())
assert integration['blockers'] == ['off_machine_backup_confirmed']
identity = json.loads((HERE / 'identity-audit.json').read_text())
assert identity['actual_exit'] == 0
assert json.loads((HERE / 'positive-command.json').read_text())['actual_exit'] == 0
assert json.loads((HERE / 'negative-command.json').read_text())['actual_exit'] == 1
assert json.loads((HERE / 'audit-command.json').read_text())['actual_exit'] == 0
result = {'actual_exit': 0, 'local_behavior_compilation': 0, 'wrong_result_rejection': 1,
          'published_assumption_parser': 0, 'direct_assumption_count': len(identity['assumptions']),
          'historical_consumer_cases': consumer['cases'], 'strict_integration_exit': proc.returncode,
          'strict_integration_blockers': integration['blockers'],
          'full_new_independent_kernel': 'NOT RUN', 'new_release_admission': 'NOT RUN',
          'new_hosted_execution': 'NOT RUN', 'stage_transition': False, 'end_to_end': False}
(HERE / 'acceptance.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
print(json.dumps({k: v for k, v in result.items() if k != 'historical_consumer_cases'}))
