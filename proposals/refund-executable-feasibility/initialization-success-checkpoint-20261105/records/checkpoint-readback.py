"""Check captured files and process records. This is not a proof checker."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path('/Users/mackianni/forge')
WT = Path('/private/tmp/forge-readiness-docs-20261103')
OUT = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text())
base = read(OUT / 'baseline.json')
assert not (OUT / 'checkpoint-readback.json').exists()
expected = {'inspect-0001': 0, 'success-0001': 1, 'success-0002': 0}
records = {}
for name, code in expected.items():
    record = read(OUT / name / 'command.json')
    assert record['actual_exit'] == code and record['end_to_end'] is False
    assert sha(OUT / name / 'proof.sml') == record['source_sha256']
    assert sha(TC / 'cakeml/misc/cakeml-heap') == record['heap_sha256']
    assert record['completion_marker'] == (name == 'success-0002')
    for path, digest in record.get('objects', {}).items():
        assert sha(OUT / name / path) == digest
    records[name] = record
diagnostic = (OUT / 'inspect-0001/stdout.log').read_text()
assert 'INITIALIZATION_PREMISE_INSPECTION_COMPLETE' in diagnostic
failure = (OUT / 'success-0001/stdout.log').read_text()
assert 'Type error in function application' in failure
assert 'pair$prod' in failure and 'fcp$cart' in failure
assert 'RUNTIME_PROOF_COMPLETE' not in failure
success = (OUT / 'success-0002/stdout.log').read_text()
claims = ['refund_lab_code', 'refund_lab_oracle', 'refund_initialization_sufficient']
for claim in claims:
    assert 'CHECKED ' + claim + '\n' in success
assert 'REMAINING_ANTECEDENTS 17' in success
assert 'RUNTIME_PROOF_COMPLETE' in success
assert sha(OUT / 'success-stackname.sml') == records['success-0002']['source_sha256']
assert (OUT / 'success.sml').read_text().replace(
    'backend$to_stack ac c prg=(bm,c\',code)',
    'backend$to_stack ac c prg=(bm,c\',stack_prg)'
) == (OUT / 'success-stackname.sml').read_text()
assert read(OUT / 'inspection-error.json')['actual_exit'] == 1
pins = {'cakeml': 'cd9155694c16831373ab695a670794f23282ed62',
        'HOL': '9783a49979c94c401ff8c0e51b2eefae7ea95ae3'}
for repo, pin in pins.items():
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=TC/repo).decode().strip() == pin
    assert subprocess.run(['git', 'diff', '--quiet', 'HEAD'], cwd=TC/repo).returncode == 0
sources = {**base['source_hashes'], **read(OUT / 'supplemental-sources.json')}
for name, digest in sources.items():
    committed = subprocess.check_output(['git', 'show', pins['cakeml'] + ':' + name], cwd=TC/'cakeml')
    assert hashlib.sha256(committed).hexdigest() == digest
    assert sha(TC/'cakeml'/name) == digest == sha(OUT/'upstream'/name)
for name, digest in base['protected'].items():
    assert sha(ROOT/name) == digest
assert sha(ROOT/'FORGE_MISSION.md') == base['mission_sha256'] == sha(WT/'FORGE_MISSION.md')
native = ROOT/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
assert sha(native) == base['native_sha256']
prior = 'proposals/refund-executable-feasibility/pointer-witness-validation-20261105'
for root in [ROOT, WT]:
    packet = root/prior
    assert sha(packet/'manifest.json') == base['prior_manifest_sha256']
    manifest = read(packet/'manifest.json')
    assert len(manifest) == base['prior_members']
    for name, digest in manifest.items():
        assert sha(packet/name) == digest
result = {'actual_exit': 0, 'scope': 'Captured-byte and process-record readback only.',
          'base_commit': base['base_commit'], 'recorded_child_exits': expected,
          'reported_claims': claims, 'reported_remaining_antecedents': 17,
          'exports': records['success-0002']['objects'],
          'proof_source_sha256': records['success-0002']['source_sha256'],
          'source_hashes': sources, 'source_pin_count': len(sources),
          'protected_path_count': len(base['protected']),
          'prior_members_per_copy': base['prior_members'],
          'native_sha256': sha(native), 'mission_sha256': base['mission_sha256'],
          'fresh_contract_import': 'NOT RUN', 'closure_audit': 'NOT RUN',
          'proof_repeat': 'NOT RUN', 'new_negative_controls': 'NOT RUN',
          'native_or_hosted_execution': 'NOT RUN', 'end_to_end': False}
(OUT/'checkpoint-readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if k not in ['source_hashes', 'exports']}))
