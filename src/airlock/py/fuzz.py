#!/usr/bin/env python3
"""forge-airlock fuzz (Goal 20, L5): a FINITE fuzz pass against a real store. Python stdlib only. end_to_end=false.

  python3 src/airlock/py/fuzz.py --engine-dir build/airlock [--node PATH] [--seed N] [--rounds N] [--json OUT]
  (or: bin/forge-airlock fuzz [--seed N] [--rounds N] [--json OUT])

Label: FINITE TEST. It proves nothing. It tries a finite, seeded list of inputs and checks invariants.

Each round, against ONE real store (a fresh temp folder; the real engine through bin/forge-airlock serve):
  * boundary integers as refund amounts: 0, -1, 1, remaining, remaining+1, MaxMoney, MaxMoney+1, 2^64, '01'
  * strings: NUL, CR, tab, Unicode, 0xff, oversized (> 65,536 bytes) lines as RAW lines; unsafe ids through the SDK
  * cross-tenant tokens: another tenant writes and gets the key (UNKNOWN_KEY: keys, request ids and leases are per
    tenant, review D3) and opens a lease with an id of the first tenant in its own namespace; mixed-tenant row sets
    through read_scoped
  * injected mid-handler exceptions inside with_lease (before the sink, and after the sink)
  * a 50-way TOCTOU burst: 50 engine `serve` processes, one pre_state_hash, one REFUND each (raw lines)
  * a duplicate-id replay storm: one fresh request id sent by 20 processes at once, then a used id resent 20 times
Oracle after EVERY round, from the engine's own `replay`, `state` and `leases --sweep`:
  I1 per money key: sum of committed refunds <= original
  I2 per key: SHIPPING total <= the shipping_paid fact; no GOODWILL refund above 2000 without a cosign (no key pinned)
  I3 no effect under a wrong tenant (every record of a key names the tenant that opened it)
  I4 exactly one effect per request id; every id answered COMMITTED is in the WAL once; every WAL id was answered COMMITTED
  I5 every refused request id (never answered COMMITTED) left no effect record
  I6 the store still opens: `state` exit 0 (no CORRUPT_WAL), its effect count equals the replay count
  I7 the open leases past their deadline are exactly the leases (request id, tenant) whose handler raised before the sink
  I8 burst: exactly 1 COMMITTED and 49 STALE_STATE_HASH; storm: exactly 1 COMMITTED for the fresh id; 0 for the used id
Deterministic for a seed (random.Random(seed)). The bursts are racy in WHICH process wins; only invariant facts are
recorded. The --json file holds no time, pid, path or state hash. Exit 0 only if every invariant held.
"""

import argparse
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'sdk' / 'py'))
import forge_airlock as fa  # noqa: E402

DISPATCHER = ROOT / 'bin' / 'forge-airlock'
FIX = ROOT / 'tests' / 'airlock' / 'fixtures'
MAX_MONEY = 9223372036854775807
REASONS = ('DUPLICATE_CHARGE', 'SHIPPING', 'GOODWILL', 'NOT_A_RULE')
BURST = 50
STORM = 20


