"""launcher.py: PROTOTYPE launch-path control for the M1 refund executable (worker W-launch, 2026-11-19).

Class: UNVERIFIED PYTHON, TESTED-UNPROVED. It is a prototype, not a proof. Standard library only.
It imports nothing from the repository. Two parts are COPIED (semantics unchanged, comments shortened):
  * the frame printer and the strict parser from
    proposals/m1b-mission-20261119/drafts/fail-closed/frame.py (render_*, make_str_safe, strict_parse);
  * the decision steps D0..D12 from drafts/fail-closed/m1_fail_closed.py (decide_from_result).
New here: the launch path (L1..L12 below) and the process-image check (L7).

Run with:  /usr/bin/python3 -B -I launcher.py --exe ABSOLUTE_PATH --request-json FILE
Output:    one line  "M1-LAUNCHER-DECISION <json>\n"  on stdout, written in full (non-blocking safe).
Exit code: 0 AUTHORIZED, 3 NOT_AUTHORIZED, 4 REFUSED. A consumer MUST require the full line AND the code.

LAUNCH STEPS (first failing step gives REFUSED):
 L0  The launcher's own process: Python runs isolated (-I) and its environment has no DYLD_* variable.
     (If a DYLD library was ALREADY injected into Python, this check cannot help: the launcher process and the
     interpreter are TRUSTED. See CONTROL_MATRIX.md rows AC2-L*.)
 L1  The executable path is absolute. The last path component is not a symlink (O_NOFOLLOW).
 L2  The opened file is a regular file of at most 16 MiB; its bytes are read ONCE into memory and their
     SHA-256 equals the pinned digest.
 L3  Those SAME in-memory bytes are written to a NEW file (O_CREAT|O_EXCL|O_NOFOLLOW, mode 0500) in a NEW
     directory (mkdtemp, mode 0700) under the fixed base /private/tmp (sticky, root-owned; TMPDIR is ignored).
 L4  The child gets: argv = [copy path]; an EMPTY environment; cwd = the private directory; fresh BLOCKING
     pipes on fds 0, 1, 2 (stderr is a separate pipe); every other descriptor closed (close_fds);
     a new session (no controlling terminal: no terminal signals); in the child before exec: every signal
     disposition SIG_DFL, signal mask empty, RLIMIT_CORE 0.
 L5  (time-of-check/time-of-use) macOS has no fexecve. The path of the private copy is exec'd. To bind the
     exec'd image to the checked bytes, L7 asks the KERNEL for the code-directory hash of the RUNNING process.
 L6  The request is not written before L7 passes. The child blocks in read(0) meanwhile.
 L7  csops(pid, CS_OPS_STATUS) has CS_VALID, and csops(pid, CS_OPS_CDHASH) equals the pinned CDHash (the
     20-byte code-directory hash of the pinned file; recorded from `codesign -dv`). Else: kill, REFUSED.
 L8  The request bytes are written in full, then stdin is closed.
 L9  stdout and stderr are read to EOF (all bytes drained; at most bound+1 kept). Time limit: kill the session.
 L10 The process is reaped; exit code or signal is recorded.
 L11 The private copy is hashed again (detects a later change of the copy; weak) and removed.
 L12 decide_from_result (D0..D12): accept ONLY exit 0, empty stderr, stdout exactly ONE strict frame with
     nothing after it, echoing the sent charge id, request id, amount and reason (or the exact rejection frame).
"""
import ctypes
import hashlib
import json
import os
import re
import resource
import selectors
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
from collections import namedtuple

PINNED_SHA256 = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
PINNED_CDHASH = '7c0eef4687359f32f0f393e9063a96024fd4229d'   # codesign -dv: CDHash= (static/codesign_orig.log)
TIME_LIMIT_S = 5.0
MAX_EXE_BYTES = 16 * 1024 * 1024
PRIVATE_BASE = '/private/tmp'
FIELDS = ('charge', 'request', 'original', 'remaining', 'enabled', 'opened', 'candidate', 'amount', 'reason')

# ============================================================================ COPY of frame.py (printer, strict parser)
TAG = b'refund-result-v1'
REJECTED_BYTES = b'(refund-result-v1 False 0 "" "" "" 0)'
MAX_MONEY = 9223372036854775807
APPROVED_REASONS = [b'duplicate_charge', b'service_not_delivered', b'returned_item']


