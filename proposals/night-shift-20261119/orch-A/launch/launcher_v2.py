"""launcher_v2.py: PROTOTYPE launch-path control for the M1 refund executable, round 2 (worker W-launch).

Class: UNVERIFIED PYTHON, TESTED-UNPROVED. Not a proof. Standard library only; imports nothing from the repository.
launcher.py (v1) is kept UNCHANGED as the failing side of the round-2 tests.
COPIED, semantics unchanged: printer + strict parser (from drafts/fail-closed/frame.py, via launcher.py lines
62-177) and decision steps D0..D12 (from drafts/fail-closed/m1_fail_closed.py, via launcher.py lines 179-248).

Invocation the CONSUMER must use (no code can enforce it; see CONTROL_MATRIX_v2.md, consumer duties):
    /usr/bin/env -i /usr/bin/python3 -B -I -S /ABS/launcher_v2.py --exe /ABS/refund --request-json FILE
Output: one line "M1-LAUNCHER-DECISION <json>\\n" (with request_sha256 = SHA-256 of the request bytes sent).
Exit code: 0 AUTHORIZED, 3 NOT_AUTHORIZED, 4 REFUSED. A consumer requires the full line AND the matching code.

Changes against v1 (review_launcher.txt F-xx, FINDINGS_FROM_C.md Fx):
 V0  (F-01) At the start of decide(): the launcher resets ITS OWN signal state: SIGCHLD SIG_DFL and the
     SA_NOCLDWAIT flag checked clear (read back with sigaction); every other catchable signal SIG_DFL except
     SIGPIPE (SIG_IGN: EPIPE becomes an error) and SIGTERM/SIGHUP/SIGINT/SIGQUIT/SIGXCPU (handler: clean up,
     REFUSED); signal mask emptied.
 V1  (F-03) At the start of decide(): the launcher sets its own TASK exception ports to MACH_PORT_NULL for
     EXC_MASK_ALL|EXC_MASK_CRASH|EXC_MASK_CORPSE_NOTIFY (task_set_exception_ports). A child inherits the null
     ports at fork. kern_return != 0 -> REFUSED. Thread-level and host-level ports are not touched.
 V2  (F-01) The launcher reaps the child ITSELF with os.wait4(pid). ECHILD or a status that is neither a normal
     exit nor a signal -> REFUSED ("child status unknown"). Popen.wait/poll is never used.
 V3  (F-02) open of --exe uses O_NONBLOCK (a FIFO cannot block it); fstat S_ISREG before any read.
 V4  (F-02, F-07) Request size bound MAX_REQUEST_BYTES; the request is written through a NON-BLOCKING pipe end
     under the same deadline as the reads; every partial write is counted; EPIPE or a short total -> REFUSED.
 V5  (F-08) pinned_cdhash None or pinned_sha256 None -> REFUSED (no silent skip of L2/L7).
 V6  (F-03, T-1) Fixed child rlimits: CORE 0, STACK 8 MiB, FSIZE 0, CPU 10 s, NOFILE 64. A caller hard limit
     below these makes setrlimit fail -> exec fails -> REFUSED.
 V7  (F-13) On every exit path of decide(), including SIGTERM/SIGHUP/SIGINT/SIGQUIT/SIGXCPU to the launcher:
     kill the child's process group, reap it, remove the private copy. SIGKILL to the launcher cannot be caught:
     the private directory /private/tmp/m1launch-* stays; the child then sees EOF on stdin (or EPIPE on stdout).
 V8  (F-12) Echo: the frame carries 4 of the 9 request fields (charge, request, amount, reason); D9/D11 bind
     those 4. original, remaining, enabled, opened, candidate are NOT in the frame: bound only by N20 (the
     launcher wrote them; request_sha256 in the decision line records which bytes were sent).
"""
import ctypes
import errno
import fcntl
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
PINNED_CDHASH = '7c0eef4687359f32f0f393e9063a96024fd4229d'
TIME_LIMIT_S = 5.0
MAX_EXE_BYTES = 16 * 1024 * 1024
MAX_REQUEST_BYTES = 1024 * 1024
PRIVATE_BASE = '/private/tmp'
FIELDS = ('charge', 'request', 'original', 'remaining', 'enabled', 'opened', 'candidate', 'amount', 'reason')
CHILD_RLIMITS = ((resource.RLIMIT_CORE, 0), (resource.RLIMIT_STACK, 8 * 1024 * 1024), (resource.RLIMIT_FSIZE, 0),
                 (resource.RLIMIT_CPU, 10), (resource.RLIMIT_NOFILE, 64))

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


