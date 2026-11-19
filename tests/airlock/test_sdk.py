#!/usr/bin/env python3
"""FINITE TEST of the forge-airlock SDKs (sdk/py and sdk/ts), Goal 20. It proves nothing. end_to_end=false.

Usage: python3 tests/airlock/test_sdk.py --engine-dir build/airlock [--node PATH] [--case NAME]... [--keep]

Every typed result is reached for real through the engine (build/airlock/airlock-engine via bin/forge-airlock serve),
and each case checks the store afterwards with the engine's own `replay` / `leases`. The TypeScript cases run
examples/unbreakable_store/ts_part.ts through Node 24 (built-in type stripping) with sdk/ts/forge_airlock.ts.
ONE kind of test double exists here: a STAND-IN ENGINE script (labelled STAND-IN) used ONLY by the *_garbage cases,
to feed the SDK answer lines that the real engine never gives. Nothing else is mocked.
A case that cannot run FAILS with NOT RUN; it never passes. Exit 0 only if every selected case passed.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'sdk' / 'py'))
import forge_airlock as fa  # noqa: E402

DISPATCHER = ROOT / 'bin' / 'forge-airlock'
FIX = ROOT / 'tests' / 'airlock' / 'fixtures'
TS_PART = ROOT / 'examples' / 'unbreakable_store' / 'ts_part.ts'
POLICIES = ('money-parametric', 'money-canonical', 'saga-payout', 'inventory-seats')
CERT_OK = {'A': [['1', '1', '1']], 'c': ['2'], 'w': ['5', '3', '2'], 'x': ['1', '1', '0'], 'y': ['3'], 'z': ['2', '0', '0'], 'alpha_bps': '0'}
CERT_OVERBOOK = dict(CERT_OK, x=['1', '1', '1'])
CERT_GAP = dict(CERT_OK, x=['1', '0', '1'])

STANDIN = r'''#!/usr/bin/env python3
# STAND-IN ENGINE (test double of the serve process; protocol-robustness tests ONLY). It answers each request line
# with a fixed bad answer. It is never used for a block, a crash or a commit that a result reports.
import sys, time
mode = sys.argv[1]
line = sys.stdin.buffer.readline()
out = sys.stdout.buffer
answers = {
  'unknown-token': b'COMMITTEDX r1 5 ' + b'a' * 32 + b' REFUND t1 k1 r1 X 1 0\n',
  'lowercase': b'committed r1 5 ' + b'a' * 32 + b' REFUND t1 k1 r1 X 1 0\n',
  'other-request': b'COMMITTED other 5 ' + b'a' * 32 + b' REFUND t1 k1 other X 1 0\n',
  'short-hash': b'COMMITTED r1 5 abc REFUND t1 k1 r1 X 1 0\n',
  'ok-for-write': b'OK 1\n',
  'two-lines': b'REJECTED_POLICY TOTAL_CAP\nCOMMITTED r1 5 ' + b'a' * 32 + b' REFUND t1 k1 r1 X 1 0\n',
  'binary': b'\xff\xfeCOMMITTED\n',
  'empty-line': b'\n',
  'no-detail': b'REJECTED_POLICY\n',
  'ok-one': b'OK 1\n',
}
if mode == 'short-read':
    out.write(b'COMMITTED r1 5 ' + b'a' * 32); out.flush(); sys.exit(0)
if mode == 'exit':
    sys.exit(0)
if mode == 'silent':
    time.sleep(30); sys.exit(0)
out.write(answers[mode]); out.flush()
time.sleep(2)
'''
GARBAGE_MODES = ('unknown-token', 'lowercase', 'other-request', 'short-hash', 'ok-for-write', 'two-lines', 'binary',
                 'empty-line', 'no-detail', 'short-read', 'exit', 'silent')


class Failed(Exception):
    pass


def require(cond, msg):
    if not cond:
        raise Failed(msg)


class Suite:
    def __init__(self, a):
        self.node = a.node
        self.engine_dir = Path(a.engine_dir).resolve()
        self.work = Path(tempfile.mkdtemp(prefix='airlock-sdk-'))
        self.n = 0

    def folder(self, name):
        self.n += 1
        p = self.work / ('%03d-%s' % (self.n, name))
        p.mkdir()
        return p

    def cli(self, args, stdin=b''):
        if args[0] in ('init', 'replay', 'leases', 'state', 'get', 'cosign-message'):
            args = list(args) + ['--engine-dir', self.engine_dir]
        p = subprocess.run([sys.executable, str(DISPATCHER)] + [str(x) for x in args], input=stdin, capture_output=True, timeout=300)
        return p.returncode, p.stdout.decode('ascii', 'replace'), p.stderr.decode('utf-8', 'replace')

    def store(self, name, pubkey=None, store_id=None):
        path = self.folder(name) / 'store'
        args = ['init', path, '--store-id', store_id or ('st-' + name)[:24]]
        for p in POLICIES:
            args += ['--policy', FIX / (p + '.json')]
        if pubkey:
            args += ['--cosign-pubkey', pubkey]
        code, out, err = self.cli(args)
        require(code == 0 and out.startswith('INITIALIZED '), 'init %s: %d %r %r' % (name, code, out, err))
        return path

    def open(self, path, **kw):
        return fa.Store(path, node=self.node, engine_dir=self.engine_dir, **kw)

    def keygen(self, name):
        d = Path(tempfile.mkdtemp(prefix='airlock-key-'))
        code, out, err = self.cli(['cosign-keygen', d / 'key', '--node', self.node])
        require(code == 0, 'NOT RUN: keygen: %r' % err)
        return d, d / 'key', out.strip()

    def sign(self, key, msg):
        code, out, err = self.cli(['cosign-sign', key, '--node', self.node], stdin=msg)
        require(code == 0, 'sign: %r' % err)
        return out.strip()

    def effects(self, path):
        code, out, _ = self.cli(['replay', path])
        require(code == 0, 'replay: %d %r' % (code, out))
        return [ln.split(' ', 2)[2] for ln in out.split('\n')[1:] if ln]

    def leases(self, path):
        code, out, _ = self.cli(['leases', path])
        require(code == 0, 'leases: %r' % out)
        return [ln.split(' ')[1] for ln in out.split('\n')[1:] if ln]

    def ts(self, plan):
        require(Path(self.node).exists(), 'NOT RUN: node %s is missing' % self.node)
        f = self.folder('plan') / 'plan.json'
        f.write_text(json.dumps(plan))
        p = subprocess.run([self.node, str(TS_PART), str(f)], capture_output=True, timeout=300)
        out = p.stdout.decode('utf-8', 'replace').strip().split('\n')[-1]
        require(p.returncode == 0 and out.startswith('{'), 'NOT RUN: ts_part exit %d %r %r' % (p.returncode, out[:300], p.stderr[-600:]))
        res = json.loads(out)
        require('fatal' not in res, 'ts_part fatal: %s' % res.get('fatal', '')[:400])
        return {s['step']: s for s in res['steps']}

    def standin(self):
        d = self.folder('standin')
        (d / 'engine.py').write_text(STANDIN)
        return d / 'engine.py'


def expect(res, code, msg):
    require(isinstance(res, fa.Result) and res.code == code, '%s: expected %s, got %r' % (msg, code, res))
    return res


def raises(fn, cls, msg):
    try:
        r = fn()
    except cls as e:
        return e
    except fa.AirlockError as e:
        raise Failed('%s: expected %s, got %s %s' % (msg, cls.__name__, type(e).__name__, e))
    raise Failed('%s: expected %s, got a result %r' % (msg, cls.__name__, r))


# ------------------------------------------------------------------------------------------------ Python cases

def case_py_typed(s):
    p = s.store('py-typed')
    with s.open(p) as st:
        expect(st.open_money('t1', 'o1', 'r0', 'store-refunds', 10000, {'shipping_paid': 1000}), 'COMMITTED', 'open')
        h = st.get('t1', 'o1').state_hash
        r = expect(st.refund('t1', 'o1', 'r1', h, 'DUPLICATE_CHARGE', 500), 'COMMITTED', 'refund')
        require(r.committed and r.request_id == 'r1' and r.state_hash != h, 'COMMITTED fields: %r' % r.line)
        expect(st.refund('t1', 'o1', 'r2', r.state_hash, 'SHIPPING', 8000), 'REJECTED_POLICY', 'shipping cap')
        expect(st.refund('t1', 'o1', 'r3', r.state_hash, 'GOODWILL', 7500), 'REQUIRE_HUMAN_COSIGN', 'goodwill')
        stale = expect(st.refund('t1', 'o1', 'r4', h, 'DUPLICATE_CHARGE', 5), 'STALE_STATE_HASH', 'stale')
        require(stale.state_hash == r.state_hash, 'stale detail names the present hash')
        expect(st.refund('t1', 'o1', 'r1', r.state_hash, 'DUPLICATE_CHARGE', 5), 'DUPLICATE_REQUEST_ID', 'duplicate')
        expect(st.refund('t2', 'o1', 'r5', r.state_hash, 'DUPLICATE_CHARGE', 5), 'TENANT_ISOLATION_BREACH', 'other tenant write')
        expect(st.get('t2', 'o1'), 'TENANT_ISOLATION_BREACH', 'other tenant get')
        raises(lambda: st.refund('t1', 'nokey', 'r6', r.state_hash, 'DUPLICATE_CHARGE', 5), fa.EngineRefusal, 'unknown key')
        e = raises(lambda: st.refund('t1', 'o1', 'r6', r.state_hash, 'DUPLICATE_CHARGE', '01'), fa.EngineRefusal, 'non-canonical amount')
        require(e.code == 'MALFORMED_REQUEST', 'code: %r' % e.code)
        for bad in ('r\n7', 'r\r7', 'r\x007', 'r 7', 'ré7', 'r' * 25, ''):
            raises(lambda: st.refund('t1', 'o1', bad, r.state_hash, 'DUPLICATE_CHARGE', 5), fa.LocalRefusal, 'unsafe id %r' % bad)
        raises(lambda: st.refund('t1', 'o1', 'r7', r.state_hash, 'DUPLICATE_CHARGE', '5\n'), fa.LocalRefusal, 'LF in amount')
        raises(lambda: st.refund('t1', 'o1', 'r7', r.state_hash, 'DUPLICATE_CHARGE', True), fa.LocalRefusal, 'bool amount')

        def boom(lease):
            raise RuntimeError('handler bug')
        try:
            st.with_lease('L1', 1000, boom)
            raise Failed('the handler exception did not propagate')
        except RuntimeError:
            pass
        expect(st.state(), 'OK', 'stream in step after refusals')
    sw = s.open(p)
    try:
        d = expect(sw.sweep(now_ms=1001), 'DROPPED_OBLIGATION', 'sweep')
        require(d.dropped == [('L1', 1000)], 'dropped: %r' % d.dropped)
    finally:
        sw.close()
    eff = s.effects(p)
    require(eff == ['OPEN_MONEY t1 o1 r0 store-refunds 10000 shipping_paid=1000', 'REFUND t1 o1 r1 DUPLICATE_CHARGE 500 0'], 'WAL effects: %r' % eff)
    return 'all 7 typed results from the real engine; UNKNOWN_KEY and MALFORMED_REQUEST raise EngineRefusal; 9 unsafe inputs refused locally; WAL = 2 effects'


def case_py_cosign(s):
    d, key, pub = s.keygen('human')
    d2, key2, _ = s.keygen('other')
    try:
        p = s.store('py-cosign', pubkey=pub, store_id='store-cosign')
        with s.open(p) as st:
            st.open_money('t1', 'o1', 'r0', 'store-refunds', 10000)
            h = st.get('t1', 'o1').state_hash
            msg = st.cosign_message(fa.refund_action('t1', 'o1', 'g1', h, 'GOODWILL', 7500))
            expect(st.refund('t1', 'o1', 'g1', h, 'GOODWILL', 7500), 'REQUIRE_HUMAN_COSIGN', 'no signature')
            r = expect(st.refund('t1', 'o1', 'g1', h, 'GOODWILL', 7500, s.sign(key2, msg)), 'REQUIRE_HUMAN_COSIGN', 'other key')
            require(r.detail == 'COSIGN_INVALID', 'other key detail %r' % r.detail)
            r = expect(st.refund('t1', 'o1', 'g1', h, 'GOODWILL', 7500, s.sign(key, msg)), 'COMMITTED', 'pinned key')
            require(r.payload.endswith(' 1'), 'cosign flag: %r' % r.payload)
        require(s.effects(p)[-1] == 'REFUND t1 o1 g1 GOODWILL 7500 1', 'WAL: %r' % s.effects(p))
    finally:
        shutil.rmtree(d, ignore_errors=True)
        shutil.rmtree(d2, ignore_errors=True)
    return 'temporary keys: no signature and another key -> REQUIRE_HUMAN_COSIGN; pinned key -> COMMITTED (flag 1); keys deleted'


def case_py_canonical(s):
    p = s.store('py-canon')
    with s.open(p) as st:
        expect(st.open_money('t1', 'ch1', 'c0', 'canonical', 10000), 'COMMITTED', 'open canonical')
        h = st.get('t1', 'ch1').state_hash
        r = expect(st.refund('t1', 'ch1', 'c1', h, 'returned_item', 5000000), 'REJECTED_POLICY', 'over the charge')
        require(r.detail == 'CAKEML_REJECTED', 'detail %r' % r.detail)
        r = expect(st.refund('t1', 'ch1', 'c2', h, 'goodwill', 100), 'REJECTED_POLICY', 'unapproved reason')
        require(r.detail == 'CAKEML_REJECTED', 'detail %r' % r.detail)
        expect(st.refund('t1', 'ch1', 'c3', h, 'returned_item', 2500), 'COMMITTED', 'canonical refund')
    require(s.effects(p)[-1] == 'REFUND t1 ch1 c3 returned_item 2500 0', 'WAL')
    return 'PROVED CORE decision (CakeML binary b8ed5ec2...7bb8): 2 CAKEML_REJECTED, 1 COMMITTED'


def case_py_saga_inventory(s):
    require((s.engine_dir / 'checker' / 'model.cjs').is_file(), 'NOT RUN: build/airlock/checker/model.cjs is missing')
    p = s.store('py-saga-inv')
    with s.open(p) as st:
        st.open_saga('t1', 'pay1', 's0', 'payout')
        h = st.get('t1', 'pay1').state_hash
        r = expect(st.saga('t1', 'pay1', 's1', h, 'IN_FLIGHT', 'stripe', 'idem-1'), 'COMMITTED', 'in flight')
        r2 = expect(st.saga('t1', 'pay1', 's2', r.state_hash, 'IN_FLIGHT', 'paypal', 'idem-2'), 'REJECTED_POLICY', 'failover')
        require(r2.detail == 'PROCESSOR_IN_FLIGHT', 'detail %r' % r2.detail)
        st.open_inventory('t1', 'seats', 'i0', 'seats', [2])
        h = st.get('t1', 'seats').state_hash
        expect(st.book('t1', 'seats', 'b1', h, CERT_OVERBOOK), 'REJECTED_POLICY', 'overbook')
        expect(st.book('t1', 'seats', 'b2', h, CERT_GAP), 'REJECTED_POLICY', 'gap')
        expect(st.book('t1', 'seats', 'b3', h, CERT_OK), 'COMMITTED', 'optimum')
        require(st.get('t1', 'seats').fields['remaining'] == '0', 'remaining')
    return 'saga failover while IN_FLIGHT refused; inventory: 2 buggy batches rejected, optimum COMMITTED through the checker'


def case_py_read(s):
    p = s.store('py-read')
    with s.open(p) as st:
        good = [{'tenant_id': 'tA', 'total': 12}, {'tenant_id': 'tA', 'n': None}]
        r = expect(st.read_scoped('tA', good), 'OK', 'good rows')
        require(r.rows == good, 'rows released')
        expect(st.read_scoped('tA', []), 'OK', 'zero rows')
        bad = {'missing tenant_id': [{'tenant_id': 'tA'}, {'total': 1}],
               'wrong tenant': [{'tenant_id': 'tA'}, {'tenant_id': 'tB', 'secret': 'x' * 100}],
               'row tenant not a string': [{'tenant_id': 1}],
               'row tenant empty': [{'tenant_id': ''}],
               'row not an object': [['tA']],
               'lone surrogate': [{'tenant_id': 'tA', 's': '\ud800'}]}
        for why, rows in bad.items():
            r = expect(st.read_scoped('tA', rows), 'TENANT_ISOLATION_BREACH', why)
            require(r.rows == [] and not r.detail.startswith('LOCAL'), '%s: engine answer with 0 rows: %r' % (why, r.detail))
        for why, tenant in {'empty caller tenant': '', 'non-string caller tenant': 5, 'None tenant': None, 'LF tenant': 'tA\n'}.items():
            r = expect(st.read_scoped(tenant, good), 'TENANT_ISOLATION_BREACH', why)
            require(r.rows == [], why)
        r = expect(st.read_scoped('tA', [{'tenant_id': 'tA', 'f': float('nan')}]), 'TENANT_ISOLATION_BREACH', 'NaN row')
        require(r.rows == [] and r.detail.startswith('LOCAL'), 'NaN')
        expect(st.state(), 'OK', 'stream in step')
    return '2 good rows released; 6 bad row sets refused by the engine and 5 bad inputs refused locally, 0 rows each'


def case_py_lease(s):
    p = s.store('py-lease')
    with s.open(p) as st:
        st.open_money('t1', 'o1', 'r0', 'store-refunds', 10000, {'shipping_paid': 1000})

        def commit(lease):
            h = st.get('t1', 'o1').state_hash
            return lease.commit('refund', tenant='t1', key='o1', pre_state_hash=h, reason='DUPLICATE_CHARGE', amount=100)

        def rejected(lease):
            h = st.get('t1', 'o1').state_hash
            return lease.commit('refund', tenant='t1', key='o1', pre_state_hash=h, reason='SHIPPING', amount=8000)

        def throws(lease):
            event = None
            return event['data']  # a real TypeError before the sink

        r = expect(st.with_lease('w1', 5000, commit), 'COMMITTED', 'commit handler')
        r = expect(st.with_lease('w2', 5000, rejected), 'REJECTED_POLICY', 'rejected handler')
        require(r.lease_closed is not None, 'LEASE_CLOSED part: %r' % r.line)
        try:
            st.with_lease('w3', 5000, throws)
            raise Failed('TypeError did not propagate')
        except TypeError:
            pass
        require(st.with_lease('w4', 5000, lambda lease: 'done') == 'done', 'return value')
        e = raises(lambda: st.with_lease('w4', 5000, lambda lease: 1 / 0), fa.LeaseNotOpened, 'second lease on an open id')
        require(e.result.code == 'DUPLICATE_REQUEST_ID', 'code %r' % e.result.code)
        d = expect(st.sweep(now_ms=5001), 'DROPPED_OBLIGATION', 'sweep')
        require(sorted(x for x, _ in d.dropped) == ['w3', 'w4'], 'dropped %r' % d.dropped)
        expect(st.sweep(now_ms=5000), 'OK', 'deadline itself is not past')
    require(s.leases(p) == ['w3', 'w4'], 'open leases: %r' % s.leases(p))
    return 'commit and policy rejection close the lease; TypeError and no-sink handlers leave it open; sweep -> DROPPED_OBLIGATION w3, w4'


def case_py_kill(s):
    p = s.store('py-kill')
    st = s.open(p)
    st.open_money('t1', 'o1', 'r0', 'store-refunds', 10000)
    h = st.get('t1', 'o1').state_hash
    os.kill(st.pid, signal.SIGKILL)
    time.sleep(0.2)
    e = raises(lambda: st.refund('t1', 'o1', 'r1', h, 'DUPLICATE_CHARGE', 5), fa.EngineDead, 'after SIGKILL')
    require(e.outcome_known is False, 'outcome unknown')
    raises(lambda: st.state(), fa.EngineDead, 'closed client stays closed')
    st.close()
    require(len(s.effects(p)) == 1, 'nothing committed')
    # kill DURING a commit: the kill build stops after the record is durable and before the answer (point c)
    kill = s.engine_dir / 'airlock-engine-kill'
    require(kill.is_file(), 'NOT RUN: %s is missing' % kill)
    st = fa.Store(p, serve_argv=[str(kill), 'serve', str(p)], env={'PATH': '/usr/bin:/bin', 'AIRLOCK_KILL_AT': 'c'}, timeout=30)
    killer = threading.Timer(1.5, lambda: os.kill(st.pid, signal.SIGKILL))
    killer.start()
    e = raises(lambda: st.refund('t1', 'o1', 'r2', h, 'DUPLICATE_CHARGE', 7), fa.EngineDead, 'killed mid-commit')
    killer.join()
    st.close()
    require(e.outcome_known is False, 'mid-commit kill must be an unknown outcome')
    eff = s.effects(p)
    with s.open(p) as again:
        dup = again.refund('t1', 'o1', 'r2', h, 'DUPLICATE_CHARGE', 7)
    require(eff[-1] == 'REFUND t1 o1 r2 DUPLICATE_CHARGE 7 0' and dup.code == 'DUPLICATE_REQUEST_ID',
            'durable record, never answered COMMITTED, retry -> DUPLICATE_REQUEST_ID: %r %r' % (eff[-1], dup))
    return 'SIGKILL between requests -> EngineDead; SIGKILL after the durable record (kill point c) -> EngineDead, outcome unknown, never COMMITTED'


def case_py_garbage(s):
    eng = s.standin()
    seen = []
    for mode in GARBAGE_MODES:
        st = fa.Store('unused', serve_argv=[sys.executable, str(eng), mode], timeout=2 if mode == 'silent' else 20)
        try:
            st.refund('t1', 'k1', 'r1', 'a' * 32, 'X', 1)
            raise Failed('STAND-IN %s: the SDK returned a result' % mode)
        except (fa.ProtocolError, fa.EngineDead, fa.EngineTimeout) as e:
            require(e.outcome_known is False, '%s: outcome must be unknown' % mode)
            seen.append(type(e).__name__)
        finally:
            st.close()
    return 'STAND-IN engine (protocol robustness only): %d garbage answers -> %s; never COMMITTED' % (len(seen), ','.join(sorted(set(seen))))


def case_py_protocol(s):
    """read_scoped against a STAND-IN engine that answers `OK 1` for two rows; the two local guards on their own."""
    eng = s.standin()
    st = fa.Store('unused', serve_argv=[sys.executable, str(eng), 'ok-one'], timeout=20)
    try:
        r = st.read_scoped('tA', [{'tenant_id': 'tA'}, {'tenant_id': 'tB', 'secret': 'x'}])
        raise Failed('STAND-IN ok-one: read_scoped released rows on an OK for another row count: %r %r' % (r, r.rows))
    except fa.ProtocolError as e:
        require(e.outcome_known is False, 'outcome unknown')
    finally:
        st.close()
    # the field guard alone (build_line, no engine): LF, CR, NUL in an amount text
    for bad in ('5\n', '5\r', '5\x00'):
        try:
            fa.build_line('refund', {'tenant': 't1', 'key': 'k1', 'request_id': 'r1', 'pre_state_hash': 'a' * 32, 'reason': 'X', 'amount': bad})
            raise Failed('the field guard let %r through build_line' % bad)
        except fa.LocalRefusal:
            pass
    # the line guard alone (_send): a request line with a line end inside is refused before the pipe
    st = fa.Store('unused', serve_argv=[sys.executable, str(eng), 'exit'], timeout=5)
    try:
        st._send('STATE\nSTATE')
        raise Failed('the line guard let a line end through _send')
    except fa.LocalRefusal:
        pass
    except fa.AirlockError as e:
        raise Failed('the line guard let a line end through _send (the engine answered: %s)' % type(e).__name__)
    finally:
        st.close()
    return 'OK for another row count -> ProtocolError, 0 rows; field guard refuses LF/CR/NUL; line guard refuses a line end'


def case_py_lease_durable(s):
    """The lease is durable before the handler runs: the handler itself sees it with the engine's `leases`."""
    p = s.store('py-lease-durable')
    with s.open(p) as st:
        seen = st.with_lease('d1', 5000, lambda lease: s.leases(p))
    require(seen == ['d1'], 'the lease was not durable when the handler ran: leases seen by the handler %r' % seen)
    return 'the handler saw its lease in the WAL (engine leases)'


