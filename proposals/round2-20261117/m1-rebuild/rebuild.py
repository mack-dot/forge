"""Rebuild the pinned Poly/ML, HOL4 and CakeML tools for M1 under a hard wall-clock budget (Round 2, decision 2).

Same prefix as the original build (proposals/refund-executable-feasibility/verified-backend-20261104/build_tools.py),
so recorded scripts keep their paths. Every command is recorded with its real exit. At the deadline the running
command is killed and the script stops. This is a tool build. It is not a proof and not a replay of the M1 chain.
Usage: python3 -I -B rebuild.py <budget-seconds>
"""
import hashlib, json, os, signal, subprocess, sys, time
from pathlib import Path

FORGE = Path(__file__).resolve().parents[3]
ROOT = FORGE / '.toolchain/experiments/refund-cakeml-20261104'
PREFIX = ROOT / 'poly-install'
PINS = {'polyml': ('https://github.com/polyml/polyml', '4557554077078decce4ce5f90da00a713cfc32e4'),
        'HOL': ('https://github.com/HOL-Theorem-Prover/HOL', '9783a49979c94c401ff8c0e51b2eefae7ea95ae3'),
        'cakeml': ('https://github.com/CakeML/cakeml', 'cd9155694c16831373ab695a670794f23282ed62')}
out_root = FORGE / 'results/round2-m1-rebuild-20261117'
n = 1
while (out_root / f'attempt-{n:04d}').exists():
    n += 1
LOGS = out_root / f'attempt-{n:04d}'
LOGS.mkdir(parents=True)
BUDGET = float(sys.argv[1])
START = time.monotonic()
env = os.environ.copy()
env['CPPFLAGS'] = '-I/opt/homebrew/opt/gmp/include'
env['LDFLAGS'] = '-L/opt/homebrew/opt/gmp/lib -Wl,-rpath,/opt/homebrew/opt/gmp/lib'
env['PATH'] = str(PREFIX / 'bin') + os.pathsep + env['PATH']
env['HOLDIR'] = str(ROOT / 'HOL')
env['CAKEMLDIR'] = str(ROOT / 'cakeml')
commands = []


def save(extra=None):
    (LOGS / 'commands.json').write_text(json.dumps({'budget_seconds': BUDGET, 'elapsed_seconds': round(time.monotonic() - START, 1),
                                                    'pins': {k: v[1] for k, v in PINS.items()}, 'commands': commands,
                                                    'end_to_end': False, **(extra or {})}, indent=1) + '\n')


def run(label, argv, cwd):
    left = BUDGET - (time.monotonic() - START)
    if left <= 5:
        commands.append({'label': label, 'result': 'NOT STARTED: budget used'}); save({'stopped': 'budget'}); raise SystemExit(3)
    t = time.monotonic()
    with (LOGS / (label + '.log')).open('wb') as log:
        p = subprocess.Popen(argv, cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            p.wait(timeout=left)
            killed = False
        except subprocess.TimeoutExpired:
            os.killpg(p.pid, signal.SIGTERM); time.sleep(3)
            try:
                os.killpg(p.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):   # the group has already exited (macOS reports EPERM)
                pass
            p.wait(); killed = True
    commands.append({'label': label, 'argv': [str(a) for a in argv], 'cwd': str(cwd).replace(str(FORGE), '<FORGE>'),
                     'actual_exit': p.returncode, 'killed_at_deadline': killed, 'wall_seconds': round(time.monotonic() - t, 1),
                     'log_sha256': hashlib.sha256((LOGS / (label + '.log')).read_bytes()).hexdigest()})
    save()
    if killed:
        save({'stopped': 'budget'}); raise SystemExit(3)
    if p.returncode:
        save({'stopped': 'command failed: ' + label}); raise SystemExit(1)


ROOT.mkdir(parents=True, exist_ok=True)
for name, (url, sha) in PINS.items():
    d = ROOT / name
    if not (d / '.git').exists():
        run(f'clone-{name}', ['git', 'clone', '--quiet', url, str(d)], ROOT)
    run(f'checkout-{name}', ['git', '-c', 'advice.detachedHead=false', 'checkout', '--quiet', sha], d)
    head = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=d, capture_output=True, text=True).stdout.strip()
    commands.append({'label': f'pin-{name}', 'head': head, 'pinned': sha, 'match': head == sha}); save()
    if head != sha:
        save({'stopped': 'pin mismatch: ' + name}); raise SystemExit(1)
run('poly-configure', ['./configure', '--prefix=' + str(PREFIX), '--enable-intinf-as-int', '--with-gmp'], ROOT / 'polyml')
run('poly-make', ['make', '-j2'], ROOT / 'polyml')
run('poly-compiler', ['make', 'compiler'], ROOT / 'polyml')
run('poly-install', ['make', 'install'], ROOT / 'polyml')
run('poly-version', [str(PREFIX / 'bin/poly'), '--version'], ROOT)
run('hol-configure', [str(PREFIX / 'bin/poly'), '--script', 'tools/smart-configure.sml'], ROOT / 'HOL')
run('hol-build', ['bin/build'], ROOT / 'HOL')
# CakeML proof dependencies of the M1 chain. Incremental: a later run continues where this one stopped.
for label, sub in [('cakeml-basis', 'basis'), ('cakeml-backend-proofs', 'compiler/backend/proofs')]:
    run(label, ['nice', '-n', '15', str(ROOT / 'HOL/bin/Holmake'), '-j1'], ROOT / 'cakeml' / sub)
save({'stopped': 'all listed commands finished'})
