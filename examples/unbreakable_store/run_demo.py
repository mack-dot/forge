#!/usr/bin/env python3
"""unbreakable_store: a small store app, valid traffic and the EIGHT disasters of BRIEF.md, against real WAL state.

  python3 examples/unbreakable_store/run_demo.py --engine-dir build/airlock [--node PATH] [--json OUT] [--measurements OUT2]
  (or: bin/forge-airlock demo [--json OUT] [--measurements OUT2])

end_to_end=false. Labels: PROVED CORE (the CakeML refund binary b8ed5ec2...7bb8 for the canonical-refund profile;
the Dafny-compiled BookingDualCert checker for inventory, PROVED CORE source, Dafny compiler and Node trusted),
NATIVE CHECK (the Rust engine, not proved), FINITE TEST (this demo). No "% of bugs" figure.

Honesty rules kept here:
  * Every "blocked" and every "committed" below is the ENGINE's real answer, through sdk/py or sdk/ts. Nothing is
    mocked, hardcoded or faked. After each disaster the demo re-reads the store with the engine's own `replay`
    and computes the money that moved from the WAL; "$ leaked" is that number, not a constant.
  * The Stripe and PayPal processors are LOCAL FAKE in-process stand-ins (class LocalFakeProcessor). They are not
    real APIs. They only ever act after the engine answered COMMITTED for the saga move.
  * The cosign keys are TEMPORARY keys made at run time in a temp folder, and deleted at the end.
  * --json is deterministic (no time, pid, path, state hash, signature or racer identity). Latency and peak RSS
    go to the screen and to --measurements only.
Exit 0 only if all eight disasters and the valid traffic behaved as stated.

What the demo does NOT show (src/airlock/PROTOCOL.md section 11): every rule holds only against a caller that
reaches the store THROUGH the engine. Here the "agent" (this script), the store folder and the human cosign key all
belong to ONE OS user: the demo shows the cosign MECHANISM, not the separation that "the agent cannot self-cosign"
needs (the key outside the agent's reach AND an agent that cannot write the store folder or run another engine on
it). The opener of a key is trusted: disasters 2 and 3 are blocked only relative to the `original` and the facts
given at open; the tenant field is not authenticated. The read airlock checks only the top-level tenant_id of the
rows passed to it and returns parsed copies. A lease is bound to (request id, tenant, key); only handlers that opened
one are covered.
"""


import argparse
import json
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys
import tempfile
import threading
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'sdk' / 'py'))
import forge_airlock as fa  # noqa: E402

HERE = Path(__file__).resolve().parent
DISPATCHER = ROOT / 'bin' / 'forge-airlock'
POL = HERE / 'policies'
STORE_ID = 'unbreakable-demo'
RACERS = 50
LEASE_DEADLINE = 1700000000000      # a fixed deadline in the past; the sweep uses --now LEASE_DEADLINE + 1
ORDERS_TABLE = [  # the app's orders table (an in-memory list stands in for SQL rows)
    {'tenant_id': 'acme', 'order': 'order-1', 'total_cents': 10000, 'email': 'a1@acme.example'},
    {'tenant_id': 'acme', 'order': 'order-2', 'total_cents': 10000, 'email': 'a2@acme.example'},
    {'tenant_id': 'globex', 'order': 'gx-9', 'total_cents': 99000, 'email': 'cfo@globex.example'},
    {'tenant_id': 'globex', 'order': 'gx-10', 'total_cents': 5000, 'email': 'ops@globex.example'},
]
LBL_PARAM = 'NATIVE CHECK + FINITE TEST'
LBL_CANON = 'PROVED CORE decision (CakeML binary b8ed5ec2...7bb8) + FINITE TEST'
LBL_INV = 'PROVED CORE source (Dafny-compiled checker; compiler and Node trusted) + NATIVE CHECK + FINITE TEST'
LIMITS = [
    'trust boundary: every rule holds only against a caller that reaches the store through the engine; a process that can '
    'write the store folder can append records itself, and one that can start its own engine on it can ignore every check',
    'in this demo the agent, the store folder and the human cosign key belong to one OS user: it shows the cosign mechanism, '
    'not the separation that "the agent cannot self-cosign" needs (key outside the agent\'s reach AND no agent write access '
    'to the store folder or way to run another engine on it)',
    'the opener of a key is trusted for its tenant, original and facts; disasters 2 and 3 are blocked relative to those values; '
    'the tenant field is not authenticated',
    'the read airlock checks only the top-level tenant_id of the rows passed to it and returns parsed copies of the checked bytes',
    'a lease is bound to (request id, tenant, key); only handlers that opened a lease are covered',
    'pins: the engine pins the refund binary and (through its compiled-in helper) the checker model; the store pins the SHA-256 '
    'of the Node binary at init (inventory only); a cosign is verified by /usr/bin/ssh-keygen, which the engine checks (root-owned, '
    'not writable by group or other, no symbolic link on its path) but does not pin: the system OpenSSH is a trusted assumption; '
    'a file swapped after its check is not detected',
    'Stripe and PayPal are LOCAL FAKE in-process stand-ins; SIGKILL is not a power loss; end_to_end=false',
]


