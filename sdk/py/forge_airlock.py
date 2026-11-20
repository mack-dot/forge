"""forge_airlock: Python SDK for the forge-airlock engine (Goal 20). Python stdlib only. end_to_end=false.

The SDK decides NO write. It encodes a request line, sends it to ONE long-lived `forge-airlock serve <dir>`
process per Store (pipes), and maps the engine's answer line (src/airlock/PROTOCOL.md) to a typed result.
Label of the SDK itself: not trusted for a write decision; not proved. FINITE TEST only.

Typed results (class Result, field `code`):
  COMMITTED, REJECTED_POLICY, REQUIRE_HUMAN_COSIGN, STALE_STATE_HASH, DUPLICATE_REQUEST_ID,
  TENANT_ISOLATION_BREACH, DROPPED_OBLIGATION (from Store.sweep), plus OK for get/read/state answers.
Every other outcome RAISES a subclass of AirlockError and is never a commit:
  LocalRefusal      the SDK refused the input BEFORE sending (LF/CR/NUL/space, a non-canonical id or hash)
  EngineRefusal     the engine answered MALFORMED_REQUEST, UNKNOWN_KEY, HELPER_FAILED or BAD_FRAME (nothing committed)
  EngineFault       EPOCH_REGRESSION, CORRUPT_WAL, IO_ERROR, OUTCOME_UNKNOWN, DISPATCH_FAILED (serve ends;
                    outcome_known is False for OUTCOME_UNKNOWN and DISPATCH_FAILED)
  ProtocolError     an unknown first token, a malformed or mismatched answer, a short read (outcome unknown)
  EngineDead        the serve process is gone (outcome unknown for a request in transit)
  EngineTimeout     no answer in time; the serve process is killed (outcome unknown)
After ProtocolError, EngineDead, EngineTimeout or EngineFault the Store is closed: fail closed, no retry.

Rules kept here (the engine is the real check):
  * commit(...) needs the caller's pre_state_hash (from get()); the SDK never fetches it for you.
  * read_scoped serializes each row ONCE, sends exactly those lines, and only after the engine answered
    exactly `OK <n>` returns NEW objects parsed from exactly those lines (never the caller's objects). The
    engine checks only the TOP-LEVEL tenant_id of the rows passed to it. More than 100000 rows: LocalRefusal,
    nothing sent. Any other answer than `OK <n>` or TENANT_ISOLATION_BREACH closes the client (the stream may
    be out of step).
  * with_lease(request_id, deadline_ms, tenant, key, handler) opens a durable lease bound to (request id,
    tenant, key) BEFORE the handler runs and never closes it; only a terminal verdict of the engine for the
    same request id ON the same tenant and key closes it. A handler that raises leaves it open (the exception
    propagates); `Store.sweep` then reports DROPPED_OBLIGATION. Only handlers that opened a lease are covered.

Trust boundary (src/airlock/PROTOCOL.md section 11): every rule holds only against a caller that reaches the
store THROUGH the engine. A process that can write the store folder can append records itself; a process that
can start its own engine on the folder can ignore every check. The opener of a key is trusted for its tenant,
`original` and facts; the tenant field is not authenticated. "The agent cannot self-cosign" needs BOTH the
private key outside the agent's reach AND an agent that cannot write the store folder or run another engine on
it (for example `serve` runs under another OS user and the agent holds only its pipe).
"""

import json
import os
from pathlib import Path
import re
import select
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
DISPATCHER = ROOT / 'bin' / 'forge-airlock'
MAX_MONEY = 9223372036854775807
MAX_ANSWER = 1 << 17
ID_RE = re.compile(r'[A-Za-z0-9_-]{1,24}\Z')
HASH_RE = re.compile(r'[0-9a-f]{32}\Z')
SIG_RE = re.compile(r'[0-9a-f]{128}\Z')
DIGITS_RE = re.compile(r'(0|[1-9][0-9]*)\Z')
MAX_READ_ROWS = 100000

TYPED = ('COMMITTED', 'REJECTED_POLICY', 'REQUIRE_HUMAN_COSIGN', 'STALE_STATE_HASH', 'DUPLICATE_REQUEST_ID',
         'TENANT_ISOLATION_BREACH', 'DROPPED_OBLIGATION')