# ------------------------------------------------------------------------------------------------ TypeScript cases

def plan(s, store, steps, **kw):
    d = {'store': str(store), 'node': s.node, 'python': sys.executable, 'engine_dir': str(s.engine_dir), 'steps': steps}
    d.update(kw)
    return s.ts(d)


def case_ts_typed(s):
    p = s.store('ts-typed')
    R = lambda name, op, **f: {'do': 'commit', 'name': name, 'op': op, 'fields': f}  # noqa: E731
    o = plan(s, p, [
        R('open', 'open_money', tenant='t1', key='o1', request_id='r0', policy='store-refunds', original=10000, facts={'shipping_paid': 1000}),
        {'do': 'get', 'name': 'get', 'tenant': 't1', 'key': 'o1', 'save': 'h0'},
        dict(R('refund', 'refund', tenant='t1', key='o1', request_id='r1', pre_state_hash='$h0', reason='DUPLICATE_CHARGE', amount=500), save='h1'),
        R('cap', 'refund', tenant='t1', key='o1', request_id='r2', pre_state_hash='$h1', reason='SHIPPING', amount=8000),
        R('cosign', 'refund', tenant='t1', key='o1', request_id='r3', pre_state_hash='$h1', reason='GOODWILL', amount=7500),
        R('stale', 'refund', tenant='t1', key='o1', request_id='r4', pre_state_hash='$h0', reason='DUPLICATE_CHARGE', amount=5),
        R('dup', 'refund', tenant='t1', key='o1', request_id='r1', pre_state_hash='$h1', reason='DUPLICATE_CHARGE', amount=5),
        R('tenant', 'refund', tenant='t2', key='o1', request_id='r5', pre_state_hash='$h1', reason='DUPLICATE_CHARGE', amount=5),
        R('unknown-key', 'refund', tenant='t1', key='nokey', request_id='r6', pre_state_hash='$h1', reason='DUPLICATE_CHARGE', amount=5),
        R('malformed', 'refund', tenant='t1', key='o1', request_id='r6', pre_state_hash='$h1', reason='DUPLICATE_CHARGE', amount='01'),
        R('lf-id', 'refund', tenant='t1', key='o1', request_id='r\n7', pre_state_hash='$h1', reason='DUPLICATE_CHARGE', amount=5),
        R('nul-id', 'refund', tenant='t1\u0000', key='o1', request_id='r7', pre_state_hash='$h1', reason='DUPLICATE_CHARGE', amount=5),
        R('cr-amount', 'refund', tenant='t1', key='o1', request_id='r7', pre_state_hash='$h1', reason='DUPLICATE_CHARGE', amount='5\r'),
        R('unsafe-number', 'refund', tenant='t1', key='o1', request_id='r7', pre_state_hash='$h1', reason='DUPLICATE_CHARGE', amount=2 ** 64),
        {'do': 'lease', 'name': 'lease-throw', 'request_id': 'L1', 'deadline_ms': 1000, 'handler': 'typeerror_before_sink', 'event': '{}',
         'fields': {'tenant': 't1', 'key': 'o1', 'pre_state_hash': '$h1', 'reason': 'DUPLICATE_CHARGE'}},
        {'do': 'sweep', 'name': 'sweep', 'now_ms': 1001},
        {'do': 'state', 'name': 'state'},
        R('open-saga', 'open_saga', tenant='t1', key='pay1', request_id='s0', policy='payout'),
        {'do': 'get', 'name': 'get-saga', 'tenant': 't1', 'key': 'pay1', 'save': 'hs'},
        dict(R('in-flight', 'saga', tenant='t1', key='pay1', request_id='s1', pre_state_hash='$hs', to_state='IN_FLIGHT', processor='stripe',
               idempotency_key='idem-1'), save='hs1'),
        R('failover', 'saga', tenant='t1', key='pay1', request_id='s2', pre_state_hash='$hs1', to_state='IN_FLIGHT', processor='paypal', idempotency_key='idem-2'),
        R('open-inv', 'open_inventory', tenant='t1', key='seats', request_id='i0', policy='seats', capacities=[2]),
        {'do': 'get', 'name': 'get-inv', 'tenant': 't1', 'key': 'seats', 'save': 'hi'},
        R('book-bad', 'book', tenant='t1', key='seats', request_id='b1', pre_state_hash='$hi', certificate=CERT_OVERBOOK),
        R('book', 'book', tenant='t1', key='seats', request_id='b2', pre_state_hash='$hi', certificate=CERT_OK),
    ])
    want = {'open': 'COMMITTED', 'refund': 'COMMITTED', 'cap': 'REJECTED_POLICY', 'cosign': 'REQUIRE_HUMAN_COSIGN', 'stale': 'STALE_STATE_HASH',
            'dup': 'DUPLICATE_REQUEST_ID', 'tenant': 'TENANT_ISOLATION_BREACH', 'sweep': 'DROPPED_OBLIGATION', 'state': 'OK',
            'open-saga': 'COMMITTED', 'in-flight': 'COMMITTED', 'failover': 'REJECTED_POLICY', 'open-inv': 'COMMITTED', 'book-bad': 'REJECTED_POLICY'}
    if (s.engine_dir / 'checker' / 'model.cjs').is_file():
        want['book'] = 'COMMITTED'
    else:
        raise Failed('NOT RUN: build/airlock/checker/model.cjs is missing')
    for k, v in want.items():
        require(o[k].get('code') == v and 'error' not in o[k], 'TS %s: expected %s, got %r' % (k, v, o[k]))
    require(o['unknown-key'].get('error') == 'EngineRefusal' and o['unknown-key']['code'] == 'UNKNOWN_KEY', 'TS unknown key %r' % o['unknown-key'])
    require(o['malformed'].get('error') == 'EngineRefusal' and o['malformed']['code'] == 'MALFORMED_REQUEST', 'TS malformed %r' % o['malformed'])
    for k in ('lf-id', 'nul-id', 'cr-amount', 'unsafe-number'):
        require(o[k].get('error') == 'LocalRefusal', 'TS %s: %r' % (k, o[k]))
    require(o['lease-throw'].get('is_type_error') is True, 'TS TypeError propagated: %r' % o['lease-throw'])
    require(o['sweep']['dropped'] == [['L1', '1000']], 'TS dropped %r' % o['sweep'])
    eff = s.effects(p)
    require(len(eff) == 6 and eff[1] == 'REFUND t1 o1 r1 DUPLICATE_CHARGE 500 0' and eff[-1].startswith('BOOK t1 seats b2 '), 'WAL %r' % eff)
    return 'TS SDK: all 7 typed results from the real engine; EngineRefusal x2; 4 unsafe inputs refused locally; saga and inventory verbs; WAL = 6 effects'


