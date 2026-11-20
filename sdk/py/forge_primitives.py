"""forge_primitives: Python SDK for the primitives engine v2 (src/primitives_v2, primitives 6 to 9). Python stdlib
only. NOT proved; FINITE TEST only (tests/primitives_v2/test_sdk_primitives.py). end_to_end=false.

The SDK decides NO write. It encodes one request line, sends it to ONE long-lived `primitives-engine serve <dir>`
process per client (pipes), and maps the engine's answer line (src/primitives_v2/PROTOCOL.md section 5) to a result.

Results (returned):
  Committed  a `COMMITTED` line of a keyed op: .request_id .seq .now_ms .skew_ms .hashes {key: new hash} .effect
  Verdict    an `OK verdict=<WORD>` line of a stateless op (taint_egress, farkas): .verdict .fields .detail
  Refusal    every refusal the engine answers by design: .code, .repair (dict of the decoded key=value fields, the
             engine's bookkeeping fields now_ms/skew_ms/request_id/seq removed), .detail (for a human), .durable (a
             record was written and the request id is used up), .hashes (durable: the new state hash per key;
             STALE_STATE_HASH: the present hash per stale key, also in .repair as `hash.<key>`). An agent loop can
             repair its next proposal from .code and .repair alone.
  KeyState   a `GET` answer: .key .hash .exists .primitive .fields
Raised (never a result, never a commit):
  LocalRefusal   the SDK refused the input BEFORE sending (bad id, key, hash or a byte outside the wire alphabet)
  EngineFault    CORRUPT_WAL, IO_ERROR, OUTCOME_UNKNOWN, UNSAFE_STORE (serve ends; .outcome_known is False for
                 OUTCOME_UNKNOWN), MODULE_FAULT (a module broke the interface; nothing written)
  ProtocolError  an answer that breaks the wire grammar, a success line that does not match the request (another
                 request id, a missing or extra key hash, a digest that is not the digest of the bytes sent), a short
                 read: outcome unknown
  EngineDead     the serve process is gone (outcome unknown for a request in transit)
  EngineTimeout  no answer in time; the serve process is killed (outcome unknown)
After ProtocolError, EngineDead, EngineTimeout or a serve-ending EngineFault the client is closed: fail closed.

Rules kept here (the engine is the real check):
  * Compare-and-swap: a keyed op takes `pre`, a dict {key: state hash} (from get()), or the string 'read'. With
    'read' the SDK GETs each key just before the DO; that read is NOT atomic with the write, and a concurrent writer
    gives STALE_STATE_HASH, returned as a Refusal. The SDK never retries anything: no silent retry hides a conflict.
    `*` is sent only where the op allows it (rate_window acquire, ledger_graph claim/release) and only when the
    caller passes pre='*' (their default).
  * Request ids: the caller's, or a fresh random one (`r` + 22 hex). A durable refusal uses the id up.
  * taint_egress check: the document is serialized ONCE; the Verdict holds .document, the exact text sent, and the
    SDK checks that `sha256=` and `bytes=` of an ALLOW are the SHA-256 and length of exactly those bytes (else
    ProtocolError). Emit .document, never a re-serialization of your object (PROTOCOL.md section 12.6).
  * farkas check: the SDK computes the canonical digests itself and requires `system_sha256=` (and, on
    INFEASIBILITY_PROVED, `cert_sha256=`) to match (else ProtocolError).
Trust boundary (PROTOCOL.md section 15): every rule holds only for a caller that reaches the store THROUGH the
production engine. A process that can write the store folder or start another build on it can ignore every check.
Not built: a TypeScript wrapper (sdk/ts) for this engine.
"""

import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import select
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT / 'build' / 'primitives_v2' / 'primitives-engine'
MAX_LINE = 65536
MAX_ANSWER = 1 << 20
ID_RE = re.compile(r'[A-Za-z0-9_-]{1,24}\Z')
KEY_RE = re.compile(r'[A-Za-z0-9_.:@+-]{1,128}\Z')
NODE_RE = re.compile(r'[A-Za-z0-9_.:@+-]{1,64}\Z')
WORD_RE = re.compile(r'[!-~]+\Z')
HASH_RE = re.compile(r'[0-9a-f]{64}\Z')
ANSWER = re.compile(r'^([A-Z][A-Z0-9_]{1,47})((?: [A-Za-z0-9_.:@+-]+=[A-Za-z0-9._~:/@$\[\]+,%-]*)*)(?: -- ([ -~]*))?$')
FAULTS = ('CORRUPT_WAL', 'IO_ERROR', 'OUTCOME_UNKNOWN', 'UNSAFE_STORE', 'DISPATCH_FAILED')
ENGINE_FIELDS = ('now_ms', 'skew_ms', 'request_id', 'seq')


