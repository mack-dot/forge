"""Single-input dual-check bridge (night shift 2026-11-19, task x-bridge2). TESTED-UNPROVED code.

Its decision function is modelled and proved in dafny/Bridge2.dfy (Bridge2; same step order).
ONE data input: the candidate (pre, t = (request, post, intent)). The bridge derives BOTH sides:
  native inputs  x := encode(pre, t.request)            (UTF-8 texts; opened = candidate = True)
  expected frame   := render_fields(True, x.amount, x.reason, x.charge, x.request, 1)  once Check issued
It signs only if (1) the candidate is in range (strict types), (2) the compiled Check issues for
(pre, preStateSha256, t), (3) the pinned native program, run once on x, prints exactly the expected
frame (strict parse, clean process), and (4) post and intent RECOMPUTED from the frame and pre equal
t.post and t.intent. The output carries preStateSha256 = SHA-256(canon(pre)): the signer must not
recompute pre. The token fields come from the recomputation, not from the checker.
"""
import dataclasses
import hashlib
import importlib.util
import json
import os

_HERE = os.path.dirname(os.path.abspath(__file__))
FRAME_SHA256 = 'cf9390074435e74f4731c357a363e77a42c6887c74cd767ba0ef7a916eaa3e12'
_fp = os.path.join(_HERE, 'frame.py')
with open(_fp, 'rb') as _f:
    if hashlib.sha256(_f.read()).hexdigest() != FRAME_SHA256:
        raise ImportError('frame.py is not the pinned copy')
_spec = importlib.util.spec_from_file_location('bridge2_frame', _fp)
frame = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(frame)

PINNED_BINARY_SHA256 = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
MAX_MONEY = 9223372036854775807
MAX_TEXT_UTF16 = 256
TIMEOUT_S = 10.0


@dataclasses.dataclass(frozen=True)
class Charge:
    charge_id: str
    original: int
    remaining: int
    enabled: bool


@dataclasses.dataclass(frozen=True)
class Request:
    request_id: str
    amount: int
    reason: str


@dataclasses.dataclass(frozen=True)
class Intent:
    charge_id: str
    request_id: str
    amount: int
    reason: str


@dataclasses.dataclass(frozen=True)
class Candidate:
    pre: Charge
    request: Request
    post: Charge
    intent: Intent


@dataclasses.dataclass(frozen=True)
class Decision:
    sign: bool
    reason: str
    detail: str = ''
    token: object = None          # on SIGN: dict with preStateSha256, requestId, post, intent (recomputed)


def _text_ok(s):
    if type(s) is not str or '\x00' in s:
        return False
    try:
        s.encode('utf-8')                     # strict: a lone surrogate fails
    except UnicodeEncodeError:
        return False
    return len(s.encode('utf-16-le')) // 2 <= MAX_TEXT_UTF16


def _int_ok(v):
    return type(v) is int and 0 <= v <= MAX_MONEY


def _typed_charge(c):
    return (type(c) is Charge and type(c.charge_id) is str and type(c.original) is int
            and type(c.remaining) is int and type(c.enabled) is bool)


def in_range(c):
    """Strict types everywhere (bool is not int); range on the values sent to the native program."""
    if type(c) is not Candidate or type(c.request) is not Request or type(c.intent) is not Intent:
        return False
    if not (_typed_charge(c.pre) and _typed_charge(c.post)):
        return False
    i = c.intent
    if not (type(i.charge_id) is str and type(i.request_id) is str and type(i.amount) is int
            and type(i.reason) is str):
        return False
    return (_text_ok(c.pre.charge_id) and _text_ok(c.request.request_id) and _text_ok(c.request.reason)
            and _int_ok(c.pre.original) and _int_ok(c.pre.remaining) and _int_ok(c.request.amount))


def state_json(ch):
    return {'chargeId': ch.charge_id, 'original': str(ch.original), 'remaining': str(ch.remaining),
            'refundEnabled': ch.enabled}


def intent_json(i):
    return {'chargeId': i.charge_id, 'requestId': i.request_id, 'amount': str(i.amount), 'reason': i.reason}


def canon(v):
    """Transcription of ts/refund-finality/encoding.ts canon for str/bool/dict (TESTED against a JS copy)."""
    if type(v) is str:
        return json.dumps(v, ensure_ascii=False)
    if type(v) is bool:
        return 'true' if v else 'false'
    if type(v) is dict:
        return '{' + ','.join(json.dumps(k, ensure_ascii=False) + ':' + canon(v[k]) for k in sorted(v)) + '}'
    raise ValueError('non-canonical value')