def case_ts_read(s):
    p = s.store('ts-read')
    good = [{'tenant_id': 'tA', 'x': 1}, {'tenant_id': 'tA', 's': 'café'}]
    o = plan(s, p, [
        {'do': 'read', 'name': 'good', 'tenant': 'tA', 'rows': good},
        {'do': 'read', 'name': 'zero', 'tenant': 'tA', 'rows': []},
        {'do': 'read', 'name': 'missing', 'tenant': 'tA', 'rows': [{'tenant_id': 'tA'}, {'x': 1}]},
        {'do': 'read', 'name': 'wrong', 'tenant': 'tA', 'rows': [{'tenant_id': 'tB', 'secret': 'x' * 50}]},
        {'do': 'read', 'name': 'row-number', 'tenant': 'tA', 'rows': [{'tenant_id': 7}]},
        {'do': 'read', 'name': 'empty-caller', 'tenant': '', 'rows': good},
        {'do': 'read', 'name': 'number-caller', 'tenant': 5, 'rows': good},
        {'do': 'read', 'name': 'null-caller', 'tenant': None, 'rows': good},
        {'do': 'state', 'name': 'state'},
    ])
    require(o['good']['code'] == 'OK' and o['good']['rows'] == 2 and o['zero']['code'] == 'OK', 'TS good rows %r' % o['good'])
    for k in ('missing', 'wrong', 'row-number', 'empty-caller', 'number-caller', 'null-caller'):
        require(o[k].get('code') == 'TENANT_ISOLATION_BREACH' and o[k]['rows'] == 0 and o[k]['rows_bytes'] == 0, 'TS %s: %r' % (k, o[k]))
    for k in ('missing', 'wrong', 'row-number'):
        require(not o[k]['detail'].startswith('LOCAL'), 'TS %s must be the engine answer' % k)
    require(o['state']['code'] == 'OK', 'TS stream in step')
    return 'TS SDK: 2 good rows released; missing, wrong, non-string row tenant (engine) and empty, number, null caller tenant (local) -> 0 rows'


