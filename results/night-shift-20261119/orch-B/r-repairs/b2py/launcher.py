"""Hardened launcher for the M1 native refund executable (night shift 2026-11-19, task x-issuer-bridge).

Standard library only. NOT proved. Class of every guarantee below: TESTED-UNPROVED, and each one
rests on an operating-system ASSUMPTION named in BRIDGE_DESIGN.md section 5 (OS-*).

One call = one process = one request. Steps:
  1. The path must be absolute. The file is opened ONCE (O_RDONLY | O_NOFOLLOW), checked to be a
     regular file, read fully from that descriptor, and hashed. A digest that is not the pinned one
     refuses BEFORE any launch (no process exists).
  2. The hashed bytes (from memory, not from the path again) are written to a NEW file (O_EXCL) in a
     new private 0700 directory, mode 0500. macOS has no fexecve(2), so the copy is executed by path.
     TOCTOU that remains: a process with the same user id can replace the private copy between the
     write and the exec. The copy is hashed again after the run (detects a replacement that stays).
  3. The environment is built ONLY from ALLOWED_ENV (fixed values). Nothing is inherited. Any name
     that starts with DYLD_ or LD_ is refused even if a caller passes it.
  4. close_fds=True: only fds 0, 1, 2 reach the child. restore_signals=True: SIGPIPE is default.
     start_new_session=True: the child leads a new process group; the group is killed at the end.
  5. stdin: a pipe; the exact request bytes, then EOF. stdout and stderr: pipes whose CHILD ends are
     blocking (the parent sets only its own read ends to non-blocking). Read to EOF, with caps.
  6. A wall-clock timeout kills the whole process group (SIGKILL).
  7. cwd: a new empty private directory. No shell. argv = [copy path] only.
"""
import dataclasses
import hashlib
import hmac
import os
import selectors
import shutil
import signal
import stat
import subprocess
import tempfile
import time