class LocalFakeProcessor:
    """LOCAL FAKE payment processor: an in-process stand-in for Stripe or PayPal. NOT a real API, no network.

    `script` maps an idempotency key to what this LOCAL FAKE does: 'TIMEOUT' (takes the request, gives no answer),
    'SETTLED' (pays), 'CONFIRMED_REJECTED' (a later status query says it did not pay).
    """

    def __init__(self, name, script):
        self.name = 'LOCAL FAKE ' + name
        self.script = script
        self.calls = []
        self.paid_cents = 0

    def payout(self, idem, cents):
        self.calls.append(('payout', idem))
        outcome = self.script[idem]
        if outcome == 'SETTLED':
            self.paid_cents += cents
        return 'TIMEOUT' if outcome == 'CONFIRMED_REJECTED' else outcome

    def status(self, idem):
        self.calls.append(('status', idem))
        return self.script[idem]


class Demo:
    def __init__(self, a):
        self.a = a
        self.node = a.node
        self.engine_dir = str(Path(a.engine_dir).resolve())
        self.tmp = Path(tempfile.mkdtemp(prefix='unbreakable-'))
        self.store = self.tmp / 'store'
        self.sentinel = self.tmp / 'sentinel-bin'
        self.dafny_marker = self.tmp / 'dafny-was-started'
        self.env = {'PATH': '%s:/usr/bin:/bin' % self.sentinel, 'LANG': 'C', 'LC_ALL': 'C'}
        self.lat = []
        self.board = []
        self.valid = []
        self.blocked = 0
        self.surfaced = 0
        self.ts_lat = []
        self.ts_rss = 0

    # -- helpers
    def cli(self, args, stdin=b''):
        if args[0] in ('init', 'replay', 'leases', 'state', 'get', 'cosign-message'):
            args = list(args) + ['--engine-dir', self.engine_dir]
        p = subprocess.run([sys.executable, str(DISPATCHER)] + [str(x) for x in args], input=stdin, capture_output=True, timeout=300, env=self.env)
        return p.returncode, p.stdout.decode('ascii', 'replace'), p.stderr.decode('utf-8', 'replace')

    def timed(self, fn):
        t = time.perf_counter()
        try:
            return fn()
        finally:
            self.lat.append((time.perf_counter() - t) * 1000)

    def replay(self):
        code, out, _ = self.cli(['replay', self.store])
        if code != 0 or not out.startswith('REPLAY '):
            raise SystemExit('FAIL: replay of the store failed: %d %r' % (code, out[:200]))
        return [ln.split(' ', 2)[2].split(' ') for ln in out.split('\n')[1:] if ln]

    def refunds(self, rids=None, key=None):
        """REFUND records from the WAL (engine replay): list of (key, rid, reason, amount, cosigned)."""
        out = []
        for e in self.replay():
            if e[0] == 'REFUND' and (rids is None or e[3] in rids) and (key is None or e[2] == key):
                out.append((e[2], e[3], e[4], int(e[5]), e[6] == '1'))
        return out

    def valid_op(self, sdk, what, res, label):
        code = res.code if isinstance(res, fa.Result) else (res.get('code') if isinstance(res, dict) else repr(res))
        self.valid.append({'sdk': sdk, 'op': what, 'observed': code, 'label': label, 'result': 'PASS' if code in ('COMMITTED', 'OK') else 'FAIL'})

    def row(self, n, title, expected, observed, ok, label, leaked, blocked, surfaced=0):
        self.blocked += blocked
        self.surfaced += surfaced
        ok = bool(ok) and leaked == 0
        self.board.append({'disaster': n, 'title': title, 'expected': expected, 'observed': observed, 'money_leaked_cents': leaked,
                           'result': 'PASS' if ok else 'FAIL', 'label': label})

    def ts(self, steps):
        f = self.tmp / ('ts-plan-%d.json' % len(self.ts_lat))
        f.write_text(json.dumps({'store': str(self.store), 'node': self.node, 'python': sys.executable, 'engine_dir': self.engine_dir, 'steps': steps}))
        p = subprocess.run([self.node, str(HERE / 'ts_part.ts'), str(f)], capture_output=True, timeout=300, env=self.env)
        last = p.stdout.decode('utf-8', 'replace').strip().split('\n')[-1]
        if p.returncode != 0 or not last.startswith('{'):
            raise SystemExit('FAIL: the TypeScript part did not run: exit %d %r %r' % (p.returncode, last[:300], p.stderr[-500:]))
        res = json.loads(last)
        if 'fatal' in res:
            raise SystemExit('FAIL: the TypeScript part: %s' % res['fatal'][:400])
        self.ts_lat += res['latency_ms']
        self.ts_rss = max(self.ts_rss, res['peak_rss_bytes'])
        return {s['step']: s for s in res['steps']}

    # -- setup
    def setup(self):
        self.sentinel.mkdir()
        dafny = self.sentinel / 'dafny'
        dafny.write_text('#!/bin/sh\n: > "%s"\nexit 97\n' % self.dafny_marker)
        os.chmod(dafny, 0o700)
        keys = self.tmp / 'keys'
        keys.mkdir(mode=0o700)
        self.human_key, self.other_key = keys / 'human.key', keys / 'other.key'
        code, pub, err = self.cli(['cosign-keygen', self.human_key])  # OpenSSH ssh-keygen; no Node
        code2, _, err2 = self.cli(['cosign-keygen', self.other_key])
        if code or code2:
            raise SystemExit('FAIL: temporary cosign keygen: %r %r' % (err, err2))
        args = ['init', self.store, '--store-id', STORE_ID, '--cosign-pubkey', pub.strip(), '--node', self.node]
        for f in ('refunds.json', 'card-charges.json', 'payout.json', 'seats.json'):
            args += ['--policy', POL / f]
        code, out, err = self.cli(args)
        if code != 0:
            raise SystemExit('FAIL: init: %d %r %r' % (code, out, err))
        self.st = fa.Store(self.store, node=self.node, env=self.env, engine_dir=self.engine_dir)

    # -- valid traffic (Python half; the TS half runs with disasters 2, 6, 7)
    def valid_traffic(self):
        st = self.st
        for order in ('order-1', 'order-2', 'order-3', 'order-4', 'order-5'):
            r = self.timed(lambda: st.open_money('acme', order, 'open-' + order, 'store-refunds', 10000, {'shipping_paid': 1000}))
            self.valid_op('py', 'open %s ($100, shipping $10)' % order, r, LBL_PARAM)
        r = self.timed(lambda: st.open_money('acme', 'ch-1', 'open-ch-1', 'card-charges', 10000))
        self.valid_op('py', 'open charge ch-1 (canonical-refund)', r, LBL_CANON)
        r = self.timed(lambda: st.open_money('acme', 'ch-2', 'open-ch-2', 'card-charges', 10000))
        self.valid_op('py', 'open charge ch-2 (canonical-refund)', r, LBL_CANON)
        h = st.get('acme', 'ch-1').state_hash
        r = self.timed(lambda: st.refund('acme', 'ch-1', 'v-canon-1', h, 'returned_item', 2500))
        self.valid_op('py', 'refund $25 returned_item on ch-1', r, LBL_CANON)
        h = st.get('acme', 'order-5').state_hash
        r = self.timed(lambda: st.refund('acme', 'order-5', 'v-gw-1', h, 'GOODWILL', 1500))
        self.valid_op('py', 'refund $15 GOODWILL on order-5', r, LBL_PARAM)
        rows = [row for row in ORDERS_TABLE if row['tenant_id'] == 'acme']
        r = self.timed(lambda: st.read_scoped('acme', rows))
        self.valid_op('py', 'read_scoped acme orders (WHERE tenant_id = acme)', r, LBL_PARAM)

        def webhook(lease):
            h = st.get('acme', 'order-5').state_hash
            return lease.commit('refund', tenant='acme', key='order-5', pre_state_hash=h, reason='DUPLICATE_CHARGE', amount=500)
        r = self.timed(lambda: st.with_lease('wh-ok-1', LEASE_DEADLINE, 'acme', 'order-5', webhook))
        self.valid_op('py', 'with_lease webhook refund $5 (lease closed by the commit)', r, LBL_PARAM)

    # -- the eight disasters
    def d1_race(self):
        st = self.st
        h = st.get('acme', 'order-1').state_hash
        clients = []
        try:
            for _ in range(RACERS):
                c = fa.Store(self.store, node=self.node, env=self.env, engine_dir=self.engine_dir)
                c.state()  # the serve process is up before the race starts
                clients.append(c)
            barrier = threading.Barrier(RACERS)
            res = [None] * RACERS

            def racer(i):
                barrier.wait()
                try:
                    res[i] = clients[i].refund('acme', 'order-1', 'race-%d' % i, h, 'DUPLICATE_CHARGE', 10000).code
                except fa.AirlockError as e:
                    res[i] = 'ERROR ' + e.code
            threads = [threading.Thread(target=racer, args=(i,)) for i in range(RACERS)]
            for t in threads:
                t.start()
            for t in threads:
                t.join()
        finally:
            for c in clients:
                c.close()
        nc, ns = res.count('COMMITTED'), res.count('STALE_STATE_HASH')
        moved = sum(a for _, _, _, a, _ in self.refunds(key='order-1'))
        leaked = max(0, moved - 10000)
        self.row(1, '50-process concurrent double refund of a $100 order', '1 COMMITTED, 49 STALE_STATE_HASH (compare-and-swap)',
                 '%d COMMITTED, %d STALE_STATE_HASH, %d other; WAL refunds on order-1 = $%.2f' % (nc, ns, RACERS - nc - ns, moved / 100),
                 nc == 1 and ns == RACERS - 1 and moved == 10000, LBL_PARAM + ' (50 engine serve processes, 50 SDK clients in threads)', leaked, ns)

    def d2_injection(self, ts):
        st = self.st
        h = st.get('acme', 'order-2').state_hash
        r1 = self.timed(lambda: st.refund('acme', 'order-2', 'inj-1', h, 'GOODWILL', 5000000))
        h = st.get('acme', 'ch-2').state_hash
        r2 = self.timed(lambda: st.refund('acme', 'ch-2', 'inj-2', h, 'returned_item', 5000000))
        t = ts['d2-inject']
        moved = sum(a for _, _, _, a, _ in self.refunds(rids={'inj-1', 'inj-2', 'inj-ts'}))
        ok = (r1.code, r1.detail) == ('REJECTED_POLICY', 'TOTAL_CAP') and (r2.code, r2.detail) == ('REJECTED_POLICY', 'CAKEML_REJECTED') \
            and (t.get('code'), t.get('detail')) == ('REJECTED_POLICY', 'TOTAL_CAP')
        self.row(2, 'prompt-injected $50,000 refund on a $100 order', 'blocked (py parametric, py canonical, ts parametric), 0 effects',
                 'py: %s %s; py canonical: %s %s; ts: %s %s; WAL effects of the 3 requests = %d' % (r1.code, r1.detail, r2.code, r2.detail, t.get('code'), t.get('detail'),
                                                                                                 len(self.refunds(rids={'inj-1', 'inj-2', 'inj-ts'}))),
                 ok, LBL_PARAM + '; ch-2 attempt: ' + LBL_CANON, moved, 3)

    def d3_shipping(self):
        st = self.st
        h = st.get('acme', 'order-3').state_hash
        r = self.timed(lambda: st.refund('acme', 'order-3', 'ship-80', h, 'SHIPPING', 8000))
        moved = sum(a for _, _, _, a, _ in self.refunds(rids={'ship-80'}))
        ok_valid = self.timed(lambda: st.refund('acme', 'order-3', 'ship-10', h, 'SHIPPING', 1000))
        self.valid_op('py', 'refund the real $10 SHIPPING on order-3', ok_valid, LBL_PARAM)
        self.row(3, '$10 shipping ask proposed as $80', 'REJECTED_POLICY REASON_CAP (SHIPPING <= shipping_paid = $10)',
                 '%s %s; then the $10 ask: %s' % (r.code, r.detail, ok_valid.code), (r.code, r.detail) == ('REJECTED_POLICY', 'REASON_CAP'),
                 LBL_PARAM, moved, 1)

    def d4_goodwill(self):
        st = self.st
        h = st.get('acme', 'order-4').state_hash
        r1 = self.timed(lambda: st.refund('acme', 'order-4', 'gw-75', h, 'GOODWILL', 7500))
        msg = st.cosign_message(fa.refund_action('acme', 'order-4', 'gw-75', h, 'GOODWILL', 7500))
        code, other_sig, _ = self.cli(['cosign-sign', self.other_key], stdin=msg)
        code2, human_sig, _ = self.cli(['cosign-sign', self.human_key], stdin=msg)
        if code or code2:
            raise SystemExit('FAIL: cosign-sign with the temporary keys')
        r2 = self.timed(lambda: st.refund('acme', 'order-4', 'gw-75', h, 'GOODWILL', 7500, other_sig.strip()))
        uncosigned = sum(a for _, _, _, a, c in self.refunds(rids={'gw-75'}) if not c)
        r3 = self.timed(lambda: st.refund('acme', 'order-4', 'gw-75', h, 'GOODWILL', 7500, human_sig.strip()))
        rec = self.refunds(rids={'gw-75'})
        uncosigned += sum(a for _, _, _, a, c in rec if not c)
        ok = (r1.code, r1.detail) == ('REQUIRE_HUMAN_COSIGN', 'COSIGN_REQUIRED') and (r2.code, r2.detail) == ('REQUIRE_HUMAN_COSIGN', 'COSIGN_INVALID') \
            and r3.code == 'COMMITTED' and rec == [('order-4', 'gw-75', 'GOODWILL', 7500, True)]
        self.row(4, '$75 unstructured goodwill refund', 'REQUIRE_HUMAN_COSIGN; another key: refused; the pinned human key: COMMITTED',
                 'no signature: %s %s; other key: %s %s; pinned human key (temporary): %s, WAL cosign flag %s' % (
                     r1.code, r1.detail, r2.code, r2.detail, r3.code, '1' if rec and rec[0][4] else '0'),
                 ok, LBL_PARAM + '; Ed25519 verify through /usr/bin/ssh-keygen -Y verify (system OpenSSH with LibreSSL, trusted; no Node)', uncosigned, 2)

    def d5_failover(self):
        st = self.st
        stripe = LocalFakeProcessor('Stripe', {'idem-s1': 'CONFIRMED_REJECTED'})
        paypal = LocalFakeProcessor('PayPal', {'idem-p1': 'SETTLED'})
        payout = 4000
        self.timed(lambda: st.open_saga('acme', 'payout-7', 'open-payout-7', 'payout'))
        h = st.get('acme', 'payout-7').state_hash
        r = self.timed(lambda: st.saga('acme', 'payout-7', 'pay-s1', h, 'IN_FLIGHT', 'stripe', 'idem-s1'))
        answers = []
        if r.committed:
            answers.append(stripe.payout('idem-s1', payout))  # LOCAL FAKE: TIMEOUT
        h = r.state_hash
        retry = self.timed(lambda: st.saga('acme', 'payout-7', 'pay-s2', h, 'IN_FLIGHT', 'stripe', 'idem-s2'))
        failover = self.timed(lambda: st.saga('acme', 'payout-7', 'pay-p0', h, 'IN_FLIGHT', 'paypal', 'idem-p1'))
        for res, proc, idem in ((retry, stripe, 'idem-s2'), (failover, paypal, 'idem-p1')):
            if res.committed:  # never expected; the demo app would pay twice here
                proc.script.setdefault(idem, 'SETTLED')
                proc.payout(idem, payout)
        status = stripe.status('idem-s1')  # LOCAL FAKE: CONFIRMED_REJECTED
        cr = self.timed(lambda: st.saga('acme', 'payout-7', 'pay-s1-no', h, status, 'stripe', 'idem-s1'))
        later = self.timed(lambda: st.saga('acme', 'payout-7', 'pay-p1', cr.state_hash, 'IN_FLIGHT', 'paypal', 'idem-p1'))
        if later.committed:
            paypal.payout('idem-p1', payout)
        settle = self.timed(lambda: st.saga('acme', 'payout-7', 'pay-p1-ok', later.state_hash, 'SETTLED', 'paypal', 'idem-p1'))
        # money from the WAL: each IN_FLIGHT record is a dispatch (processor, key) that may pay; a CONFIRMED_REJECTED
        # record (it holds `- -`) closes the dispatch that was in flight just before it
        live, current = [], None
        for e in self.replay():
            if e[0] == 'SAGA' and e[2] == 'payout-7':
                if e[4] == 'IN_FLIGHT':
                    current = (e[5], e[6])
                    live.append(current)
                elif e[4] == 'CONFIRMED_REJECTED' and current in live:
                    live.remove(current)
                    current = None
        leaked = payout * max(0, len(live) - 1)
        ok = r.committed and (retry.code, retry.detail) == ('REJECTED_POLICY', 'PROCESSOR_IN_FLIGHT') \
            and (failover.code, failover.detail) == ('REJECTED_POLICY', 'PROCESSOR_IN_FLIGHT') and cr.committed and later.committed and settle.committed \
            and stripe.paid_cents + paypal.paid_cents == payout
        for what, res in (('saga PAID -> IN_FLIGHT (LOCAL FAKE Stripe)', r), ('saga -> CONFIRMED_REJECTED (LOCAL FAKE Stripe)', cr),
                          ('saga failover -> IN_FLIGHT (LOCAL FAKE PayPal)', later), ('saga -> SETTLED (LOCAL FAKE PayPal)', settle)):
            self.valid_op('py', what, res, LBL_PARAM)
        self.row(5, 'timeout retry + Stripe->PayPal failover while IN_FLIGHT (LOCAL FAKE processors)',
                 'retry and failover REJECTED_POLICY PROCESSOR_IN_FLIGHT; after CONFIRMED_REJECTED the failover commits',
                 'LOCAL FAKE Stripe: %s; retry: %s %s; failover: %s %s; after CONFIRMED_REJECTED: failover %s, settle %s; dispatches live in WAL = %d' % (
                     answers[0] if answers else '-', retry.code, retry.detail, failover.code, failover.detail, later.code, settle.code, len(live)),
                 ok, LBL_PARAM, leaked, 2)

    def d6_read(self, ts):
        st = self.st
        buggy_rows = list(ORDERS_TABLE)  # SELECT * FROM orders  -- the WHERE tenant_id = ? is forgotten
        r = self.timed(lambda: st.read_scoped('acme', buggy_rows))
        leaked_rows = [row for row in r.rows if row.get('tenant_id') != 'acme']
        leaked_bytes = len(json.dumps(leaked_rows).encode()) if leaked_rows else 0
        t = ts['d6-read']
        ok = r.code == 'TENANT_ISOLATION_BREACH' and r.rows == [] and t.get('code') == 'TENANT_ISOLATION_BREACH' and t.get('rows') == 0 and t.get('rows_bytes') == 0
        self.row(6, 'forgotten WHERE tenant_id (cross-tenant read)', 'TENANT_ISOLATION_BREACH, 0 rows and 0 bytes returned (py and ts)',
                 'py: %s %s, %d rows / %d cross-tenant bytes returned; ts: %s %s, %d rows / %d bytes' % (
                     r.code, r.detail, len(r.rows), leaked_bytes, t.get('code'), t.get('detail'), t.get('rows'), t.get('rows_bytes')),
                 ok and leaked_bytes == 0, LBL_PARAM + ' (read airlock sees only the rows passed to it)', 0, 2)

    def d7_webhook(self, ts):
        st = self.st

        def webhook(lease):
            event = json.loads('{"type": "charge.refunded", "data": null}')
            cents = event['data']['object']['amount']  # the bug: a real TypeError, before the sink is called
            h = st.get('acme', 'order-2').state_hash
            return lease.commit('refund', tenant='acme', key='order-2', pre_state_hash=h, reason='DUPLICATE_CHARGE', amount=cents)
        err = None
        try:
            self.timed(lambda: st.with_lease('wh-7', LEASE_DEADLINE, 'acme', 'order-2', webhook))
        except TypeError as e:
            err = 'TypeError'
        # a retry path rejected on ANOTHER key with the same request id must not close (hide) the obligation
        h3 = st.get('acme', 'order-3').state_hash
        other = self.timed(lambda: st.refund('acme', 'order-3', 'wh-7', h3, 'GOODWILL', 999999))
        t = ts['d7-webhook']
        sw = st.sweep(now_ms=LEASE_DEADLINE + 1)
        dropped = sorted(x[0] for x in sw.dropped)
        moved = sum(a for _, _, _, a, _ in self.refunds(rids={'wh-7', 'wh-7t'}))
        ok = err == 'TypeError' and t.get('is_type_error') is True and sw.code == 'DROPPED_OBLIGATION' and dropped == ['wh-7', 'wh-7t'] \
            and other.code == 'REJECTED_POLICY' and other.lease_closed is None
        self.row(7, 'unhandled TypeError mid-webhook before the sink', 'the lease stays open; leases --sweep reports DROPPED_OBLIGATION (py and ts)',
                 'py handler: %s; ts handler: %s; rejection of wh-7 on another key: %s %s, lease %s; sweep: %s %s' % (
                     err, 'TypeError' if t.get('is_type_error') else t, other.code, other.detail, 'closed' if other.lease_closed is not None else 'still open',
                     sw.code, ','.join(dropped)),
                 ok, LBL_PARAM + ' (lease bound to request id, tenant and key; only handlers that opened one)', moved, 0, 2)

    def d8_solver(self):
        st = self.st
        w = ['5', '3', '2', '4']
        a_row = [['1', '1', '1', '1']]

        def honest_solver(cap):
            """Exact for one capacity row of unit weights: take the cap best items; dual y = the next best weight."""
            order = sorted(range(len(w)), key=lambda j: (-int(w[j]), j))
            take = set(order[:cap])
            y = int(w[order[cap]]) if cap < len(w) else 0
            return {'A': a_row, 'c': [str(cap)], 'w': w, 'x': ['1' if j in take else '0' for j in range(len(w))], 'y': [str(y)],
                    'z': [str(max(0, int(w[j]) - y)) for j in range(len(w))], 'alpha_bps': '0'}
        good = honest_solver(2)
        overbook = dict(good, x=['1', '1', '1', '1'])        # the swapped solver: books every request
        suboptimal = dict(good, x=['1', '1', '0', '0'])      # the swapped solver: a feasible but worse batch, claims gap 0
        self.timed(lambda: st.open_inventory('acme', 'flight-9', 'open-flight-9', 'seats', [2]))
        h = st.get('acme', 'flight-9').state_hash
        before = self.dafny_processes()
        b1 = self.timed(lambda: st.book('acme', 'flight-9', 'bk-bug-1', h, overbook))
        b2 = self.timed(lambda: st.book('acme', 'flight-9', 'bk-bug-2', h, suboptimal))
        b3 = self.timed(lambda: st.book('acme', 'flight-9', 'bk-opt', h, good))
        after = self.dafny_processes()
        self.valid_op('py', 'book the optimal batch on flight-9', b3, LBL_INV)
        books = [e for e in self.replay() if e[0] == 'BOOK' and e[2] == 'flight-9']
        rem = st.get('acme', 'flight-9').fields.get('remaining')
        bad_effects = [e for e in books if e[3] in ('bk-bug-1', 'bk-bug-2')]
        sentinel = self.dafny_marker.exists()
        ok = (b1.code, b1.detail) == ('REJECTED_POLICY', 'OVERBOOKED') and (b2.code, b2.detail) == ('REJECTED_POLICY', 'GAP_TOO_LARGE') \
            and b3.committed and rem == '0' and not bad_effects and not sentinel and not (after - before)
        self.dafny_evidence = {'sentinel_dafny_on_engine_path_started': sentinel, 'demo_descendant_dafny_processes_seen_by_ps': len(after - before),
                               'limit': 'a sentinel `dafny` first on the PATH of the engine recorded no start, and two ps snapshots '
                                        'saw no dafny process that descends from the demo; a start by absolute path, or a process '
                                        'shorter than the snapshot gap, would not be seen; the helper processes run with a cleared '
                                        'environment; Dafny processes of OTHER programs on the machine are not counted'}
        self.row(8, 'untrusted solver swap with a buggy batch', 'buggy batches REJECTED_POLICY, the optimal batch COMMITTED, 0 Dafny starts',
                 'overbooked batch: %s %s; suboptimal batch: %s %s; optimal batch: %s; remaining seats %s; Dafny starts seen: %d' % (
                     b1.code, b1.detail, b2.code, b2.detail, b3.code, rem, int(sentinel) + len(after - before)),
                 ok, LBL_INV + '; the buggy batches were refused by the native Accepts check before the checker ran', 0, 2)

    dafny_evidence = {'not_run': True}
    fuzz_result = {'result': 'NOT RUN', 'exit_code': -1, 'invariants': {}}

    def dafny_processes(self):
        """pids of processes whose command names dafny AND that descend from this demo process (one ps snapshot)."""
        p = subprocess.run(['/bin/ps', '-axo', 'pid=,ppid=,command='], capture_output=True, timeout=30)
        parent, cmd = {}, {}
        for ln in p.stdout.decode('utf-8', 'replace').split('\n'):
            t = ln.split(None, 2)
            if len(t) == 3 and t[0].isdigit() and t[1].isdigit():
                parent[int(t[0])], cmd[int(t[0])] = int(t[1]), t[2]
        me, found = os.getpid(), set()
        for pid, c in cmd.items():
            if 'dafny' not in c.lower():
                continue
            q, seen = pid, set()
            while q in parent and q not in seen and q > 1:
                if q == me:
                    found.add(pid)
                    break
                seen.add(q)
                q = parent[q]
        return found

    def fuzz(self):
        out = self.tmp / 'fuzz.json'
        p = subprocess.run([sys.executable, str(ROOT / 'src/airlock/py/fuzz.py'), '--engine-dir', self.engine_dir, '--node', self.node,
                            '--seed', '20', '--rounds', '2', '--json', str(out)], capture_output=True, timeout=900)
        rep = json.loads(out.read_text()) if out.exists() else {}
        self.fuzz_result = {'command': 'fuzz --seed 20 --rounds 2', 'exit_code': p.returncode, 'result': rep.get('result', 'NOT RUN'),
                            'invariants': rep.get('invariants', {}), 'requests': rep.get('counts', {}).get('requests'), 'label': 'FINITE TEST'}
        return p.returncode == 0 and rep.get('result') == 'PASS'

    def run(self):
        self.setup()
        try:
            self.valid_traffic()
            ts = self.ts([
                {'do': 'commit', 'name': 'v-open', 'op': 'open_money', 'fields': {'tenant': 'acme', 'key': 'order-t1', 'request_id': 'open-order-t1',
                                                                                 'policy': 'store-refunds', 'original': 10000, 'facts': {'shipping_paid': 500}}},
                {'do': 'get', 'name': 'v-get', 'tenant': 'acme', 'key': 'order-t1', 'save': 'h'},
                {'do': 'commit', 'name': 'v-refund', 'op': 'refund', 'fields': {'tenant': 'acme', 'key': 'order-t1', 'request_id': 'v-ts-1',
                                                                                'pre_state_hash': '$h', 'reason': 'DUPLICATE_CHARGE', 'amount': 1999}, 'save': 'h'},
                {'do': 'read', 'name': 'v-read', 'tenant': 'acme', 'rows': [r for r in ORDERS_TABLE if r['tenant_id'] == 'acme']},
                {'do': 'lease', 'name': 'v-lease', 'request_id': 'wh-ok-t', 'deadline_ms': LEASE_DEADLINE, 'tenant': 'acme', 'key': 'order-t1',
                 'handler': 'commit', 'op': 'refund',
                 'fields': {'tenant': 'acme', 'key': 'order-t1', 'pre_state_hash': '$h', 'reason': 'SHIPPING', 'amount': 500}},
                {'do': 'commit', 'name': 'd2-open', 'op': 'open_money', 'fields': {'tenant': 'acme', 'key': 'order-t2', 'request_id': 'open-order-t2',
                                                                                  'policy': 'store-refunds', 'original': 10000}},
                {'do': 'get', 'name': 'd2-get', 'tenant': 'acme', 'key': 'order-t2', 'save': 'h2'},
                {'do': 'commit', 'name': 'd2-inject', 'op': 'refund', 'fields': {'tenant': 'acme', 'key': 'order-t2', 'request_id': 'inj-ts',
                                                                                 'pre_state_hash': '$h2', 'reason': 'GOODWILL', 'amount': 5000000}},
                {'do': 'read', 'name': 'd6-read', 'tenant': 'acme', 'rows': ORDERS_TABLE},
                {'do': 'lease', 'name': 'd7-webhook', 'request_id': 'wh-7t', 'deadline_ms': LEASE_DEADLINE, 'tenant': 'acme', 'key': 'order-t2',
                 'handler': 'typeerror_before_sink',
                 'event': '{"type":"charge.refunded"}', 'fields': {'tenant': 'acme', 'key': 'order-t2', 'pre_state_hash': '$h2', 'reason': 'DUPLICATE_CHARGE'}},
            ])
            for name, what in (('v-open', 'open order-t1'), ('v-refund', 'refund $19.99 DUPLICATE_CHARGE'), ('v-read', 'read_scoped acme orders'),
                               ('d2-open', 'open order-t2')):
                self.valid_op('ts', what, ts[name], LBL_PARAM)
            self.valid_op('ts', 'with_lease webhook refund $5 SHIPPING', ts['v-lease'].get('handler_returned', ts['v-lease']), LBL_PARAM)
            for n, fn, args in ((1, self.d1_race, ()), (2, self.d2_injection, (ts,)), (3, self.d3_shipping, ()), (4, self.d4_goodwill, ()),
                                (5, self.d5_failover, ()), (6, self.d6_read, (ts,)), (7, self.d7_webhook, (ts,)), (8, self.d8_solver, ())):
                try:
                    fn(*args)
                except (fa.AirlockError, KeyError) as e:  # an error is never a pass: the row says what happened
                    if self.st._closed is not None and not isinstance(e, KeyError):
                        self.st = fa.Store(self.store, node=self.node, env=self.env, engine_dir=self.engine_dir)
                    self.row(n, 'disaster %d' % n, 'see the disaster list', 'ERROR %s: %s' % (type(e).__name__, str(e)[:160]), False, 'FINITE TEST', 0, 0)
            fuzz_ok = self.fuzz()
        finally:
            self.st.close()
        # whole-store money check from the WAL: no key refunded above its original
        opened, moved = {}, {}
        for e in self.replay():
            if e[0] == 'OPEN_MONEY':
                opened[e[2]] = int(e[5])
            elif e[0] == 'REFUND':
                moved[e[2]] = moved.get(e[2], 0) + int(e[5])
        over = {k: v - opened[k] for k, v in moved.items() if v > opened[k]}
        return fuzz_ok, over, sum(moved.values())


