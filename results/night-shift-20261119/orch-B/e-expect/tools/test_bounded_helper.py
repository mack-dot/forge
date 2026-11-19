#!/usr/bin/env python3
"""Unit test of the `bounded` helper (+ limit_reached / CHECKER_TIMEOUT) extracted VERBATIM from a patched copy.
Usage: test_bounded_helper.py <patched file> <step-seconds-name>"""
import ast, os, signal, subprocess, sys, time
from pathlib import Path
src, const = Path(sys.argv[1]), sys.argv[2]
tree = ast.parse(src.read_text())
keep = [n for n in tree.body if getattr(n, 'name', None) in ('bounded', 'limit_reached')
        or (isinstance(n, ast.Assign) and getattr(n.targets[0], 'id', None) == const)]


class Rejected(Exception):
    pass


env = {'os': os, 'signal': signal, 'subprocess': subprocess, 'Path': Path, 'Rejected': Rejected}
exec(compile(ast.Module(body=keep, type_ignores=[]), str(src), 'exec'), env)
production = env[const]
env[const] = 2
bad = 0
for name, argv, want in [('sleep30', ['/bin/sleep', '30'], 'LIMIT'), ('quick', ['/bin/sh', '-c', 'echo ok; exit 3'], 'PASS'),
                         ('grandchild', ['/bin/sh', '-c', '/bin/sleep 31 & /bin/sleep 30'], 'LIMIT')]:
    t0 = time.monotonic()
    try:
        r = env['bounded'](argv, text=True)
        got = 'LIMIT' if r is None else 'PASS'
        detail = 'None' if r is None else 'exit %d out %r' % (r.returncode, r.stdout)
    except (Rejected, RuntimeError) as e:
        got, detail = 'LIMIT', str(e)
    dt = time.monotonic() - t0
    if got == 'LIMIT' and 'limit_reached' in env and r is None:
        detail = str(env['limit_reached'](argv))
    ps = subprocess.run(['/bin/ps', '-axo', 'command'], capture_output=True, text=True).stdout.splitlines()
    orphans = sum(1 for l in ps if l.strip() in ('/bin/sleep 30', '/bin/sleep 31'))
    ok = got == want and orphans == 0 and (want != 'LIMIT' or dt < 4)
    bad += not ok
    print('%-4s %-10s want=%-5s got=%-5s %.2fs orphans=%d | %s' % ('ok' if ok else 'FAIL', name, want, got, dt, orphans, detail))
print('production %s = %s; failures: %d' % (const, production, bad))
sys.exit(1 if bad else 0)