class Err(Exception):
    pass


def is_space(b):
    return b == 32 or 9 <= b <= 13


def is_safe_char(b):
    return b not in b'()"\x00' and not is_space(b)


ESCAPES = {9: b'\\t', 10: b'\\n', 92: b'\\\\', 34: b'\\"'}


def make_str_safe(s):
    if s == b'':
        return b'""'
    if all(is_safe_char(b) for b in s):
        return s
    return b'"' + b''.join(ESCAPES.get(b, bytes([b])) for b in s) + b'"'


def int_to_string(i):
    return (b'~' if i < 0 else b'') + str(abs(i)).encode()


def bool_atom(v):
    return b'True' if v else b'False'


def render_fields(ok, amount, reason, charge, request, count):
    atoms = [TAG, bool_atom(ok), int_to_string(amount), make_str_safe(reason),
             make_str_safe(charge), make_str_safe(request), int_to_string(count)]
    return b'(' + b' '.join(atoms) + b')'


def render_request(charge, request, original, remaining, enabled, opened, candidate, amount, reason):
    atoms = [make_str_safe(charge), make_str_safe(request), int_to_string(original), int_to_string(remaining),
             bool_atom(enabled), bool_atom(opened), bool_atom(candidate), int_to_string(amount),
             make_str_safe(reason)]
    return b'(' + b' '.join(atoms) + b')'


CANON_INT = re.compile(rb'(0|[1-9][0-9]*)\Z')


def _strict_atom(s, i):
    if i < len(s) and s[i] == 34:
        j, val = i + 1, bytearray()
        while True:
            if j >= len(s):
                raise Err('strict: unterminated quoted atom')
            c = s[j]
            if c == 34:
                j += 1
                break
            if c == 92:
                if j + 1 >= len(s) or s[j + 1] not in b'\\"tn':
                    raise Err('strict: escape not emitted by the printer')
                val.append({92: 92, 34: 34, 116: 9, 110: 10}[s[j + 1]])
                j += 2
                continue
            if c in (9, 10):
                raise Err('strict: raw tab or newline in quoted atom')
            val.append(c)
            j += 1
        val = bytes(val)
    else:
        j = i
        while j < len(s) and is_safe_char(s[j]):
            j += 1
        if j == i:
            raise Err('strict: empty bare atom')
        val = s[i:j]
    if make_str_safe(val) != s[i:j]:
        raise Err('strict: atom spelling is not canonical')
    return val, j


def strict_parse(s):
    if not isinstance(s, (bytes, bytearray)):
        raise Err('strict: not bytes')
    s = bytes(s)
    if s[:1] != b'(':
        raise Err('strict: no opening parenthesis')
    i, vals = 1, []
    for k in range(7):
        v, i = _strict_atom(s, i)
        vals.append(v)
        sep = b' ' if k < 6 else b')'
        if s[i:i + 1] != sep:
            raise Err('strict: separator %r missing after field %d' % (sep, k + 1))
        i += 1
    if i != len(s):
        raise Err('strict: bytes after the frame')
    tag, okb, amb, reason, charge, request, cnb = vals
    if tag != TAG:
        raise Err('strict: wrong tag')
    if okb not in (b'True', b'False'):
        raise Err('strict: not a boolean')
    for x in (amb, cnb):
        if not CANON_INT.match(x):
            raise Err('strict: integer not canonical')
    out = (okb == b'True', int(amb), reason, charge, request, int(cnb))
    if render_fields(*out) != s:
        raise Err('strict: re-render differs')
    return out


# ============================================================================ COPY of m1_fail_closed.py (D0..D12)
ProcessResult = namedtuple('ProcessResult', 'exit_code signal timed_out stdout stderr overflow')


def check_request(fields):
    if set(fields) != set(FIELDS):
        raise ValueError('request fields are not exactly the nine fields')
    for k in ('charge', 'request', 'reason'):
        if not isinstance(fields[k], bytes):
            raise TypeError(k + ' is not bytes')
    for k in ('original', 'remaining', 'amount'):
        if type(fields[k]) is not int:
            raise TypeError(k + ' is not int')
    for k in ('enabled', 'opened', 'candidate'):
        if type(fields[k]) is not bool:
            raise TypeError(k + ' is not bool')


def wire(fields):
    return render_request(*(fields[k] for k in FIELDS))