def pct(xs, p):
    xs = sorted(xs)
    return round(xs[min(len(xs) - 1, int(round(p / 100 * (len(xs) - 1))))], 3) if xs else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--engine-dir', default=str(ROOT / 'build' / 'airlock'))
    ap.add_argument('--node', default='/opt/homebrew/bin/node')
    ap.add_argument('--json', default=None)
    ap.add_argument('--measurements', default=None)
    ap.add_argument('--keep', action='store_true')
    a = ap.parse_args()
    for need in (Path(a.engine_dir) / 'airlock-engine', Path(a.engine_dir) / 'checker' / 'model.cjs', ROOT / 'build/airlock/refund-binary'):
        if not need.is_file():
            print('NOT RUN: %s is missing (bin/forge-airlock build; build --checker for model.cjs)' % need)
            return 2
    d = Demo(a)
    t0 = time.time()
    try:
        fuzz_ok, over, refunded_total = d.run()
    finally:
        if not a.keep:
            shutil.rmtree(d.tmp, ignore_errors=True)  # also deletes the temporary cosign keys
    leaked = sum(r['money_leaked_cents'] for r in d.board) + sum(over.values())
    ok_dis = len(d.board) == 8 and all(r['result'] == 'PASS' for r in d.board)
    ok_valid = d.valid and all(v['result'] == 'PASS' for v in d.valid)
    ok = ok_dis and ok_valid and fuzz_ok and leaked == 0 and not over
    report = {'demo': 'unbreakable_store', 'end_to_end': False, 'labels': {'parametric': LBL_PARAM, 'canonical': LBL_CANON, 'inventory': LBL_INV},
              'processors': 'Stripe and PayPal are LOCAL FAKE in-process stand-ins', 'limits': LIMITS, 'disasters': d.board, 'valid_traffic': d.valid,
              'valid_commits': sum(1 for v in d.valid if v['observed'] == 'COMMITTED'), 'attacks_blocked': d.blocked,
              'obligations_surfaced': d.surfaced, 'money_leaked_cents_from_wal': leaked, 'money_refunded_cents_from_wal': refunded_total,
              'keys_refunded_above_original': over, 'dafny_at_run_time': d.dafny_evidence, 'fuzz': d.fuzz_result,
              'result': 'PASS' if ok else 'FAIL'}
    print('unbreakable_store scoreboard (FINITE TEST; end_to_end=false)')
    for r in d.board:
        print('%s D%d %-62s leaked $%.2f' % (r['result'], r['disaster'], r['title'][:62], r['money_leaked_cents'] / 100))
        print('      expected: %s' % r['expected'])
        print('      observed: %s' % r['observed'])
        print('      label:    %s' % r['label'])
    for v in d.valid:
        print('%s valid %-3s %-60s %s' % (v['result'], v['sdk'], v['op'][:60], v['observed']))
    print('valid commits: %d; attacks blocked: %d; obligations surfaced: %d' % (report['valid_commits'], d.blocked, d.surfaced))
    print('money leaked (from the WAL): $%.2f; money refunded in total (from the WAL): $%.2f' % (leaked / 100, refunded_total / 100))
    print('Dafny at run time: %s' % json.dumps({k: v for k, v in d.dafny_evidence.items() if k != 'limit'}))
    print('fuzz: %s (exit %d); %s' % (d.fuzz_result['result'], d.fuzz_result['exit_code'], ', '.join('%s %s' % kv for kv in sorted(d.fuzz_result['invariants'].items()))))
    rusage_self = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    rusage_kids = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
    meas = {'note': 'measurements of one run on this machine; not deterministic; not part of --json',
            'python_sdk_call_latency_ms': {'n': len(d.lat), 'p50': pct(d.lat, 50), 'p99': pct(d.lat, 99)},
            'ts_sdk_step_latency_ms': {'n': len(d.ts_lat), 'p50': pct(d.ts_lat, 50), 'p99': pct(d.ts_lat, 99)},
            'peak_rss_bytes': {'demo_python': rusage_self, 'largest_child_process': rusage_kids, 'ts_node': d.ts_rss},
            'wall_seconds': round(time.time() - t0, 2)}
    print('latency p50/p99 (ms): python %s/%s, ts %s/%s; peak RSS: demo %.1f MB, largest child %.1f MB, ts node %.1f MB' % (
        meas['python_sdk_call_latency_ms']['p50'], meas['python_sdk_call_latency_ms']['p99'], meas['ts_sdk_step_latency_ms']['p50'],
        meas['ts_sdk_step_latency_ms']['p99'], rusage_self / 2 ** 20, rusage_kids / 2 ** 20, d.ts_rss / 2 ** 20))
    if a.json:
        Path(a.json).write_text(json.dumps(report, indent=1, sort_keys=True) + '\n')
    if a.measurements:
        Path(a.measurements).write_text(json.dumps(meas, indent=1, sort_keys=True) + '\n')
    if not ok:
        bad = [('D%d' % r['disaster']) for r in d.board if r['result'] != 'PASS'] + [('valid ' + v['op']) for v in d.valid if v['result'] != 'PASS']
        print('DEMO FAIL: %s%s%s' % (', '.join(bad) or '-', '; fuzz failed' if not fuzz_ok else '', '; money leaked' if leaked or over else ''))
    print('limits (what this demo does not show):')
    for line in LIMITS:
        print('  - ' + line)
    print('demo %s; end_to_end=false' % report['result'])
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
