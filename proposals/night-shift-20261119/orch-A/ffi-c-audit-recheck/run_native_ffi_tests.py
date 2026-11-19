"""A9 native FFI divergence tests. FINITE TEST, not a proof.
Runs the copied refund executable (SHA-256 b8ed5ec2...7bb8) under unusual fd and signal set-ups.
Writes native_ffi_results.json in the current directory. Run from the evidence directory.
"""
import fcntl
import hashlib
import json
import os
import signal
import subprocess
import sys
import time

sys.path.insert(0, '/Users/USER/forge/proposals/m1b-mission-20261119/drafts/fail-closed')
import frame  # noqa: E402

EXE = './refund'
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C', 'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}
assert hashlib.sha256(open(EXE, 'rb').read()).hexdigest() == \
    'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'

SMALL = frame.render_request(b'c', b'r', 100, 60, True, True, True, 40, b'returned_item')
BIG = frame.render_request(b'y' * 2000, b'z' * 2000, 100, 60, True, True, True, 40, b'returned_item')
SMALL_OUT = frame.render_fields(True, 40, b'returned_item', b'c', b'r', 1)
BIG_OUT = frame.render_fields(True, 40, b'returned_item', b'y' * 2000, b'z' * 2000, 1)
RUNS = [0]
RES = []


def desc(b):
    return {'len': len(b), 'sha256': hashlib.sha256(b).hexdigest(),
            'head': b[:80].decode('latin-1'), 'strict_full_frame': frame.strict_accepts(b) is not None,
            'is_strict_prefix_of_small': len(b) < len(SMALL_OUT) and SMALL_OUT.startswith(b),
            'is_strict_prefix_of_big': len(b) < len(BIG_OUT) and BIG_OUT.startswith(b),
            'equals_small': b == SMALL_OUT, 'equals_big': b == BIG_OUT}


def record(name, how, model, rc, out, err, extra=None):
    RUNS[0] += 1
    r = {'test': name, 'how': how, 'model_prediction': model, 'returncode': rc,
         'signal': (-rc if rc is not None and rc < 0 else None), 'stdout': desc(out), 'stderr': desc(err),
         'stderr_text': err[:300].decode('latin-1')}
    if extra:
        r.update(extra)
    RES.append(r)
    print(name, 'rc=%s' % rc, 'out=%d' % len(out), 'err=%r' % err[:120])


def plain(name, how, model, data, args=(), env=ENV, **kw):
    p = subprocess.run([EXE] + list(args), input=data, capture_output=True, env=env, timeout=60, **kw)
    record(name, how, model, p.returncode, p.stdout, p.stderr)


def with_fds(name, how, model, data, setup):
    """setup() runs in the child before exec (preexec_fn) to change fds 0/1."""
    p = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         env=ENV, preexec_fn=setup)
    out, err = p.communicate(data, timeout=60)
    record(name, how, model, p.returncode, out, err)