# ============================================================================ launch path (v2)
class LaunchRefused(Exception):
    pass


class LauncherTerminated(BaseException):
    """Raised by the launcher's own handler for SIGTERM/SIGHUP/SIGINT/SIGQUIT/SIGXCPU (V0, V7)."""


_CS_OPS_STATUS = 0
_CS_OPS_CDHASH = 5
_CS_VALID = 0x00000001
_SA_NOCLDWAIT = 0x0020
_EXC_MASKS = 0x1BFE | (1 << 10) | (1 << 13)        # EXC_MASK_ALL (0x1bfe, probe2) | EXC_MASK_CRASH | CORPSE_NOTIFY
_EXCEPTION_DEFAULT = 1
_THREAD_STATE_NONE = 5                              # arm THREAD_STATE_NONE (mach/arm/thread_status.h:58)
_libc = ctypes.CDLL('/usr/lib/libSystem.B.dylib', use_errno=True)
_libc.csops.argtypes = [ctypes.c_int, ctypes.c_uint, ctypes.c_void_p, ctypes.c_size_t]
_libc.csops.restype = ctypes.c_int
_libc.task_set_exception_ports.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_int, ctypes.c_int]
_libc.task_set_exception_ports.restype = ctypes.c_int


class _SigAction(ctypes.Structure):                 # macOS user struct sigaction: handler, mask, flags
    _fields_ = [('handler', ctypes.c_void_p), ('mask', ctypes.c_uint32), ('flags', ctypes.c_int)]


_libc.sigaction.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]
_libc.sigaction.restype = ctypes.c_int
_HANDLED = (signal.SIGTERM, signal.SIGHUP, signal.SIGINT, signal.SIGQUIT, signal.SIGXCPU)


def _on_terminate(signum, frame):
    raise LauncherTerminated(signum)


def reset_own_state():
    """V0 + V1. Changes the state of the WHOLE launcher process (documented side effect)."""
    for s in range(1, signal.NSIG):
        if s in (signal.SIGKILL, signal.SIGSTOP):
            continue
        try:
            if s == signal.SIGPIPE:
                signal.signal(s, signal.SIG_IGN)
            elif s in _HANDLED:
                signal.signal(s, _on_terminate)
            else:
                signal.signal(s, signal.SIG_DFL)
        except (OSError, ValueError, RuntimeError):
            pass
    signal.pthread_sigmask(signal.SIG_SETMASK, set())
    sa = _SigAction()
    if _libc.sigaction(signal.SIGCHLD, None, ctypes.byref(sa)) != 0:
        raise LaunchRefused('V0 sigaction read failed')
    if sa.handler not in (None, 0) or (sa.flags & _SA_NOCLDWAIT):
        raise LaunchRefused('V0 SIGCHLD is not SIG_DFL without SA_NOCLDWAIT (handler %r flags 0x%x)' %
                            (sa.handler, sa.flags))
    task = ctypes.c_uint.in_dll(_libc, 'mach_task_self_').value
    kr = _libc.task_set_exception_ports(task, _EXC_MASKS, 0, _EXCEPTION_DEFAULT, _THREAD_STATE_NONE)
    if kr != 0:
        raise LaunchRefused('V1 task_set_exception_ports kern_return %d' % kr)


def kernel_cdhash(pid):
    st = ctypes.c_uint32(0)
    if _libc.csops(pid, _CS_OPS_STATUS, ctypes.byref(st), 4) != 0:
        raise LaunchRefused('L7 csops status failed errno %d' % ctypes.get_errno())
    buf = (ctypes.c_ubyte * 20)()
    if _libc.csops(pid, _CS_OPS_CDHASH, buf, 20) != 0:
        raise LaunchRefused('L7 csops cdhash failed errno %d' % ctypes.get_errno())
    return st.value, bytes(buf).hex()