# The executable reads these two names (CakeML runtime heap and stack in MiB). The values are the ones
# of every recorded run of b8ed5ec2... (named assumption A-ENV-HEAP). No other name is passed.
ALLOWED_ENV = {'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}
MAX_BINARY_BYTES = 64 * 1024 * 1024


@dataclasses.dataclass(frozen=True)
class LaunchResult:
    launched: bool               # False: refused before any process existed
    refusal: str                 # '' or the pre-launch refusal reason
    stdout: bytes                # at most stdout_cap bytes are kept
    exit_code: object            # int or None (None if killed by a signal or not launched)
    signal: object               # int or None
    timed_out: bool
    stderr_len: int              # bytes seen on stderr (counted up to stderr_cap + 1)
    stdout_overflow: bool        # more than stdout_cap bytes were written
    stdin_complete: bool         # every request byte was written before EOF
    copy_unchanged: bool         # the private copy still has the pinned digest after the run
    elapsed_s: float


def _refused(reason):
    return LaunchResult(False, reason, b'', None, None, False, 0, False, False, False, 0.0)


def _read_pinned(path, pinned_sha256):
    """Open once, hash the opened descriptor. Returns (bytes, '') or (None, reason)."""
    if not isinstance(path, str) or not os.path.isabs(path):
        return None, 'PATH_NOT_ABSOLUTE'
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except OSError:
        return None, 'BINARY_OPEN_FAILED'
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or st.st_size > MAX_BINARY_BYTES:
            return None, 'BINARY_NOT_REGULAR'
        chunks, total = [], 0
        while True:
            c = os.read(fd, 1 << 20)
            if not c:
                break
            total += len(c)
            if total > MAX_BINARY_BYTES:
                return None, 'BINARY_NOT_REGULAR'
            chunks.append(c)
    finally:
        os.close(fd)
    data = b''.join(chunks)
    if not hmac.compare_digest(hashlib.sha256(data).hexdigest(), pinned_sha256):
        return None, 'DIGEST_MISMATCH'
    return data, ''


def _check_env(env):
    for k, v in env.items():
        if not isinstance(k, str) or not isinstance(v, str):
            return False
        if k.startswith('DYLD_') or k.startswith('LD_') or k not in ALLOWED_ENV or ALLOWED_ENV[k] != v:
            return False
    return True


def launch(binary_path, pinned_sha256, stdin_bytes, stdout_cap, stderr_cap=4096, timeout_s=10.0,
           work_root=None, env=None):
    """Run the pinned executable once. Never raises for a process outcome; returns a LaunchResult."""
    env = dict(ALLOWED_ENV) if env is None else dict(env)
    if not _check_env(env):
        return _refused('ENV_NOT_ALLOWED')
    data, why = _read_pinned(binary_path, pinned_sha256)
    if data is None:
        return _refused(why)
    priv = tempfile.mkdtemp(prefix='bin-', dir=work_root)       # mode 0700
    cwd = tempfile.mkdtemp(prefix='cwd-', dir=work_root)        # mode 0700, stays empty
    copy = os.path.join(priv, 'refund')
    t0 = time.monotonic()
    try:
        fd = os.open(copy, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC, 0o500)
        try:
            view = memoryview(data)
            while view:
                view = view[os.write(fd, view):]
            os.fsync(fd)
        finally:
            os.close(fd)
        try:
            p = subprocess.Popen([copy], executable=copy, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                 stderr=subprocess.PIPE, env=env, cwd=cwd, close_fds=True, shell=False,
                                 start_new_session=True, restore_signals=True)
        except OSError:
            return _refused('LAUNCH_FAILED')
        out, err_len, out_over = bytearray(), 0, False
        stdin_complete, timed_out = False, False
        deadline = t0 + timeout_s
        sel = selectors.DefaultSelector()
        for f in (p.stdin, p.stdout, p.stderr):
            os.set_blocking(f.fileno(), False)                    # parent ends only
        pending = memoryview(stdin_bytes)
        if pending:
            sel.register(p.stdin, selectors.EVENT_WRITE)
        else:
            p.stdin.close(); stdin_complete = True
        sel.register(p.stdout, selectors.EVENT_READ)
        sel.register(p.stderr, selectors.EVENT_READ)
        while sel.get_map():
            left = deadline - time.monotonic()
            if left <= 0:
                timed_out = True
                break
            for key, _ in sel.select(min(left, 0.25)):
                f = key.fileobj
                if f is p.stdin:
                    try:
                        n = os.write(f.fileno(), pending[:65536])
                        pending = pending[n:]
                    except BlockingIOError:
                        continue
                    except (BrokenPipeError, OSError):
                        sel.unregister(f); f.close(); continue
                    if not pending:
                        sel.unregister(f); f.close(); stdin_complete = True
                    continue
                try:
                    chunk = os.read(f.fileno(), 65536)
                except BlockingIOError:
                    continue
                if not chunk:
                    sel.unregister(f); f.close(); continue
                if f is p.stdout:
                    room = stdout_cap + 1 - len(out)
                    out += chunk[:max(room, 0)]
                    if len(out) > stdout_cap:
                        out_over = True
                else:
                    err_len = min(err_len + len(chunk), stderr_cap + 1)
                if out_over or err_len > stderr_cap:
                    break
            if out_over or err_len > stderr_cap:
                break
        sel.close()
        if timed_out or out_over or err_len > stderr_cap:
            _killpg(p)
        left = max(deadline - time.monotonic(), 0.0)
        try:
            p.wait(timeout=left if not timed_out else 1.0)
        except subprocess.TimeoutExpired:
            timed_out = True
            _killpg(p)
            p.wait()
        _killpg(p)                                                # any leftover member of the group
        for f in (p.stdin, p.stdout, p.stderr):
            try:
                f.close()
            except Exception:
                pass
        rc = p.returncode
        sig = -rc if rc is not None and rc < 0 else None
        code = rc if rc is not None and rc >= 0 else None
        unchanged = _digest_of(copy) == pinned_sha256
        return LaunchResult(True, '', bytes(out[:stdout_cap]), code, sig, timed_out, err_len, out_over,
                            stdin_complete, unchanged, time.monotonic() - t0)
    finally:
        shutil.rmtree(priv, ignore_errors=True)
        shutil.rmtree(cwd, ignore_errors=True)


def _killpg(p):
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass


def _digest_of(path):
    try:
        with open(path, 'rb') as f:
            return hashlib.sha256(f.read()).hexdigest()
    except OSError:
        return ''