def case_ts_lease(s):
    p = s.store('ts-lease')
    rf = {'tenant': 't1', 'key': 'o1', 'pre_state_hash': '$h', 'reason': 'DUPLICATE_CHARGE', 'amount': 100}
    o = plan(s, p, [
        {'do': 'commit', 'name': 'open', 'op': 'open_money', 'fields': {'tenant': 't1', 'key': 'o1', 'request_id': 'r0', 'policy': 'store-refunds',
                                                                       'original': 10000, 'facts': {'shipping_paid': 1000}}},
        {'do': 'get', 'name': 'get', 'tenant': 't1', 'key': 'o1', 'save': 'h'},
        {'do': 'lease', 'name': 'commit', 'request_id': 'w1', 'deadline_ms': 5000, 'handler': 'commit', 'op': 'refund', 'fields': rf},
        {'do': 'get', 'name': 'get2', 'tenant': 't1', 'key': 'o1', 'save': 'h'},
        {'do': 'lease', 'name': 'rejected', 'request_id': 'w2', 'deadline_ms': 5000, 'handler': 'commit', 'op': 'refund',
         'fields': dict(rf, reason='SHIPPING', amount=8000)},
        {'do': 'lease', 'name': 'throws', 'request_id': 'w3', 'deadline_ms': 5000, 'handler': 'typeerror_before_sink', 'event': '{"id":"evt"}', 'fields': rf},
        {'do': 'lease', 'name': 'no-sink', 'request_id': 'w4', 'deadline_ms': 5000, 'handler': 'return_without_sink'},
        {'do': 'sweep', 'name': 'sweep', 'now_ms': 5001},
    ])
    require(o['commit']['handler_returned']['code'] == 'COMMITTED', 'TS commit %r' % o['commit'])
    rj = o['rejected']['handler_returned']
    require(rj['code'] == 'REJECTED_POLICY' and rj['lease_closed'] is not None, 'TS rejected %r' % rj)
    require(o['throws'].get('is_type_error') is True, 'TS throws %r' % o['throws'])
    require(o['no-sink']['handler_returned'] == {'returned': True}, 'TS no-sink %r' % o['no-sink'])
    require(o['sweep']['code'] == 'DROPPED_OBLIGATION' and sorted(x[0] for x in o['sweep']['dropped']) == ['w3', 'w4'], 'TS sweep %r' % o['sweep'])
    require(s.leases(p) == ['w3', 'w4'], 'open leases %r' % s.leases(p))
    return 'TS SDK: commit and rejection close; TypeError and no-sink leave the lease open; sweep -> DROPPED_OBLIGATION w3, w4'


