"""Light wiring test of the proposed gate functions js_bound() and translate_and_bound() (gate-new/b/gate/refund.py).
The functions are taken from the gate copy by text. `run` executes the real Node checker (gate-new/b copy) on a given
file; Dafny is NOT run: translate is stubbed by copying an existing translation. Prints one line per case."""
import json, re, shutil, subprocess, sys, tempfile
from pathlib import Path
H = Path('/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-gate')
B = H / 'gate-new/b'
src = (B / 'gate/refund.py').read_text()
i = src.index('def js_bound('); j = src.index('def hostile(')
code = src[i:j]


class Rejected(Exception):
    pass


ROOT = B  # the checker path JS_CHECK is relative to ROOT
def relative(p):
    return str(p)
def run(command, work, name, records):
    if command[0] == 'node':
        command = ['/opt/homebrew/bin/node'] + command[1:]
        child = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=60,
                               env={'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'HOME': str(work)})
    else:  # stubbed translate: copy the translation named in STUB
        Path(command[command.index('--output') + 1] + '.js').write_bytes(Path(STUB).read_bytes())
        child = subprocess.CompletedProcess(command, 0, b'', b'')
    records.append(name)
    return child
class Fake:  # scripts.javascript_env.check
    @staticmethod
    def check():
        return {}
sys.modules['scripts'] = Fake; sys.modules['scripts.javascript_env'] = Fake
class D:
    DAFNY = 'dafny'
env = {'json': json, 'sys': sys, 'ROOT': ROOT, 'Rejected': Rejected, 'run': run, 'relative': relative,
       'JS_CHECK': 'gate/refund/js_bound_check.cjs', 'dafny': D}
exec(code, env)
for case in sys.argv[1:]:
    mode, path = case.split(':', 1)
    work = Path(tempfile.mkdtemp(dir=H / 'work'))
    STUB = path
    try:
        if mode == 'hostile':
            v = env['js_bound'](work, [], Path(path))
        else:
            v = env['translate_and_bound'](work, [])
        print(mode, Path(path).name, 'ACCEPT', v.get('code'))
    except Rejected as e:
        print(mode, Path(path).name, 'Rejected:', str(e)[:110])
    shutil.rmtree(work, ignore_errors=True)