REFUSALS = ('MALFORMED_REQUEST', 'UNKNOWN_KEY', 'HELPER_FAILED', 'BAD_FRAME')
FAULTS = ('EPOCH_REGRESSION', 'CORRUPT_WAL', 'IO_ERROR', 'OUTCOME_UNKNOWN', 'DISPATCH_FAILED')
VERBS = {'open_money': 'OPEN_MONEY', 'refund': 'REFUND', 'open_saga': 'OPEN_SAGA', 'saga': 'SAGA',
         'open_inventory': 'OPEN_INVENTORY', 'book': 'BOOK'}


# ------------------------------------------------------------------------------------------------ errors

class AirlockError(Exception):
    """Any outcome that is not a typed result. Never a commit. `outcome_known` False = the write may or may not stay."""
    outcome_known = True

    def __init__(self, code, detail='', line=None):
        super().__init__('%s %s' % (code, detail) if detail else code)
        self.code, self.detail, self.line = code, detail, line


class LocalRefusal(AirlockError):
    """The SDK refused the input before it sent anything."""


class EngineRefusal(AirlockError):
    """The engine refused with a code outside the typed set; nothing was committed."""


class EngineFault(AirlockError):
    def __init__(self, code, detail='', line=None):
        super().__init__(code, detail, line)
        self.outcome_known = code not in ('OUTCOME_UNKNOWN', 'DISPATCH_FAILED')


class ProtocolError(AirlockError):
    outcome_known = False


class EngineDead(AirlockError):
    outcome_known = False


class EngineTimeout(AirlockError):
    outcome_known = False


class LeaseNotOpened(AirlockError):
    """OPEN_LEASE was refused (`result` holds the typed answer); the handler did not run."""

    def __init__(self, result):
        super().__init__(result.code, result.detail, result.line)
        self.result = result


# ------------------------------------------------------------------------------------------------ results

class Result:
    """A typed answer. `committed` is True only for an exact, checked COMMITTED line."""

    def __init__(self, code, detail='', line='', **kw):
        self.code, self.detail, self.line = code, detail, line
        self.request_id = kw.get('request_id')
        self.epoch = kw.get('epoch')
        self.state_hash = kw.get('state_hash')
        self.payload = kw.get('payload')
        self.lease_closed = kw.get('lease_closed')
        self.fields = kw.get('fields', {})
        self.kind = kw.get('kind')
        self.rows = kw.get('rows', [])
        self.dropped = kw.get('dropped', [])

    @property
    def committed(self):
        return self.code == 'COMMITTED'

    def __repr__(self):
        return 'Result(%s %s)' % (self.code, self.detail)


class Lease:
    """An open obligation lease bound to (request_id, tenant, key). commit() through it uses the lease's
    request id, and the lease's tenant and key unless given (a verdict on another key does not close it)."""

    def __init__(self, store, request_id, epoch, deadline_ms, tenant, key):
        self.store, self.request_id, self.epoch, self.deadline_ms = store, request_id, epoch, deadline_ms
        self.tenant, self.key = tenant, key

    def commit(self, op, **fields):
        fields['request_id'] = self.request_id
        fields.setdefault('tenant', self.tenant)
        fields.setdefault('key', self.key)
        return self.store.commit(op, **fields)


# ------------------------------------------------------------------------------------------------ field checks

def _printable(name, s):
    if not isinstance(s, str) or not s or any(not (0x21 <= ord(ch) <= 0x7e) for ch in s):
        raise LocalRefusal('LOCAL_REFUSED', '%s: empty, not a string, or holds a byte outside 0x21..0x7e (LF, CR, NUL, space, non-ASCII)' % name)
    return s


def _id(name, v):
    if not isinstance(v, str) or not ID_RE.match(v):
        raise LocalRefusal('LOCAL_REFUSED', '%s: not a canonical id [A-Za-z0-9_-]{1,24}' % name)
    return v


def _hash(name, v):
    if not isinstance(v, str) or not HASH_RE.match(v):
        raise LocalRefusal('LOCAL_REFUSED', '%s: not 32 lowercase hex digits' % name)
    return v


def _amount(name, v):
    """An int becomes its decimal text; a str is sent as it is (printable, no space). The ENGINE checks the range."""
    if isinstance(v, bool):
        raise LocalRefusal('LOCAL_REFUSED', '%s: a bool is not an amount' % name)
    if isinstance(v, int):
        return str(v)
    return _printable(name, v)