class Fuzz:
    def __init__(self, a):
        self.a = a
        self.rng = random.Random(a.seed)
        self.work = Path(tempfile.mkdtemp(prefix='airlock-fuzz-'))
        self.store = self.work / 'store'
        self.engine = str(Path(a.engine_dir).resolve() / 'airlock-engine')
        self.n = 0
        self.answers = {}        # request id -> list of first tokens the engine answered
        self.keys = {}           # key -> (tenant, original, shipping_paid)
        self.expect_open = set()  # (request id, tenant) of every lease that must stay open
        self.open_rid = {}        # key -> the request id of its OPEN_MONEY
        self.counts = {'requests': 0, 'local_refusals': 0, 'raw_lines': 0, 'by_code': {}, 'burst_processes': 0,
                       'storm_processes': 0, 'handler_exceptions': 0, 'reads': 0}
        self.violations = []
        self.invariants = {}

    def rid(self, tag):
        self.n += 1
        return '%s%d' % (tag, self.n)

    def cli(self, args):
        args = list(args) + ['--engine-dir', str(Path(self.a.engine_dir).resolve())]
        p = subprocess.run([sys.executable, str(DISPATCHER)] + [str(x) for x in args], capture_output=True, timeout=300)
        return p.returncode, p.stdout.decode('ascii', 'replace')

    def note(self, rid, code):
        self.counts['requests'] += 1
        self.counts['by_code'][code] = self.counts['by_code'].get(code, 0) + 1
        if rid is not None:
            self.answers.setdefault(rid, []).append(code)

    def call(self, rid, fn):
        try:
            r = fn()
            self.note(rid, r.code)
            return r
        except fa.LocalRefusal:
            self.counts['local_refusals'] += 1
            return None
        except fa.AirlockError as e:
            self.note(rid, e.code)
            if not e.outcome_known or isinstance(e, (fa.EngineFault, fa.EngineDead)):
                self.violations.append('engine fault or unknown outcome: %s' % e)
                raise
            return None

    # -- the attacks
    def open_keys(self, st, r):
        made = []
        for tenant in ('tA', 'tB'):
            key = 'o%d%s' % (r, tenant[1])
            original = self.rng.choice([1, 2, 100, 10000, self.rng.randint(1, 10 ** 6), MAX_MONEY])
            ship = self.rng.choice([0, 1, 10, original])
            rid = self.rid('op')
            res = self.call(rid, lambda: st.open_money(tenant, key, rid, 'store-refunds', original, {'shipping_paid': ship}))
            if res and res.committed:
                self.keys[key] = (tenant, original, ship)
                self.open_rid[key] = rid  # a request id that this tenant used
                made.append(key)
        return made

    def boundary(self, st, key):
        tenant, original, _ = self.keys[key]
        for _ in range(12):
            h = st.get(tenant, key)
            remaining = int(h.fields['remaining'])
            amount = self.rng.choice([0, -1, 1, remaining, remaining + 1, MAX_MONEY, MAX_MONEY + 1, 2 ** 64, '01', '1e3', '+1', 2001, 7500])
            reason = self.rng.choice(REASONS)
            pre = h.state_hash if self.rng.random() < 0.85 else self.rng.choice(['0' * 32, 'f' * 32])
            rid = self.rid('b')
            self.call(rid, lambda: st.refund(tenant, key, rid, pre, reason, amount))

    def strings(self, st, key):
        tenant, _, _ = self.keys[key]
        h = st.get(tenant, key).state_hash
        raws = [b'REFUND %s %s s%d %s DUPLICATE_CHARGE 1\x00' % (tenant.encode(), key.encode(), self.n, h.encode()),
                b'REFUND %s %s s%d %s DUPLICATE_CHARGE 1\r' % (tenant.encode(), key.encode(), self.n, h.encode()),
                b'REFUND\t%s %s s%d %s DUPLICATE_CHARGE 1' % (tenant.encode(), key.encode(), self.n, h.encode()),
                ('REFUND %s %s sé%d %s DUPLICATE_CHARGE 1' % (tenant, key, self.n, h)).encode('utf-8'),
                b'REFUND %s %s s%d %s DUPLICATE_CHARGE \xff' % (tenant.encode(), key.encode(), self.n, h.encode()),
                b'REFUND %s %s s%d %s %s 1' % (tenant.encode(), key.encode(), self.n, h.encode(), b'R' * self.rng.randint(70000, 90000)),
                b'REFUND  %s %s s%d %s DUPLICATE_CHARGE 1' % (tenant.encode(), key.encode(), self.n, h.encode()),
                b'', b' ', b'\x00' * self.rng.randint(1, 64)]
        for line in raws:
            self.n += 1
            a = st.raw(line)
            self.counts['raw_lines'] += 1
            code = a.split(' ')[0]
            self.note(None, code)
            if code == 'COMMITTED':
                self.violations.append('a raw garbage line committed: %r' % line[:60])
        for bad in ('a\nb', 'a\rb', 'a\x00b', 'café', 'x' * 25, '', 'a b'):
            rid = self.rid('u')
            self.call(rid, lambda: st.refund(tenant, key, bad, h, 'DUPLICATE_CHARGE', 1))
            self.call(rid, lambda: st.refund(bad, key, rid, h, 'DUPLICATE_CHARGE', 1))

    def cross_tenant(self, st, key):
        tenant, _, _ = self.keys[key]
        other = 'tB' if tenant == 'tA' else 'tA'
        h = st.get(tenant, key).state_hash
        rid = self.rid('x')
        r = self.call(rid, lambda: st.refund(other, key, rid, h, 'DUPLICATE_CHARGE', 1))
        if r is not None or self.answers.get(rid, [None])[-1] != 'UNKNOWN_KEY':
            self.violations.append('cross-tenant write was not UNKNOWN_KEY: %r %r' % (r, self.answers.get(rid)))
        try:
            g = st.get(other, key)
            self.violations.append('cross-tenant get was not refused: %r' % g)
        except fa.EngineRefusal as e:
            if e.code != 'UNKNOWN_KEY':
                self.violations.append('cross-tenant get was not UNKNOWN_KEY: %s' % e.code)
        rows = [{'tenant_id': tenant, 'n': i} for i in range(self.rng.randint(1, 5))]
        rows.insert(self.rng.randint(0, len(rows)), self.rng.choice([{'tenant_id': other}, {'x': 1}, {'tenant_id': 7}, {'tenant_id': tenant + ' '}]))
        res = st.read_scoped(tenant, rows)
        self.counts['reads'] += 1
        self.note(None, res.code)
        if res.code != 'TENANT_ISOLATION_BREACH' or res.rows:
            self.violations.append('a mixed-tenant row set was released: %r' % res)
        # a lease of the other tenant on the same key name, with a request id that the first tenant used: it is the other
        # tenant's own lease (no squatting, no breach); its handler raises before the sink, so the sweep must report it
        used = self.open_rid[key]

        def raises_before(lease):
            raise ValueError('injected before the sink (other tenant)')
        try:
            st.with_lease(used, 1, other, key, raises_before)
            self.violations.append('a handler exception did not propagate')
        except ValueError:
            self.counts['handler_exceptions'] += 1
            self.expect_open.add((used, other))
        except fa.LeaseNotOpened as e:
            self.note(None, e.code)
            self.violations.append("a lease of tenant %s was refused because tenant %s used its id: %s" % (other, tenant, e.code))

    def handlers(self, st, key, r):
        tenant, _, _ = self.keys[key]
        for i in range(3):
            rid = self.rid('L')
            where = self.rng.choice(['before', 'after', 'none'])
            deadline = 1000 + r

            def handler(lease):
                if where == 'before':
                    raise ValueError('injected before the sink')
                h = st.get(tenant, key).state_hash
                res = lease.commit('refund', tenant=tenant, key=key, pre_state_hash=h, reason='DUPLICATE_CHARGE', amount=1)
                self.note(rid, res.code)
                if where == 'after':
                    raise ValueError('injected after the sink')
                return res
            try:
                st.with_lease(rid, deadline, tenant, key, handler)
            except ValueError:
                self.counts['handler_exceptions'] += 1
            if where == 'before':
                self.expect_open.add((rid, tenant))
            else:
                # the commit closes the lease if it COMMITTED or got REJECTED_POLICY; else it stays open (also after
                # REQUIRE_HUMAN_COSIGN: the lease is then PENDING_COSIGN and dropped after its deadline, review D6)
                last = self.answers.get(rid, [None])[-1]
                if last not in ('COMMITTED', 'REJECTED_POLICY'):
                    self.expect_open.add((rid, tenant))

    def burst(self, st, key):
        tenant, _, _ = self.keys[key]
        g = st.get(tenant, key)
        if int(g.fields['remaining']) < 1:
            return
        h = g.state_hash
        procs, ids = [], []
        for _ in range(BURST):
            rid = self.rid('t')
            ids.append(rid)
            procs.append(subprocess.Popen([self.engine, 'serve', str(self.store)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                          stderr=subprocess.DEVNULL, env={'PATH': '/usr/bin:/bin'}))
        for rid, p in zip(ids, procs):
            p.stdin.write(('REFUND %s %s %s %s DUPLICATE_CHARGE 1\n' % (tenant, key, rid, h)).encode())
        for p in procs:
            p.stdin.close()
        codes = []
        for rid, p in zip(ids, procs):
            code = p.stdout.read().decode('ascii', 'replace').split(' ')[0].strip()
            p.wait(timeout=120)
            codes.append(code)
            self.note(rid, code)
        self.counts['burst_processes'] += BURST
        if codes.count('COMMITTED') != 1 or codes.count('STALE_STATE_HASH') != BURST - 1:
            self.violations.append('burst: %d COMMITTED, %d STALE of %d' % (codes.count('COMMITTED'), codes.count('STALE_STATE_HASH'), BURST))

    def storm(self, st, key):
        tenant, _, _ = self.keys[key]
        g = st.get(tenant, key)
        if int(g.fields['remaining']) < 1:
            return
        for fresh in (True, False):
            rid = self.rid('d') if fresh else self.storm_used
            h = st.get(tenant, key).state_hash
            procs = [subprocess.Popen([self.engine, 'serve', str(self.store)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                      stderr=subprocess.DEVNULL, env={'PATH': '/usr/bin:/bin'}) for _ in range(STORM)]
            for p in procs:
                p.stdin.write(('REFUND %s %s %s %s DUPLICATE_CHARGE 1\n' % (tenant, key, rid, h)).encode())
                p.stdin.close()
            codes = []
            for p in procs:
                codes.append(p.stdout.read().decode('ascii', 'replace').split(' ')[0].strip())
                p.wait(timeout=120)
            for c in codes:
                self.note(rid, c)
            self.counts['storm_processes'] += STORM
            want = 1 if fresh else 0
            if codes.count('COMMITTED') != want or codes.count('DUPLICATE_REQUEST_ID') != STORM - want:
                self.violations.append('storm (%s id): %r' % ('fresh' if fresh else 'used', sorted(set(codes))))
            if fresh:
                self.storm_used = rid

    # -- the oracle
    def oracle(self, r):
        code, out = self.cli(['replay', self.store])
        lines = out.split('\n')
        held = {}
        if code != 0 or not lines[0].startswith('REPLAY '):
            self.violations.append('round %d: replay failed: %d %r' % (r, code, out[:100]))
            return
        effects = [ln.split(' ', 2)[2].split(' ') for ln in lines[1:] if ln]
        opened, refunded, ship, ids = {}, {}, {}, {}
        i1 = i2 = i3 = i4 = i5 = True
        for e in effects:
            kind, tenant, key, rid = e[0], e[1], e[2], e[3]
            ids[rid] = ids.get(rid, 0) + 1
            if kind == 'OPEN_MONEY':
                facts = dict(x.split('=', 1) for x in e[6:])
                opened[key] = (tenant, int(e[5]), int(facts.get('shipping_paid', '0')))
            elif kind == 'REFUND':
                if key not in opened or opened[key][0] != tenant:
                    i3 = False
                    self.violations.append('round %d: REFUND %s under tenant %s' % (r, key, tenant))
                amount = int(e[5])
                refunded[key] = refunded.get(key, 0) + amount
                if e[4] == 'SHIPPING':
                    ship[key] = ship.get(key, 0) + amount
                if e[4] == 'GOODWILL' and amount > 2000 and e[6] != '1':
                    i2 = False
                    self.violations.append('round %d: GOODWILL %d without a cosign' % (r, amount))
                if e[4] not in ('DUPLICATE_CHARGE', 'SHIPPING', 'GOODWILL'):
                    i2 = False
                    self.violations.append('round %d: reason %s has no rule' % (r, e[4]))
        for key, total in refunded.items():
            if total > opened[key][1]:
                i1 = False
                self.violations.append('round %d: key %s refunded %d > original %d' % (r, key, total, opened[key][1]))
            if ship.get(key, 0) > opened[key][2]:
                i2 = False
                self.violations.append('round %d: key %s SHIPPING %d > fact %d' % (r, key, ship[key], opened[key][2]))
        committed = {rid for rid, codes in self.answers.items() if 'COMMITTED' in codes}
        for rid, n in ids.items():
            if n != 1 or rid not in committed:
                i4 = False
                self.violations.append('round %d: id %s has %d effects; answered COMMITTED: %s' % (r, rid, n, rid in committed))
        for rid in committed:
            if self.answers[rid].count('COMMITTED') != 1 or rid not in ids:
                i4 = False
                self.violations.append('round %d: id %s answered COMMITTED %d times, in WAL: %s' % (r, rid, self.answers[rid].count('COMMITTED'), rid in ids))
        for rid in set(self.answers) - committed:
            if rid in ids:
                i5 = False
                self.violations.append('round %d: refused id %s left an effect' % (r, rid))
        code, st = self.cli(['state', self.store])
        i6 = code == 0 and st.startswith('STATE ') and ('effects=%d ' % len(effects)) in st
        if not i6:
            self.violations.append('round %d: state %d %r' % (r, code, st[:120]))
        code, sw = self.cli(['leases', self.store, '--sweep', '--now', str(10 ** 12)])
        dropped = {(ln.split(' ')[1], ln.split(' ')[3]) for ln in sw.split('\n') if ln.startswith('DROPPED_OBLIGATION ')}
        i7 = dropped == self.expect_open and code == (24 if dropped else 0)
        if not i7:
            self.violations.append('round %d: dropped %s, expected %s' % (r, sorted(dropped), sorted(self.expect_open)))
        held = {'I1_total_cap': i1, 'I2_reason_caps': i2, 'I3_tenant': i3, 'I4_one_commit_per_id': i4, 'I5_refusal_no_effect': i5,
                'I6_store_opens': i6, 'I7_dropped_obligations': i7}
        for k, v in held.items():
            self.invariants[k] = self.invariants.get(k, True) and v

    def run(self):
        args = ['init', self.store, '--store-id', 'fuzz-%d' % (self.a.seed % 10 ** 9), '--node', self.a.node]
        for p in ('money-parametric', 'saga-payout', 'inventory-seats'):
            args += ['--policy', FIX / (p + '.json')]
        code, out = self.cli(args)
        if code != 0:
            print('NOT RUN: init failed: %d %r' % (code, out))
            return False
        before = len(self.violations)
        with fa.Store(self.store, node=self.a.node, engine_dir=Path(self.a.engine_dir).resolve()) as st:
            for r in range(self.a.rounds):
                keys = self.open_keys(st, r)
                for key in keys:
                    self.boundary(st, key)
                    self.strings(st, key)
                    self.cross_tenant(st, key)
                    self.handlers(st, key, r)
                race = 'race%d' % r
                rid = self.rid('op')
                res = self.call(rid, lambda: st.open_money('tA', race, rid, 'store-refunds', 1000000, {'shipping_paid': 0}))
                if res is None or not res.committed:
                    self.violations.append('round %d: could not open the race key' % r)
                    continue
                self.keys[race] = ('tA', 1000000, 0)
                self.burst(st, race)
                self.storm(st, race)
                self.oracle(r)
                print('round %d: %d requests so far, %d violations' % (r, self.counts['requests'], len(self.violations)), flush=True)
        self.invariants['I8_burst_and_storm'] = not any(v.startswith(('burst', 'storm')) for v in self.violations[before:])
        return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--engine-dir', default=str(ROOT / 'build' / 'airlock'))
    ap.add_argument('--node', default=None)
    ap.add_argument('--seed', type=int, default=20)
    ap.add_argument('--rounds', type=int, default=3)
    ap.add_argument('--json', default=None)
    ap.add_argument('--keep', action='store_true')
    a = ap.parse_args()
    if a.rounds < 1 or a.rounds > 100:
        print('--rounds: 1..100')
        return 2
    a.node = a.node or os.environ.get('FORGE_AIRLOCK_NODE') or shutil.which('node')
    if not a.node:
        print('NOT RUN: no node (give --node; Node 24.3.0)')
        return 2
    if not (Path(a.engine_dir) / 'airlock-engine').is_file():
        print('NOT RUN: %s/airlock-engine is missing' % a.engine_dir)
        return 2
    f = Fuzz(a)
    t0 = time.time()
    try:
        ran = f.run()
    except fa.AirlockError as e:
        f.violations.append('stopped by %s' % e)
        ran = True
    finally:
        if not a.keep:
            shutil.rmtree(f.work, ignore_errors=True)
    ok = ran and not f.violations and len(f.invariants) == 8 and all(f.invariants.values())
    report = {'label': 'FINITE TEST', 'end_to_end': False, 'seed': a.seed, 'rounds': a.rounds,
              'counts': {k: (dict(sorted(v.items())) if isinstance(v, dict) else v) for k, v in sorted(f.counts.items())},
              'invariants': {k: ('HELD' if v else 'VIOLATED') for k, v in sorted(f.invariants.items())},
              'violations': f.violations[:50], 'result': 'PASS' if ok else 'FAIL'}
    for k, v in report['counts'].items():
        print('count %-18s %s' % (k, json.dumps(v, sort_keys=True)))
    for k, v in report['invariants'].items():
        print('%-8s %s' % (v, k))
    for v in f.violations[:20]:
        print('VIOLATION %s' % v)
    print('fuzz %s: seed %d, %d rounds, %.1fs; FINITE TEST; end_to_end=false' % (report['result'], a.seed, a.rounds, time.time() - t0))
    if a.json:
        Path(a.json).write_text(json.dumps(report, indent=1, sort_keys=True) + '\n')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