def expected_accept(fields):
    return render_fields(True, fields['amount'], fields['reason'], fields['charge'], fields['request'], 1)


def output_bound(fields):
    return max(len(expected_accept(fields)), len(REJECTED_BYTES))


def decide_from_result(fields, result):
    try:
        check_request(fields)                                                         # D0
        if not isinstance(result, ProcessResult):
            return ('REFUSED', 'D0 no process result')
        if result.timed_out:
            return ('REFUSED', 'D1 time limit reached')
        if result.signal is not None:
            return ('REFUSED', 'D2 process ended by signal %d' % result.signal)
        if result.exit_code != 0:
            return ('REFUSED', 'D3 exit code %r is not 0' % (result.exit_code,))
        if result.stderr != b'':
            return ('REFUSED', 'D4 stderr is not empty')
        if result.overflow or len(result.stdout) > output_bound(fields):
            return ('REFUSED', 'D5 stdout longer than the bound %d' % output_bound(fields))
        out = result.stdout
        if out == b'':
            return ('REFUSED', 'D6 stdout is empty (no decision)')
        try:
            ok, amount, reason, charge, request, count = strict_parse(out)              # D7
        except Err as e:
            return ('REFUSED', 'D7 stdout is not exactly one canonical frame: %s' % e)
        if not ok:
            if out == REJECTED_BYTES:                                                 # D8
                return ('NOT_AUTHORIZED', 'program rejected the request')
            return ('REFUSED', 'D8 False frame is not the exact rejection frame')
        if charge != fields['charge'] or request != fields['request']:               # D9
            return ('REFUSED', 'D9 echoed charge id or request id differs from the sent one')
        if amount != fields['amount'] or reason != fields['reason']:
            return ('REFUSED', 'D9 echoed amount or reason differs from the sent one')
        if not (0 <= amount <= MAX_MONEY) or reason not in APPROVED_REASONS:
            return ('REFUSED', 'D10 amount out of range or reason not approved')
        if count != 1:
            return ('REFUSED', 'D10 intent count is not 1')
        if out != expected_accept(fields):                                           # D11
            return ('REFUSED', 'D11 frame differs from the one expected frame')
        return ('AUTHORIZED', amount, reason)
    except Exception as e:                                                            # D12
        return ('REFUSED', 'D12 caller exception: %s: %s' % (type(e).__name__, e))


# ============================================================================ NEW: launch path
class LaunchRefused(Exception):
    pass


_CS_OPS_STATUS = 0
_CS_OPS_CDHASH = 5
_CS_VALID = 0x00000001
_libc = ctypes.CDLL('/usr/lib/libSystem.B.dylib', use_errno=True)
_libc.csops.argtypes = [ctypes.c_int, ctypes.c_uint, ctypes.c_void_p, ctypes.c_size_t]
_libc.csops.restype = ctypes.c_int


def kernel_cdhash(pid):
    """(status flags, cdhash hex) of a RUNNING process, as the kernel recorded them at exec."""
    st = ctypes.c_uint32(0)
    if _libc.csops(pid, _CS_OPS_STATUS, ctypes.byref(st), 4) != 0:
        raise LaunchRefused('L7 csops status failed errno %d' % ctypes.get_errno())
    buf = (ctypes.c_ubyte * 20)()
    if _libc.csops(pid, _CS_OPS_CDHASH, buf, 20) != 0:
        raise LaunchRefused('L7 csops cdhash failed errno %d' % ctypes.get_errno())
    return st.value, bytes(buf).hex()


def check_own_process():
    """L0. Cannot detect code that already ran; refuses a visibly hostile launcher environment."""
    if not sys.flags.isolated:
        raise LaunchRefused('L0 Python is not in isolated mode (-I)')
    bad = sorted(k for k in os.environ if k.startswith('DYLD_'))
    if bad:
        raise LaunchRefused('L0 launcher environment has %s' % ','.join(bad))


