"""TEST driver (W-launch round 2). Loads a launcher module FROM A PATH and runs one action in this process.
usage: driver.py LAUNCHER_PY ACTION EXE [ARG]
ACTION: decide        -> decide(BASE, EXE) pinned to EXE's own SHA-256 and CDHash (test pin)
        decide-real   -> decide(BASE, EXE) with the module's production pins
        decide-nocd   -> decide(BASE, EXE) pinned to EXE's SHA-256 with pinned_cdhash=None
        decide-bigreq -> decide(BASE with a charge id of ARG bytes, EXE) test pin
        probe         -> spawn_and_collect on a private copy of EXE, prints the child's stdout
        hold          -> decide(BASE, EXE, test pin) with on_blocked printing the child pid and sleeping ARG s
Prints one line: DRIVER <json>. Also prints the driver's own SIGCHLD disposition before the action."""
import hashlib, importlib.util, json, os, re, shutil, signal, subprocess, sys, tempfile, time

lp, action, exe = sys.argv[1], sys.argv[2], sys.argv[3]
arg = sys.argv[4] if len(sys.argv) > 4 else None
spec = importlib.util.spec_from_file_location('launcher_under_test', lp)
L = importlib.util.module_from_spec(spec)
spec.loader.exec_module(L)
BASE = dict(charge=b'c', request=b'r', original=100, remaining=60, enabled=True, opened=True, candidate=True,
            amount=40, reason=b'returned_item')


def pins(path):
    sha = hashlib.sha256(open(path, 'rb').read()).hexdigest()
    out = subprocess.run(['/usr/bin/codesign', '-dv', '--verbose=4', path], capture_output=True, timeout=8)
    m = re.search(rb'^CDHash=([0-9a-f]{40})$', out.stderr, re.M)
    return sha, m.group(1).decode()


def disp(s):
    h = signal.getsignal(s)
    return {signal.SIG_IGN: 'SIG_IGN', signal.SIG_DFL: 'SIG_DFL'}.get(h, 'handler')


if arg in ('inproc-ign', 'inproc-nocldwait'):   # measurement only: set in THIS process (not via exec)
    if arg == 'inproc-ign':
        signal.signal(signal.SIGCHLD, signal.SIG_IGN)
    else:
        import ctypes

        class SA(ctypes.Structure):
            _fields_ = [('handler', ctypes.c_void_p), ('mask', ctypes.c_uint32), ('flags', ctypes.c_int)]
        ctypes.CDLL('/usr/lib/libSystem.B.dylib').sigaction(signal.SIGCHLD, ctypes.byref(SA(None, 0, 0x20)), None)
rec = {'inproc': arg, 'launcher': os.path.basename(lp), 'action': action, 'driver_sigchld_before': disp(signal.SIGCHLD)}
t0 = time.monotonic()
if action == 'decide':
    sha, cd = pins(exe)
    d = L.decide(BASE, exe, pinned_sha256=sha, pinned_cdhash=cd, check_self=False)
elif action == 'decide-nocd':
    sha, cd = pins(exe)
    d = L.decide(BASE, exe, pinned_sha256=sha, pinned_cdhash=None, check_self=False)
elif action == 'decide-real':
    d = L.decide(BASE, exe, check_self=False)
elif action == 'decide-bigreq':
    sha, cd = pins(exe)
    d = L.decide(dict(BASE, charge=b'x' * int(arg)), exe, pinned_sha256=sha, pinned_cdhash=cd, check_self=False)
elif action == 'probe':
    sha, cd = pins(exe)
    tmp = tempfile.mkdtemp(prefix='wl2-probe-', dir='/private/tmp')
    cp = os.path.join(tmp, 'probe')
    shutil.copyfile(exe, cp)
    os.chmod(cp, 0o500)
    try:
        getattr(L, 'reset_own_state', lambda: None)()   # what v2's decide() does first; v1 has no such step
        res = L.spawn_and_collect(cp, b'x', 8000, cd)
        d = ('PROBE', res.stdout.decode().strip())
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
elif action == 'hold':
    sha, cd = pins(exe)

    def hold(pid):
        print('CHILDPID %d' % pid, flush=True)
        time.sleep(float(arg))
    d = L.decide(BASE, exe, pinned_sha256=sha, pinned_cdhash=cd, check_self=False, on_blocked=hold)
else:
    raise SystemExit('unknown action')
rec['decision'] = [x.decode('latin-1') if isinstance(x, bytes) else x for x in d]
rec['driver_sigchld_after'] = disp(signal.SIGCHLD)
rec['seconds'] = round(time.monotonic() - t0, 2)
print('DRIVER ' + json.dumps(rec), flush=True)