def _json(name, v):
    try:
        text = json.dumps(v, ensure_ascii=True, separators=(',', ':'), allow_nan=False)
    except (TypeError, ValueError) as e:
        raise LocalRefusal('LOCAL_REFUSED', '%s: not JSON (%s)' % (name, e))
    if any(not (0x20 <= ord(ch) <= 0x7e) for ch in text):
        raise LocalRefusal('LOCAL_REFUSED', '%s: JSON text is not printable ASCII' % name)
    return text


def refund_action(tenant, key, request_id, pre_state_hash, reason, amount):
    """The canonical action text that a human cosigns (PROTOCOL.md section 7)."""
    return ' '.join(['REFUND', _id('tenant', tenant), _id('key', key), _id('request_id', request_id),
                     _hash('pre_state_hash', pre_state_hash), _id('reason', reason), _amount('amount', amount)])


def build_line(op, f):
    """The request line for commit(op, **f). Raises LocalRefusal or TypeError (unknown op or field)."""
    allowed = {'open_money': {'tenant', 'key', 'request_id', 'policy', 'original', 'facts'},
               'refund': {'tenant', 'key', 'request_id', 'pre_state_hash', 'reason', 'amount', 'signature'},
               'open_saga': {'tenant', 'key', 'request_id', 'policy'},
               'saga': {'tenant', 'key', 'request_id', 'pre_state_hash', 'to_state', 'processor', 'idempotency_key'},
               'open_inventory': {'tenant', 'key', 'request_id', 'policy', 'capacities'},
               'book': {'tenant', 'key', 'request_id', 'pre_state_hash', 'certificate'}}
    if op not in allowed:
        raise TypeError('unknown op %r; one of %s' % (op, ', '.join(sorted(allowed))))
    extra = set(f) - allowed[op]
    if extra:
        raise TypeError('%s: unknown fields %s' % (op, sorted(extra)))
    t = [VERBS[op], _id('tenant', f.get('tenant')), _id('key', f.get('key')), _id('request_id', f.get('request_id'))]
    if op == 'open_money':
        t += [_id('policy', f.get('policy')), _amount('original', f.get('original'))]
        facts = f.get('facts') or {}
        if not isinstance(facts, dict):
            raise LocalRefusal('LOCAL_REFUSED', 'facts: not a dict')
        t += ['%s=%s' % (_id('fact', k), _amount('fact ' + str(k), v)) for k, v in sorted(facts.items(), key=lambda kv: str(kv[0]))]
    elif op == 'refund':
        t += [_hash('pre_state_hash', f.get('pre_state_hash')), _id('reason', f.get('reason')), _amount('amount', f.get('amount'))]
        if f.get('signature') is not None:
            sig = f['signature']
            if not isinstance(sig, str) or not SIG_RE.match(sig):
                raise LocalRefusal('LOCAL_REFUSED', 'signature: not 128 lowercase hex digits')
            t.append(sig)
    elif op == 'open_saga':
        t.append(_id('policy', f.get('policy')))
    elif op == 'saga':
        t += [_hash('pre_state_hash', f.get('pre_state_hash')), _id('to_state', f.get('to_state'))]
        p, k = f.get('processor'), f.get('idempotency_key')
        if (p is None) != (k is None):
            raise LocalRefusal('LOCAL_REFUSED', 'processor and idempotency_key go together')
        if p is not None:
            t += [_id('processor', p), _id('idempotency_key', k)]
    elif op == 'open_inventory':
        caps = f.get('capacities')
        if not isinstance(caps, (list, tuple)) or not caps:
            raise LocalRefusal('LOCAL_REFUSED', 'capacities: a non-empty list')
        t += [_id('policy', f.get('policy')), ','.join(_amount('capacity', c) for c in caps)]
    elif op == 'book':
        t += [_hash('pre_state_hash', f.get('pre_state_hash')), _json('certificate', f.get('certificate'))]
    return ' '.join(t)


# ------------------------------------------------------------------------------------------------ answer parsing

def _tok(line):
    return line.split(' ')