# ------------------------------------------------------------------------------------------------ errors

class PrimitivesError(Exception):
    """Any outcome that is not a result. Never a commit. `outcome_known` False: a write may or may not stay."""
    outcome_known = True

    def __init__(self, code, detail='', line=None):
        super().__init__('%s %s' % (code, detail) if detail else code)
        self.code, self.detail, self.line = code, detail, line


class LocalRefusal(PrimitivesError):
    """The SDK refused the input before it sent anything."""


class EngineFault(PrimitivesError):
    def __init__(self, code, detail='', line=None, fields=None):
        super().__init__(code, detail, line)
        self.fields = fields or {}
        self.outcome_known = code not in ('OUTCOME_UNKNOWN', 'DISPATCH_FAILED')


class ProtocolError(PrimitivesError):
    outcome_known = False


class EngineDead(PrimitivesError):
    outcome_known = False


class EngineTimeout(PrimitivesError):
    outcome_known = False


# ------------------------------------------------------------------------------------------------ results

class Committed:
    committed = True

    def __init__(self, line, request_id, seq, now_ms, skew_ms, hashes, effect):
        self.line, self.request_id, self.seq, self.now_ms, self.skew_ms = line, request_id, seq, now_ms, skew_ms
        self.hashes, self.effect = hashes, effect
        self.code = 'COMMITTED'

    def __repr__(self):
        return 'Committed(%s seq=%d)' % (self.request_id, self.seq)


class Verdict:
    committed = False

    def __init__(self, line, verdict, fields, detail, now_ms, skew_ms, document=None):
        self.line, self.verdict, self.fields, self.detail, self.now_ms, self.skew_ms = line, verdict, fields, detail, now_ms, skew_ms
        self.document = document
        self.code = 'OK'

    def __repr__(self):
        return 'Verdict(%s)' % self.verdict


class Refusal:
    committed = False

    def __init__(self, line, code, repair, detail, durable=False, request_id=None, seq=None, hashes=None, now_ms=None, skew_ms=None):
        self.line, self.code, self.repair, self.detail, self.durable = line, code, repair, detail, durable
        self.request_id, self.seq, self.hashes, self.now_ms, self.skew_ms = request_id, seq, hashes or {}, now_ms, skew_ms

    def __repr__(self):
        return 'Refusal(%s %s)' % (self.code, ' '.join('%s=%s' % kv for kv in self.repair.items()))


class KeyState:
    def __init__(self, line, key, hash, exists, primitive, fields, now_ms):
        self.line, self.key, self.hash, self.exists, self.primitive, self.fields, self.now_ms = line, key, hash, exists, primitive, fields, now_ms
        self.code = 'OK'

    def __repr__(self):
        return 'KeyState(%s exists=%d)' % (self.key, self.exists)


# ------------------------------------------------------------------------------------------------ wire

def _pct_decode(v, line):
    out = bytearray()
    i = 0
    while i < len(v):
        if v[i] == '%':
            h = v[i + 1:i + 3]
            if len(h) != 2 or not all(c in '0123456789ABCDEF' for c in h):
                raise ProtocolError('BAD_ANSWER', 'bad percent escape', line)
            out.append(int(h, 16))
            i += 3
        else:
            out.append(ord(v[i]))
            i += 1
    try:
        return out.decode('ascii')
    except UnicodeDecodeError:
        raise ProtocolError('BAD_ANSWER', 'a decoded value is not ASCII', line)


def parse_answer(line):
    """(code, ordered list of (name, decoded value), detail). Raises ProtocolError on any break of the grammar."""
    m = ANSWER.match(line)
    if m is None:
        raise ProtocolError('BAD_ANSWER', 'answer breaks the wire grammar', line)
    fields = []
    seen = set()
    for tok in m.group(2).split():
        k, v = tok.split('=', 1)
        if k in seen:
            raise ProtocolError('BAD_ANSWER', 'a field is named twice', line)
        seen.add(k)
        fields.append((k, _pct_decode(v, line)))
    return m.group(1), fields, m.group(3) or ''


