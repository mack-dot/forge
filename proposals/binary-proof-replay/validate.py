"""Check proposal syntax and boundaries. Does not execute or judge a proof."""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
import yaml

HERE = Path(__file__).resolve().parent
SOURCE = Path('/private/tmp/forge-campaign-main-20261102')
MAIN = 'f9eb1cbc252b28c80e5dfe2774da71bc35a31bd3'
assert subprocess.check_output(['git', '-C', str(SOURCE), 'rev-parse', 'HEAD'], text=True).strip() == MAIN
path = HERE / 'binary-proof-replay.yml.proposed'
x = yaml.safe_load(path.read_text())
base = yaml.safe_load((SOURCE / '.github/workflows/provenance.yml').read_text())
assert x['on'] == {'workflow_dispatch': {}}
assert x['permissions'] == {'contents': 'read'}
assert set(x['jobs']) == {'proof'}
job = x['jobs']['proof']
assert 'permissions' not in job
assert job['runs-on'] == base['jobs']['proof']['runs-on']
assert job['timeout-minutes'] == base['jobs']['proof']['timeout-minutes']
assert job['steps'][:5] == base['jobs']['proof']['steps'][:5]
assert job['env']['FORGE_STAGE9_IMPLEMENTATION'] == hashlib.sha256(
    (SOURCE / 'gate/provenance/implementation.lock').read_bytes()).hexdigest()
assert all(re.fullmatch(r'[A-Za-z0-9_./-]+@[0-9a-f]{40}', s['uses'])
           for s in job['steps'] if 'uses' in s)
syntax = []
for step in job['steps']:
    if 'run' in step:
        r = subprocess.run(['bash', '-n'], input=step['run'], text=True, capture_output=True)
        syntax.append({'step': step['name'], 'exit_code': r.returncode, 'stderr': r.stderr})
        assert r.returncode == 0
run = job['steps'][-2]['run']
program = run.split("<<'PYTHON'\n", 1)[1].rsplit('\nPYTHON', 1)[0]
tree = ast.parse(program)
calls = [ast.unparse(n.func) for n in ast.walk(tree) if isinstance(n, ast.Call)]
assert calls.count('producer.replay') == 1
assert not any(c in calls for c in ['producer.package', 'producer.sign', 'producer.produce',
                                   'producer.request_create', 'release.verify', 'release.main'])
assert 'FORGE_STAGE9_REQUEST' not in path.read_text()
assert 'id-token' not in path.read_text()
assert 'workflow_run' not in x['on'] and 'pull_request' not in x['on']
assert 'secrets.' not in path.read_text() or 'secrets.token_hex(32)' in path.read_text()
assert job['steps'][-1]['if'] == 'always()'
# The only repository diff will add this workflow. Protected checker code stays unchanged.
target = '.github/workflows/binary-proof-replay.yml'
r = subprocess.run(['git', 'diff', '--no-index', '--', '/dev/null', str(path)],
                   capture_output=True, text=True)
assert r.returncode == 1
patch = r.stdout.replace('b/' + str(path), 'b/' + target).replace('+++ b/' + str(path), '+++ b/' + target)
# git emits the relative path supplied; normalize both headers explicitly.
lines = patch.splitlines()
lines[0] = 'diff --git a/' + target + ' b/' + target
for i, line in enumerate(lines):
    if line.startswith('+++ '): lines[i] = '+++ b/' + target
patch = '\n'.join(lines) + '\n'
(HERE / 'fix.patch').write_text(patch)
check = subprocess.run(['git', '-C', str(SOURCE), 'apply', '--check', '-'], input=patch,
                       capture_output=True, text=True)
assert check.returncode == 0, check.stderr
result = {'exit_code': 0, 'base_commit': MAIN,
          'workflow_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
          'patch_sha256': hashlib.sha256(patch.encode()).hexdigest(),
          'implementation_lock_sha256': job['env']['FORGE_STAGE9_IMPLEMENTATION'],
          'shell_syntax': syntax, 'python_ast': 'passed', 'git_apply_check': check.returncode,
          'setup_steps_match_approved_workflow': True, 'proof_checker_changes': False,
          'release_authority': False, 'installed': False, 'published': False,
          'hosted_execution': 'NOT RUN', 'end_to_end': False}
(HERE / 'validation.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'exit_code': 0, 'shell_steps': len(syntax), 'git_apply_check': 0,
                  'workflow_sha256': result['workflow_sha256'], 'execution': 'NOT RUN'}))