def pre_state_sha256(pre):
    return hashlib.sha256(canon(state_json(pre)).encode('utf-8')).hexdigest()


def u8(s):
    return s.encode('utf-8')


def encode(pre, q):
    """The fixed encoding (Bridge2.Encode): flat inputs from (pre, request) only."""
    return (u8(pre.charge_id), u8(q.request_id), pre.original, pre.remaining, pre.enabled, True, True,
            q.amount, u8(q.reason))


def native_wire(x):
    c, q, o, r, e, op, ca, a, why = x
    return frame.render_request(c, q, o, r, e, op, ca, a, why)


def auth_tuple(x):
    """Bridge2.AuthTuple: (ok, amount, reason, charge, request, count)."""
    return (True, x[7], x[8], x[0], x[1], 1)


def stdout_cap(x):
    return max(len(frame.render_fields(*auth_tuple(x))), len(frame.REJECTED_BYTES))


def _same(a, b):
    """Equality that also compares types element-wise (True != 1)."""
    if type(a) is not type(b):
        return False
    if isinstance(a, tuple):
        return len(a) == len(b) and all(_same(p, q) for p, q in zip(a, b))
    return a == b


def decide2(c, issue, r):
    """c: Candidate (in range), issue: the checker's answer, r: LaunchResult of ONE launch on encode(c).
    Same order as Bridge2.dfy after the range check; the process checks refine `native(x) = None`."""
    try:
        if not in_range(c):
            return Decision(False, 'OUT_OF_RANGE')
        if issue is not True:
            return Decision(False, 'CHECK_REFUSE')
        if r is None or not r.launched:
            return Decision(False, getattr(r, 'refusal', '') or 'NOT_LAUNCHED')
        if r.timed_out:
            return Decision(False, 'TIMEOUT')
        if r.stdout_overflow:
            return Decision(False, 'STDOUT_OVERFLOW')
        if r.stderr_len != 0:
            return Decision(False, 'STDERR_NONEMPTY')
        if r.signal is not None:
            return Decision(False, 'SIGNAL')
        if False:
            return Decision(False, 'EXIT_NONZERO')
        if r.stdin_complete is not True:
            return Decision(False, 'STDIN_INCOMPLETE')
        if r.copy_unchanged is not True:
            return Decision(False, 'BINARY_CHANGED')
        out = r.stdout
        if type(out) is not bytes or out == b'':
            return Decision(False, 'NO_FRAME')
        nat = frame.strict_accepts(out)
        if nat is None:
            return Decision(False, 'NO_FRAME')
        x = encode(c.pre, c.request)
        exp = auth_tuple(x)
        if not _same(tuple(nat), exp) or out != frame.render_fields(*exp):
            return Decision(False, 'FRAME_NOT_AUTHORIZED_TUPLE')
        amount = nat[1]
        post = Charge(c.pre.charge_id, c.pre.original, c.pre.remaining - amount, c.pre.enabled)
        intent = Intent(c.pre.charge_id, nat[4].decode('utf-8', 'strict'), amount,
                        nat[2].decode('utf-8', 'strict'))
        if not _same(dataclasses.astuple(c.post), dataclasses.astuple(post)):
            return Decision(False, 'POST_MISMATCH')
        if not _same(dataclasses.astuple(c.intent), dataclasses.astuple(intent)):
            return Decision(False, 'INTENT_MISMATCH')
        token = {'preStateSha256': pre_state_sha256(c.pre), 'requestId': intent.request_id,
                 'post': state_json(post), 'intent': intent_json(intent)}
        return Decision(True, 'SIGN', token=token)
    except Exception as e:                        # any error refuses
        return Decision(False, 'INTERNAL_ERROR', repr(e))


def bridge2(candidate, *, checker, binary_path, launch_fn, pinned_sha256=PINNED_BINARY_SHA256,
            timeout_s=TIMEOUT_S, work_root=None):
    """The only data input is `candidate`. checker(pre, t, preStateSha256) -> bool is the compiled Check
    (configuration, like the binary). Returns (Decision, LaunchResult or None)."""
    if not in_range(candidate):
        return Decision(False, 'OUT_OF_RANGE'), None
    try:
        issue = checker(candidate, pre_state_sha256(candidate.pre))
    except Exception as e:
        return Decision(False, 'CHECK_ERROR', repr(e)), None
    if issue is not True:
        return Decision(False, 'CHECK_REFUSE'), None
    x = encode(candidate.pre, candidate.request)
    r = launch_fn(binary_path, pinned_sha256, native_wire(x), stdout_cap(x), timeout_s=timeout_s,
                  work_root=work_root)
    return decide2(candidate, issue, r), r
