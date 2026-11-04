"""Build pinned established tools in an isolated local prefix; no gate changes."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = Path('/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104')
PREFIX = ROOT / 'poly-install'
LOGS = OUT / 'tool-build'
LOGS.mkdir(exist_ok=False)
env = os.environ.copy()
env['CPPFLAGS'] = '-I/opt/homebrew/opt/gmp/include'
env['LDFLAGS'] = '-L/opt/homebrew/opt/gmp/lib -Wl,-rpath,/opt/homebrew/opt/gmp/lib'
env['PATH'] = str(PREFIX / 'bin') + os.pathsep + env['PATH']
env['HOLDIR'] = str(ROOT / 'HOL')
commands = []

def run(label, argv, cwd):
    print(label + ': started', flush=True)
    t = time.monotonic()
    with (LOGS / (label + '.log')).open('wb') as log:
        p = subprocess.run(argv, cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT)
    record = dict(label=label, argv=argv, cwd=str(cwd), actual_exit=p.returncode,
                  wall_seconds=time.monotonic()-t,
                  log_sha256=hashlib.sha256((LOGS / (label + '.log')).read_bytes()).hexdigest())
    commands.append(record)
    (LOGS / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
    print(label + ': actual exit ' + str(p.returncode), flush=True)
    if p.returncode:
        print((LOGS / (label + '.log')).read_text(errors='replace')[-4000:], flush=True)
        raise SystemExit(p.returncode)

run('poly-configure', ['./configure', '--prefix=' + str(PREFIX), '--enable-intinf-as-int', '--with-gmp'], ROOT / 'polyml')
run('poly-make', ['make', '-j2'], ROOT / 'polyml')
run('poly-compiler', ['make', 'compiler'], ROOT / 'polyml')
run('poly-install', ['make', 'install'], ROOT / 'polyml')
run('poly-version', [str(PREFIX / 'bin/poly'), '--version'], ROOT)
run('hol-configure', [str(PREFIX / 'bin/poly'), '--script', 'tools/smart-configure.sml'], ROOT / 'HOL')
run('hol-build', ['bin/build'], ROOT / 'HOL')
print('Pinned Poly/ML and HOL build commands completed. This is not a refund proof.', flush=True)