def read_pinned_bytes(path, pinned_sha256):
    """L1, L2: one open, one read; the hash is over exactly the bytes later written to the copy."""
    if not isinstance(path, str) or not os.path.isabs(path):
        raise LaunchRefused('L1 executable path is not absolute')
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except OSError as e:
        raise LaunchRefused('L1 open failed (symlink or missing): %s' % e)
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or st.st_size > MAX_EXE_BYTES:
            raise LaunchRefused('L2 not a regular file of at most 16 MiB')
        chunks, n = [], 0
        while True:
            c = os.read(fd, 1 << 20)
            if not c:
                break
            n += len(c)
            if n > MAX_EXE_BYTES:
                raise LaunchRefused('L2 file grew beyond 16 MiB')
            chunks.append(c)
    finally:
        os.close(fd)
    data = b''.join(chunks)
    if hashlib.sha256(data).hexdigest() != pinned_sha256:
        raise LaunchRefused('L2 SHA-256 of the executable bytes is not the pinned one')
    return data


def _child_setup():
    """Runs in the child after fork, before exec (L4). Single-threaded launcher: preexec_fn is safe here."""
    for s in range(1, signal.NSIG):
        if s in (signal.SIGKILL, signal.SIGSTOP):
            continue
        try:
            signal.signal(s, signal.SIG_DFL)
        except (OSError, ValueError, RuntimeError):
            pass
    signal.pthread_sigmask(signal.SIG_SETMASK, set())
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def _write_all_to(fd, data, deadline):
    """Write data in full to a possibly non-blocking descriptor."""
    view = memoryview(data)
    sel = selectors.DefaultSelector()
    sel.register(fd, selectors.EVENT_WRITE)
    try:
        while view:
            left = deadline - time.monotonic()
            if left <= 0:
                raise TimeoutError('write time limit')
            if not sel.select(left):
                continue
            try:
                n = os.write(fd, view)
            except BlockingIOError:
                continue
            view = view[n:]
    finally:
        sel.close()


