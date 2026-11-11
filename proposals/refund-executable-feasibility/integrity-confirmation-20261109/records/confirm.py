"""Check preserved integrity evidence and fresh read-only provider responses."""
from pathlib import Path
import hashlib, json, shutil, subprocess, sys

root = Path('/Users/mackianni/forge')
out = Path(__file__).resolve().parent
base = root / 'proposals/refund-executable-feasibility'
prior = base / 'hosted-integrity-run-20261109'
sha = lambda b: hashlib.sha256(b).hexdigest()
read = lambda p: json.loads(p.read_text())
write = lambda p, v: p.write_text(json.dumps(v, indent=2) + '\n')

packets = {}
for name in ['integrity-preflight-20261108', 'integrity-preflight-20261109', 'hosted-integrity-run-20261109']:
    packet = base / name
    manifest = read(packet / 'MANIFEST.json')
    for name_in_packet, digest in manifest['files'].items():
        assert sha((packet / name_in_packet).read_bytes()) == digest, name_in_packet
    packets[name] = {'files': len(manifest['files']), 'manifest_sha256': sha((packet / 'MANIFEST.json').read_bytes())}
baseline = read(base / 'native-audit-20261104/records/baseline.json')
for name, digest in baseline['protected'].items():
    assert sha((root / name).read_bytes()) == digest, name
assert sha((root / 'FORGE_MISSION.md').read_bytes()) == baseline['mission_sha256']
before = {}
for name in ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md']:
    data = (root / name).read_bytes()
    assert b'U336' not in data
    before[name] = {'bytes': len(data), 'sha256': sha(data)}
write(out / 'tracking-before.json', before)

def fresh(name):
    result = read(out / ('fresh-' + name + '.json'))
    assert not result.get('isError'), name
    return result['structuredContent']

workflow = fresh('workflow')['content'].encode()
assert workflow == (prior / 'records/proposed-workflow.yml').read_bytes()
assert len(workflow) == 13735
assert sha(workflow) == 'b8c96c19049e04aedc5b2902b9342ec26db4234690d2c5cce589bbd1730016e9'
assert b'permissions: {}\n' in workflow and b'timeout-minutes: 5\n' in workflow
assert b'runs-on: ubuntu-24.04\n' in workflow
assert b'secrets.' not in workflow and b'uses:' not in workflow
assert b'class NoRedirect(' in workflow
log = fresh('logs')['content'].encode()
assert log == (prior / 'records/hosted-job.log').read_bytes()
assert sha(log) == 'b22630463ade3fc54f9481975f528de87ef283a94a05dd4dc496c062958b4187'
(out / 'hosted-job.log').write_bytes(log)
for old_name, new_name in [('run-detail-01.json', 'run'), ('final-run-list.json', 'runs'), ('run-jobs-01.json', 'jobs'), ('run-timing.json', 'timing')]:
    shutil.copyfile(out / ('fresh-' + new_name + '.json'), out / old_name)
shutil.copyfile(prior / 'records/readback.py', out / 'readback.py')
command = [sys.executable, '-I', '-B', str(out / 'readback.py')]
with (out / 'readback.stdout.log').open('wb') as stdout, (out / 'readback.stderr.log').open('wb') as stderr:
    result = subprocess.run(command, stdout=stdout, stderr=stderr)
write(out / 'readback-command.json', {'argv': command, 'actual_exit': result.returncode})
assert result.returncode == 0, 'Fresh evidence reader failed; see preserved logs'
assert (out / 'INDEPENDENT-READBACK.json').read_bytes() == (prior / 'records/INDEPENDENT-READBACK.json').read_bytes()
assert sha((prior / 'records/proposed-proof-workflow.yml').read_bytes()) == '1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1'
record = {'actual_exit': 0, 'status': 'TRANSFER_INTEGRITY_ESTABLISHED',
          'fresh_provider_readback': True, 'new_hosted_runs': 0,
          'existing_run_id': 42624212334, 'existing_job_id': 129183679727,
          'existing_hosted_exit': 0, 'fresh_evidence_reader_exit': result.returncode,
          'workflow_sha256': sha(workflow), 'log_sha256': sha(log),
          'prior_packets': packets, 'protected_paths': len(baseline['protected']),
          'mission_matches': True, 'HOL_executed': False, 'end_to_end': False}
write(out / 'CONFIRMATION.json', record)
print(json.dumps(record))
