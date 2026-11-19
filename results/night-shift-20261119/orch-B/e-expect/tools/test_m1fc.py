"""Test the PATCHED m1_fail_closed.run_process with harmless stand-ins (pin overridden to each stand-in)."""
import hashlib, subprocess, sys, time
sys.path.insert(0, sys.argv[1])
import m1_fail_closed as m
bad = 0
for name, tl, want in [('standin-quick', 5, 'ok'), ('standin-sleep', 2, 'timeout'), ('standin-spin', 30, 'cpu')]:
    exe = sys.argv[1] + '/' + name
    m.PINNED_SHA256 = hashlib.sha256(open(exe, 'rb').read()).hexdigest()
    t0 = time.monotonic(); r = m.run_process(exe, b'', 100, time_limit=tl if name != 'standin-spin' else 2); dt = time.monotonic() - t0
    ps = subprocess.run(['/bin/ps', '-axo', 'command'], capture_output=True, text=True).stdout.splitlines()
    orph = sum(1 for l in ps if l.strip() in ('/bin/sleep 30', '/bin/sleep 31') or l.strip() == '/bin/sh -c while :; do :; done')
    got = 'timeout' if r.timed_out else ('cpu' if r.signal in (24, 9) else 'ok' if r.exit_code == 0 else 'other')
    ok = (got == want or (want == 'cpu' and got == 'timeout')) and orph == 0 and dt < 5
    bad += not ok
    print('%-4s %-14s want=%-7s got=%-7s %.2fs orphans=%d %r' % ('ok' if ok else 'FAIL', name, want, got, dt, orph, r))
print('failures:', bad); sys.exit(1 if bad else 0)