def case_ts_kill(s):
    p = s.store('ts-kill')
    o = plan(s, p, [
        {'do': 'commit', 'name': 'open', 'op': 'open_money', 'fields': {'tenant': 't1', 'key': 'o1', 'request_id': 'r0', 'policy': 'store-refunds', 'original': 10000}},
        {'do': 'get', 'name': 'get', 'tenant': 't1', 'key': 'o1', 'save': 'h'},
        {'do': 'kill', 'name': 'kill'},
        {'do': 'commit', 'name': 'after', 'op': 'refund', 'fields': {'tenant': 't1', 'key': 'o1', 'request_id': 'r1', 'pre_state_hash': '$h', 'reason': 'DUPLICATE_CHARGE', 'amount': 5}},
        {'do': 'state', 'name': 'again'},
    ])
    require(o['after'].get('error') == 'EngineDead' and o['after']['outcome_known'] is False, 'TS after kill %r' % o['after'])
    require(o['again'].get('error') == 'EngineDead', 'TS closed client stays closed %r' % o['again'])
    require(len(s.effects(p)) == 1, 'nothing committed')
    return 'TS SDK: SIGKILL of the serve child -> EngineDead (outcome unknown), never COMMITTED; WAL unchanged'


def case_ts_protocol(s):
    eng = s.standin()
    o = s.ts({'store': 'unused', 'node': s.node, 'serve_argv': [sys.executable, str(eng), 'ok-one'], 'timeout_ms': 20000,
              'steps': [{'do': 'read', 'name': 'x', 'tenant': 'tA', 'rows': [{'tenant_id': 'tA'}, {'tenant_id': 'tB', 'secret': 'x'}]}]})
    x = o['x']
    require(x.get('error') == 'ProtocolError' and x.get('outcome_known') is False and 'rows' not in x,
            'TS STAND-IN ok-one: readScoped on an OK for another row count: %r' % x)
    return 'TS: OK for another row count -> ProtocolError, no rows'


