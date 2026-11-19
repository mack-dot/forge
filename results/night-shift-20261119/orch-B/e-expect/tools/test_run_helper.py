#!/usr/bin/env python3
"""Unit test of the PATCHED run() of gate/refund.py (copy p3/b), in isolation, with harmless stand-ins.
Run as: env -i PATH=/usr/bin:/bin HOME=<dir> python3 -I -B test_run_helper.py <patched refund.py> <workdir>"""
import ast, hashlib, json, os, resource, signal, subprocess, sys, time
from pathlib import Path
src, work = Path(sys.argv[1]), Path(sys.argv[2])
work.mkdir(parents=True, exist_ok=True)
tree = ast.parse(src.read_text())
keep = [n for n in tree.body if getattr(n, 'name', None) in ('child_limits', 'run')
        or (isinstance(n, ast.Assign) and getattr(n.targets[0], 'id', None) in ('STEP_SECONDS', 'OUTPUT_BYTES'))]
assert len(keep) == 4


class Rejected(Exception):
    pass


env = {'os': os, 'signal': signal, 'resource': resource, 'subprocess': subprocess, 'ROOT': work,
       'Rejected': Rejected, 'relative': lambda p: str(Path(p).relative_to(work)),
       'digest': lambda b: hashlib.sha256(b).hexdigest(),
       'canonical': lambda o: (json.dumps(o, sort_keys=True, separators=(',', ':')) + '\n').encode()}
exec(compile(ast.Module(body=keep, type_ignores=[]), str(src), 'exec'), env)
production = (dict(env['STEP_SECONDS']), env['OUTPUT_BYTES'])
# Test bounds (the production values are printed, not changed in the file).
env['STEP_SECONDS'].clear()
env['STEP_SECONDS'].update({'sleep30': 2, 'quick': 2, 'flood10mb': 20, 'grandchild': 2, 'selfkill': 5, 'exit3': 5})
env['OUTPUT_BYTES'] = 1024 * 1024
PY = sys.executable
cases = [
    ('sleep30', ['/bin/sleep', '30'], 'RESOURCE_LIMIT', 'wall-clock'),
    ('quick', ['/bin/sh', '-c', 'echo ok'], 'PASS', None),
    ('exit3', ['/bin/sh', '-c', 'echo out; echo err >&2; exit 3'], 'PASS', None),
    ('flood10mb', [PY, '-I', '-c', 'import sys; sys.stdout.buffer.write(b"x" * 10_000_000)'], 'RESOURCE_LIMIT', None),
    ('grandchild', ['/bin/sh', '-c', '/bin/sleep 31 & /bin/sleep 30'], 'RESOURCE_LIMIT', 'wall-clock'),
    ('selfkill', ['/bin/sh', '-c', 'kill -9 $$'], 'RESOURCE_LIMIT', 'signal'),
]
bad = 0
print('production bounds:', production)
for name, argv, want, why in cases:
    records = []
    t0 = time.monotonic()
    try:
        child = env['run'](argv, work, name, records)
        got, detail = 'PASS', 'exit %d stdout %d B stderr %d B' % (child.returncode, len(child.stdout), len(child.stderr))
    except Rejected as e:
        got, detail = 'RESOURCE_LIMIT' if str(e).startswith('RESOURCE_LIMIT') else 'OTHER', str(e)
    dt = time.monotonic() - t0
    left = subprocess.run(['/bin/ps', '-axo', 'command'], capture_output=True, text=True).stdout
    orphans = sum(1 for l in left.splitlines() if l.strip() in ('/bin/sleep 30', '/bin/sleep 31'))
    sizes = ((work / (name + '.stdout')).stat().st_size, (work / (name + '.stderr')).stat().st_size)
    ok = got == want and orphans == 0 and (why != 'wall-clock' or dt < 4.0)
    bad += not ok
    print('%-4s %-11s want=%-14s got=%-14s %.2fs orphans=%d files=%s rec_exit=%s | %s' % (
        'ok' if ok else 'FAIL', name, want, got, dt, orphans, sizes, records[-1]['exit_code'], detail))
print('failures:', bad)
sys.exit(1 if bad else 0)