def main():
    plain('T00-baseline-small', 'valid request, pipes', 'Success; stdout = SMALL_OUT', SMALL)
    plain('T01-baseline-big', 'valid request with 2000-byte ids (output > 2048 bytes, 2+ write chunks)',
          'Success; stdout = BIG_OUT', BIG)
    plain('T02-odd-argv', 'argv: --repl, empty, 100000 x, 0xff byte',
          'argv not modelled for this program (no clFFI name); stdout = SMALL_OUT',
          SMALL, args=['--repl', '', 'x' * 100000, os.fsdecode(b'\xff')])

    def close0():
        os.close(0)
    with_fds('T03-stdin-closed', 'fd 0 closed before exec',
             'outside model (STD_streams assumes fd 0); C read -> -1 EBADF -> InvalidFD raised', SMALL, close0)

    def close1():
        os.close(1)
    with_fds('T04-stdout-closed', 'fd 1 closed before exec (stdout bytes not observable)',
             'outside model; C write -> -1 EBADF -> InvalidFD raised', SMALL, close1)

    def ro1():
        fd = os.open('/dev/null', os.O_RDONLY)
        os.dup2(fd, 1)
    with_fds('T05-stdout-readonly', 'fd 1 = /dev/null O_RDONLY',
             'outside model; C write -> -1 EBADF -> InvalidFD raised', SMALL, ro1)

    def dir0():
        fd = os.open('.', os.O_RDONLY)
        os.dup2(fd, 0)
    with_fds('T06-stdin-directory', 'fd 0 = a directory',
             'outside model; C read -> -1 EISDIR -> InvalidFD raised', SMALL, dir0)

    # T07/T08: stdout pipe with its reader closed
    for name, ign in (('T07-epipe-sigpipe-default', False), ('T08-epipe-sigpipe-ignored', True)):
        r, w = os.pipe()
        os.close(r)

        def pre(ign=ign):
            if ign:
                signal.signal(signal.SIGPIPE, signal.SIG_IGN)
        p = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=w, stderr=subprocess.PIPE, env=ENV,
                             preexec_fn=pre)
        os.close(w)
        out, err = p.communicate(SMALL, timeout=60)
        record(name, 'stdout = pipe whose reader is closed; SIGPIPE %s' % ('SIG_IGN' if ign else 'SIG_DFL'),
               'model write on fd 1 never fails (liveFS); real: %s' % (
                   'EPIPE -> InvalidFD raised' if ign else 'killed by SIGPIPE'), p.returncode, b'', err)

    # T09/T10: non-blocking stdout pipe that is full or nearly full
    for name, data, free in (('T09-nonblock-full-small', SMALL, 0), ('T10-nonblock-partial-big', BIG, 1000)):
        r, w = os.pipe()
        fl = fcntl.fcntl(w, fcntl.F_GETFL)
        fcntl.fcntl(w, fcntl.F_SETFL, fl | os.O_NONBLOCK)
        filled = 0
        while True:
            try:
                filled += os.write(w, b'F')
            except BlockingIOError:
                break
        freed = len(os.read(r, free)) if free else 0
        p = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=w, stderr=subprocess.PIPE, env=ENV)
        os.close(w)
        _, err = p.communicate(data, timeout=60)
        fl = fcntl.fcntl(r, fcntl.F_GETFL)
        allb = b''
        while True:
            c = os.read(r, 65536)
            if not c:
                break
            allb += c
        os.close(r)
        filler = filled - freed
        assert allb[:filler] == b'F' * filler
        out = allb[filler:]
        record(name, 'stdout = O_NONBLOCK pipe pre-filled with %d bytes, %d freed' % (filled, freed),
               'model write on fd 1 never fails; real: EAGAIN possible -> InvalidFD raised',
               p.returncode, out, err, {'pipe_filled': filled, 'pipe_freed': freed})

    # T11: slow writer, two chunks
    p = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=ENV)
    half = len(SMALL) // 2
    p.stdin.write(SMALL[:half]); p.stdin.flush(); time.sleep(0.3)
    p.stdin.write(SMALL[half:]); p.stdin.close()
    out, err = p.stdout.read(), p.stderr.read(); p.wait()
    record('T11-slow-writer', 'stdin pipe written in two chunks 0.3 s apart',
           'partial reads allowed (numchars); Success; stdout = SMALL_OUT', p.returncode, out, err)

    # T16: non-blocking stdin with only half the request available
    r, w = os.pipe()
    os.write(w, SMALL[:half])
    fl = fcntl.fcntl(r, fcntl.F_GETFL)
    fcntl.fcntl(r, fcntl.F_SETFL, fl | os.O_NONBLOCK)
    p = subprocess.Popen([EXE], stdin=r, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=ENV)
    os.close(r)
    out, err = p.communicate(timeout=60)
    os.close(w)
    record('T16-nonblock-stdin-half', 'stdin = O_NONBLOCK pipe holding the first half; writer still open',
           'model read waits for content (no EAGAIN); real: read -> -1 EAGAIN -> InvalidFD raised',
           p.returncode, out, err)

    # T12: tiny heap with the big request
    env = dict(ENV, CML_HEAP_SIZE='1', CML_STACK_SIZE='1')
    plain('T12-tiny-heap-big', 'CML_HEAP_SIZE=1 CML_STACK_SIZE=1, big request',
          'model: Resource_limit_hit allowed with an output prefix; real exit via cml_exit(x0)', BIG, env=env)

    # T13: dynamic loader injection (environment boundary, not an FFI function)
    if os.path.exists('./forged.dylib'):
        env = dict(ENV, DYLD_INSERT_LIBRARIES='./forged.dylib')
        plain('T13-dyld-insert', 'DYLD_INSERT_LIBRARIES=./forged.dylib (constructor writes a frame, _exit(0))',
              'no model counterpart: the stored theorems start at the installed state after _main', SMALL,
              env=env)

    with open('native_ffi_results.json', 'w') as f:
        json.dump({'class': 'TESTED-UNPROVED (finite test)', 'executable_sha256':
                   'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8',
                   'runs': RUNS[0], 'results': RES}, f, indent=1)
    return 0


if __name__ == '__main__':
    sys.exit(main())