def parse_commit_answer(line, verb, tenant, key, request_id):
    """Map one answer line of a commit verb. A COMMITTED line must name this request exactly."""
    t = _tok(line)
    code = t[0]
    if code == 'COMMITTED':
        ok = (len(t) >= 8 and t[1] == request_id and DIGITS_RE.match(t[2]) and HASH_RE.match(t[3])
              and t[4] == verb and t[5] == tenant and t[6] == key and t[7] == request_id)
        if not ok:
            raise ProtocolError('BAD_ANSWER', 'a COMMITTED line that does not name this request', line)
        return Result('COMMITTED', line=line, request_id=t[1], epoch=int(t[2]), state_hash=t[3], payload=' '.join(t[4:]))
    return _refusal(line, t, ('REJECTED_POLICY', 'REQUIRE_HUMAN_COSIGN', 'STALE_STATE_HASH', 'DUPLICATE_REQUEST_ID',
                              'TENANT_ISOLATION_BREACH'))


def _refusal(line, t, typed):
    code = t[0]
    detail = ' '.join(t[1:])
    if code in typed:
        closed = None  # a bare code (no detail) is a valid answer form (PROTOCOL.md section 10)
        if 'LEASE_CLOSED' in t:
            i = t.index('LEASE_CLOSED')
            if i + 2 != len(t) or not DIGITS_RE.match(t[i + 1]) or code not in ('REJECTED_POLICY', 'REQUIRE_HUMAN_COSIGN'):
                raise ProtocolError('BAD_ANSWER', 'bad LEASE_CLOSED part', line)
            closed = int(t[i + 1])
        if code == 'STALE_STATE_HASH' and (len(t) < 2 or not HASH_RE.match(t[1])):
            raise ProtocolError('BAD_ANSWER', 'STALE_STATE_HASH without a hash', line)
        return Result(code, detail, line, lease_closed=closed, state_hash=t[1] if code == 'STALE_STATE_HASH' else None)
    if code in REFUSALS:
        raise EngineRefusal(code, detail, line)
    if code in FAULTS:
        raise EngineFault(code, detail, line)
    raise ProtocolError('UNKNOWN_ANSWER', 'first token %r is not an answer code for this request' % code[:40], line)


# ------------------------------------------------------------------------------------------------ the store client

