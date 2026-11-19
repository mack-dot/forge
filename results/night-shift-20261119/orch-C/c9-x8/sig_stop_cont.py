"""c9-x8: does a stop/continue or a default-ignored signal, delivered while the real refund process is
blocked in read(0) or write(1), change its observable behaviour?  Targets X11 rows E5 and E18
("no state change"; "EINTR needs a handler").  Exit 1 = divergence seen (the claim is FALSE on this run);
exit 0 = every case gave the expected complete frame and status 0.  At most ~12 short runs.
"""
import fcntl, hashlib, json, os, signal, subprocess, sys, time
sys.path.insert(0, '/Users/mackianni/forge/proposals/m1b-mission-20261119/drafts/fail-closed')
import frame  # noqa: E402

EXE = '/Users/mackianni/forge/results/night-shift-20261119/orch-A/ffi-c-audit/refund'
assert hashlib.sha256(open(EXE, 'rb').read()).hexdigest() == \
    'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C', 'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}
SMALL = frame.render_request(b'c', b'r', 100, 60, True, True, True, 40, b'returned_item')
SMALL_OUT = frame.render_fields(True, 40, b'returned_item', b'c', b'r', 1)
BIG = frame.render_request(b'y' * 2000, b'z' * 2000, 100, 60, True, True, True, 40, b'returned_item')
BIG_OUT = frame.render_fields(True, 40, b'returned_item', b'y' * 2000, b'z' * 2000, 1)
RES = []
STATES = []


def pstate(pid):
    try:
        return subprocess.run(['/bin/ps', '-o', 'stat=,wchan=', '-p', str(pid)], capture_output=True,
                              timeout=5).stdout.decode().strip()
    except Exception as e:
        return 'ps-failed:%r' % e


def kick(pid, sigs):
    STATES.append(pstate(pid))
    for s in sigs:
        os.kill(pid, s)
        time.sleep(0.1)


def read_case(name, sigs):
    """child blocked in read(0, ...) on an empty blocking pipe; signals; then the request."""
    p = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=ENV)
    time.sleep(0.3)
    kick(p.pid, sigs)
    out, err = p.communicate(SMALL, timeout=30)
    ok = (p.returncode == 0 and out == SMALL_OUT)
    RES.append({'case': name, 'rc': p.returncode, 'out_len': len(out), 'out_ok': out == SMALL_OUT,
                'err': err[:200].decode('latin-1'), 'pass': ok, 'state_before_signals': STATES[-1]})


def write_case(name, sigs):
    """child blocked in write(1, ...) on a FULL blocking pipe; signals; then drain."""
    r, w = os.pipe()
    fl = fcntl.fcntl(w, fcntl.F_GETFL)
    fcntl.fcntl(w, fcntl.F_SETFL, fl | os.O_NONBLOCK)
    filled = 0
    while True:
        try:
            filled += os.write(w, b'F' * 512)
        except BlockingIOError:
            try:
                filled += os.write(w, b'F')
            except BlockingIOError:
                break
    fcntl.fcntl(w, fcntl.F_SETFL, fl)  # back to BLOCKING before exec (shared file description)
    p = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=w, stderr=subprocess.PIPE, env=ENV)
    os.close(w)
    p.stdin.write(BIG); p.stdin.close()
    time.sleep(0.4)
    kick(p.pid, sigs)
    allb = b''
    while True:
        c = os.read(r, 65536)
        if not c:
            break
        allb += c
    os.close(r)
    err = p.stderr.read(); p.wait()
    out = allb[filled:]
    ok = (p.returncode == 0 and allb[:filled] == b'F' * filled and out == BIG_OUT)
    RES.append({'case': name, 'rc': p.returncode, 'filled': filled, 'out_len': len(out),
                'out_ok': out == BIG_OUT, 'err': err[:200].decode('latin-1'), 'pass': ok, 'state_before_signals': STATES[-1]})


def main():
    S = signal
    read_case('R0-control', [])
    read_case('R1-stop-cont', [S.SIGSTOP, S.SIGCONT])
    read_case('R2-tstp-cont', [S.SIGTSTP, S.SIGCONT])
    read_case('R3-cont-only', [S.SIGCONT])
    read_case('R4-default-ignored', [S.SIGWINCH, S.SIGCHLD, S.SIGURG, S.SIGINFO])
    write_case('W0-control', [])
    write_case('W1-stop-cont', [S.SIGSTOP, S.SIGCONT])
    write_case('W2-tstp-cont', [S.SIGTSTP, S.SIGCONT])
    write_case('W3-default-ignored', [S.SIGWINCH, S.SIGCHLD, S.SIGURG, S.SIGINFO])
    for r in RES:
        print(json.dumps(r))
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sig_stop_cont_results.json'), 'w') as f:
        json.dump(RES, f, indent=1)
    return 0 if all(r['pass'] for r in RES) else 1


if __name__ == '__main__':
    sys.exit(main())
