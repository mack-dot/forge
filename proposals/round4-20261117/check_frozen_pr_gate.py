"""Compare the eight PR-gate modules at a git revision with the recorded digests. Reads only; no verdict on the code.

The list is frozen-pr-gate-modules.json beside this file: the SHA-256 of each module at the commit that holds
step A and record 0001 (the bootstrap content). Exit 0: all eight are equal. Exit 1: a module differs or is absent.
Usage: python3 -I -B check_frozen_pr_gate.py <revision>
"""
import hashlib, json, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
FORGE = HERE.parents[1]
revision = sys.argv[1]
frozen = json.loads((HERE / 'frozen-pr-gate-modules.json').read_text())
rows = {}
for name, expected in sorted(frozen['sha256'].items()):
    child = subprocess.run(['git', '-C', str(FORGE), 'show', revision + ':' + name], capture_output=True)
    actual = hashlib.sha256(child.stdout).hexdigest() if child.returncode == 0 else None
    rows[name] = 'equal' if actual == expected else 'ABSENT' if actual is None else 'DIFFERENT: ' + actual
commit = subprocess.run(['git', '-C', str(FORGE), 'rev-parse', revision], capture_output=True, text=True).stdout.strip()
equal = all(value == 'equal' for value in rows.values())
print(json.dumps({'revision': revision, 'commit': commit, 'recorded_at_commit': frozen['recorded_at_commit'],
                  'modules': rows, 'all_equal': equal}, indent=1, sort_keys=True))
raise SystemExit(0 if equal else 1)