class Store:
    """One `serve` process for one store folder. Thread safe (one request at a time on the pipe)."""

    def __init__(self, store_dir, node=None, timeout=60.0, serve_argv=None, env=None, python=None, engine_dir=None):
        """engine_dir: a folder with airlock-engine (and checker/model.cjs); default build/airlock (dispatcher)."""
        self.store_dir = str(store_dir)
        self.engine_opt = ['--engine-dir', str(engine_dir)] if engine_dir else []
        self.node = node
        self.timeout = timeout
        self.env = env
        self.python = python or sys.executable
        self._lock = threading.Lock()
        self._buf = b''
        self._closed = None
        self._err = tempfile.TemporaryFile()
        argv = serve_argv or [self.python, str(DISPATCHER), 'serve', self.store_dir] + (['--node', node] if node else []) + self.engine_opt
        self.proc = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self._err, env=env)
        os.set_blocking(self.proc.stdin.fileno(), False)
        self.pid = self.proc.pid

    # -- context manager and lifetime
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def close(self):
        if self.proc.poll() is None:
            try:
                self.proc.stdin.close()
            except OSError:
                pass
            try:
                self.proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        if self._closed is None:
            self._closed = 'closed by the caller'

    def _fail(self, exc):
        """Fail closed: kill the serve process, remember why, raise."""
        self._closed = '%s: %s' % (type(exc).__name__, exc)
        if self.proc.poll() is None:
            self.proc.kill()
        try:
            self.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            pass
        raise exc

    def stderr_tail(self):
        try:
            self._err.seek(0, 2)
            n = self._err.tell()
            self._err.seek(max(0, n - 2000))
            return self._err.read().decode('utf-8', 'replace')
        except OSError:
            return ''

    # -- the pipe
    def _exchange(self, data):
        """Send bytes (one or more complete lines); return ONE answer line (ASCII, no LF)."""
        with self._lock:
            if self._closed is not None:
                raise EngineDead('ENGINE_DEAD', 'store client is closed (%s)' % self._closed)
            deadline = time.monotonic() + self.timeout
            fd = self.proc.stdin.fileno()
            view = memoryview(data)
            while view:
                left = deadline - time.monotonic()
                if left <= 0:
                    self._fail(EngineTimeout('TIMEOUT', 'request not taken in %.1fs' % self.timeout))
                _, w, _ = select.select([], [fd], [], left)
                if not w:
                    continue
                try:
                    n = os.write(fd, view)
                except BrokenPipeError:
                    self._fail(EngineDead('ENGINE_DEAD', 'serve process closed its input; exit %r; %s' % (self.proc.poll(), self.stderr_tail().strip()[-300:])))
                except BlockingIOError:
                    continue
                view = view[n:]
            out = self.proc.stdout.fileno()
            while b'\n' not in self._buf:
                if len(self._buf) > MAX_ANSWER:
                    self._fail(ProtocolError('BAD_ANSWER', 'answer longer than %d bytes' % MAX_ANSWER))
                left = deadline - time.monotonic()
                if left <= 0:
                    self._fail(EngineTimeout('TIMEOUT', 'no answer in %.1fs' % self.timeout))
                r, _, _ = select.select([out], [], [], left)
                if not r:
                    continue
                chunk = os.read(out, 65536)
                if not chunk:
                    why = 'short read (%d bytes, no line end)' % len(self._buf) if self._buf else 'no answer'
                    self.proc.wait()
                    self._fail(EngineDead('ENGINE_DEAD', '%s; serve exit %r; %s' % (why, self.proc.returncode, self.stderr_tail().strip()[-300:])))
                self._buf += chunk
            line, self._buf = self._buf.split(b'\n', 1)
            if self._buf:
                self._fail(ProtocolError('BAD_ANSWER', 'more than one answer line for one request'))
            try:
                text = line.decode('ascii')
            except UnicodeDecodeError:
                self._fail(ProtocolError('BAD_ANSWER', 'answer is not ASCII'))
            if not text or any(not (0x20 <= ord(ch) <= 0x7e) for ch in text):
                self._fail(ProtocolError('BAD_ANSWER', 'empty or unprintable answer', text))
            if text.split(' ')[0] in FAULTS:
                self._closed = 'engine fault ' + text[:80]  # serve ends after a fault answer
            return text

    def _send(self, line):
        if not isinstance(line, str) or any(not (0x20 <= ord(ch) <= 0x7e) for ch in line):
            raise LocalRefusal('LOCAL_REFUSED', 'request line holds a byte outside 0x20..0x7e')
        return self._exchange(line.encode('ascii') + b'\n')

    def _guard(self, fn, text):
        try:
            return fn(text)
        except (ProtocolError, EngineFault) as e:
            if isinstance(e, ProtocolError):
                self._closed = 'protocol error'
                if self.proc.poll() is None:
                    self.proc.kill()
            raise

    def _bad(self, why, text):
        self._closed = 'protocol error'
        if self.proc.poll() is None:
            self.proc.kill()
        raise ProtocolError('BAD_ANSWER', why, text)

    def raw(self, line_bytes):
        """TESTING ONLY (fuzz): send one raw line (no LF allowed in it) and return the raw answer text."""
        if b'\n' in line_bytes:
            raise LocalRefusal('LOCAL_REFUSED', 'raw line holds LF')
        return self._exchange(line_bytes + b'\n')

    # -- verbs
    def commit(self, op, **fields):
        """op: open_money, refund, open_saga, saga, open_inventory, book. Returns a typed Result or raises."""
        line = build_line(op, fields)
        text = self._send(line)
        return self._guard(lambda a: parse_commit_answer(a, VERBS[op], fields['tenant'], fields['key'], fields['request_id']), text)

    def open_money(self, tenant, key, request_id, policy, original, facts=None):
        return self.commit('open_money', tenant=tenant, key=key, request_id=request_id, policy=policy, original=original, facts=facts or {})

    def refund(self, tenant, key, request_id, pre_state_hash, reason, amount, signature=None):
        return self.commit('refund', tenant=tenant, key=key, request_id=request_id, pre_state_hash=pre_state_hash,
                           reason=reason, amount=amount, signature=signature)

    def open_saga(self, tenant, key, request_id, policy):
        return self.commit('open_saga', tenant=tenant, key=key, request_id=request_id, policy=policy)

    def saga(self, tenant, key, request_id, pre_state_hash, to_state, processor=None, idempotency_key=None):
        return self.commit('saga', tenant=tenant, key=key, request_id=request_id, pre_state_hash=pre_state_hash,
                           to_state=to_state, processor=processor, idempotency_key=idempotency_key)

    def open_inventory(self, tenant, key, request_id, policy, capacities):
        return self.commit('open_inventory', tenant=tenant, key=key, request_id=request_id, policy=policy, capacities=capacities)

    def book(self, tenant, key, request_id, pre_state_hash, certificate):
        return self.commit('book', tenant=tenant, key=key, request_id=request_id, pre_state_hash=pre_state_hash, certificate=certificate)

    def get(self, tenant, key):
        """OK Result with .state_hash, .kind, .fields; or TENANT_ISOLATION_BREACH; UNKNOWN_KEY raises EngineRefusal."""
        text = self._send('GET %s %s' % (_id('tenant', tenant), _id('key', key)))

        def parse(a):
            t = _tok(a)
            if t[0] == 'OK':
                if len(t) < 3 or not HASH_RE.match(t[1]) or any('=' not in x for x in t[3:]):
                    raise ProtocolError('BAD_ANSWER', 'bad GET answer', a)
                return Result('OK', line=a, state_hash=t[1], kind=t[2], fields=dict(x.split('=', 1) for x in t[3:]))
            return _refusal(a, t, ('TENANT_ISOLATION_BREACH',))
        return self._guard(parse, text)

    def state(self):
        text = self._send('STATE')

        def parse(a):
            t = _tok(a)
            if t[0] != 'STATE' or len(t) != 7:
                return _refusal(a, t, ())
            return Result('OK', line=a, epoch=int(t[1]), state_hash=t[2], fields=dict(x.split('=', 1) for x in t[4:]))
        return self._guard(parse, text)

    def read_scoped(self, tenant_id, rows):
        """Release rows only if the engine answers exactly `OK <n>` for the n lines sent; else 0 rows + TENANT_ISOLATION_BREACH.

        Each row is serialized ONCE; the released rows are NEW objects parsed from exactly the sent lines, so a
        change of the caller's objects (another thread, a dict subclass) cannot reach the result. A tenant that is
        not a canonical id, or a row that is not JSON, is refused here (0 rows, nothing sent). More than 100000
        rows: LocalRefusal (nothing sent). Limits: the engine sees only the rows passed here and checks only
        their TOP-LEVEL tenant_id.
        """
        rows = list(rows)
        if len(rows) > MAX_READ_ROWS:
            raise LocalRefusal('LOCAL_REFUSED', 'read_scoped: %d rows; the engine takes at most %d' % (len(rows), MAX_READ_ROWS))
        if not isinstance(tenant_id, str) or not ID_RE.match(tenant_id):
            return Result('TENANT_ISOLATION_BREACH', 'LOCAL TENANT_NOT_CANONICAL', '', rows=[])
        try:
            sent = [_json('row %d' % i, r) for i, r in enumerate(rows)]
        except LocalRefusal as e:
            return Result('TENANT_ISOLATION_BREACH', 'LOCAL ' + e.detail, '', rows=[])
        rows = sent  # from here on only the serialized text exists: what the engine checks is what is released
        text = self._exchange(('READ %s %d\n' % (tenant_id, len(rows))).encode('ascii') + b''.join(r.encode('ascii') + b'\n' for r in sent))
        if text == 'OK %d' % len(rows):
            return Result('OK', line=text, rows=[json.loads(r) for r in sent])
        t = _tok(text)
        if t[0] == 'OK':
            self._bad('OK for another row count', text)
        if t[0] == 'TENANT_ISOLATION_BREACH':
            return Result('TENANT_ISOLATION_BREACH', ' '.join(t[1:]), text, rows=[])
        self._closed = 'READ answered %s; the stream may be out of step' % t[0][:40]  # fail closed
        if self.proc.poll() is None:
            self.proc.kill()
        return self._guard(lambda a: _refusal(a, t, ()), text)

    def with_lease(self, request_id, deadline_ms, tenant, key, handler):
        """Open a durable lease bound to (request_id, tenant, key), then run handler(lease). The SDK never closes it.

        deadline_ms: absolute milliseconds since the Unix epoch (the sweep compares it with its clock or --now).
        Returns what the handler returns. A handler exception propagates; the lease stays open. One lease per
        request id, ever (DUPLICATE_REQUEST_ID LEASE_USED).
        """
        dl = _amount('deadline_ms', deadline_ms)
        text = self._send('OPEN_LEASE %s %s %s %s' % (_id('request_id', request_id), dl, _id('tenant', tenant), _id('key', key)))
        t = _tok(text)
        if t[0] == 'LEASE_OPENED':
            if len(t) != 6 or t[1] != request_id or not DIGITS_RE.match(t[2]) or t[3] != dl or t[4] != tenant or t[5] != key:
                self._bad('LEASE_OPENED for another lease', text)
            return handler(Lease(self, request_id, int(t[2]), deadline_ms, tenant, key))
        res = self._guard(lambda a: _refusal(a, t, ('DUPLICATE_REQUEST_ID', 'TENANT_ISOLATION_BREACH')), text)
        raise LeaseNotOpened(res)

    def leases(self, all=False):
        """`leases [--all]`: list of token lists after `LEASE` (request_id, deadline_ms, tenant, key[, OPEN|CLOSED ...])."""
        code, out = self._sub(['leases', self.store_dir] + (['--all'] if all else []))
        lines = [ln for ln in out.split('\n') if ln]
        if code != 0 or not lines or not lines[0].startswith('LEASES '):
            raise EngineFault(lines[0].split(' ')[0] if lines else 'LEASES_FAILED', out.strip()[:200])
        return [ln.split(' ')[1:] for ln in lines[1:] if ln.startswith('LEASE ')]

    # -- one-shot engine subcommands (separate short processes, read-only for the WAL contents)
    def _sub(self, args):
        p = subprocess.run([self.python, str(DISPATCHER)] + args + self.engine_opt, capture_output=True, timeout=self.timeout * 2, env=self.env)
        return p.returncode, p.stdout.decode('ascii', 'replace')

    def cosign_message(self, action):
        """The exact bytes a human signs (engine `cosign-message`)."""
        code, out = self._sub(['cosign-message', self.store_dir, _printable_action(action)])
        if code != 0:
            raise EngineRefusal(out.split(' ')[0] or 'COSIGN_MESSAGE', out.strip())
        return out.encode('ascii')

    def replay(self):
        """List of (epoch, payload) of every effect record, from the engine's own replay."""
        code, out = self._sub(['replay', self.store_dir])
        lines = out.split('\n')
        if code != 0 or not lines[0].startswith('REPLAY '):
            raise EngineFault(lines[0].split(' ')[0] or 'REPLAY_FAILED', out.strip()[:200])
        n = int(lines[0].split(' ')[1])
        effects = []
        for ln in lines[1:1 + n]:
            t = ln.split(' ', 2)
            if t[0] != 'EFFECT' or len(t) != 3:
                raise ProtocolError('BAD_ANSWER', 'bad replay line', ln)
            effects.append((int(t[1]), t[2]))
        if len(effects) != n:
            raise ProtocolError('BAD_ANSWER', 'replay: %d of %d lines' % (len(effects), n))
        return effects

    def sweep(self, now_ms=None):
        """`leases --sweep`: Result DROPPED_OBLIGATION (.dropped = [(request_id, deadline_ms, tenant, key)]) or OK."""
        args = ['leases', self.store_dir, '--sweep'] + (['--now', str(int(now_ms))] if now_ms is not None else [])
        code, out = self._sub(args)
        lines = [ln for ln in out.split('\n') if ln]
        if not lines or not lines[0].startswith('SWEEP ') or code not in (0, 24):
            raise EngineFault(lines[0].split(' ')[0] if lines else 'SWEEP_FAILED', out.strip()[:200])
        dropped = [(x[1], int(x[2]), x[3], x[4]) for x in (ln.split(' ') for ln in lines[1:] if ln.startswith('DROPPED_OBLIGATION ')) if len(x) == 5]
        if len(dropped) != len([ln for ln in lines[1:] if ln.startswith('DROPPED_OBLIGATION ')]):
            raise ProtocolError('BAD_ANSWER', 'bad DROPPED_OBLIGATION line', out)
        if (code == 24) != bool(dropped):
            raise ProtocolError('BAD_ANSWER', 'sweep exit code and lines disagree', out)
        return Result('DROPPED_OBLIGATION' if dropped else 'OK', lines[0], out, dropped=dropped)


def _printable_action(a):
    if not isinstance(a, str) or any(not (0x20 <= ord(ch) <= 0x7e) for ch in a) or not a:
        raise LocalRefusal('LOCAL_REFUSED', 'action: not printable ASCII')
    return a
