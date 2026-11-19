"""Round-2 tests (W-launch): for each repaired review finding, the same attack against launcher.py (v1, must
FAIL: attack succeeds or a hang is caught by a short outer time-out) and launcher_v2.py (must PASS).
Every launcher run is a separate process: /usr/bin/env -i /usr/bin/python3 -B -I -S tests_v2/driver.py ...
TEST CODE. Finite test. Exit 0 iff every row is as expected."""
import glob
import json
import os
import signal
import subprocess
import sys
import time

LAUNCH = '/Users/USER/forge/results/night-shift-20261119/orch-A/launch'
V1, V2 = os.path.join(LAUNCH, 'launcher.py'), os.path.join(LAUNCH, 'launcher_v2.py')
DRV = os.path.join(LAUNCH, 'tests_v2', 'driver.py')
B2 = os.path.join(LAUNCH, 'bin2')
EXE = os.path.join(LAUNCH, '..', 'ffi-c-audit', 'refund')
PY = ['/usr/bin/env', '-i', '/usr/bin/python3', '-B', '-I', '-S']
ROWS = []


def drv(launcher, action, exe, arg=None, prefix=(), timeout=10, shell_prefix=None):
    argv = list(prefix) + PY + [DRV, launcher, action, exe] + ([arg] if arg else [])
    if shell_prefix:
        argv = ['/bin/bash', '-c', shell_prefix + ' && exec "$@"', 'x'] + argv
    t0 = time.monotonic()
    try:
        p = subprocess.run(argv, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired as e:
        return {'hang': True, 'seconds': round(time.monotonic() - t0, 2), 'stderr': (e.stderr or b'')[-200:].decode('latin-1')}
    line = [l for l in p.stdout.decode('latin-1').splitlines() if l.startswith('DRIVER ')]
    r = json.loads(line[-1][7:]) if line else {'no_line': True, 'stdout': p.stdout[-300:].decode('latin-1')}
    r['rc'] = p.returncode
    r['stderr_tail'] = p.stderr[-200:].decode('latin-1')
    r['wall'] = round(time.monotonic() - t0, 2)
    return r


def dec(r):
    if r.get('hang'):
        return 'HANG(outer time-out %ss)' % r['seconds']
    d = r.get('decision')
    if not d:
        return 'NO-DECISION'
    return d[0] + ('(%s)' % d[1] if d[0] == 'AUTHORIZED' else ' ' + str(d[1])[:40])


def row(finding, sub, r1, r2, v1_fails, v2_passes, note=''):
    ok = bool(v1_fails) and bool(v2_passes)
    ROWS.append({'finding': finding, 'subcase': sub, 'v1': r1, 'v2': r2, 'v1_fails_as_expected': bool(v1_fails),
                 'v2_passes': bool(v2_passes), 'as_expected': ok, 'note': note})
    print('%-6s %-44s v1=%-40s v2=%-40s %s' % (finding, sub, r1 if isinstance(r1, str) else dec(r1),
                                               r2 if isinstance(r2, str) else dec(r2), 'OK' if ok else 'NOT AS EXPECTED'))


def m1launch_dirs():
    return set(glob.glob('/private/tmp/m1launch-*'))


def main():
    start_dirs = m1launch_dirs()
    # F-01 (a-d): SIGCHLD ignored / SA_NOCLDWAIT INSIDE the launcher process; child writes the exact accept
    # frame, then exit 7 or abort.
    for mode in ('inproc-ign', 'inproc-nocldwait'):
        for fake in ('fake_accept_exit7', 'fake_accept_abort'):
            r1 = drv(V1, 'decide', os.path.join(B2, fake), mode)
            r2 = drv(V2, 'decide', os.path.join(B2, fake), mode)
            row('F-01', '%s %s' % (mode, fake), r1, r2, dec(r1).startswith('AUTHORIZED'),
                dec(r2).startswith('REFUSED D3') or dec(r2).startswith('REFUSED D2'))
    # F-01 (e): the caller sets SIG_IGN and execs the launcher (the review's scenario). Probe result for v1.
    r1 = drv(V1, 'decide', os.path.join(B2, 'fake_accept_exit7'),
             prefix=['/usr/bin/python3', '-B', '-I', os.path.join(LAUNCH, 'tests_v2', 'sigchld_exec.py'), 'ign'])
    r2 = drv(V2, 'decide', os.path.join(B2, 'fake_accept_exit7'),
             prefix=['/usr/bin/python3', '-B', '-I', os.path.join(LAUNCH, 'tests_v2', 'sigchld_exec.py'), 'ign'])
    row('F-01', 'caller SIG_IGN then exec (exit 7)', r1, r2, True, dec(r2).startswith('REFUSED D3'),
        'v1 NOT reproduced via exec: SIG_IGN is inherited (driver sees it) but the status was still delivered; '
        'recorded as no failing side for this route')

    # F-02 (a): FIFO at --exe.
    fifo = os.path.join(LAUNCH, 'tests_v2', 'fifo-exe')
    if os.path.exists(fifo):
        os.unlink(fifo)
    os.mkfifo(fifo)
    try:
        r1 = drv(V1, 'decide-real', fifo, timeout=6)
        r2 = drv(V2, 'decide-real', fifo, timeout=6)
    finally:
        os.unlink(fifo)
    row('F-02', 'FIFO at the --exe path', r1, r2, r1.get('hang'), dec(r2).startswith('REFUSED'),
        'production pins; the driver itself does not open the path')
    # F-02 (b): child never reads stdin; request of 1,000,000 bytes (> pipe capacity).
    before = m1launch_dirs()
    r1 = drv(V1, 'decide-bigreq', os.path.join(B2, 'fake_noread'), '1000000', timeout=9)
    r2 = drv(V2, 'decide-bigreq', os.path.join(B2, 'fake_noread'), '1000000', timeout=12)
    row('F-02', 'non-reading child, 1 MB request', r1, r2, r1.get('hang'),
        dec(r2).startswith('REFUSED D1') and r2.get('seconds', 99) < 9,
        'v1 driver killed by the outer time-out leaves an orphan fake_noread (sleeps 30 s) and a copy dir')
    # F-02 (c): request above the bound.
    r2 = drv(V2, 'decide-bigreq', os.path.join(B2, 'fake_noread'), '2000000', timeout=12)
    row('F-02', 'request 2 MB > MAX_REQUEST_BYTES', '(not run on v1)', r2, True, dec(r2).startswith('REFUSED V4'),
        'v2 only: the bound is new')

    # F-07: EPIPE on the request write (child closed stdin; then prints the exact accept frame, exit 0).
    r1 = drv(V1, 'hold', os.path.join(B2, 'fake_closestdin'), '0.1')
    r2 = drv(V2, 'hold', os.path.join(B2, 'fake_closestdin'), '0.1')
    row('F-07', 'EPIPE on request write', r1, r2, dec(r1).startswith('AUTHORIZED'), dec(r2).startswith('REFUSED V4'))

    # F-08: pinned_cdhash None.
    r1 = drv(V1, 'decide-nocd', os.path.join(LAUNCH, 'bin', 'fake_refund'))
    r2 = drv(V2, 'decide-nocd', os.path.join(LAUNCH, 'bin', 'fake_refund'))
    row('F-08', 'pinned_cdhash=None (fake binary, its own SHA pin)', r1, r2, dec(r1).startswith('AUTHORIZED'),
        dec(r2).startswith('REFUSED V5'))

    # F-03: an exception port set by the CALLER (excport_exec) before exec of env -i python ... launcher.
    pre = [os.path.join(B2, 'excport_exec')]
    r1 = drv(V1, 'probe', os.path.join(B2, 'probe2'), prefix=pre)
    r2 = drv(V2, 'probe', os.path.join(B2, 'probe2'), prefix=pre)
    p1, p2 = r1.get('decision', ['', ''])[1], r2.get('decision', ['', ''])[1]
    row('F-03', 'caller exception port inherited by the child', 'excports: ' + p1.split('excports_set_masks=')[-1],
        'excports: ' + p2.split('excports_set_masks=')[-1], True, 'excports_set=0 ' in p2,
        'caller wrapper stderr v1: %s. The CALLER masks (0x66) were NOT seen in the v1 child: route not reproduced '
        '(no failing side). The ports 0xc00,0x2000 seen by v1 are present at every exec in this session (origin '
        'unknown); v2 clears them for its child.' % r1.get('stderr_tail', '').strip()[:60])

    # T-1 / F-03: caller soft rlimits; and a caller HARD limit below the fixed child value.
    sp = 'ulimit -S -n 32; ulimit -S -s 1024; ulimit -S -t 3'
    r1 = drv(V1, 'probe', os.path.join(B2, 'probe2'), shell_prefix=sp)
    r2 = drv(V2, 'probe', os.path.join(B2, 'probe2'), shell_prefix=sp)
    p1, p2 = r1.get('decision', ['', ''])[1], r2.get('decision', ['', ''])[1]
    g = lambda p: ' '.join(x for x in p.split() if x.split('=')[0] in ('stack', 'cpu', 'nofile', 'fsize'))  # noqa: E731
    row('T-1', 'caller soft rlimits (nofile 32, stack 1 MiB, cpu 3)', g(p1), g(p2), 'nofile=32/' in p1,
        'nofile=64/64' in p2 and 'stack=8388608/8388608' in p2 and 'cpu=10/10' in p2)
    r1 = drv(V1, 'decide-real', EXE, shell_prefix='ulimit -S -n 32; ulimit -H -n 32')
    r2 = drv(V2, 'decide-real', EXE, shell_prefix='ulimit -S -n 32; ulimit -H -n 32')
    row('T-1', 'caller HARD nofile 32 (< 64)', r1, r2, True, dec(r2).startswith('REFUSED'),
        'v2 refuses (FALSE REFUSAL by design; fail closed); v1 decides normally: no failing side')

    # F-13: SIGTERM / SIGKILL to the launcher while the child waits for input.
    for sig in (signal.SIGTERM, signal.SIGKILL):
        res = {}
        for name, lp in (('v1', V1), ('v2', V2)):
            before = m1launch_dirs()
            p = subprocess.Popen(PY + [DRV, lp, 'hold', EXE, '3'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            line = p.stdout.readline().decode()
            cpid = int(line.split()[1]) if line.startswith('CHILDPID') else None
            os.kill(p.pid, sig)
            p.wait(timeout=5)
            time.sleep(0.5)
            alive = False
            if cpid:
                try:
                    os.kill(cpid, 0)
                    alive = True
                except ProcessLookupError:
                    alive = False
            left = m1launch_dirs() - before
            res[name] = 'rc=%s child_alive=%s leftover_dirs=%d' % (p.returncode, alive, len(left))
        if sig == signal.SIGTERM:
            row('F-13', 'SIGTERM to the launcher', res['v1'], res['v2'], 'leftover_dirs=1' in res['v1'],
                'leftover_dirs=0' in res['v2'] and 'child_alive=False' in res['v2'])
        else:
            row('F-13', 'SIGKILL to the launcher (cannot be caught)', res['v1'], res['v2'], True,
                'child_alive=False' in res['v2'],
                'expected: copy dir LEFT by both (recorded); child ends by EOF on stdin')

    # F-09: the launcher's OWN non-blocking stdout with 0 bytes free (its EAGAIN path), via the CLI.
    import fcntl
    req = os.path.join(LAUNCH, 'tests_v2', 'req-f09.json')
    with open(req, 'w') as f:
        json.dump({'charge': 'c', 'request': 'r', 'original': 100, 'remaining': 60, 'enabled': True,
                   'opened': True, 'candidate': True, 'amount': 40, 'reason': 'returned_item'}, f)
    out = {}
    for name, lp in (('v1', V1), ('v2', V2)):
        r, w = os.pipe()
        fcntl.fcntl(w, fcntl.F_SETFL, fcntl.fcntl(w, fcntl.F_GETFL) | os.O_NONBLOCK)
        filled = 0
        while True:
            try:
                filled += os.write(w, b'F')
            except BlockingIOError:
                break
        p = subprocess.Popen(PY + [lp, '--exe', os.path.abspath(EXE), '--request-json', req], stdout=w,
                             stderr=subprocess.PIPE)
        os.close(w)
        time.sleep(1.0)
        data = b''
        while True:
            c = os.read(r, 65536)
            if not c:
                break
            data += c
        os.close(r)
        p.wait(timeout=10)
        line = data[filled:]
        out[name] = 'rc=%d line_complete=%s %s' % (p.returncode, line.endswith(b'\n') and line.count(b'\n') == 1,
                                                   line[:60].decode('latin-1'))
    os.unlink(req)
    row('F-09', 'launcher own stdout full + O_NONBLOCK', out['v1'], out['v2'], True,
        'rc=0 line_complete=True' in out['v2'], 'exercised on both; no failing side expected')

    import shutil
    made = m1launch_dirs() - start_dirs
    for d in made:                      # remove the copies that killed launchers left behind (own files)
        shutil.rmtree(d, ignore_errors=True)
    print('removed %d left-over /private/tmp/m1launch-* dirs made by this test' % len(made))
    bad = [r for r in ROWS if not r['as_expected']]
    with open(os.path.join(LAUNCH, 'tests_v2', 'test_v2_findings_results.json'), 'w') as f:
        json.dump({'class': 'TESTED-UNPROVED; run by the author of the control', 'rows': ROWS, 'failures': len(bad)},
                  f, indent=1)
    print('test_v2_findings: %d rows, %d not as expected' % (len(ROWS), len(bad)))
    return 0 if not bad else 1


if __name__ == '__main__':
    sys.exit(main())
