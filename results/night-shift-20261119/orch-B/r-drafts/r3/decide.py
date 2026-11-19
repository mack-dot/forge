"""Strict bridge decision (night shift 2026-11-19, task x-issuer-bridge). NOT proved: TESTED-UNPROVED.

The issuer may sign ONLY IF
  (a) the compiled Dafny RefundFinality.Check returned Issue, AND
  (b) the pinned M1 native executable, run by launcher.launch on the SAME flat inputs, wrote exactly
      one complete frame, accepted by the strict parser of frame.py (a byte-equal copy of
      proposals/m1b-mission-20261119/drafts/fail-closed/frame.py, SHA-256 FRAME_SHA256), whose six
      fields equal the six fields derived from the Dafny verdict.
Every other outcome is REFUSE with one reason. The first failing step decides. The exit status is
necessary, never sufficient (CE-1).
"""
import dataclasses
import hashlib
import importlib.util
import os

_HERE = os.path.dirname(os.path.abspath(__file__))
FRAME_SHA256 = 'cf9390074435e74f4731c357a363e77a42c6887c74cd767ba0ef7a916eaa3e12'
_fp = os.path.join(_HERE, 'frame.py')
with open(_fp, 'rb') as _f:
    if hashlib.sha256(_f.read()).hexdigest() != FRAME_SHA256:
        raise ImportError('frame.py is not the pinned copy')
_spec = importlib.util.spec_from_file_location('bridge_frame', _fp)
frame = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(frame)

PINNED_BINARY_SHA256 = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
MAX_MONEY = 9223372036854775807
MAX_TEXT_UTF16 = 256          # the issuer's own text limit (ts/refund-finality/encoding.ts MAX_TEXT)
TIMEOUT_S = 10.0
FIELDS = ('authorized', 'amount', 'reason', 'charge', 'request', 'count')


@dataclasses.dataclass(frozen=True)
class CheckInputs:
    """The flat inputs of RefundFinality.Check that the native program also reads."""
    charge_id: str
    original: int
    remaining: int
    enabled: bool
    request_id: str
    amount: int
    reason: str


@dataclasses.dataclass(frozen=True)
class DafnySide:
    """Fields derived from the compiled Check verdict: issue = verdict.Issue?; on Issue:
    amount/reason/charge = token.intent, request = token.requestId, count = |plan|."""
    issue: bool
    amount: int = 0
    reason: str = ''
    charge_id: str = ''
    request_id: str = ''
    count: int = 0


@dataclasses.dataclass(frozen=True)
class Decision:
    sign: bool
    reason: str
    detail: str = ''


def _text_ok(s):
    if not isinstance(s, str) or '\x00' in s:
        return False
    try:
        b = s.encode('utf-8')                       # strict: a lone surrogate fails here
    except UnicodeEncodeError:
        return False
    return len(s.encode('utf-16-le')) // 2 <= MAX_TEXT_UTF16 and isinstance(b, bytes)


def _int_ok(v):
    return type(v) is int and 0 <= v <= MAX_MONEY


def in_range(x):
    """The bridge's input range. It is inside the domain of the stored HOL theorem (every mlstring,
    every int) and equal to the issuer's shape domain. Outside it: REFUSE, no launch."""
    return (isinstance(x, CheckInputs) and _text_ok(x.charge_id) and _text_ok(x.request_id)
            and _text_ok(x.reason) and _int_ok(x.original) and _int_ok(x.remaining) and _int_ok(x.amount)
            and type(x.enabled) is bool)


def u8(s):
    return s.encode('utf-8')


def native_wire(x):
    """Request bytes for stdin: sexp_to_string (refund_request c q o r e opened candidate a reason),
    transcribed by frame.render_request. opened = True and candidate = True: Check fixes both."""
    return frame.render_request(u8(x.charge_id), u8(x.request_id), x.original, x.remaining, x.enabled,
                                True, True, x.amount, u8(x.reason))


def stdout_cap(x):
    return max(len(frame.render_fields(True, x.amount, u8(x.reason), u8(x.charge_id), u8(x.request_id), 1)),
               len(frame.REJECTED_BYTES))


def expected_fields(d):
    return (True, d.amount, u8(d.reason), u8(d.charge_id), u8(d.request_id), d.count)


def _classify_bad_frame(out, expected_bytes):
    for k in range(1, len(out)):
        if frame.strict_accepts(out[:k]) is not None:
            return 'FRAME_EXTRA_BYTES'
    if len(out) < len(expected_bytes) and expected_bytes.startswith(out):
        return 'FRAME_TRUNCATED'
    return 'FRAME_MALFORMED'


def decide(x, d, r):
    """x: CheckInputs, d: DafnySide, r: launcher.LaunchResult. Returns a Decision."""
    try:
        if not r.launched:
            return Decision(False, r.refusal or 'NOT_LAUNCHED')
        if r.timed_out:
            return Decision(False, 'TIMEOUT')
        if r.stdout_overflow:                     # before SIGNAL: the launcher kills on overflow
            return Decision(False, 'STDOUT_OVERFLOW')
        if r.stderr_len != 0:
            return Decision(False, 'STDERR_NONEMPTY', str(r.stderr_len))
        if r.signal is not None:
            return Decision(False, 'SIGNAL', str(r.signal))
        if r.exit_code != 0:
            return Decision(False, 'EXIT_NONZERO', str(r.exit_code))
        if not r.stdin_complete:
            return Decision(False, 'STDIN_INCOMPLETE')
        if not r.copy_unchanged:
            return Decision(False, 'BINARY_CHANGED')
        out = r.stdout
        if out == b'':
            return Decision(False, 'STDOUT_EMPTY')
        expected_bytes = frame.render_fields(*expected_fields(d)) if d.issue else frame.REJECTED_BYTES
        nat = frame.strict_accepts(out)
        if nat is None:
            return Decision(False, _classify_bad_frame(out, expected_bytes))
        if nat[0] is False and out != frame.REJECTED_BYTES:
            return Decision(False, 'REJECT_FRAME_NOT_CANONICAL')
        if not d.issue:
            return Decision(False, 'DAFNY_REFUSE_NATIVE_AUTHORIZE' if nat[0] else 'BOTH_REFUSE')
        exp = expected_fields(d)
        for name, a, b in zip(FIELDS, nat, exp):
            if a != b:
                return Decision(False, 'MISMATCH_' + name.upper())
        if out != expected_bytes:
            return Decision(False, 'MISMATCH_BYTES')
        return Decision(True, 'SIGN')
    except Exception as e:                        # any error refuses
        return Decision(False, 'INTERNAL_ERROR', repr(e))


def bridge(x, d, binary_path, launch_fn, pinned_sha256=PINNED_BINARY_SHA256, timeout_s=TIMEOUT_S,
           work_root=None):
    """Range check, one hardened launch on the same flat inputs, strict decision."""
    if not in_range(x):
        return Decision(False, 'OUT_OF_RANGE'), None
    r = launch_fn(binary_path, pinned_sha256, native_wire(x), stdout_cap(x), timeout_s=timeout_s,
                  work_root=work_root)
    return decide(x, d, r), r