def case_ts_garbage(s):
    eng = s.standin()
    seen = []
    for mode in GARBAGE_MODES:
        o = s.ts({'store': 'unused', 'node': s.node, 'serve_argv': [sys.executable, str(eng), mode], 'timeout_ms': 2000 if mode == 'silent' else 20000,
                  'steps': [{'do': 'commit', 'name': 'x', 'op': 'refund', 'fields': {'tenant': 't1', 'key': 'k1', 'request_id': 'r1',
                                                                                     'pre_state_hash': 'a' * 32, 'reason': 'X', 'amount': 1}}]})
        x = o['x']
        require(x.get('error') in ('ProtocolError', 'EngineDead', 'EngineTimeout') and x['outcome_known'] is False, 'TS STAND-IN %s: %r' % (mode, x))
        seen.append(x['error'])
    return 'TS SDK vs STAND-IN engine (protocol robustness only): %d garbage answers -> %s; never COMMITTED' % (len(seen), ','.join(sorted(set(seen))))


CASES = [('py_typed', case_py_typed), ('py_cosign', case_py_cosign), ('py_canonical', case_py_canonical),
         ('py_saga_inventory', case_py_saga_inventory), ('py_read', case_py_read), ('py_lease', case_py_lease),
         ('py_kill', case_py_kill), ('py_garbage', case_py_garbage), ('py_protocol', case_py_protocol), ('py_lease_durable', case_py_lease_durable),
         ('ts_typed', case_ts_typed), ('ts_read', case_ts_read), ('ts_lease', case_ts_lease), ('ts_kill', case_ts_kill), ('ts_garbage', case_ts_garbage),
         ('ts_protocol', case_ts_protocol)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--engine-dir', required=True)
    ap.add_argument('--node', default='/opt/homebrew/bin/node')
    ap.add_argument('--case', action='append', choices=[n for n, _ in CASES])
    ap.add_argument('--keep', action='store_true')
    a = ap.parse_args()
    engine = Path(a.engine_dir) / 'airlock-engine'
    if not engine.is_file():
        print('cannot start: %s is missing (run bin/forge-airlock build)' % engine)
        return 2
    s = Suite(a)
    failed = 0
    try:
        for name, fn in CASES:
            if a.case and name not in a.case:
                continue
            t = time.time()
            try:
                detail = fn(s)
                print('PASS %-18s %5.1fs %s' % (name, time.time() - t, detail), flush=True)
            except Failed as e:
                failed += 1
                print('FAIL %-18s %5.1fs %s' % (name, time.time() - t, e), flush=True)
            except Exception as e:  # a fault of the suite is a failure, never a pass
                failed += 1
                print('FAIL %-18s %5.1fs suite error %s: %s' % (name, time.time() - t, type(e).__name__, e), flush=True)
    finally:
        if not a.keep:
            shutil.rmtree(s.work, ignore_errors=True)
    print('end_to_end=false; label: FINITE TEST')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
