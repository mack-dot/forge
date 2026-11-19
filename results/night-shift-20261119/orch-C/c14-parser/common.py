"""c14-parser shared helpers. Read-only use of the consumer (frame.py, m1_fail_closed.py)."""
import sys, subprocess, hashlib
sys.dont_write_bytecode = True
FC = '<REPO>/proposals/m1b-mission-20261119/drafts/fail-closed'
sys.path.insert(0, FC)
import frame            # noqa: E402  the repository's Python strict parser (consumer)
import m1_fail_closed as fc  # noqa: E402  the repository's host-side caller (decide_from_result)

EXE = '<REPO>/results/night-shift-20261119/orch-A/ffi-c-audit/refund'
PIN = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
assert hashlib.sha256(open(EXE, 'rb').read()).hexdigest() == PIN
ENV = dict(fc.ENVIRONMENT)
MAX = 9223372036854775807
APPROVED = (b'duplicate_charge', b'service_not_delivered', b'returned_item')


def run(stdin_bytes, timeout=20):
    p = subprocess.run([EXE], input=stdin_bytes, capture_output=True, env=ENV, timeout=timeout)
    return p.returncode, p.stdout, p.stderr


def as_result(rc, out, err):
    return fc.ProcessResult(exit_code=None if rc < 0 else rc, signal=-rc if rc < 0 else None,
                            timed_out=False, stdout=out, stderr=err, overflow=False)


def oracle(f):
    """Independent oracle from spec/refund/protocol.md lines 15-33 (valid context, 0<=amount<=remaining,
    approved reason; zero is an authorization). Returns ('AUTHORIZED', amount, reason) or ('NOT_AUTHORIZED',)."""
    ok = (f['charge'] != b'' and f['request'] != b'' and f['enabled'] is True and f['opened'] is True
          and f['candidate'] is True and 0 <= f['remaining'] <= f['original'] <= MAX
          and 0 <= f['amount'] <= f['remaining'] and f['reason'] in APPROVED)
    return ('AUTHORIZED', f['amount'], f['reason']) if ok else ('NOT_AUTHORIZED',)
