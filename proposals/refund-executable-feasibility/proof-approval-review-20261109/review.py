"""Static approval review only; never imports or runs the proposed driver."""
from pathlib import Path
import ast, hashlib, json, subprocess

root = Path('/Users/mackianni/forge')
base = root / 'proposals/refund-executable-feasibility'
out = Path(__file__).resolve().parent
prior = base / 'hosted-integrity-run-20261109'
records = prior / 'records'
sha = lambda b: hashlib.sha256(b).hexdigest()
read = lambda p: json.loads(p.read_text())
write = lambda p, v: p.write_text(json.dumps(v, indent=2) + '\n')
before = {n: {'bytes': len((root/n).read_bytes()), 'sha256': sha((root/n).read_bytes())}
          for n in ['ROADMAP.md', 'FORGE_MISSION_STATUS.md', 'unsure.md']}
assert b'U337' not in (root/'unsure.md').read_bytes()
write(out/'tracking-before.json', before)
for name in ['hosted-integrity-run-20261109', 'integrity-confirmation-20261109']:
    p = base/name
    for member, digest in read(p/'MANIFEST.json')['files'].items():
        assert sha((p/member).read_bytes()) == digest, member
workflow = (records/'proposed-proof-workflow.yml').read_bytes()
driver = (records/'proposed-proof-driver.py').read_bytes()
assert len(workflow) == 16385 and sha(workflow) == '1af894a0f8f13b279c3c4752f77366c02c32075959041d08174c996c01b560a1'
assert sha(driver) == '2667f6d8f81e4286c04a80bf3e856b66c74ce15141d5e80c18e1fb4662d45fd8'
ast.parse(driver)
shell = ''.join(line[10:] + '\n' for line in workflow.decode().split('        run: |\n', 1)[1].splitlines())
assert shell.encode() == (records/'proposed-proof-shell.sh').read_bytes()
assert shell.split("<<'PY'\n", 1)[1].rsplit('\nPY\n', 1)[0].encode() + b'\n' == driver
assert workflow.count(b'    runs-on:') == 1 and b'    runs-on: macos-15\n' in workflow
assert b'permissions: {}\n' in workflow and b'    timeout-minutes: 15\n' in workflow
assert b'uses:' not in workflow and b'secrets.' not in workflow
argv = ['/bin/bash', '--noprofile', '--norc', '-n', str(records/'proposed-proof-shell.sh')]
r = subprocess.run(argv, capture_output=True)
(out/'shell.stdout.log').write_bytes(r.stdout)
(out/'shell.stderr.log').write_bytes(r.stderr)
write(out/'shell-command.json', {'argv': argv, 'actual_exit': r.returncode})
assert r.returncode == 0
manifest_records = []
files = {}
for name, size, digest, count in [('addon',932639,'6822e8da53f477f991bfa4a7cab02ffc59906a58460048a49af190fb42b2c105',1475),('base',8435,'6822d1ae4ef5ca78ae14e352c5b1e222ed113bba1f3760d9b0141b70386c51a7',18)]:
    path = base/'integrity-preflight-20261108/records'/('remote-'+name+'-manifest.json')
    data = path.read_bytes()
    assert len(data) == size and sha(data) == digest
    m = json.loads(data)
    assert len(m['files']) == count
    assert len(set(f['path'] for f in m['files'])) == count
    assert not set(files).intersection(f['path'] for f in m['files'])
    files.update({f['path']: f for f in m['files']})
    manifest_records.append({'package': name, 'bytes': size, 'sha256': digest, 'members': count,
                             'archive_sha256': m['archive_sha256'], 'archive_bytes': m['archive_bytes'], 'parts': m['parts']})
candidate = 'results/refund-read-event-gap-20261107/attempt-0001/generic-read-0001.sml'
prep = 'results/hosted-cf-preparation-20261107/attempt-0001/prepared-inputs/'
special = [candidate] + [prep+n+'.sml' for n in ['import','wrong-exception','omitted-event']]
for name in special:
    b = (root/name).read_bytes()
    assert len(b) == files[name]['bytes'] and sha(b) == files[name]['sha256'], name
term = (root/candidate).read_bytes().split(b'store_thm ("read_error_generic", ``',1)[1].split(b'``,',1)[0]
expected = (root/(prep+'import.sml')).read_bytes().split(b'val expected = ``',1)[1].split(b'``;',1)[0]
assert term == expected and sha(term) == '289b8be8c848dc3debddbac5184e613e2c1e127c56dddd574e5b43087cc8c29a'
old = read(records/'INDEPENDENT-READBACK.json')
assert old['members_checked'] == 1493 and old['mutation_controls_rejected'] == 3
assert old['actual_checker_exit'] == 0 and old['proof_executed'] is False
baseline = read(base/'native-audit-20261104/records/baseline.json')
for name, digest in baseline['protected'].items():
    assert sha((root/name).read_bytes()) == digest, name
assert sha((root/'FORGE_MISSION.md').read_bytes()) == baseline['mission_sha256']
result = {'workflow_sha256': sha(workflow), 'workflow_bytes': len(workflow), 'driver_sha256': sha(driver),
          'manifest_records': manifest_records, 'members': len(files), 'quotation_sha256': sha(term),
          'special_sources': {n: files[n]['sha256'] for n in special}, 'shell_syntax_exit': r.returncode,
          'integrity_controls': {'count': 3, 'observed': 'Expected in-process ValueError rejections', 'separate_process_exit_codes': None},
          'proof_controls': {'count': 2, 'expected_child_exit': 1, 'actual_child_exits': None, 'status': 'NOT_RUN'},
          'HOL_executed': False, 'hosted_runs': 0, 'approval_granted': False, 'end_to_end': False}
write(out/'REVIEW.json', result)
print(json.dumps({'members': len(files), 'shell_syntax_exit': r.returncode, 'workflow_sha256': sha(workflow), 'HOL_executed': False, 'approval_granted': False, 'end_to_end': False}))
