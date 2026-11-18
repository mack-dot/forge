"""Start driver.py in its own session so that a tool timeout cannot stop it between records.
Usage: python3 -I -B launch_detached.py <log name> <driver arguments...>"""
from pathlib import Path
import subprocess, sys
OUT = Path(__file__).resolve().parent.parent
log = open(OUT / 'logs' / sys.argv[1], 'ab')
import os
env = dict(os.environ)
if sys.argv[2] == 'phase2':
    env.update({'FORGE_PLAN': 'phase2', 'FORGE_BUDGET_FILE': 'budget-phase2.json', 'FORGE_BUDGET_SECONDS': '14566'})
    del sys.argv[2]
p = subprocess.Popen(['python3', '-I', '-B', str(OUT / 'scripts/driver.py')] + sys.argv[2:], cwd=str(OUT), stdout=log, stderr=subprocess.STDOUT,
                     stdin=subprocess.DEVNULL, start_new_session=True, env=env)
print('started pid', p.pid)
