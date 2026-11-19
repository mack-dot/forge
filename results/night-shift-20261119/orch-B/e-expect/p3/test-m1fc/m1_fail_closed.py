"""Reference fail-closed caller for the PRESENT M1 refund executable. NOT proved. Standard library only.

decide(request_fields, executable_path) -> ("AUTHORIZED", amount, reason)
                                         | ("NOT_AUTHORIZED", "program rejected the request")
                                         | ("REFUSED", why)

Only "AUTHORIZED" permits the protected effect. "NOT_AUTHORIZED" (the exact rejection frame) and
"REFUSED" (no valid decision) both forbid it. The effect is authorized IF AND ONLY IF every check passes.
decide_from_result(...) holds the decision steps on a recorded process result, so that controls can
plant process results without running the executable.
"""
import hashlib
import os
import resource
import shutil
import signal
import subprocess
import tempfile
from collections import namedtuple

import frame

PINNED_SHA256 = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
ENVIRONMENT = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C', 'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}
TIME_LIMIT_S = 60
FIELDS = ('charge', 'request', 'original', 'remaining', 'enabled', 'opened', 'candidate', 'amount', 'reason')

# exit_code: int or None; signal: int or None; timed_out: bool; stdout, stderr: bytes;
# overflow: True when the bounded reader saw more than the bound (or the file size limit fired).
ProcessResult = namedtuple('ProcessResult', 'exit_code signal timed_out stdout stderr overflow')


def check_request(fields):
    """Types the caller must send. Any other value is a caller error -> REFUSED."""
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
    return frame.render_request(*(fields[k] for k in FIELDS))


def expected_accept(fields):
    """The only authorizing frame this request can have (refund_fields: ok => echo amount, reason, ids, 1)."""
    return frame.render_fields(True, fields['amount'], fields['reason'], fields['charge'], fields['request'], 1)


def output_bound(fields):
    return max(len(expected_accept(fields)), len(frame.REJECTED_BYTES))


def decide_from_result(fields, result):
    """Steps D1..D11 of FAIL_CLOSED_CONTRACT.md, in order. First failing step gives REFUSED."""
    try:
        check_request(fields)                                                        # D0
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
            ok, amount, reason, charge, request, count = frame.strict_parse(out)    # D7 (includes re-render)
        except frame.Err as e:
            return ('REFUSED', 'D7 stdout is not exactly one canonical frame: %s' % e)
        if not ok:
            if out == frame.REJECTED_BYTES:                                          # D8
                return ('NOT_AUTHORIZED', 'program rejected the request')
            return ('REFUSED', 'D8 False frame is not the exact rejection frame')
        if charge != fields['charge'] or request != fields['request']:               # D9 BindingValid
            return ('REFUSED', 'D9 echoed charge id or request id differs from the sent one')
        if amount != fields['amount'] or reason != fields['reason']:
            return ('REFUSED', 'D9 echoed amount or reason differs from the sent one')
        if not (0 <= amount <= frame.MAX_MONEY) or reason not in frame.APPROVED_REASONS:
            return ('REFUSED', 'D10 amount out of range or reason not approved')
        if count != 1:
            return ('REFUSED', 'D10 intent count is not 1')
        if out != expected_accept(fields):                                           # D11 cross-check
            return ('REFUSED', 'D11 frame differs from the one expected frame (internal inconsistency)')
        return ('AUTHORIZED', amount, reason)
    except Exception as e:                                                            # D12
        return ('REFUSED', 'D12 caller exception: %s: %s' % (type(e).__name__, e))


def sha256_file(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def run_process(executable_path, stdin_bytes, bound, time_limit=TIME_LIMIT_S):
    """Run a PRIVATE COPY of the pinned executable. stdout and stderr go to private files whose size the
    kernel limits (RLIMIT_FSIZE = bound + 1), so a flood cannot exhaust the caller. Returns ProcessResult."""
    work = tempfile.mkdtemp(prefix='m1fc-')
    try:
        exe = os.path.join(work, 'refund')
        shutil.copyfile(executable_path, exe)
        if sha256_file(exe) != PINNED_SHA256:                                         # pin the copy we run
            raise RuntimeError('EXECUTABLE: SHA-256 is not the pinned one')
        os.chmod(exe, 0o700)
        limit = bound + 1

        def child_limits():
            resource.setrlimit(resource.RLIMIT_FSIZE, (limit, limit))
            # CPU-time bound in the kernel, independent of the caller's wall-clock wait (SIGXCPU, then SIGKILL).
            resource.setrlimit(resource.RLIMIT_CPU, (time_limit, time_limit + 1))

        with open(os.path.join(work, 'out'), 'w+b') as fo, open(os.path.join(work, 'err'), 'w+b') as fe:
            p = subprocess.Popen([exe], stdin=subprocess.PIPE, stdout=fo, stderr=fe, env=ENVIRONMENT,
                                 cwd=work, preexec_fn=child_limits, close_fds=True, start_new_session=True)
            timed_out = False
            try:
                p.communicate(input=stdin_bytes, timeout=time_limit)
            except subprocess.TimeoutExpired:
                timed_out = True
            finally:
                try:                                                                 # the whole group
                    os.killpg(p.pid, signal.SIGKILL)
                except (ProcessLookupError, PermissionError):
                    pass
                p.wait()
            if sha256_file(exe) != PINNED_SHA256:
                raise RuntimeError('EXECUTABLE: the copy changed during the run')
            fo.seek(0, 2); osz = fo.tell(); fe.seek(0, 2); esz = fe.tell()
            fo.seek(0); fe.seek(0)
            stdout = fo.read(limit); stderr = fe.read(limit)
        rc = p.returncode
        return ProcessResult(exit_code=None if (rc is None or rc < 0) else rc,
                             signal=-rc if (rc is not None and rc < 0) else None,
                             timed_out=timed_out, stdout=stdout, stderr=stderr,
                             overflow=osz > bound or esz > bound)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def decide(request_fields, executable_path):
    try:
        check_request(request_fields)
        if sha256_file(executable_path) != PINNED_SHA256:
            return ('REFUSED', 'D0 executable SHA-256 is not the pinned one')
        result = run_process(executable_path, wire(request_fields), output_bound(request_fields))
        return decide_from_result(request_fields, result)
    except Exception as e:
        return ('REFUSED', 'D12 caller exception: %s: %s' % (type(e).__name__, e))
