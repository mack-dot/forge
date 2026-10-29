"""Adversarial controls for the v3.3 candidate (U128 V1-V4 and low findings).

  python3 -I run_controls.py CANDIDATE_REPO OUTPUT

CANDIDATE_REPO is a scratch Git clone of main with the candidate committed at
HEAD; this tool resets it with git checkout/clean after every plant. Every
attack plants code that writes a marker when it runs. A control passes only on
the expected exit code AND the expected reason AND no marker. Exit 0 when every
control passes.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

REPO, OUT = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
NEW = json.loads((Path(__file__).resolve().parent / 'approval-manifest.json').read_text())['new_lock_sha256']
OLD = 'be23ec85ec2d9652bd1c87f6870c0d7130862af169319af24975b941ac3b5f57'
MAIN = 'd43f5f4de55573a17f4f9cf4d41528dd159e9f2f'
OUT.mkdir(parents=True, exist_ok=False)
MARKS = OUT / 'markers'
MARKS.mkdir()
results = []


def marker(name):
    return MARKS / name.replace('/', '_')


def payload(name):
    return f"open({str(marker(name))!r}, 'w').write('ran')\n"


def git(*args):
    return subprocess.run(['git', '-C', str(REPO)] + list(args), capture_output=True, text=True, check=True).stdout


def reset():
    git('checkout', '-q', '--', '.')
    git('clean', '-fdxq')


def record(name, expected_exit, expected_reason, argv, *, cwd=REPO, env=None, plant=None):
    if plant:
        plant()
    child = subprocess.run(argv, cwd=cwd, capture_output=True, text=True,
                           env=env if env is not None else {'PATH': '/usr/bin:/bin:/usr/local/bin', 'HOME': str(OUT)})
    text = child.stdout + child.stderr
    ran = marker(name).exists()
    ok = child.returncode == expected_exit and (expected_reason is None or expected_reason in text) and not ran
    results.append({'control': name, 'argv': argv, 'exit': child.returncode, 'expected_exit': expected_exit,
                    'expected_reason': expected_reason, 'attacker_code_executed': ran, 'pass': ok,
                    'last_line': (text.strip().splitlines() or [''])[-1][:300]})
    (OUT / (name.replace(' ', '_').replace('/', '_') + '.log')).write_text(text)
    print(json.dumps(results[-1]), flush=True)
    reset()


def write(rel, text):
    def plant():
        path = REPO / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    return plant


py = sys.executable
check = [py, '-I', '-S', '-B', 'gate/provenance/bootstrap.py', '--implementation-sha256', NEW, '--check']

# 1. Bootstrap: clean candidate, then every importable root entry is refused.
record('clean candidate', 0, 'BOOTSTRAP_VERIFIED', check)
record('installed v3.2 lock refused by candidate', 1, 'IMPLEMENTATION_LOCK',
       [py, '-I', '-S', '-B', 'gate/provenance/bootstrap.py', '--implementation-sha256', OLD, '--check'])
for name, rel in [('root ensurepip.py', 'ensurepip.py'), ('root runpy.py', 'runpy.py'), ('root json.py', 'json.py'),
                  ('root sitecustomize.py', 'sitecustomize.py'), ('root pip package', 'pip/__init__.py'),
                  ('root sourceless bytecode', 'json.pyc'), ('root extension module', 'json.cpython-310-darwin.so'),
                  ('root pth file', 'evil.pth'), ('root bytecode cache', '__pycache__/x.cpython-310.pyc')]:
    record('bootstrap: ' + name, 1, 'ROOT_IMPORTABLE', check, plant=write(rel, payload('bootstrap: ' + name)))
record('bootstrap: root symlink to a package', 1, 'ROOT_IMPORTABLE', check,
       plant=lambda: (REPO / 'json').symlink_to(REPO / 'gate/provenance'))
# False-positive controls: plain data at the root stays accepted.
record('bootstrap: root data file accepted', 0, 'BOOTSTRAP_VERIFIED', check, plant=write('NOTES.txt', 'data\n'))
record('bootstrap: root directory without __init__ accepted', 0, 'BOOTSTRAP_VERIFIED', check,
       plant=write('pip/README', 'not a package\n'))

# 2. V1/V2 behaviour: the same interpreter, with and without -I, in a checkout carrying attacker modules.
plant_v1 = write('ensurepip.py', payload('v1 without -I (v3.2 behaviour)') + 'raise SystemExit(0)\n')
record('v1 without -I (v3.2 behaviour)', 0, None, [py, '-m', 'ensurepip', '--version'], plant=plant_v1)
results[-1]['pass'] = results[-1]['attacker_code_executed']  # this control must show the attack working
plant_v1i = write('ensurepip.py', payload('v1 with -I (candidate)') + 'raise SystemExit(0)\n')
record('v1 with -I (candidate)', 0, 'pip', [py, '-I', '-m', 'ensurepip', '--version'], plant=plant_v1i)


def plant_pip(name):
    def plant():
        write('pip/__init__.py', '')()
        write('pip/__main__.py', payload(name))()
    return plant


record('v2 without -I (v3.2 behaviour)', 0, None, [py, '-m', 'pip', '--version'],
       plant=plant_pip('v2 without -I (v3.2 behaviour)'))
results[-1]['pass'] = results[-1]['attacker_code_executed']
record('v2 with -I (candidate)', 0, 'pip', [py, '-I', '-m', 'pip', '--version'], plant=plant_pip('v2 with -I (candidate)'))
record('collector with -I in a planted cwd', 0, 'collector-ok',
       [py, '-I', '-c', 'import hashlib, json, pathlib, re; print("collector-ok")'],
       plant=write('json.py', payload('collector with -I in a planted cwd')))

# 3. Verifier source_tree on committed trees.
probe = OUT / 'probe.py'
probe.write_text('import json, sys\n'
                 'sys.path.insert(0, sys.argv[1] + "/gate/provenance")\n'
                 'from pathlib import Path\n'
                 'from common import Records, Rejected, context, source_tree\n'
                 '_, _, impl = context(sys.argv[2])\n'
                 'try:\n'
                 '    source_tree(Path(sys.argv[1]) / ".git", sys.argv[3], impl, Records(Path(sys.argv[4])))\n'
                 '    print("ACCEPTED")\n'
                 'except Rejected as error:\n'
                 '    print(error.reason); raise SystemExit(1)\n')
head = git('rev-parse', 'HEAD').strip()
tree_n = 0


def tree(name, expected_exit, reason, commit):
    global tree_n
    tree_n += 1
    record('source_tree: ' + name, expected_exit, reason,
           [py, '-B', str(probe), str(REPO), NEW, commit, str(OUT / f'tree-{tree_n:02d}')])


tree('candidate commit', 0, 'ACCEPTED', head)
tree('installed main carries the old lock', 1, 'IMPLEMENTATION_LOCK_AT_COMMIT', MAIN)
for name, rel in [('root ensurepip.py', 'ensurepip.py'), ('root pip package', 'pip/__init__.py'),
                  ('root runpy.py', 'runpy.py'), ('root pth file', 'evil.pth'),
                  ('root bytecode cache', '__pycache__/x.cpython-310.pyc'),
                  ('root directory named json.py', 'json.py/data.txt')]:
    write(rel, payload('commit: ' + name))()
    git('add', '-f', rel)
    git('-c', 'user.name=c', '-c', 'user.email=c@invalid', 'commit', '-qm', 'attack: ' + name)
    attack = git('rev-parse', 'HEAD').strip()
    git('checkout', '-q', '--detach', head)
    tree('commit with ' + name, 1, 'ROOT_IMPORTABLE', attack)
os.symlink('gate/provenance', REPO / 'json')
git('add', 'json')
git('-c', 'user.name=c', '-c', 'user.email=c@invalid', 'commit', '-qm', 'attack: root symlink')
attack = git('rev-parse', 'HEAD').strip()
git('checkout', '-q', '--detach', head)
reset()
tree('commit with a root symlink', 1, 'ROOT_IMPORTABLE', attack)

# 4. Verifier independence guard and git credential isolation (no network: fetch is replaced).
guard = OUT / 'guard.py'
guard.write_text('import json, os, sys\n'
                 'sys.path.insert(0, sys.argv[1] + "/gate/provenance")\n'
                 'from pathlib import Path\n'
                 'import common\n'
                 'from common import Records, Rejected, context, repository_identity\n'
                 'policy, _, impl = context(sys.argv[2])\n'
                 'mode = sys.argv[3]\n'
                 'seen = {}\n'
                 'def fake_fetch(url, records, label, *, token_name=None):\n'
                 '    s = policy["signer"]\n'
                 '    return json.dumps({"full_name": s["repository"], "id": s["repository_id"],\n'
                 '                       "owner": {"id": s["owner_id"]}, "private": mode == "private"}).encode()\n'
                 'common.fetch = fake_fetch\n'
                 'real_run = Records.run\n'
                 'def spy(self, argv, label, **kw):\n'
                 '    if label == "source-fetch":\n'
                 '        env = kw.get("env") or {}\n'
                 '        seen["token_var"] = "FORGE_VERIFIER_GITHUB_TOKEN" in env\n'
                 '        seen["header"] = env.get("GIT_CONFIG_KEY_0") == "http.https://github.com/.extraheader"\n'
                 '        raise Rejected("STOP_BEFORE_NETWORK")\n'
                 '    return real_run(self, argv, label, **kw)\n'
                 'Records.run = spy\n'
                 'os.environ["FORGE_VERIFIER_GITHUB_TOKEN"] = "github_pat_" + "B" * 82\n'
                 'try:\n'
                 '    repository_identity(policy, impl, "0" * 40, Records(Path(sys.argv[4])))\n'
                 'except Rejected as error:\n'
                 '    print(error.reason, json.dumps(seen, sort_keys=True))\n')
base_env = {'PATH': '/usr/bin:/bin:/usr/local/bin', 'HOME': str(OUT)}
record('guard: GITHUB_ACTIONS=1 refused', 0, 'VERIFIER_NOT_INDEPENDENT',
       [py, '-B', str(guard), str(REPO), NEW, 'public', str(OUT / 'guard-1')], env=dict(base_env, GITHUB_ACTIONS='1'))
record('guard: OIDC request URL refused', 0, 'VERIFIER_NOT_INDEPENDENT',
       [py, '-B', str(guard), str(REPO), NEW, 'public', str(OUT / 'guard-2')],
       env=dict(base_env, ACTIONS_ID_TOKEN_REQUEST_URL='https://example.invalid'))
record('credential: public fetch gets no token and no header', 0,
       'STOP_BEFORE_NETWORK {"header": false, "token_var": false}',
       [py, '-B', str(guard), str(REPO), NEW, 'public', str(OUT / 'guard-3')], env=base_env)
record('credential: private fetch gets the header but not the token variable', 0,
       'STOP_BEFORE_NETWORK {"header": true, "token_var": false}',
       [py, '-B', str(guard), str(REPO), NEW, 'private', str(OUT / 'guard-4')], env=base_env)

# 5. EXIT harness: verifier launch through the bootstrap from another cwd; no bytecode left behind.
record('harness launch form works from another cwd', 0, 'usage: release.py',
       [py, '-I', '-S', '-B', str(REPO / 'gate/provenance/bootstrap.py'), '--implementation-sha256', NEW, '--',
        str(REPO / 'gate/provenance/release.py'), '--help'], cwd=OUT)
subprocess.run([py, str(REPO / 'scripts/exit_stage_9.py'), '--case', 'unsigned'], cwd=REPO, capture_output=True)
caches = sorted(str(p.relative_to(REPO)) for p in REPO.rglob('__pycache__'))
results.append({'control': 'harness leaves no bytecode cache', 'caches': caches, 'pass': not caches})
print(json.dumps(results[-1]), flush=True)
record('bootstrap still verifies after the harness ran', 0, 'BOOTSTRAP_VERIFIED', check)

# 6. D3: the harness refuses unless the bootstrap started it, before any import can
#    resolve from the checkout (U131); through the bootstrap, a planted module is refused.
toolchain = REPO / '.toolchain/stage9'


def controller(lock):
    def plant():
        toolchain.mkdir(parents=True, exist_ok=True)
        (toolchain / 'controller.json').write_text(json.dumps({'implementation_sha256': lock}))
    return plant


def via(lock):
    return [py, '-I', '-S', '-B', 'gate/provenance/bootstrap.py', '--implementation-sha256', lock, '--',
            'scripts/exit_stage_9.py', '--case', 'unsigned']


direct = [py, 'scripts/exit_stage_9.py', '--case', 'unsigned']
v32copy = OUT / 'v32-copy'
subprocess.run(['git', 'clone', '-q', str(Path.home() / 'forge-stage9-rehearsal-0001/main'), str(v32copy)], check=True)
name = 'd3 planted scripts/argparse.py runs under installed v3.2 (exploit reproduced)'
(v32copy / 'scripts/argparse.py').write_text(payload(name))
record(name, 1, None, direct, cwd=v32copy)
results[-1]['pass'] = results[-1]['attacker_code_executed']
for name, argv in [('d3 direct run with planted scripts/argparse.py refused before import', direct),
                   ('d3 direct -E -s -B run with planted scripts/argparse.py refused',
                    [py, '-E', '-s', '-B'] + direct[1:])]:
    record(name, 1, 'EXIT_SETUP_NOT_ESTABLISHED', argv, plant=write('scripts/argparse.py', payload(name)))
name = 'd3 bootstrap launch with planted scripts/argparse.py refused'
record(name, 1, 'UNLOCKED_EXECUTABLE:scripts/argparse.py', via(NEW), plant=write('scripts/argparse.py', payload(name)))
record('d3 bootstrap launch with the old lock refused', 1, 'BOOTSTRAP_REJECTED: IMPLEMENTATION_LOCK', via(OLD))


def tamper_release():
    path = REPO / 'gate/provenance/release.py'
    path.write_text(payload('d3 bootstrap launch with a changed locked file refused') + path.read_text())


record('d3 bootstrap launch with a changed locked file refused', 1, 'BOOTSTRAP_REJECTED: LOCKED_INPUT', via(NEW),
       plant=tamper_release)
record('d3 bootstrap launch without controller.json: not established, not a verdict', 1, None, via(NEW))

# 7. V4: relabelled receipts. v3.2 accepts them; the candidate needs the GitHub run record.
REH = Path.home() / 'forge-stage9-rehearsal-0001'
V32 = REH / 'main'
v4 = OUT / 'v4.py'
v4.write_text('import json, shutil, subprocess, sys\n'
              'from pathlib import Path\n'
              'code, lock, proof, request_path, mode, out = sys.argv[1:7]\n'
              'sys.path.insert(0, code + "/gate/provenance")\n'
              'import common\n'
              'from common import Records, Rejected, canonical, context, read, write\n'
              'import release\n'
              'def gh_fetch(url, records, label, *, token_name=None):\n'
              '    # Read-only GitHub API through gh; the verifier itself uses its own token.\n'
              '    child = subprocess.run(["gh", "api", url.replace("https://api.github.com/", "")], capture_output=True)\n'
              '    if child.returncode:\n'
              '        raise Rejected("GITHUB_HTTP_STATUS:gh-api-error")\n'
              '    return child.stdout\n'
              'common.fetch = gh_fetch\n'
              'policy, lk, _ = context(lock)\n'
              'request = read(Path(request_path))\n'
              'copy = Path(out) / "proof"\n'
              'shutil.copytree(proof, copy)\n'
              'receipt = read(copy / "receipt.json")\n'
              'new = dict(request, challenge="ab" * 32)\n'
              'receipt["challenge"] = new["challenge"]\n'
              'if mode.startswith("candidate"):\n'
              '    run = mode.split(":")[1]\n'
              '    receipt["execution"] = {"run_id": run, "run_attempt": mode.split(":")[2]}\n'
              'write(copy / "receipt.json", receipt)\n'
              'try:\n'
              '    release.validate_receipt(copy, policy, lk, new)\n'
              '    if mode.startswith("candidate"):\n'
              '        common.run_identity(policy, new, receipt["execution"], Records(Path(out) / "records"))\n'
              '    print("ACCEPTED")\n'
              'except Rejected as error:\n'
              '    print(error.reason)\n')
proof = REH / 'artifact/x/proof'
request_path = REH / 'request/request.json'
for name, code, lock, mode, expected in [
        ('v4 relabelled receipt accepted by installed v3.2 (exploit reproduced)', V32, OLD, 'v32', 'ACCEPTED'),
        ('v4 relabelled receipt without execution refused by candidate', REPO, NEW, 'candidate-noexec', 'PROOF_RECEIPT_FIELDS'),
        ('v4 relabelled receipt naming the real rehearsal run', REPO, NEW, 'candidate:40810179164:1', 'PROOF_RUN_IDENTITY'),
        ('v4 relabelled receipt naming the B2-prime dry-run run', REPO, NEW, 'candidate:40787574980:1', 'PROOF_RUN_IDENTITY'),
        ('v4 relabelled receipt claiming a re-run attempt', REPO, NEW, 'candidate:40810179164:2', 'PROOF_RECEIPT_EXECUTION'),
        ('v4 relabelled receipt naming a nonexistent run', REPO, NEW, 'candidate:1:1', 'GITHUB_HTTP_STATUS')]:
    target = OUT / ('v4-' + str(len(results)))
    target.mkdir()
    mode_arg = 'none' if mode == 'candidate-noexec' else mode
    record(name, 0, expected, [py, '-B', str(v4), str(code), lock, str(proof), str(request_path), mode_arg, str(target)],
           env={'PATH': '/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin', 'HOME': str(Path.home())})

(OUT / 'results.json').write_text(json.dumps({'candidate_lock': NEW, 'repo_head': head, 'results': results,
                                              'end_to_end': False}, indent=2) + '\n')
failed = [r['control'] for r in results if not r['pass']]
print('controls', len(results), 'failed', failed)
sys.exit(1 if failed else 0)