def check_own_process():
    """L0 (kept; weak: the review F-10 shows it never fires in a real invocation)."""
    if not sys.flags.isolated:
        raise LaunchRefused('L0 Python is not in isolated mode (-I)')
    bad = sorted(k for k in os.environ if k.startswith('DYLD_'))
    if bad:
        raise LaunchRefused('L0 launcher environment has %s' % ','.join(bad))


def read_pinned_bytes(path, pinned_sha256):
    """L1, L2 with V3: O_NONBLOCK open; fstat S_ISREG before any read."""
    if not pinned_sha256:
        raise LaunchRefused('V5 no pinned SHA-256')
    if not isinstance(path, str) or not os.path.isabs(path):
        raise LaunchRefused('L1 executable path is not absolute')
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC)
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
    """In the child after fork, before exec: dispositions, mask, fixed rlimits (V6)."""
    for s in range(1, signal.NSIG):
        if s in (signal.SIGKILL, signal.SIGSTOP):
            continue
        try:
            signal.signal(s, signal.SIG_DFL)
        except (OSError, ValueError, RuntimeError):
            pass
    signal.pthread_sigmask(signal.SIG_SETMASK, set())
    for r, v in CHILD_RLIMITS:
        resource.setrlimit(r, (v, v))


def _write_all_to(fd, data, deadline):
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


def _decode_status(status):
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status), None
    if os.WIFSIGNALED(status):
        return None, os.WTERMSIG(status)
    raise LaunchRefused('V2 child status 0x%x is neither an exit nor a signal' % status)


class _Child:
    """Owns the child: kill + reap on every path (V7)."""

    def __init__(self, p):
        self.p, self.status = p, None

    def try_reap(self):
        if self.status is not None:
            return True
        try:
            pid, st = os.wait4(self.p.pid, os.WNOHANG)[:2]
        except ChildProcessError:
            raise LaunchRefused('V2 child status unknown (ECHILD)')
        if pid == 0:
            return False
        self.status = st
        return True

    def kill_and_reap(self):
        if self.status is None:
            for f in (lambda: os.killpg(self.p.pid, signal.SIGKILL), lambda: os.kill(self.p.pid, signal.SIGKILL)):
                try:
                    f()
                except OSError:
                    pass
            try:
                self.status = os.wait4(self.p.pid, 0)[1]
            except ChildProcessError:
                self.status = -1                         # unknown; never used for a decision
        self.p.returncode = -9999                         # keep Popen from reaping or inventing a status later
        for f in (self.p.stdin, self.p.stdout, self.p.stderr):
            try:
                if f and not f.closed:
                    f.close()
            except OSError:
                pass