def _dec(name, v, line):
    if v is None or not re.match(r'(0|[1-9][0-9]{0,19})\Z', v):
        raise ProtocolError('BAD_ANSWER', '%s is missing or not a decimal' % name, line)
    return int(v)


def _local(name, v, rx):
    if not isinstance(v, str) or not rx.match(v):
        raise LocalRefusal('LOCAL_REFUSED', '%s: not of the form %s' % (name, rx.pattern))
    return v


def _uint(name, v):
    if isinstance(v, bool) or not isinstance(v, int) or v < 0:
        raise LocalRefusal('LOCAL_REFUSED', '%s: not a non-negative int' % name)
    return str(v)  # the ENGINE checks the range (u64)


def _ascii_json(name, v):
    try:
        text = json.dumps(v, ensure_ascii=True, separators=(',', ':'), allow_nan=False)
    except (TypeError, ValueError) as e:
        raise LocalRefusal('LOCAL_REFUSED', '%s: not JSON (%s)' % (name, e))
    return text


# ------------------------------------------------------------------------------------------------ the client

class Primitives:
    """One `serve` process for one store folder. Thread safe (one request at a time on the pipe)."""

    def __init__(self, store_dir, engine=None, timeout=120.0, env=None):
        self.store_dir = str(store_dir)
        self.engine = str(engine or ENGINE)
        self.timeout = timeout
        self._lock = threading.Lock()
        self._buf = b''
        self._closed = None
        self._err = tempfile.TemporaryFile()
        self.proc = subprocess.Popen([self.engine, 'serve', self.store_dir], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=self._err, env=env if env is not None else {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'})
        os.set_blocking(self.proc.stdin.fileno(), False)

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
                self.proc.wait(timeout=30)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        if self._closed is None:
            self._closed = 'closed by the caller'

    def _fail(self, exc):
        self._closed = '%s: %s' % (type(exc).__name__, exc)
        if self.proc.poll() is None:
            self.proc.kill()
        try:
            self.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            pass
        raise exc

    def _stderr_tail(self):
        try:
            self._err.seek(0, 2)
            n = self._err.tell()
            self._err.seek(max(0, n - 1000))
            return self._err.read().decode('utf-8', 'replace').strip()
        except OSError:
            return ''

    def _exchange(self, line):
        """Send one request line; return (line, code, fields, detail) of ONE answer line."""
        if not isinstance(line, str) or len(line) > MAX_LINE or any(not (0x20 <= ord(c) <= 0x7e) for c in line):
            raise LocalRefusal('LOCAL_REFUSED', 'request line: printable ASCII, at most %d bytes' % MAX_LINE)
        with self._lock:
            if self._closed is not None:
                raise EngineDead('ENGINE_DEAD', 'client is closed (%s)' % self._closed)
            deadline = time.monotonic() + self.timeout
            fd = self.proc.stdin.fileno()
            view = memoryview(line.encode('ascii') + b'\n')
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
                    self._fail(EngineDead('ENGINE_DEAD', 'serve closed its input; exit %r; %s' % (self.proc.poll(), self._stderr_tail()[-300:])))
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
                    self._fail(EngineDead('ENGINE_DEAD', '%s; serve exit %r; %s' % (why, self.proc.returncode, self._stderr_tail()[-300:])))
                self._buf += chunk
            raw, self._buf = self._buf.split(b'\n', 1)
            if self._buf:
                self._fail(ProtocolError('BAD_ANSWER', 'more than one answer line for one request'))
            try:
                text = raw.decode('ascii')
            except UnicodeDecodeError:
                self._fail(ProtocolError('BAD_ANSWER', 'answer is not ASCII'))
            try:
                code, fields, detail = parse_answer(text)
            except ProtocolError as e:
                self._fail(e)
            d = dict(fields)
            if code in FAULTS:
                self._closed = 'engine fault ' + text[:80]  # serve ends after a fault
                raise EngineFault(code, detail, text, d)
            if code == 'MODULE_FAULT':
                raise EngineFault(code, detail, text, d)
            return text, code, fields, detail

    def _bad(self, why, text):
        self._fail(ProtocolError('BAD_ANSWER', why, text))

    # -- read verbs
    def state(self):
        """The `STATE` fields as a dict (store_id, seq, tail, last_ms, now_ms, wall_ms, skew_ms, build)."""
        text, code, fields, _ = self._exchange('STATE')
        if code != 'STATE':
            self._bad('STATE answered %s' % code, text)
        d = dict(fields)
        for k in ('store_id', 'seq', 'tail', 'now_ms'):
            if k not in d:
                self._bad('STATE without %s' % k, text)
        return d

    def get(self, tenant, key):
        """KeyState, or a Refusal (TENANT_ISOLATION_BREACH: the key is another tenant's)."""
        text, code, fields, detail = self._exchange('GET %s %s' % (_local('tenant', tenant, ID_RE), _local('key', key, KEY_RE)))
        d = dict(fields)
        if code != 'OK':
            return self._refusal(text, code, fields, detail)
        if d.get('key') != key or not HASH_RE.match(d.get('hash', '')) or d.get('exists') not in ('0', '1'):
            self._bad('GET answer does not match the key asked', text)
        extra = {k: v for k, v in fields if k not in ('key', 'hash', 'exists', 'primitive', 'now_ms', 'skew_ms')}
        return KeyState(text, key, d['hash'], d['exists'] == '1', d.get('primitive'), extra, _dec('now_ms', d.get('now_ms'), text))

    def read_hashes(self, tenant, keys):
        """{key: present state hash} by one GET per key (NOT atomic with a later write). Raises LocalRefusal when a key
        is another tenant's (the GET refusal is in .detail)."""
        out = {}
        for k in keys:
            r = self.get(tenant, k)
            if isinstance(r, Refusal):
                raise LocalRefusal('LOCAL_REFUSED', 'GET %s answered %s' % (k, r.code), r.line)
            out[k] = r.hash
        return out

    # -- the DO line and its answer
    def _do(self, prim, op, tenant, keys, pre, args, request_id, star_ok):
        rid = request_id if request_id is not None else 'r' + secrets.token_hex(11)
        _local('request_id', rid, ID_RE)
        _local('tenant', tenant, ID_RE)
        keys = sorted(set(keys))
        for k in keys:
            _local('key', k, KEY_RE)
        if isinstance(pre, str) and pre not in ('*', 'read') and len(keys) == 1:
            pre = {keys[0]: pre}  # one key: a bare hash
        if pre == 'read':
            got = {}
            for k in keys:
                g = self.get(tenant, k)
                if isinstance(g, Refusal):
                    return g  # the engine's own refusal of the read (TENANT_ISOLATION_BREACH); no DO was sent
                got[k] = g.hash
            pre = got
        hashes = []
        for k in keys:
            if pre == '*':
                if not star_ok:
                    raise LocalRefusal('LOCAL_REFUSED', '%s %s needs the present state hash of every key (pre=dict or pre="read")' % (prim, op))
                hashes.append('*')
                continue
            if not isinstance(pre, dict) or k not in pre:
                raise LocalRefusal('LOCAL_REFUSED', 'pre: no state hash for key %s (pass a dict from get(), or pre="read")' % k)
            h = pre[k]
            if h != '*' or not star_ok:
                _local('pre[%s]' % k, h, HASH_RE)
            hashes.append(h)
        parts = ['DO', prim, op, rid, tenant, str(len(keys))]
        for k, h in zip(keys, hashes):
            parts += [k, h]
        line = ' '.join(parts) + (' ' + args if args else '')
        text, code, fields, detail = self._exchange(line)
        d = dict(fields)
        if code == 'COMMITTED':
            if not keys:
                self._bad('a stateless op answered COMMITTED', text)
            got = {k[5:]: v for k, v in fields if k.startswith('hash.')}
            if d.get('request_id') != rid or set(got) != set(keys) or len(set(got.values())) != 1 or not all(HASH_RE.match(v) for v in got.values()):
                self._bad('COMMITTED does not match the request (id or key hashes)', text)
            if 'effect' not in d:
                self._bad('COMMITTED without effect', text)
            return Committed(text, rid, _dec('seq', d.get('seq'), text), _dec('now_ms', d.get('now_ms'), text),
                             _dec('skew_ms', d.get('skew_ms'), text), got, d['effect'])
        if code == 'OK':
            if keys or 'verdict' not in d:
                self._bad('OK verdict= for an op with keys, or without verdict', text)
            rest = {k: v for k, v in fields if k not in ('verdict', 'now_ms', 'skew_ms')}
            return Verdict(text, d['verdict'], rest, detail, _dec('now_ms', d.get('now_ms'), text), _dec('skew_ms', d.get('skew_ms'), text))
        r = self._refusal(text, code, fields, detail)
        if r.durable:
            if r.request_id != rid or set(r.hashes) != set(keys):
                self._bad('a durable refusal does not match the request (id or key hashes)', text)
        elif code == 'STALE_STATE_HASH':
            if not r.hashes or not set(r.hashes) <= set(keys) or str(len(r.hashes)) != r.repair.get('stale'):
                self._bad('STALE_STATE_HASH does not match the request', text)
        return r

    def _refusal(self, text, code, fields, detail):
        if code in ('COMMITTED', 'OK', 'STATE', 'REPLAY', 'RECORD', 'INITIALIZED'):
            self._bad('a success word where a refusal was expected', text)
        d = dict(fields)
        durable = 'seq' in d
        hashes = {k[5:]: v for k, v in fields if k.startswith('hash.')}
        if not all(HASH_RE.match(v) for v in hashes.values()):
            self._bad('a state hash is not 64 lowercase hex', text)
        repair = {k: v for k, v in fields if k not in ENGINE_FIELDS and not (durable and k.startswith('hash.'))}
        return Refusal(text, code, repair, detail, durable=durable, request_id=d.get('request_id'),
                       seq=_dec('seq', d['seq'], text) if durable else None, hashes=hashes,
                       now_ms=int(d['now_ms']) if d.get('now_ms', '').isdigit() else None,
                       skew_ms=int(d['skew_ms']) if d.get('skew_ms', '').isdigit() else None)

    # -- primitive 6: rate_window
    def acquire(self, tenant, key, policy, volume, pre='*', request_id=None):
        """`DO rate_window acquire`: COMMITTED, or RATE_LIMIT_EXCEEDED retry_after_ms=, COOLDOWN_ACTIVE retry_after_ms=,
        VOLUME_ABOVE_CAP, POLICY_MISMATCH, UNKNOWN_POLICY (a Refusal)."""
        return self._do('rate_window', 'acquire', tenant, [key], pre,
                        '%s %s' % (_local('policy', policy, ID_RE), _uint('volume', volume)), request_id, True)

    # -- primitive 7: ledger_graph
    def open_accounts(self, tenant, ledger, balances, pre='read', request_id=None):
        """`open`: balances = {key: opening balance} (1..16 new accounts)."""
        keys = sorted(balances)
        args = ' '.join([_local('ledger', ledger, ID_RE)] + [_uint('balance', balances[k]) for k in keys])
        return self._do('ledger_graph', 'open', tenant, keys, pre, args, request_id, False)

    def transfer(self, tenant, ledger, from_key, to_key, amount, pre='read', request_id=None):
        args = '%s %s %s %s' % (_local('ledger', ledger, ID_RE), _local('from', from_key, KEY_RE), _local('to', to_key, KEY_RE), _uint('amount', amount))
        return self._do('ledger_graph', 'transfer', tenant, [from_key, to_key], pre, args, request_id, False)

    def post(self, tenant, ledger, legs, pre='read', request_id=None):
        """`post`: legs = {key: signed int}; negative = debit (leaves), positive = credit (enters). 0 is sent as `+0`
        (the engine refuses it: ZERO_AMOUNT)."""
        keys = sorted(legs)
        out = []
        for k in keys:
            v = legs[k]
            if isinstance(v, bool) or not isinstance(v, int):
                raise LocalRefusal('LOCAL_REFUSED', 'leg %s: not an int' % k)
            out.append(('-%d' % -v) if v < 0 else ('+%d' % v))
        return self._do('ledger_graph', 'post', tenant, keys, pre, ' '.join([_local('ledger', ledger, ID_RE)] + out), request_id, False)

    def mint(self, tenant, ledger, key, amount, pre='read', request_id=None):
        return self._do('ledger_graph', 'mint', tenant, [key], pre, '%s %s' % (_local('ledger', ledger, ID_RE), _uint('amount', amount)), request_id, False)

    def burn(self, tenant, ledger, key, amount, pre='read', request_id=None):
        return self._do('ledger_graph', 'burn', tenant, [key], pre, '%s %s' % (_local('ledger', ledger, ID_RE), _uint('amount', amount)), request_id, False)

    def claim(self, tenant, registry, name, pre='*', request_id=None):
        """`claim` on the caller's own handle `reg:<tenant>`. DUPLICATE_KEY registry= when the name is taken."""
        return self._do('ledger_graph', 'claim', tenant, ['reg:' + tenant], pre,
                        '%s %s' % (_local('registry', registry, ID_RE), _local('name', name, WORD_RE)), request_id, True)

    def release(self, tenant, registry, name, pre='*', request_id=None):
        return self._do('ledger_graph', 'release', tenant, ['reg:' + tenant], pre,
                        '%s %s' % (_local('registry', registry, ID_RE), _local('name', name, WORD_RE)), request_id, True)

    def add_edges(self, tenant, graph_key, policy, edges, pre='read', request_id=None):
        """`add_edge`: edges = [(from, to), ...], a batch (all or nothing). DAG_CYCLE_DETECTED edge= cycle_len= index=."""
        if not edges:
            raise LocalRefusal('LOCAL_REFUSED', 'edges: at least one edge')
        parts = [_local('policy', policy, ID_RE)]
        for a, b in edges:
            parts += [_local('from', a, NODE_RE), _local('to', b, NODE_RE)]
        return self._do('ledger_graph', 'add_edge', tenant, [graph_key], pre, ' '.join(parts), request_id, False)

    def remove_edge(self, tenant, graph_key, policy, from_node, to_node, pre='read', request_id=None):
        args = '%s %s %s' % (_local('policy', policy, ID_RE), _local('from', from_node, NODE_RE), _local('to', to_node, NODE_RE))
        return self._do('ledger_graph', 'remove_edge', tenant, [graph_key], pre, args, request_id, False)

    # -- primitive 8: taint_egress
    def taint_check(self, tenant, policy, destination, document, request_id=None):
        """`DO taint_egress check`. document: a JSON text (str, printable ASCII) sent as it is, or a Python value
        serialized ONCE (ensure_ascii). Verdict ALLOW (.document = the exact text sent; sha256 and bytes checked),
        or a Refusal (TAINT_EGRESS_BLOCKED json_path= label= more=, UNLABELLED_FIELD, ...). Emit only .document."""
        text = document if isinstance(document, str) else _ascii_json('document', document)
        if not text or any(not (0x20 <= ord(c) <= 0x7e) for c in text) or text[0] == ' ' or text[-1] == ' ':
            raise LocalRefusal('LOCAL_REFUSED', 'document: printable ASCII JSON text without a leading or trailing space')
        args = '%s %s %s' % (_local('policy', policy, ID_RE), _local('destination', destination, WORD_RE), text)
        r = self._do('taint_egress', 'check', tenant, [], {}, args, request_id, False)
        if isinstance(r, Verdict):
            raw = text.encode('ascii')
            if r.fields.get('sha256') != hashlib.sha256(raw).hexdigest() or r.fields.get('bytes') != str(len(raw)):
                self._bad('ALLOW is not bound to the bytes sent (sha256/bytes)', r.line)
            r.document = text
        return r

    # -- primitive 9: farkas
    def farkas_check(self, tenant, A, b, y, request_id=None):
        """`DO farkas check`: Verdict INFEASIBILITY_PROVED (scope=nonneg_integer_x), or a Refusal (CERT_REJECTED
        reason=, SHAPE why=, OVERFLOW, MALFORMED_REQUEST why=FARKAS_*). A refusal never means "feasible"."""
        for name, v in (('A', A), ('b', b), ('y', y)):
            flat = [x for row in v for x in row] if name == 'A' and isinstance(v, list) and all(isinstance(r, list) for r in v) else v
            if not isinstance(flat, list) or any(isinstance(x, bool) or not isinstance(x, int) for x in flat):
                raise LocalRefusal('LOCAL_REFUSED', '%s: not a list of ints' % name)
        vec = lambda v: '[' + ','.join(str(x) for x in v) + ']'  # noqa: E731
        system = '{"A":[%s],"b":%s}' % (','.join(vec(r) for r in A), vec(b))
        doc = '{"A":[%s],"b":%s,"y":%s}' % (','.join(vec(r) for r in A), vec(b), vec(y))
        r = self._do('farkas', 'check', tenant, [], {}, doc, request_id, False)
        sys_h = hashlib.sha256(system.encode('ascii')).hexdigest()
        if isinstance(r, Verdict):
            if r.fields.get('system_sha256') != sys_h or r.fields.get('cert_sha256') != hashlib.sha256(('{"y":%s}' % vec(y)).encode('ascii')).hexdigest():
                self._bad('INFEASIBILITY_PROVED is not bound to the system and certificate sent', r.line)
        elif 'system_sha256' in r.repair and r.repair['system_sha256'] != sys_h:
            self._bad('a farkas refusal names another system', r.line)
        return r
