"""AC-3: the C FFI aborts or misreports (model: an error byte or no error; C: exit 0 with no or partial output,
a signal, or an abort). TEST CODE (W-launch). Finite test.
The launcher does not change the C code. It removes the descriptor and signal STATES that drive the C into
those paths (N09, N11, N14, N20, N21), and it refuses every non-clean outcome. Model-level divergences at
states the launcher cannot influence (configuration length, short array, 32-bit descriptor) stay OPEN."""
import fcntl
import os
import re
import signal
import subprocess
import sys
import time

sys.path.insert(0, '/Users/mackianni/forge/results/night-shift-20261119/orch-A/launch/tests_v2/old')
import common as C  # noqa: E402

L = C.L
PROBE = os.path.join(C.BIN, 'probe')


def probe_copy():
    import shutil, tempfile
    d = tempfile.mkdtemp(prefix='wl-probe-', dir='/private/tmp')
    cp = os.path.join(d, 'probe')
    shutil.copyfile(PROBE, cp)
    os.chmod(cp, 0o500)
    return d, cp


def main():
    hb, hres = C.honest(C.BASE)
    hbig, _ = C.honest(C.BIG)
    same = lambda d: (lambda o: o == C.short(d))   # noqa: E731

    # AC3-a: launch state seen by a process. Hostile caller: extra inheritable fds, DYLD var, blocked signals,
    # SIGPIPE/SIGTERM ignored, non-blocking stdout. Naive spawn vs launcher spawn primitive (pinned to the probe).
    extra = os.open('/dev/null', os.O_RDONLY)
    os.set_inheritable(extra, True)
    old_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGUSR1, signal.SIGALRM, signal.SIGWINCH})
    old_term = signal.signal(signal.SIGTERM, signal.SIG_IGN)       # Python already ignores SIGPIPE
    r, w = os.pipe()
    fcntl.fcntl(w, fcntl.F_SETFL, fcntl.fcntl(w, fcntl.F_GETFL) | os.O_NONBLOCK)
    try:
        naive = C.raw_run([PROBE], b'x', env={'DYLD_PRINT_TO_FILE': '/dev/null', 'X': '1'}, stdout=w,
                          close_fds=False, restore_signals=False)
        os.close(w)
        naive_out = C.drain(r).decode()
        os.close(r)
        d, cp = probe_copy()
        launch_out = L.spawn_and_collect(cp, b'x', 4000, C.cdhash_of(PROBE)).stdout.decode()
        __import__('shutil').rmtree(d, ignore_errors=True)
    finally:
        signal.pthread_sigmask(signal.SIG_SETMASK, old_mask)
        signal.signal(signal.SIGTERM, old_term)
        os.close(extra)
    want = re.compile(r'^env_count=0 cwd=/private/tmp/[^ ]+ fds=0:fifo\+ro,1:fifo\+wo,2:fifo\+wo, blocked= '
                      r'nondefault= rlimit_core=0\n$')
    C.row('test_ac3', 'AC-3', 'AC3-a launch state (probe)', 'N09,N11,N14,N15,N21', 'naive_spawn', naive_out.strip(),
          bool(re.search(r'nonblock|blocked=\d|nondefault=\d|env_count=[1-9]', naive_out)), launch_out.strip(),
          lambda o: bool(want.match(o + '\n')),
          'probe = a private copy run by spawn_and_collect (the same primitive decide() uses)')

    # AC3-b..e: the four C-path misreports reproduced on the naive side (exit 0, no frame / prefix / signal).
    def dir0():
        fd = os.open('/', os.O_RDONLY)
        os.dup2(fd, 0)

    def ro1():
        fd = os.open('/dev/null', os.O_RDONLY)
        os.dup2(fd, 1)
    for sub, pre, prem in (('AC3-b stdin is a directory (read error)', dir0, 'N09,N10'),
                           ('AC3-c stdout read-only (write error)', ro1, 'N11,N12')):
        p = subprocess.Popen([C.EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             env={}, preexec_fn=pre)
        out, err = p.communicate(L.wire(C.BASE), timeout=C.TIMEOUT)
        ld = L.decide(C.BASE, C.EXE)
        C.row('test_ac3', 'AC-3', sub, prem, 'naive_exit', '%s rc=%s out=%d err=%d' %
              ('COMPLETE' if p.returncode == 0 else 'FAILED', p.returncode, len(out), len(err)),
              p.returncode == 0 and out == b'', C.short(ld), same(hb),
              'launcher gives fds it created; the state cannot arise (AC3-a)')

    # AC3-d: non-blocking stdin holding half the request (EAGAIN on read).
    half = len(L.wire(C.BASE)) // 2
    r, w = os.pipe()
    os.write(w, L.wire(C.BASE)[:half])
    fcntl.fcntl(r, fcntl.F_SETFL, fcntl.fcntl(r, fcntl.F_GETFL) | os.O_NONBLOCK)
    p = subprocess.Popen([C.EXE], stdin=r, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env={})
    os.close(r)
    out, err = p.communicate(timeout=C.TIMEOUT)
    os.close(w)
    ld = L.decide(C.BASE, C.EXE, feed_chunk=1, feed_delay_s=0.003)     # short reads under the launcher
    C.row('test_ac3', 'AC-3', 'AC3-d nonblock stdin (EAGAIN) / 1-byte feed', 'N09,N10', 'naive_exit',
          '%s rc=%s out=%d' % ('COMPLETE' if p.returncode == 0 else 'FAILED', p.returncode, len(out)),
          p.returncode == 0 and out == b'', C.short(ld), same(hb),
          'launcher row: request fed 1 byte at a time, 3 ms apart: every read is short')

    # AC3-e/f: stdout reader closed; SIGPIPE ignored (inherited SIG_IGN) vs default.
    for sub, ign in (('AC3-e EPIPE with SIGPIPE ignored', True), ('AC3-f EPIPE with SIGPIPE default', False)):
        r, w = os.pipe()
        os.close(r)
        p = subprocess.Popen([C.EXE], stdin=subprocess.PIPE, stdout=w, stderr=subprocess.PIPE, env={},
                             restore_signals=not ign)
        os.close(w)
        _, err = p.communicate(L.wire(C.BASE), timeout=C.TIMEOUT)
        C.row('test_ac3', 'AC-3', sub, 'N11,N14', 'naive_exit', '%s rc=%s' %
              ('COMPLETE' if p.returncode == 0 else 'FAILED', p.returncode), p.returncode == 0,
              'n/a (launcher drains to EOF; reader never closed early; SIGPIPE SIG_DFL per AC3-a)',
              lambda o: True, expect_attack=ign)

    # AC3-g EINTR: default-ignored signals sent while the child is blocked in read(0), under the launcher.
    sent = []

    def poke(pid):
        time.sleep(0.05)
        for s in (signal.SIGWINCH, signal.SIGURG, signal.SIGCHLD, signal.SIGINFO, signal.SIGIO, signal.SIGCONT):
            os.kill(pid, s)
            sent.append(int(s))
            time.sleep(0.01)
        os.kill(pid, signal.SIGSTOP)
        time.sleep(0.05)
        os.kill(pid, signal.SIGCONT)
        sent.extend([int(signal.SIGSTOP), int(signal.SIGCONT)])
    ld = L.decide(C.BASE, C.EXE, on_blocked=poke)
    C.row('test_ac3', 'AC-3', 'AC3-g signals while blocked in read', 'N14,N10', 'none', 'signals %s' % sent, None,
          C.short(ld), same(hb), 'no handler installed in the child, so no EINTR; one run', expect_attack=None)

    # AC3-h big request: output 4044 bytes in 2048-byte chunks over a pipe (PIPE_BUF 512): partial writes.
    ld = L.decide(C.BIG, C.EXE)
    C.row('test_ac3', 'AC-3', 'AC3-h big output, partial writes', 'N11,N12,N22', 'none', '-', None, C.short(ld),
          same(hbig), expect_attack=None)

    # AC3-i an abort in the C (shape of a bad configuration length): refused by D2. Test executable pinned.
    fa = os.path.join(C.BIN, 'fake_abort')
    res = C.raw_run([fa], L.wire(C.BASE), env={})
    ld = L.decide(C.BASE, fa, pinned_sha256=C.sha_of(fa), pinned_cdhash=C.cdhash_of(fa))
    C.row('test_ac3', 'AC-3', 'AC3-i C abort (SIGABRT)', 'N07,N10/N12 (R6 model gap)', 'naive_exit',
          '%s sig=%s' % (C.naive_exit(res), res.signal), False, C.short(ld) + ' ' + ld[1][:2],
          lambda o: o == 'REFUSED D2', 'safe direction already for naive_exit; recorded', expect_attack=False)
    return C.finish('test_ac3')


if __name__ == '__main__':
    sys.exit(main())