def spawn_and_collect(exe_copy, stdin_bytes, bound, pinned_cdhash, time_limit=TIME_LIMIT_S,
                      feed_chunk=0, feed_delay_s=0.0, on_blocked=None):
    """L4..L10. feed_chunk/feed_delay_s/on_blocked are TEST HOOKS ONLY (slow feeding; a callback with the pid
    while the child waits for input). The request bytes are the same either way."""
    p = subprocess.Popen([exe_copy], executable=exe_copy, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, env={}, cwd=os.path.dirname(exe_copy), close_fds=True,
                         restore_signals=True, start_new_session=True, preexec_fn=_child_setup)
    deadline = time.monotonic() + time_limit
    out, err, overflow, timed_out = bytearray(), bytearray(), False, False
    try:
        if pinned_cdhash is not None:                                                  # L7
            flags, cd = kernel_cdhash(p.pid)
            if not (flags & _CS_VALID) or cd != pinned_cdhash:
                raise LaunchRefused('L7 running image: flags 0x%x cdhash %s is not the pinned one' % (flags, cd))
        if on_blocked is not None:
            on_blocked(p.pid)
        sel = selectors.DefaultSelector()
        sel.register(p.stdout, selectors.EVENT_READ, out)
        sel.register(p.stderr, selectors.EVENT_READ, err)
        wfd = p.stdin.fileno()
        pending = memoryview(stdin_bytes)
        open_readers = 2
        next_feed = time.monotonic()
        while open_readers:                                                            # L8, L9
            now = time.monotonic()
            if now >= deadline:
                timed_out = True
                break
            if pending is not None and now >= next_feed:
                n = len(pending) if feed_chunk <= 0 else min(feed_chunk, len(pending))
                try:
                    os.write(wfd, pending[:n])      # blocking pipe; a small request fits the pipe buffer
                    pending = pending[n:]
                except BrokenPipeError:
                    pending = memoryview(b'')
                if not pending:
                    p.stdin.close()
                    pending = None
                else:
                    next_feed = now + feed_delay_s
            wait = deadline - now
            if pending is not None:
                wait = min(wait, max(0.0, next_feed - now))
            for key, _ in sel.select(wait):
                chunk = os.read(key.fileobj.fileno(), 65536)
                if not chunk:
                    sel.unregister(key.fileobj)
                    open_readers -= 1
                    continue
                buf = key.data
                room = bound + 1 - len(buf)
                if len(chunk) > room:
                    overflow = True
                buf += chunk[:max(room, 0)]
        sel.close()
    except BaseException:
        _kill(p)
        raise
    if timed_out:
        _kill(p)
    else:
        try:
            p.wait(timeout=max(0.1, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            timed_out = True
            _kill(p)
    for f in (p.stdin, p.stdout, p.stderr):
        try:
            if f and not f.closed:
                f.close()
        except OSError:
            pass
    rc = p.returncode
    return ProcessResult(exit_code=None if (rc is None or rc < 0) else rc,
                         signal=-rc if (rc is not None and rc < 0) else None,
                         timed_out=timed_out, stdout=bytes(out), stderr=bytes(err), overflow=overflow)


def _kill(p):
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except OSError:
        pass
    try:
        p.kill()
    except OSError:
        pass
    p.wait()


def decide(fields, exe_path, pinned_sha256=PINNED_SHA256, pinned_cdhash=PINNED_CDHASH, check_self=True, **hooks):
    """Full launch path. Returns ('AUTHORIZED', amount, reason) | ('NOT_AUTHORIZED', why) | ('REFUSED', why).
    pinned_* parameters exist so that TESTS can pin a test executable; production uses the defaults."""
    work = None
    try:
        if check_self:
            check_own_process()                                                        # L0
        check_request(fields)
        data = read_pinned_bytes(exe_path, pinned_sha256)                              # L1, L2
        work = tempfile.mkdtemp(prefix='m1launch-', dir=PRIVATE_BASE)                  # L3
        os.chmod(work, 0o700)
        copy = os.path.join(work, 'refund')
        fd = os.open(copy, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC, 0o700)
        try:
            _write_all_to(fd, data, time.monotonic() + TIME_LIMIT_S)
            os.fsync(fd)
            os.fchmod(fd, 0o500)
        finally:
            os.close(fd)
        result = spawn_and_collect(copy, wire(fields), output_bound(fields), pinned_cdhash, **hooks)
        with open(copy, 'rb') as f:                                                    # L11
            if hashlib.sha256(f.read()).hexdigest() != pinned_sha256:
                return ('REFUSED', 'L11 the private copy changed during the run')
        return decide_from_result(fields, result)                                      # L12
    except LaunchRefused as e:
        return ('REFUSED', str(e))
    except Exception as e:
        return ('REFUSED', 'D12 launcher exception: %s: %s' % (type(e).__name__, e))
    finally:
        if work is not None:
            shutil.rmtree(work, ignore_errors=True)


# ============================================================================ CLI
def _fields_from_json(path):
    with open(path, 'rb') as f:
        j = json.loads(f.read().decode('utf-8'))
    out = {}
    for k in ('charge', 'request', 'reason'):
        out[k] = j[k].encode('latin-1') if isinstance(j[k], str) else j[k]
    for k in ('original', 'remaining', 'amount', 'enabled', 'opened', 'candidate'):
        out[k] = j[k]
    return out


def _std_fds_or_exit():
    """CLI only: a caller may start the launcher with fd 0, 1 or 2 closed. Then a later pipe could land on
    0..2 and the decision line could go into the wrong pipe. Fill closed 0 and 2 with /dev/null. If fd 1 is
    closed the decision cannot be reported: occupy it with /dev/null and exit 4 (REFUSED)."""
    closed = []
    for fd in (0, 1, 2):
        try:
            os.fstat(fd)
        except OSError:
            closed.append(fd)
    for fd in closed:
        n = os.open('/dev/null', os.O_RDWR)
        if n != fd:
            os.dup2(n, fd)
            os.close(n)
    if 1 in closed:
        sys.exit(4)


def main(argv):
    _std_fds_or_exit()
    exe, req = None, None
    try:
        i = 1
        while i < len(argv):
            if argv[i] == '--exe':
                exe = argv[i + 1]
            elif argv[i] == '--request-json':
                req = argv[i + 1]
            else:
                raise ValueError('unknown argument %r' % argv[i])
            i += 2
        d = decide(_fields_from_json(req), exe)
    except Exception as e:
        d = ('REFUSED', 'CLI %s: %s' % (type(e).__name__, e))
    if d[0] == 'AUTHORIZED':
        rec = {'decision': 'AUTHORIZED', 'amount': d[1], 'reason': d[2].decode('latin-1')}
    else:
        rec = {'decision': d[0], 'why': d[1]}
    line = b'M1-LAUNCHER-DECISION ' + json.dumps(rec, sort_keys=True).encode() + b'\n'
    try:
        _write_all_to(1, line, time.monotonic() + 30)
    except Exception:
        return 4
    return {'AUTHORIZED': 0, 'NOT_AUTHORIZED': 3}.get(d[0], 4)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
