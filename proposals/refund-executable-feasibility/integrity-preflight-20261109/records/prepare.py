from pathlib import Path
import ast
import hashlib
import json
import subprocess
import yaml

root = Path('/Users/mackianni/forge')
out = Path(__file__).resolve().parent
old = root / 'proposals/refund-executable-feasibility/integrity-preflight-20261108/records'
sha = lambda b: hashlib.sha256(b).hexdigest()
source = (old / 'integrity_driver.py').read_text()
workflow = (old / 'proposed-workflow.yml').read_text()
assert sha(source.encode()) == 'a22b7aa7496739a189366f6178c1d041dd4dda354dc441cb255221ce3def6812'
assert sha(workflow.encode()) == '3e7c35a8b3a21a3645f8f966e6ba8058a2a605646c9eb3499d105eed2ed20e78'
new = source.replace('def git_hash(kind,data):', '''class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,request,response,code,message,headers,new_url):
        raise ValueError('redirect refused before follow-up request')
def git_hash(kind,data):''', 1)
new = new.replace('with urllib.request.urlopen(request,timeout=15) as response:',
                  'opener=urllib.request.build_opener(NoRedirect())\n'
                  '        with opener.open(request,timeout=15) as response:', 1)
assert new != source
ast.parse(new)
indent = lambda text: ''.join('          ' + line + '\n' for line in text.splitlines())
assert workflow.count(indent(source)) == 1
workflow = workflow.replace(indent(source), indent(new), 1)
workflow = workflow.replace('proposal/m1-input-integrity-20261108', 'proposal/m1-input-integrity-20261109')
workflow = workflow.replace('forge-m1-input-integrity-20261108', 'forge-m1-input-integrity-20261109')
parsed = yaml.load(workflow, Loader=yaml.BaseLoader)
assert parsed['permissions'] == {}
assert parsed['on'] == {'push': {'branches': ['proposal/m1-input-integrity-20261109'],
                                  'paths': ['.github/workflows/m1-input-integrity.yml']}}
assert len(parsed['jobs']) == 1
job = parsed['jobs']['integrity-only']
assert job['runs-on'] == 'ubuntu-24.04' and job['timeout-minutes'] == '5'
assert len(job['steps']) == 1
step = job['steps'][0]
assert set(step) == {'name', 'shell', 'run'}
assert step['shell'] == 'bash --noprofile --norc -euo pipefail {0}'
assert step['run'] == "/usr/bin/python3 -I -B - <<'PY'\n" + new + 'PY\n'
for name, data in [('integrity_driver.py', new), ('proposed-workflow.yml', workflow), ('proposed-shell.sh', step['run'])]:
    p = out / name
    assert not p.exists(), name
    p.write_text(data)
argv = ['/bin/bash', '--noprofile', '--norc', '-n', str(out / 'proposed-shell.sh')]
p = subprocess.run(argv, capture_output=True)
(out / 'shell.stdout.log').write_bytes(p.stdout)
(out / 'shell.stderr.log').write_bytes(p.stderr)
assert p.returncode == 0
r = {'actual_exit': 0, 'source_workflow_sha256': sha((old / 'proposed-workflow.yml').read_bytes()),
     'workflow_sha256': sha(workflow.encode()), 'workflow_bytes': len(workflow.encode()),
     'driver_sha256': sha(new.encode()), 'driver_bytes': len(new.encode()),
     'changes': ['Refuse HTTP redirects before a follow-up request.', 'Use a new proposal branch and concurrency group.'],
     'shell_check': {'argv': argv, 'actual_exit': p.returncode},
     'proof_inputs_changed': False, 'hosted_job': 'NOT_RUN', 'end_to_end': False}
(out / 'PREPARATION.json').write_text(json.dumps(r, indent=2) + '\n')
print(json.dumps(r))