def spawn_and_collect(exe_copy, stdin_bytes, bound, pinned_cdhash, time_limit=TIME_LIMIT_S,
                      feed_chunk=0, feed_delay_s=0.0, on_blocked=None):
    """L4..L10 with V2, V4, V5, V7. feed_chunk/feed_delay_s/on_blocked: TEST HOOKS ONLY."""
    if not pinned_cdhash:
        raise LaunchRefused('V5 no pinned CDHash')
    if len(stdin_bytes) > MAX_REQUEST_BYTES:
        raise LaunchRefused('V4 request longer than %d bytes' % MAX_REQUEST_BYTES)
    p = subprocess.Popen([exe_copy], executable=exe_copy, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, env={}, cwd=os.path.dirname(exe_copy), close_fds=True,
                         restore_signals=True, start_new_session=True, preexec_fn=_child_setup)
    child = _Child(p)
    deadline = time.monotonic() + time_limit
    out, err, overflow, timed_out = bytearray(), bytearray(), False, False
    try:
        flags, cd = kernel_cdhash(p.pid)                                              # L7
        if not (flags & _CS_VALID) or cd != pinned_cdhash:
            raise LaunchRefused('L7 running image: flags 0x%x cdhash %s is not the pinned one' % (flags, cd))
        if on_blocked is not None:
            on_blocked(p.pid)
        wfd = p.stdin.fileno()
        fcntl.fcntl(wfd, fcntl.F_SETFL, fcntl.fcntl(wfd, fcntl.F_GETFL) | os.O_NONBLOCK)   # parent's end only
        sel = selectors.DefaultSelector()
        sel.register(p.stdout, selectors.EVENT_READ, out)
        sel.register(p.stderr, selectors.EVENT_READ, err)
        sel.register(wfd, selectors.EVENT_WRITE, None)
        sent, total = 0, len(stdin_bytes)
        writing, open_readers, next_feed = True, 2, time.monotonic()
        while open_readers or writing:
            now = time.monotonic()
            if now >= deadline:
                timed_out = True
                break
            wait = deadline - now
            if writing and now < next_feed:
                wait = min(wait, next_feed - now)
            for key, ev in sel.select(wait):
                if key.data is None:                                                  # stdin writable
                    if time.monotonic() < next_feed:
                        continue
                    end = total if feed_chunk <= 0 else min(total, sent + feed_chunk)
                    try:
                        n = os.write(wfd, stdin_bytes[sent:end])
                    except BlockingIOError:
                        continue
                    except BrokenPipeError:
                        raise LaunchRefused('V4 EPIPE after %d of %d request bytes' % (sent, total))
                    sent += n
                    next_feed = time.monotonic() + (feed_delay_s if feed_chunk > 0 else 0.0)
                    if sent == total:
                        sel.unregister(wfd)
                        p.stdin.close()
                        writing = False
                    continue
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
        if not timed_out and sent != total:
            raise LaunchRefused('V4 request not fully written (%d of %d)' % (sent, total))
        while not timed_out and not child.try_reap():                                  # L10 with V2
            if time.monotonic() >= deadline:
                timed_out = True
                break
            time.sleep(0.002)
        if timed_out:
            child.kill_and_reap()
            return ProcessResult(None, None, True, bytes(out), bytes(err), overflow)
        code, sig = _decode_status(child.status)
        return ProcessResult(exit_code=code, signal=sig, timed_out=False, stdout=bytes(out), stderr=bytes(err),
                             overflow=overflow)
    finally:
        child.kill_and_reap()


def decide(fields, exe_path, pinned_sha256=PINNED_SHA256, pinned_cdhash=PINNED_CDHASH, check_self=True, **hooks):
    """('AUTHORIZED', amount, reason) | ('NOT_AUTHORIZED', why) | ('REFUSED', why). LauncherTerminated
    propagates (after clean-up) when the launcher itself receives a terminating signal."""
    work = None
    try:
        reset_own_state()                                                              # V0, V1
        if check_self:
            check_own_process()                                                        # L0
        check_request(fields)
        if not pinned_cdhash:
            raise LaunchRefused('V5 no pinned CDHash')
        data = read_pinned_bytes(exe_path, pinned_sha256)                              # L1, L2, V3
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
    except LauncherTerminated:
        raise
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
    exe, req, rsha = None, None, None
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
        fields = _fields_from_json(req)
        try:
            rsha = hashlib.sha256(wire(fields)).hexdigest()
        except Exception:
            rsha = None
        d = decide(fields, exe)
    except LauncherTerminated as t:
        d = ('REFUSED', 'V7 launcher received signal %s' % t.args[0])
    except Exception as e:
        d = ('REFUSED', 'CLI %s: %s' % (type(e).__name__, e))
    if d[0] == 'AUTHORIZED':
        rec = {'decision': 'AUTHORIZED', 'amount': d[1], 'reason': d[2].decode('latin-1')}
    else:
        rec = {'decision': d[0], 'why': d[1]}
    rec['request_sha256'] = rsha
    line = b'M1-LAUNCHER-DECISION ' + json.dumps(rec, sort_keys=True).encode() + b'\n'
    try:
        _write_all_to(1, line, time.monotonic() + 30)
    except BaseException:
        return 4
    return {'AUTHORIZED': 0, 'NOT_AUTHORIZED': 3}.get(d[0], 4)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
