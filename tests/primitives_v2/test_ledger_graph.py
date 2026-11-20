#!/usr/bin/env python3
"""FINITE TEST of primitive 7, `ledger_graph` (src/primitives_v2/ledger_graph.rs). It proves nothing.

Usage: python3 tests/primitives_v2/test_ledger_graph.py <engine> [--case NAME]... [--work DIR] [--steps N] [--keep]

<engine> is the production build of the primitives engine. Every case drives the real binary (`init`, `serve`,
`state`, `replay`) with Python standard library only. The suite has its OWN transcription of the WAL record format
(zlib CRC-32, hashlib SHA-256) to read the WAL and to write hostile records with a valid chain; that transcription
and the engine can be wrong in the same way. Case `model` compares the engine with a small independent Python model
of the rules (written from the documentation at the top of ledger_graph.rs, not from its code). A SIGKILL is not a
power loss. All times are indicative: the machine is shared and loaded.
A case that cannot run FAILS with NOT RUN in its message; it never passes.
Exit 0: every selected case passed. 1: at least one failed. 2: the suite could not start.
"""

import argparse
import collections
import hashlib
import os
from pathlib import Path
import random
import re
import select
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse
import zlib

sys.dont_write_bytecode = True
HDR = 68
MAGIC = b'PV2R'
WAL = 'primitives.wal'
U64 = (1 << 64) - 1
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}
EXITS = {'COMMITTED': 0, 'OK': 0, 'STATE': 0, 'INITIALIZED': 0, 'USAGE': 2, 'MALFORMED_REQUEST': 12,
         'STALE_STATE_HASH': 13, 'DUPLICATE_REQUEST_ID': 14, 'TENANT_ISOLATION_BREACH': 16, 'CORRUPT_WAL': 17,
         'IO_ERROR': 18, 'OUTCOME_UNKNOWN': 19, 'MALFORMED_POLICY': 25, 'STORE_BUSY': 26, 'NOT_IMPLEMENTED': 27,
         'UNSAFE_STORE': 28, 'MODULE_FAULT': 29}
ANSWER = re.compile(r'^([A-Z][A-Z0-9_]{1,47})((?: [A-Za-z0-9_.:@+-]+=[A-Za-z0-9._~:/@$\[\]+,%-]*)*)(?: -- ([ -~]*))?$')


class Failed(Exception):
    pass


def require(cond, msg):
    if not cond:
        raise Failed(msg)


class Answer:
    def __init__(self, line):
        m = ANSWER.match(line)
        require(m is not None, 'answer breaks the wire grammar: %r' % line)
        self.line, self.code, self.detail = line, m.group(1), m.group(3) or ''
        self.f = {k: urllib.parse.unquote(v) for k, v in (tok.split('=', 1) for tok in m.group(2).split())}

    def __repr__(self):
        return self.line

    def num(self, k):
        v = self.f.get(k, '')
        return int(v) if v.isdigit() else -1


# ---- the WAL, transcribed independently -------------------------------------------------------------------------
def crc(b):
    return zlib.crc32(b) & 0xffffffff


def record(seq, now, wall, prev, payload):
    h = MAGIC + struct.pack('<QQQ', seq, now, wall) + prev + struct.pack('<I', len(payload))
    h += struct.pack('<I', crc(h))
    body = h + payload
    return body + struct.pack('<I', crc(body))


def parse_wal(data):
    out, i, prev = [], 0, b'\0' * 32
    while i + HDR <= len(data):
        h = data[i:i + HDR]
        require(h[:4] == MAGIC and struct.unpack('<I', h[64:68])[0] == crc(h[:64]), 'suite WAL parser: header at %d' % i)
        seq, now, wall = struct.unpack('<QQQ', h[4:28])
        n = struct.unpack('<I', h[60:64])[0]
        if i + HDR + n + 4 > len(data):
            break
        rec = data[i:i + HDR + n + 4]
        require(struct.unpack('<I', rec[-4:])[0] == crc(rec[:-4]) and h[28:60] == prev and seq == len(out), 'suite WAL parser: record %d' % len(out))
        out.append({'seq': seq, 'now': now, 'wall': wall, 'payload': rec[HDR:HDR + n].decode(), 'raw': rec})
        prev = hashlib.sha256(rec).digest()
        i += len(rec)
    return out, data[i:]


def wal_of(store):
    return (Path(store) / WAL).read_bytes()


def effects(recs):
    """(op, rid, tenant, keys, payload) of every effect record of ledger_graph."""
    out = []
    for r in recs[1:]:
        head, _, payload = r['payload'].partition(' |')
        t = head.split(' ')
        if t[1] != 'ledger_graph':
            continue
        require(t[5] == 'C', 'a ledger_graph record of kind %s' % t[5])
        out.append((t[2], t[3], t[4], t[7:7 + int(t[6])], payload[1:]))
    return out


def append_forged(store, payload):
    """Appends one record with a valid chain, seq and time (the suite's own writer). Returns the old bytes."""
    data = wal_of(store)
    recs, rest = parse_wal(data)
    require(rest == b'', 'forge: torn tail')
    last = recs[-1]
    (Path(store) / WAL).write_bytes(data + record(len(recs), last['now'], last['now'], hashlib.sha256(last['raw']).digest(), payload.encode()))
    return data


# ---- processes ----------------------------------------------------------------------------------------------------
def run(engine, *args, inp=None, timeout=600):
    p = subprocess.run([str(engine)] + [str(a) for a in args], input=inp, capture_output=True, env=ENV, timeout=timeout)
    return p.returncode, p.stdout.decode(errors='replace')


def one(engine, *args, expect=None):
    code, out = run(engine, *args)
    a = Answer(out.rstrip('\n'))
    require(code == EXITS.get(a.code, 10), 'exit %d does not match the answer %r' % (code, a.line))
    if expect:
        require(a.code == expect, '%s: expected %s, got %r' % (args[0], expect, a.line))
    return a


class Session:
    def __init__(self, engine, store):
        self.p = subprocess.Popen([str(engine), 'serve', str(store)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, env=ENV, bufsize=0)

    def read(self, timeout=300):
        buf = b''
        end = time.monotonic() + timeout
        while not buf.endswith(b'\n'):
            r, _, _ = select.select([self.p.stdout], [], [], max(end - time.monotonic(), 0))
            if not r:
                return None
            c = self.p.stdout.read(1)
            if not c:
                return None
            buf += c
        return Answer(buf[:-1].decode())

    def ask(self, line, expect=None, why=None):
        self.p.stdin.write(line.encode() + b'\n')
        a = self.read()
        require(a is not None, 'no answer to %r' % line[:200])
        if expect:
            require(a.code == expect, '%s: expected %s, got %r' % (why or line[:160], expect, a.line[:300]))
        return a

    def close(self):
        try:
            self.p.stdin.close()
        except OSError:
            pass
        return self.p.wait(timeout=600)

    def kill(self):
        self.p.kill()
        self.p.wait()


POLICIES = {
    'L1': {'kind': 'ledger', 'issuance': 'fixed', 'max_balance': '1000', 'max_legs': '4'},
    'L2': {'kind': 'ledger', 'issuance': 'mint_burn', 'max_balance': '500', 'max_legs': '16'},
    'names': {'kind': 'registry', 'case': 'ascii_fold', 'max_name_bytes': '24'},
    'slugs': {'kind': 'registry', 'case': 'exact', 'max_name_bytes': '8'},
    'gp': {'kind': 'graph', 'max_nodes': '6', 'max_edges': '8'},
    'gq': {'kind': 'graph', 'max_nodes': '100', 'max_edges': '100'},
}


class Suite:
    def __init__(self, engine, work, steps):
        self.engine, self.work, self.steps, self.n = engine, Path(work), steps, 0

    def folder(self, name):
        self.n += 1
        d = self.work / ('%s-%d' % (name, self.n))
        d.mkdir(mode=0o700)
        return d

    def store(self, name, pols=None):
        d = self.folder(name)
        args = ['init', d / 'st', '--store-id', 'st1']
        for pname, body in (pols or POLICIES).items():
            p = d / ('%s.json' % pname)
            p.write_text('{"primitive": "ledger_graph", "version": 1, "name": "%s", %s}' % (pname, ', '.join('"%s": "%s"' % kv for kv in body.items())))
            args += ['--policy', p]
        a = one(self.engine, *args, expect='INITIALIZED')
        return d / 'st', a.f['genesis']


# ---- the independent model ----------------------------------------------------------------------------------------
class Model:
    """The rules of ledger_graph.rs, written from its documentation. Engine checks it predicts: tenant of a key,
    stale hash (the caller says which keys are stale). Everything else is the module."""

    def __init__(self, pols):
        self.pols = pols
        self.acc = {}       # key -> [tenant, ledger, balance]
        self.led = {}       # (tenant, ledger) -> [total, issued, destroyed, accounts]
        self.names = {}     # (registry, canonical) -> tenant
        self.reg = {}       # handle -> claims
        self.graphs = {}    # key -> {'tenant', 'policy', 'edges': set}
        self.bound = {}     # key -> tenant (engine binding)

    def snapshot(self):
        return repr((sorted(self.acc.items()), sorted(self.led.items()), sorted(self.names.items()), sorted(self.reg.items()),
                     sorted((k, g['tenant'], g['policy'], sorted(g['edges'])) for k, g in self.graphs.items()), sorted(self.bound.items())))

    def kind(self, k):
        return 'account' if k in self.acc else 'graph' if k in self.graphs else 'registry' if k in self.reg else None

    def lpol(self, name):
        p = self.pols.get(name)
        if p is None:
            return None, ('UNKNOWN_POLICY', {})
        if p['kind'] != 'ledger':
            return None, ('WRONG_POLICY_KIND', {'policy_kind': 'not_ledger'})
        return p, None

    def accounts(self, tenant, ledger, keys):
        for k in keys:
            if k not in self.acc:
                kd = self.kind(k)
                return ('WRONG_KEY_KIND', {'key': k, 'kind': kd}) if kd else ('UNKNOWN_ACCOUNT', {'key': k})
            if self.acc[k][1] != ledger:
                return ('CROSS_LEDGER', {'key': k, 'ledger': self.acc[k][1]})
        return None

    @staticmethod
    def reach(adj, start, goal):
        if start == goal:
            return 0
        seen, q = {start}, collections.deque([(start, 0)])
        while q:
            n, d = q.popleft()
            for m in adj.get(n, ()):
                if m == goal:
                    return d + 1
                if m not in seen:
                    seen.add(m)
                    q.append((m, d + 1))
        return None

    def module(self, tenant, op, keys, args):
        """(code, fields, payload or None). No change of state."""
        t = args.split(' ')
        if op == 'open':
            p, err = self.lpol(t[0])
            if err:
                return err + (None,)
            bals = [int(x) for x in t[1:]]
            if len(bals) != len(keys):
                return 'MALFORMED_REQUEST', {'why': 'LEG_COUNT'}, None
            for k in keys:
                if k.startswith('reg:'):
                    return 'MALFORMED_REQUEST', {'why': 'RESERVED_KEY'}, None
                kd = self.kind(k)
                if kd:
                    return ('ACCOUNT_EXISTS', {'key': k}, None) if kd == 'account' else ('WRONG_KEY_KIND', {'key': k, 'kind': kd}, None)
            for k, b in zip(keys, bals):
                if b > int(p['max_balance']):
                    return 'BALANCE_LIMIT', {'key': k, 'max_balance': p['max_balance']}, None
            if p['issuance'] == 'fixed' and (tenant, t[0]) in self.led and any(bals):
                return 'SUPPLY_FIXED', {}, None
            return 'COMMITTED', {}, args
        if op == 'transfer':
            p, err = self.lpol(t[0])
            if err:
                return err + (None,)
            f, to, amt = t[1], t[2], int(t[3])
            if f == to:
                return 'SELF_TRANSFER', {}, None
            if sorted([f, to]) != keys:
                return 'MALFORMED_REQUEST', {'why': 'LEG_KEYS'}, None
            if amt == 0:
                return 'ZERO_AMOUNT', {'index': '0'}, None
            e = self.accounts(tenant, t[0], keys)
            if e:
                return e + (None,)
            if self.acc[f][2] < amt:
                return 'INSUFFICIENT_FUNDS', {'key': f, 'balance': str(self.acc[f][2]), 'needed': str(amt)}, None
            if self.acc[to][2] + amt > int(p['max_balance']):
                return 'BALANCE_LIMIT', {'key': to, 'max_balance': p['max_balance']}, None
            return 'COMMITTED', {}, args
        if op == 'post':
            p, err = self.lpol(t[0])
            if err:
                return err + (None,)
            legs = [(x[0] == '+', int(x[1:])) for x in t[1:]]
            if len(legs) != len(keys):
                return 'MALFORMED_REQUEST', {'why': 'LEG_COUNT'}, None
            if len(keys) > int(p['max_legs']):
                return 'TOO_MANY_LEGS', {'max_legs': p['max_legs']}, None
            for i, (_, a) in enumerate(legs):
                if a == 0:
                    return 'ZERO_AMOUNT', {'index': str(i)}, None
            deb = sum(a for c, a in legs if not c)
            cre = sum(a for c, a in legs if c)
            if deb != cre:
                return 'CONSERVATION_BREACH', {'debit_total': str(deb), 'credit_total': str(cre)}, None
            e = self.accounts(tenant, t[0], keys)
            if e:
                return e + (None,)
            for k, (c, a) in zip(keys, legs):
                if not c and self.acc[k][2] < a:
                    return 'INSUFFICIENT_FUNDS', {'key': k, 'balance': str(self.acc[k][2]), 'needed': str(a)}, None
                if c and self.acc[k][2] + a > int(p['max_balance']):
                    return 'BALANCE_LIMIT', {'key': k, 'max_balance': p['max_balance']}, None
            return 'COMMITTED', {}, args
        if op in ('mint', 'burn'):
            p, err = self.lpol(t[0])
            if err:
                return err + (None,)
            if p['issuance'] == 'fixed':
                return 'ISSUANCE_DISABLED', {}, None
            amt = int(t[1])
            if amt == 0:
                return 'ZERO_AMOUNT', {'index': '0'}, None
            e = self.accounts(tenant, t[0], keys)
            if e:
                return e + (None,)
            b = self.acc[keys[0]][2]
            if op == 'mint' and b + amt > int(p['max_balance']):
                return 'BALANCE_LIMIT', {'key': keys[0], 'max_balance': p['max_balance']}, None
            if op == 'burn' and b < amt:
                return 'INSUFFICIENT_FUNDS', {'key': keys[0], 'balance': str(b), 'needed': str(amt)}, None
            return 'COMMITTED', {}, args
        if op in ('claim', 'release'):
            if keys != ['reg:' + tenant]:
                return 'MALFORMED_REQUEST', {'why': 'REGISTRY_KEY', 'expected': 'reg:' + tenant}, None
            p = self.pols.get(t[0])
            if p is None:
                return 'UNKNOWN_POLICY', {}, None
            if p['kind'] != 'registry':
                return 'WRONG_POLICY_KIND', {'policy_kind': 'not_registry'}, None
            if len(t[1]) > int(p['max_name_bytes']):
                return 'MALFORMED_REQUEST', {'why': 'NAME', 'max_name_bytes': p['max_name_bytes']}, None
            canon = ''.join(chr(ord(c) + 32) if 'A' <= c <= 'Z' else c for c in t[1]) if p['case'] == 'ascii_fold' else t[1]
            holder = self.names.get((t[0], canon))
            if op == 'claim' and holder is not None:
                return 'DUPLICATE_KEY', {'registry': t[0]}, None
            if op == 'release' and holder != tenant:
                return 'NOT_HOLDER', {'registry': t[0]}, None
            return 'COMMITTED', {}, '%s %s' % (t[0], canon)
        if op in ('add_edge', 'remove_edge'):
            p = self.pols.get(t[0])
            if p is None:
                return 'UNKNOWN_POLICY', {}, None
            if p['kind'] != 'graph':
                return 'WRONG_POLICY_KIND', {'policy_kind': 'not_graph'}, None
            k = keys[0]
            if k.startswith('reg:'):
                return 'MALFORMED_REQUEST', {'why': 'RESERVED_KEY'}, None
            kd = self.kind(k)
            if kd not in (None, 'graph'):
                return 'WRONG_KEY_KIND', {'key': k, 'kind': kd}, None
            g = self.graphs.get(k)
            if g and g['policy'] != t[0]:
                return 'POLICY_MISMATCH', {'policy': g['policy']}, None
            edges = set(g['edges']) if g else set()
            pairs = list(zip(t[1::2], t[2::2]))
            if op == 'remove_edge':
                if pairs[0] not in edges:
                    return 'NO_SUCH_EDGE', {'edge': '%s->%s' % pairs[0]}, None
                return 'COMMITTED', {}, args
            nodes = {n for e in edges for n in e}
            for i, (a, b) in enumerate(pairs):
                edge = '%s->%s' % (a, b)
                if a == b:
                    return 'DAG_CYCLE_DETECTED', {'edge': edge, 'cycle_len': '1', 'index': str(i)}, None
                if (a, b) in edges:
                    return 'EDGE_EXISTS', {'edge': edge, 'index': str(i)}, None
                adj = {}
                for x, y in edges:
                    adj.setdefault(x, []).append(y)
                d = self.reach(adj, b, a)
                if d is not None:
                    return 'DAG_CYCLE_DETECTED', {'edge': edge, 'cycle_len': str(d + 1), 'index': str(i)}, None
                edges.add((a, b))
                if len(edges) > int(p['max_edges']):
                    return 'GRAPH_FULL', {'limit': 'max_edges', 'max': p['max_edges']}, None
                nodes |= {a, b}
                if len(nodes) > int(p['max_nodes']):
                    return 'GRAPH_FULL', {'limit': 'max_nodes', 'max': p['max_nodes']}, None
            return 'COMMITTED', {}, args
        raise Failed('model: unknown op %s' % op)

    def apply(self, tenant, op, keys, payload):
        t = payload.split(' ')
        for k in keys:
            self.bound[k] = tenant
        if op == 'open':
            led = self.led.setdefault((tenant, t[0]), [0, 0, 0, 0])
            for k, b in zip(keys, map(int, t[1:])):
                self.acc[k] = [tenant, t[0], b]
                led[0] += b
                led[1] += b
                led[3] += 1
        elif op == 'transfer':
            self.acc[t[1]][2] -= int(t[3])
            self.acc[t[2]][2] += int(t[3])
        elif op == 'post':
            for k, x in zip(keys, t[1:]):
                self.acc[k][2] += int(x[1:]) if x[0] == '+' else -int(x[1:])
        elif op == 'mint':
            self.acc[keys[0]][2] += int(t[1])
            self.led[(tenant, t[0])][0] += int(t[1])
            self.led[(tenant, t[0])][1] += int(t[1])
        elif op == 'burn':
            self.acc[keys[0]][2] -= int(t[1])
            self.led[(tenant, t[0])][0] -= int(t[1])
            self.led[(tenant, t[0])][2] += int(t[1])
        elif op == 'claim':
            self.names[(t[0], t[1])] = tenant
            self.reg[keys[0]] = self.reg.get(keys[0], 0) + 1
        elif op == 'release':
            del self.names[(t[0], t[1])]
            self.reg[keys[0]] -= 1
        elif op == 'add_edge':
            g = self.graphs.setdefault(keys[0], {'tenant': tenant, 'policy': t[0], 'edges': set()})
            g['edges'] |= set(zip(t[1::2], t[2::2]))
        elif op == 'remove_edge':
            self.graphs[keys[0]]['edges'].discard((t[1], t[2]))

    def request(self, tenant, op, keys, args, stale=()):
        """The whole predicted answer, engine checks included; applies a commit."""
        for k in keys:
            if self.bound.get(k, tenant) != tenant:
                return 'TENANT_ISOLATION_BREACH', {'why': 'KEY_OF_ANOTHER_TENANT', 'key': k}, None
        if stale:
            return 'STALE_STATE_HASH', {'stale': str(len(stale))}, None
        code, f, payload = self.module(tenant, op, keys, args)
        if code == 'COMMITTED':
            self.apply(tenant, op, keys, payload)
        return code, f, payload

    def describe(self, k):
        if k in self.acc:
            t, l, b = self.acc[k]
            led = self.led[(t, l)]
            return {'kind': 'account', 'ledger': l, 'balance': str(b), 'ledger_total': str(led[0]), 'ledger_issued': str(led[1]),
                    'ledger_destroyed': str(led[2]), 'ledger_accounts': str(led[3])}
        if k in self.reg:
            return {'kind': 'registry', 'claims': str(self.reg[k])}
        if k in self.graphs:
            g = self.graphs[k]
            return {'kind': 'graph', 'policy': g['policy'], 'nodes': str(len({n for e in g['edges'] for n in e})), 'edges': str(len(g['edges']))}
        return None

    def check_conservation(self):
        for (t, l), (total, issued, destroyed, _) in self.led.items():
            s = sum(a[2] for a in self.acc.values() if a[0] == t and a[1] == l)
            require(s == total == issued - destroyed, 'model conservation (%s, %s)' % (t, l))
            require(all(a[2] >= 0 for a in self.acc.values()), 'model: a negative balance')


def fold_wal(store):
    """The model's own fold of the WAL: every record must be a commit the model accepts."""
    m = Model(POLICIES)
    recs, rest = parse_wal(wal_of(store))
    require(rest == b'', 'torn tail left after state')
    for op, rid, tenant, keys, payload in effects(recs):
        code, f, p = m.request(tenant, op, keys, payload)
        require(code == 'COMMITTED' and p == payload, 'the model refuses WAL record %s %s %r: %s %r' % (rid, op, payload, code, f))
    return m


# ---- helpers on a session -----------------------------------------------------------------------------------------
class Client:
    def __init__(self, engine, store, genesis):
        self.ses = Session(engine, store)
        self.g = genesis
        self.n = 0

    def rid(self):
        self.n += 1
        return 'r%d' % self.n

    def hash(self, tenant, k):
        a = self.ses.ask('GET %s %s' % (tenant, k))
        return a.f.get('hash', self.g)

    def do(self, tenant, op, keys, args, expect=None, why=None, hashes=None):
        keys = sorted(keys)
        hs = hashes or [self.hash(tenant, k) for k in keys]
        line = 'DO ledger_graph %s %s %s %d %s %s' % (op, self.rid(), tenant, len(keys), ' '.join('%s %s' % kh for kh in zip(keys, hs)), args)
        return self.ses.ask(line, expect, why)

    def get(self, tenant, k):
        return self.ses.ask('GET %s %s' % (tenant, k))

    def conservation(self, tenant, ledger, accounts, const=None):
        tot = 0
        info = None
        for k in accounts:
            a = self.get(tenant, k)
            require(a.code == 'OK' and a.f.get('ledger') == ledger, 'GET %s: %r' % (k, a))
            tot += int(a.f['balance'])
            info = a
        require(info.num('ledger_total') == tot == info.num('ledger_issued') - info.num('ledger_destroyed'),
                'conservation from outside: sum %d, %r' % (tot, info))
        if const is not None:
            require(tot == const, 'fixed supply changed: %d != %d' % (tot, const))
        return tot

    def close(self):
        return self.ses.close()


# ---- cases --------------------------------------------------------------------------------------------------------
def case_policy(s):
    bad = [{'kind': 'ledger', 'issuance': 'fixed', 'max_balance': '0', 'max_legs': '4'},
           {'kind': 'ledger', 'issuance': 'fixed', 'max_balance': '10', 'max_legs': '17'},
           {'kind': 'ledger', 'issuance': 'free', 'max_balance': '10', 'max_legs': '4'},
           {'kind': 'ledger', 'issuance': 'fixed', 'max_balance': '10', 'max_legs': '4', 'x': '1'},
           {'kind': 'registry', 'case': 'unicode', 'max_name_bytes': '8'},
           {'kind': 'registry', 'case': 'exact', 'max_name_bytes': '257'},
           {'kind': 'graph', 'max_nodes': '1', 'max_edges': '5'},
           {'kind': 'graph', 'max_nodes': '5'},
           {'kind': 'tree', 'max_nodes': '5', 'max_edges': '5'}]
    for i, body in enumerate(bad):
        d = s.folder('pol')
        p = d / 'p.json'
        p.write_text('{"primitive": "ledger_graph", "version": 1, "name": "p", %s}' % ', '.join('"%s": "%s"' % kv for kv in body.items()))
        code, out = run(s.engine, 'init', d / 'st', '--policy', p)
        require(code == 25 and out.startswith('MALFORMED_POLICY'), 'bad policy %d accepted: %r' % (i, out))
        require(not (d / 'st').exists(), 'a refused init left a store')
    s.store('pol-ok')
    return '%d bad policy files refused (exit 25); the 6 policies of the suite accepted' % len(bad)


def case_ledger(s):
    st, g = s.store('ledger')
    c = Client(s.engine, st, g)
    A = ['a0', 'a1', 'a2']
    c.do('t1', 'open', A, 'L1 600 300 100', 'COMMITTED')
    c.conservation('t1', 'L1', A, 1000)
    c.do('t1', 'open', ['a3'], 'L1 5', 'SUPPLY_FIXED', 'a second open with a nonzero balance in a fixed ledger')
    c.do('t1', 'open', ['a3'], 'L1 0', 'COMMITTED')
    A.append('a3')
    c.do('t1', 'open', ['a0'], 'L1 0', 'ACCOUNT_EXISTS')
    c.do('t1', 'open', ['reg:t1'], 'L1 0', 'MALFORMED_REQUEST')
    a = c.do('t1', 'transfer', ['a0', 'a1'], 'L1 a0 a1 250', 'COMMITTED')
    require(a.f['hash.a0'] == a.f['hash.a1'], 'one record for both accounts: %r' % a)
    c.conservation('t1', 'L1', A, 1000)
    a = c.do('t1', 'transfer', ['a2', 'a3'], 'L1 a2 a3 101', 'INSUFFICIENT_FUNDS', 'overdraft')
    require(a.f['balance'] == '100' and a.f['needed'] == '101' and a.f['key'] == 'a2', 'overdraft repair fields: %r' % a)
    c.do('t1', 'transfer', ['a2', 'a3'], 'L1 a2 a3 100', 'COMMITTED')
    c.do('t1', 'transfer', ['a2', 'a3'], 'L1 a2 a3 0', 'ZERO_AMOUNT', 'zero transfer')
    c.do('t1', 'transfer', ['a2', 'a3'], 'L1 a3 a3 1', 'SELF_TRANSFER', 'self transfer')
    c.do('t1', 'transfer', ['a1', 'a3'], 'L1 a1 a2 1', 'MALFORMED_REQUEST', 'from/to not the keys')
    c.do('t1', 'transfer', ['a1', 'a9'], 'L1 a1 a9 1', 'UNKNOWN_ACCOUNT', 'unknown account')
    a = c.do('t1', 'transfer', ['a1', 'a3'], 'L1 a1 a3 %d' % (U64 + 1), 'MALFORMED_REQUEST', 'amount above u64')
    # u64 overflow in a ledger with max_balance = u64::MAX
    st2, g2 = s.store('ledger-u64', {'LM': {'kind': 'ledger', 'issuance': 'mint_burn', 'max_balance': str(U64), 'max_legs': '2'}})
    c2 = Client(s.engine, st2, g2)
    c2.do('t1', 'open', ['x', 'y'], 'LM %d %d' % (U64, U64), 'COMMITTED')
    c2.do('t1', 'transfer', ['x', 'y'], 'LM x y 1', 'BALANCE_LIMIT', 'u64 overflow')
    c2.do('t1', 'mint', ['x'], 'LM 1', 'BALANCE_LIMIT', 'u64 overflow by mint')
    c2.do('t1', 'burn', ['x'], 'LM %d' % U64, 'COMMITTED')
    c2.conservation('t1', 'LM', ['x', 'y'])
    a = c2.get('t1', 'x')
    require(a.f['ledger_total'] == str(U64) and a.f['ledger_issued'] == str(2 * U64), 'u128 totals: %r' % a)
    c2.close()
    # cross tenant and cross ledger
    c.do('t2', 'open', ['b0'], 'L1 400', 'COMMITTED')  # t2's own instance of L1: its own fixed supply
    c.do('t1', 'transfer', ['a1', 'b0'], 'L1 a1 b0 1', 'TENANT_ISOLATION_BREACH', 'cross-tenant transfer')
    c.do('t1', 'open', ['m0', 'm1'], 'L2 100 0', 'COMMITTED')
    a = c.do('t1', 'transfer', ['a1', 'm1'], 'L1 a1 m1 1', 'CROSS_LEDGER', 'cross-ledger transfer')
    require(a.f['key'] == 'm1' and a.f['ledger'] == 'L2', 'cross-ledger repair: %r' % a)
    c.do('t1', 'transfer', ['a1', 'a3'], 'names a1 a3 1', 'WRONG_POLICY_KIND')
    c.do('t1', 'transfer', ['a1', 'a3'], 'nope a1 a3 1', 'UNKNOWN_POLICY')
    # postings
    a = c.do('t1', 'post', ['a0', 'a1', 'a3'], 'L1 -100 +60 +50', 'CONSERVATION_BREACH', 'unbalanced posting')
    require(a.f['debit_total'] == '100' and a.f['credit_total'] == '110', 'breach repair fields: %r' % a)
    require(c.conservation('t1', 'L1', A, 1000) == 1000, 'a refused posting changed a balance')
    c.do('t1', 'post', ['a0', 'a1', 'a3'], 'L1 -100 +60 +40', 'COMMITTED')
    c.conservation('t1', 'L1', A, 1000)
    c.do('t1', 'post', ['a0', 'a1', 'a2', 'a3', 'b9'], 'L1 -1 -1 -1 -1 +4', 'TOO_MANY_LEGS')
    c.do('t1', 'post', ['a0', 'a1'], 'L1 -0 +0', 'ZERO_AMOUNT')
    c.do('t1', 'post', ['a2', 'a3'], 'L1 -1 +1', 'INSUFFICIENT_FUNDS', 'posting overdraft')
    c.do('t1', 'post', ['a0', 'a1'], 'L1 -5', 'MALFORMED_REQUEST', 'leg count')
    c.do('t1', 'post', ['a0', 'a1'], 'L1 5 -5', 'MALFORMED_REQUEST', 'unsigned leg')
    # mint / burn
    c.do('t1', 'mint', ['a0'], 'L1 5', 'ISSUANCE_DISABLED', 'mint in a fixed ledger')
    c.do('t1', 'burn', ['a0'], 'L1 5', 'ISSUANCE_DISABLED', 'burn in a fixed ledger')
    c.do('t1', 'mint', ['m0'], 'L2 50', 'COMMITTED')
    c.do('t1', 'burn', ['m1'], 'L2 1', 'INSUFFICIENT_FUNDS')
    c.do('t1', 'burn', ['m0'], 'L2 30', 'COMMITTED')
    c.do('t1', 'mint', ['m0'], 'L2 381', 'BALANCE_LIMIT')
    c.do('t1', 'open', ['m2'], 'L2 450', 'COMMITTED')
    a = c.do('t1', 'transfer', ['m0', 'm2'], 'L2 m2 m0 381', 'BALANCE_LIMIT', 'overflow above max_balance')
    require(a.f['max_balance'] == '500' and a.f['key'] == 'm0', 'overflow repair: %r' % a)
    c.do('t1', 'post', ['m0', 'm1', 'm2'], 'L2 +381 +1 -382', 'BALANCE_LIMIT', 'posting overflow')
    c.do('t1', 'transfer', ['m0', 'm2'], 'L2 m2 m0 380', 'COMMITTED')
    a = c.get('t1', 'm0')
    require(a.f['balance'] == '500', 'm0 at the limit: %r' % a)
    require(c.conservation('t1', 'L2', ['m0', 'm1', 'm2']) == 570 and a.f['ledger_issued'] == '600' and a.f['ledger_destroyed'] == '30', 'mint/burn totals: %r' % a)
    c.conservation('t1', 'L1', A, 1000)
    c.conservation('t2', 'L1', ['b0'], 400)
    # CAS: a stale hash of ONE account refuses the transfer; `*` is refused
    h0, h1 = c.hash('t1', 'a0'), c.hash('t1', 'a1')
    c.do('t1', 'transfer', ['a1', 'a3'], 'L1 a1 a3 1', 'COMMITTED')
    a = c.do('t1', 'transfer', ['a0', 'a1'], 'L1 a0 a1 1', 'STALE_STATE_HASH', 'stale hash of a1', hashes=[h0, h1])
    require(a.f['stale'] == '1' and 'hash.a1' in a.f, 'stale repair: %r' % a)
    c.do('t1', 'transfer', ['a0', 'a1'], 'L1 a0 a1 1', 'MALFORMED_REQUEST', '* in a transfer', hashes=['*', '*'])
    c.do('t1', 'transfer', ['a0', 'g'], 'L1 a0 g 1', 'UNKNOWN_ACCOUNT')
    c.close()
    m = fold_wal(st)
    m.check_conservation()
    return 'fixed and mint_burn ledgers; overdraft, zero, self, overflow, unknown, cross-tenant, cross-ledger, unbalanced posting refused; conservation from outside after every op'


def case_registry(s):
    st, g = s.store('registry')
    c = Client(s.engine, st, g)
    c.do('t1', 'claim', ['reg:t1'], 'names Alice@Example.COM', 'COMMITTED')
    for t, name in (('t1', 'alice@example.com'), ('t2', 'ALICE@example.com'), ('t3', 'Alice@Example.COM')):
        a = c.do(t, 'claim', ['reg:%s' % t], 'names %s' % name, 'DUPLICATE_KEY', 'claim of a held name by %s' % t)
        require('t1' not in a.line and 'alice' not in a.line.lower() and sorted(a.f) == ['now_ms', 'registry', 'skew_ms', ] and a.f['registry'] == 'names',
                'a DUPLICATE_KEY refusal shows more than the registry: %r' % a)
    a = c.get('t1', 'reg:t1')
    require(a.f['claims'] == '1', 'claims: %r' % a)
    c.do('t2', 'claim', ['reg:t2'], 'names %CE%B1lice@example.com', 'COMMITTED')  # other bytes: another name
    c.do('t2', 'claim', ['reg:t2'], 'names \\u0430lice@example.com', 'COMMITTED')  # a JSON escape is not decoded
    code, out = run(s.engine, 'serve', st, inp='DO ledger_graph claim x1 t2 1 reg:t2 * names \xd0\xb0lice\n'.encode('latin-1'))
    require(code == 12 and 'NON_ASCII' in out, 'a raw non-ASCII name: %r' % out)
    # exact registry: case matters; length bound
    c.do('t1', 'claim', ['reg:t1'], 'slugs Go', 'COMMITTED')
    c.do('t2', 'claim', ['reg:t2'], 'slugs go', 'COMMITTED')
    c.do('t2', 'claim', ['reg:t2'], 'slugs Go', 'DUPLICATE_KEY')
    a = c.do('t2', 'claim', ['reg:t2'], 'slugs abcdefghi', 'MALFORMED_REQUEST', 'name longer than max_name_bytes')
    require(a.f['max_name_bytes'] == '8', 'name bound repair: %r' % a)
    # handle rules
    a = c.do('t1', 'claim', ['reg:t2'], 'slugs zz', 'TENANT_ISOLATION_BREACH', "claim with another tenant's handle")
    a = c.do('t1', 'claim', ['reg:t9'], 'slugs zz', 'MALFORMED_REQUEST', 'claim with a foreign handle')
    require(a.f['why'] == 'REGISTRY_KEY' and a.f['expected'] == 'reg:t1', 'handle repair: %r' % a)
    c.do('t1', 'claim', ['zz'], 'slugs zz', 'MALFORMED_REQUEST')
    c.do('t1', 'claim', ['reg:t1'], 'L1 zz', 'WRONG_POLICY_KIND')
    c.do('t1', 'claim', ['reg:t1'], 'other zz', 'UNKNOWN_POLICY')
    # release
    a = c.do('t2', 'release', ['reg:t2'], 'names alice@example.com', 'NOT_HOLDER', 'release by a non-holder')
    require('t1' not in a.line, 'NOT_HOLDER shows the holder: %r' % a)
    c.do('t2', 'release', ['reg:t2'], 'names nobody', 'NOT_HOLDER', 'release of a free name')
    c.do('t1', 'release', ['reg:t1'], 'names ALICE@EXAMPLE.COM', 'COMMITTED')
    c.do('t1', 'release', ['reg:t1'], 'names alice@example.com', 'NOT_HOLDER', 'second release')
    a = c.do('t2', 'claim', ['reg:t2'], 'names alice@example.com', 'COMMITTED')
    require(a.f['effect'] == 'names alice@example.com', 'the record holds the canonical form: %r' % a)
    c.do('t1', 'claim', ['reg:t1'], 'names Alice@example.com', 'DUPLICATE_KEY')
    a = c.do('t1', 'claim', ['reg:t1'], 'names *', 'COMMITTED', hashes=['*'])
    c.close()
    fold_wal(st)
    return 'first claim wins across tenants; ascii_fold and exact; refusals name no holder; release by holder only; non-ASCII bytes are other names'


def case_graph(s):
    st, g = s.store('graph')
    c = Client(s.engine, st, g)
    c.do('t1', 'add_edge', ['g1'], 'gp a b', 'COMMITTED')
    c.do('t1', 'add_edge', ['g1'], 'gp b c c d', 'COMMITTED')
    a = c.do('t1', 'add_edge', ['g1'], 'gp d a', 'DAG_CYCLE_DETECTED', 'a 4-cycle')
    require(a.f['edge'] == 'd->a' and a.f['cycle_len'] == '4' and a.f['index'] == '0', 'cycle repair: %r' % a)
    a = c.do('t1', 'add_edge', ['g1'], 'gp e e', 'DAG_CYCLE_DETECTED', 'self-loop')
    require(a.f['cycle_len'] == '1', 'self-loop: %r' % a)
    a = c.do('t1', 'add_edge', ['g1'], 'gp e f f e', 'DAG_CYCLE_DETECTED', 'a cycle inside one batch')
    require(a.f['index'] == '1' and a.f['cycle_len'] == '2', 'batch cycle: %r' % a)
    a = c.do('t1', 'add_edge', ['g1'], 'gp e a c a', 'DAG_CYCLE_DETECTED', 'a cycle through a committed path')
    require(a.f['index'] == '1' and a.f['cycle_len'] == '3', 'batch cycle through a->b->c: %r' % a)
    a = c.do('t1', 'add_edge', ['g1'], 'gp d e e b', 'DAG_CYCLE_DETECTED', 'a cycle through a new node of the batch')
    require(a.f['cycle_len'] == '4' and a.f['index'] == '1', 'batch cycle b->c->d->e->b: %r' % a)
    c.do('t1', 'add_edge', ['g1'], 'gp a b', 'EDGE_EXISTS')
    # an edge against the order forces a reorder; a later cycle across it must still be seen
    c.do('t1', 'add_edge', ['g3'], 'gq x y', 'COMMITTED')
    c.do('t1', 'add_edge', ['g3'], 'gq z w', 'COMMITTED')
    c.do('t1', 'add_edge', ['g3'], 'gq w x', 'COMMITTED')
    a = c.do('t1', 'add_edge', ['g3'], 'gq y z', 'DAG_CYCLE_DETECTED', 'a cycle across a reorder')
    require(a.f['cycle_len'] == '4', 'cycle z->w->x->y->z: %r' % a)
    c.do('t1', 'add_edge', ['g3'], 'gq v z y v', 'DAG_CYCLE_DETECTED', 'a cycle across a reorder, new node')
    # a reorder that must move a predecessor of `from` too (the backward set): b->c, d->m, m->a, then a->b
    c.do('t1', 'add_edge', ['g4'], 'gq b c d m m a a b', 'COMMITTED')
    a = c.do('t1', 'add_edge', ['g4'], 'gq a m', 'DAG_CYCLE_DETECTED', 'a cycle after a reorder with a backward set')
    require(a.f['cycle_len'] == '2', 'cycle m->a->m: %r' % a)
    c.do('t1', 'remove_edge', ['g3'], 'gq w x', 'COMMITTED')
    c.do('t1', 'add_edge', ['g3'], 'gq y z', 'COMMITTED')
    a = c.get('t1', 'g3')
    require(a.f['nodes'] == '4' and a.f['edges'] == '3', 'g3 describe: %r' % a)
    c.do('t1', 'add_edge', ['g1'], 'gp a c', 'COMMITTED')
    c.do('t1', 'remove_edge', ['g1'], 'gp b a', 'NO_SUCH_EDGE')
    c.do('t1', 'remove_edge', ['g1'], 'gp c d', 'COMMITTED')
    c.do('t1', 'add_edge', ['g1'], 'gp d a', 'COMMITTED')  # no longer a cycle
    a = c.get('t1', 'g1')
    require(a.f['nodes'] == '4' and a.f['edges'] == '4', 'describe: %r' % a)
    a = c.do('t1', 'add_edge', ['g1'], 'gp e f f g', 'GRAPH_FULL', 'max_nodes 6')
    require(a.f['limit'] == 'max_nodes', 'nodes bound: %r' % a)
    a = c.do('t1', 'add_edge', ['g1'], 'gp c e b e a e d e d b', 'GRAPH_FULL', 'max_edges 8')
    require(a.f['limit'] == 'max_edges', 'edges bound: %r' % a)
    c.do('t1', 'add_edge', ['g1'], 'gq x y', 'POLICY_MISMATCH')
    c.do('t1', 'add_edge', ['g1'], 'L1 x y', 'WRONG_POLICY_KIND')
    c.do('t2', 'add_edge', ['g1'], 'gp x y', 'TENANT_ISOLATION_BREACH')
    c.do('t1', 'add_edge', ['g1'], 'gp x y', 'MALFORMED_REQUEST', '* in add_edge', hashes=['*'])
    c.do('t1', 'add_edge', ['reg:t1'], 'gp x y', 'MALFORMED_REQUEST')
    # two edges, each fine alone, closing a cycle together, sent with the same graph hash: one commits
    h = c.hash('t1', 'g1')
    a1 = c.do('t1', 'add_edge', ['g1'], 'gp b e', hashes=[h])
    a2 = c.do('t1', 'add_edge', ['g1'], 'gp e a', hashes=[h])
    require(a1.code == 'COMMITTED' and a2.code == 'STALE_STATE_HASH', 'same graph hash, second edge: %r %r' % (a1, a2))
    a = c.do('t1', 'add_edge', ['g1'], 'gp e a', 'DAG_CYCLE_DETECTED', 'the second edge after a re-read')
    c.close()
    m = fold_wal(st)
    require(m.describe('g1')['edges'] == '5' and m.describe('g3')['edges'] == '3', 'model fold of the graph')
    return 'cycles of length 1 to 4 refused with the cycle length; batch all-or-nothing; bounds; one graph = one CAS unit'


def chain_run(s, name, reverse):
    N, B = 100000, 3500
    st, g = s.store(name, {'big': {'kind': 'graph', 'max_nodes': str(N), 'max_edges': str(N)}})
    c = Client(s.engine, st, g)
    t0 = time.time()
    batches = [range(lo, min(lo + B, N - 1)) for lo in range(0, N - 1, B)]
    if reverse:
        batches = [reversed(r) for r in reversed(batches)]
    for r in batches:
        c.do('t1', 'add_edge', ['chain'], 'big ' + ' '.join('n%d n%d' % (i, i + 1) for i in r), 'COMMITTED')
    build = time.time() - t0
    t1 = time.time()
    a = c.do('t1', 'add_edge', ['chain'], 'big n%d n0' % (N - 1), 'DAG_CYCLE_DETECTED', 'closing edge of a 100,000-node chain')
    close = time.time() - t1
    require(a.f['cycle_len'] == str(N), 'cycle length: %r' % a)
    a = c.get('t1', 'chain')
    require(a.f['nodes'] == str(N) and a.f['edges'] == str(N - 1), 'chain describe: %r' % a)
    c.do('t1', 'add_edge', ['chain'], 'big n5 n7', 'COMMITTED')
    c.do('t1', 'add_edge', ['chain'], 'big n0 x', 'GRAPH_FULL')
    c.close()
    t2 = time.time()
    one(s.engine, 'state', st, expect='STATE')
    return '%s: %d records %.1fs, close %.2fs, replay %.2fs' % ('reverse' if reverse else 'forward', len(batches), build, close, time.time() - t2)


def case_chain(s):
    out = [chain_run(s, 'chain-f', False), chain_run(s, 'chain-r', True)]
    return '100,000-node chain both directions, closing edge refused cycle_len=100000, no stack overflow (times indicative): ' + '; '.join(out)


def case_hostile(s):
    st, g = s.store('hostile')
    c = Client(s.engine, st, g)
    c.do('t1', 'open', ['a', 'b'], 'L1 100 0', 'COMMITTED')
    c.do('t1', 'open', ['m'], 'L2 10', 'COMMITTED')
    c.do('t1', 'claim', ['reg:t1'], 'names bob', 'COMMITTED')
    c.do('t1', 'add_edge', ['g'], 'gq x y y z', 'COMMITTED')
    c.close()
    good = wal_of(st)
    forged = {
        'overdraft transfer': ('E ledger_graph transfer f1 t1 C 2 a b | L1 a b 101', 'RECHECK'),
        'unbalanced posting': ('E ledger_graph post f1 t1 C 2 a b | L1 -10 +11', 'RECHECK'),
        'second supply in a fixed ledger': ('E ledger_graph open f1 t1 C 1 c | L1 50', 'RECHECK'),
        'mint in a fixed ledger': ('E ledger_graph mint f1 t1 C 1 a | L1 5', 'RECHECK'),
        'burn more than the balance': ('E ledger_graph burn f1 t1 C 1 m | L2 11', 'RECHECK'),
        'held name claimed by another tenant': ('E ledger_graph claim f1 t2 C 1 reg:t2 | names bob', 'RECHECK'),
        'held name in another case': ('E ledger_graph claim f1 t2 C 1 reg:t2 | names Bob', 'NOT_CANONICAL'),
        'release by a non-holder': ('E ledger_graph release f1 t2 C 1 reg:t2 | names bob', 'RECHECK'),
        'edge that closes a cycle': ('E ledger_graph add_edge f1 t1 C 1 g | gq z x', 'RECHECK'),
        'self-loop edge': ('E ledger_graph add_edge f1 t1 C 1 g | gq q q', 'RECHECK'),
        'transfer legs not the keys': ('E ledger_graph transfer f1 t1 C 2 a b | L1 b c 1', 'RECHECK'),
        'refusal-kind record': ('E ledger_graph transfer f1 t1 R 2 a b | L1 a b 1', 'REFUSAL_RECORD'),
        'amount not canonical': ('E ledger_graph transfer f1 t1 C 2 a b | L1 a b 01', 'PAYLOAD'),
        'unknown account': ('E ledger_graph transfer f1 t1 C 2 a zz | L1 a zz 1', 'RECHECK'),
    }
    for why, (payload, word) in forged.items():
        (st / WAL).write_bytes(good)
        append_forged(st, payload)
        code, out = run(s.engine, 'state', st)
        require(code == 17 and out.startswith('CORRUPT_WAL') and word in out, '%s: not refused at replay: %r' % (why, out.strip()[:200]))
    (st / WAL).write_bytes(good)
    for payload in ('E ledger_graph transfer f1 t1 C 2 a b | L1 a b 100', 'E ledger_graph claim f1 t2 C 1 reg:t2 | names carol',
                    'E ledger_graph add_edge f1 t1 C 1 g | gq x z'):
        (st / WAL).write_bytes(good)
        append_forged(st, payload)
        one(s.engine, 'state', st, expect='STATE')  # the suite's writer makes records the engine accepts
    return '%d hostile records with a valid chain refused at replay (conservation, uniqueness, acyclicity, form); 3 valid controls accepted' % len(forged)


def gen_step(rnd, m, hashes, g):
    """One random request: (tenant, op, keys, args, stale keys)."""
    tenant = rnd.choice(['t1', 't1', 't2'])
    own = {'t1': ['a0', 'a1', 'a2', 'a3', 'b0', 'b1'], 't2': ['c0', 'c1', 'c2', 'd0']}
    acc_pool = own[tenant] if rnd.random() < 0.9 else own['t1'] + own['t2']
    op = rnd.choice(['open', 'transfer', 'transfer', 'transfer', 'post', 'post', 'mint', 'burn', 'claim', 'release', 'add_edge', 'add_edge', 'remove_edge'])
    ledger = rnd.choice(['L1'] * 4 + ['L2'] * 4 + ['names', 'zz'])
    if op == 'open':
        keys = sorted(rnd.sample(acc_pool + (['g1'] if rnd.random() < 0.1 else []), rnd.randint(1, 3)))
        args = '%s %s' % (ledger, ' '.join(str(rnd.choice([0, 0, rnd.randint(0, 600)])) for _ in keys))
    elif op == 'transfer':
        keys = sorted(rnd.sample(acc_pool + (['g1'] if rnd.random() < 0.1 else []), 2))
        f, t = rnd.sample(keys, 2) if rnd.random() < 0.95 else (keys[0], keys[0])
        args = '%s %s %s %d' % (ledger, f, t, rnd.choice([0, rnd.randint(1, 50), rnd.randint(1, 600)]))
    elif op == 'post':
        keys = sorted(rnd.sample(acc_pool, rnd.randint(2, min(5, len(acc_pool)))))
        legs = [rnd.randint(0, 80) for _ in keys]
        signs = [rnd.random() < 0.5 for _ in keys]
        signs[0], signs[-1] = False, True
        if rnd.random() < 0.7:
            deb = sum(a for a, c in zip(legs, signs) if not c)
            cre = sum(a for a, c in zip(legs[:-1], signs[:-1]) if c)
            legs[-1] = max(deb - cre, 0)
        args = '%s %s' % (ledger, ' '.join('%s%d' % ('+' if c else '-', a) for a, c in zip(legs, signs)))
    elif op in ('mint', 'burn'):
        keys = [rnd.choice(acc_pool)]
        args = '%s %d' % (ledger, rnd.choice([0, rnd.randint(1, 100), rnd.randint(1, 600)]))
    elif op in ('claim', 'release'):
        keys = ['reg:%s' % (tenant if rnd.random() < 0.95 else rnd.choice(['t1', 't2']))]
        reg = rnd.choice(['names', 'names', 'slugs', 'L1'])
        args = '%s %s' % (reg, rnd.choice(['Alice', 'alice', 'ALICE', 'bob', 'Bob', 'b%o', 'x' * 9, 'z=1']))
    else:
        keys = [rnd.choice(['g1', 'g1', 'g1', 'a0'] if tenant == 't1' else ['g2', 'g2', 'g2', 'g1'])]
        pol = rnd.choice(['gp', 'gp', 'gp', 'gq'])
        nodes = 'ABCDEFG'
        n = 1 if op == 'remove_edge' else rnd.randint(1, 3)
        if op == 'remove_edge' and keys[0] in m.graphs and m.graphs[keys[0]]['edges'] and rnd.random() < 0.7:
            args = '%s %s %s' % ((pol,) + rnd.choice(sorted(m.graphs[keys[0]]['edges'])))
        else:
            args = '%s %s' % (pol, ' '.join('%s %s' % (rnd.choice(nodes), rnd.choice(nodes)) for _ in range(n)))
    if op in ('open', 'transfer', 'post', 'mint', 'burn') and rnd.random() < 0.85:
        home = 'L1' if keys[0][0] in 'ac' else 'L2'
        args = home + args[args.index(' '):]
    stale = [k for k in keys if rnd.random() < 0.04]
    return tenant, op, keys, args, stale


def case_model(s):
    st, g = s.store('model')
    rnd = random.Random(20261120)
    m = Model(POLICIES)
    ses = Session(s.engine, st)
    hashes = {}
    codes = collections.Counter()
    for i in range(s.steps):
        tenant, op, keys, args, stale = gen_step(rnd, m, hashes, g)
        cas = 'claim' not in op and 'release' not in op
        hs = []
        for k in keys:
            h = hashes.get(k, g)
            if k in stale:
                h = hashlib.sha256(b'stale%d' % i).hexdigest()
            hs.append(h if cas or k in stale else rnd.choice([h, '*']))
        pred_stale = [k for k, h in zip(keys, hs) if h != '*' and h != hashes.get(k, g)]
        line = 'DO ledger_graph %s m%d %s %d %s %s' % (op, i, tenant, len(keys), ' '.join('%s %s' % kh for kh in zip(keys, hs)), args)
        code, f, payload = m.request(tenant, op, keys, args, pred_stale)
        a = ses.ask(line)
        codes[a.code] += 1
        require(a.code == code, 'step %d %r: engine %r, model %s %r' % (i, line[:200], a.line[:200], code, f))
        for k, v in f.items():
            require(a.f.get(k) == v, 'step %d %r: field %s engine %r model %r (%r)' % (i, line[:200], k, a.f.get(k), v, a.line[:200]))
        if code == 'COMMITTED':
            require(a.f['effect'] == payload, 'step %d: effect %r, model %r' % (i, a.f['effect'], payload))
            for k in keys:
                hashes[k] = a.f['hash.' + k]
        if i % 100 == 0:
            m.check_conservation()
    ses.close()
    m.check_conservation()
    # final state: every key, every tenant, against the model; then the model's own fold of the WAL
    ses = Session(s.engine, st)
    keys = ['a0', 'a1', 'a2', 'a3', 'b0', 'b1', 'c0', 'c1', 'c2', 'd0', 'g1', 'g2', 'reg:t1', 'reg:t2']
    for k in keys:
        for t in ('t1', 't2'):
            a = ses.ask('GET %s %s' % (t, k))
            if k not in m.bound:
                require(a.code == 'OK' and a.f['exists'] == '0', 'GET %s %s: %r' % (t, k, a))
            elif m.bound[k] != t:
                require(a.code == 'TENANT_ISOLATION_BREACH', 'GET %s %s: %r' % (t, k, a))
            else:
                want = m.describe(k)
                got = {x: a.f.get(x) for x in want}
                require(got == want and a.f['hash'] == hashes[k], 'final GET %s %s: engine %r model %r' % (t, k, a.line, want))
    ses.close()
    m2 = fold_wal(st)
    require(m2.snapshot() == m.snapshot(), 'the model fold of the WAL differs from the model run')
    need = ['COMMITTED', 'CONSERVATION_BREACH', 'DAG_CYCLE_DETECTED', 'DUPLICATE_KEY', 'INSUFFICIENT_FUNDS', 'STALE_STATE_HASH', 'TENANT_ISOLATION_BREACH', 'NOT_HOLDER']
    missing = [x for x in need if codes[x] == 0]
    require(not missing, 'NOT RUN: the random run never reached %r' % missing)
    return '%d random steps, same answers and fields as the model; final state and WAL fold equal; codes %s' % (
        s.steps, ' '.join('%s=%d' % kv for kv in sorted(codes.items())))


def case_replay(s):
    st, g = s.store('replay')
    rnd = random.Random(7)
    m = Model(POLICIES)
    c = Client(s.engine, st, g)
    c.do('t1', 'open', ['a0', 'a1', 'a2'], 'L1 300 300 400', 'COMMITTED')
    c.do('t1', 'claim', ['reg:t1'], 'names x', 'COMMITTED')
    c.do('t1', 'add_edge', ['g1'], 'gq p q q r', 'COMMITTED')
    for i in range(60):
        f, t = rnd.sample(['a0', 'a1', 'a2'], 2)
        c.do('t1', 'transfer', [f, t], 'L1 %s %s %d' % (f, t, rnd.randint(1, 30)))
    c.close()
    outs = [run(s.engine, 'replay', st) for _ in range(2)]
    require(outs[0][0] == 0 and outs[0] == outs[1], 'two replays differ')
    dup = s.folder('replay-copy')
    shutil.copytree(st, dup / 'st')
    os.chmod(dup / 'st', 0o700)
    gets = []
    for store in (st, dup / 'st'):
        c = Client(s.engine, store, g)
        gets.append([' '.join(x for x in c.get('t1', k).line.split() if not x.startswith(('now_ms=', 'skew_ms='))) for k in ('a0', 'a1', 'a2', 'reg:t1', 'g1')])
        c.close()
    require(gets[0] == gets[1], 'a copied store answers differently: %r' % gets)
    m = fold_wal(st)
    c = Client(s.engine, st, g)
    for k in ('a0', 'a1', 'a2'):
        require(c.get('t1', k).f['balance'] == m.describe(k)['balance'], 'model fold balance of %s' % k)
    c.conservation('t1', 'L1', ['a0', 'a1', 'a2'], 1000)
    c.close()
    return 'replay twice byte-identical; a copied store answers the same; the model fold of the WAL equals the engine'


def transfer_worker(engine, st, g, tenant, plan, out, tag):
    """One serve process: each planned transfer with GET -> DO, retried on STALE_STATE_HASH."""
    try:
        c = Client(engine, st, g)
    except Exception as e:  # noqa: BLE001
        out.append(('ERROR', tag, str(e)))
        return
    try:
        for j, (f, t, amt) in enumerate(plan):
            for attempt in range(400):
                keys = sorted([f, t])
                hs = [c.hash(tenant, k) for k in keys]
                rid = '%s-%d-%d' % (tag, j, attempt)
                line = 'DO ledger_graph transfer %s %s 2 %s %s %s %s L1 %s %s %d' % (rid, tenant, keys[0], hs[0], keys[1], hs[1], f, t, amt)
                a = c.ses.ask(line)
                if a.code != 'STALE_STATE_HASH':
                    out.append((a.code, rid, (f, t, amt)))
                    break
            else:
                out.append(('GAVE_UP', tag, (f, t, amt)))
    except Exception as e:  # noqa: BLE001
        out.append(('ERROR', tag, repr(e)))
    finally:
        try:
            c.close()
        except Exception:  # noqa: BLE001
            pass


def case_race_ledger(s):
    st, g = s.store('race-ledger')
    A = ['a%d' % i for i in range(6)]
    c = Client(s.engine, st, g)
    c.do('t1', 'open', A, 'L1 200 150 150 200 150 150', 'COMMITTED')
    c.close()
    rnd = random.Random(50)
    out = []
    threads = []
    for i in range(50):
        plan = []
        for _ in range(2):
            x, y = A[i % 6], A[(i + 1 + rnd.randint(0, 1)) % 6]
            plan.append((x, y, rnd.randint(1, 120)) if rnd.random() < 0.5 else (y, x, rnd.randint(1, 120)))
        threads.append(threading.Thread(target=transfer_worker, args=(s.engine, st, g, 't1', plan, out, 'w%d' % i)))
    t0 = time.time()
    for t in threads:
        t.start()
    for t in threads:
        t.join(1200)
    require(not any(t.is_alive() for t in threads), 'race workers did not end')
    bad = [x for x in out if x[0] not in ('COMMITTED', 'INSUFFICIENT_FUNDS')]
    require(not bad, 'race answers: %r' % bad[:3])
    require(len(out) == 100, 'race: %d results, expected 100' % len(out))
    committed = {x[1]: x[2] for x in out if x[0] == 'COMMITTED'}
    recs, rest = parse_wal(wal_of(st))
    wal_t = [(rid, p) for op, rid, _, _, p in effects(recs) if op == 'transfer']
    require(sorted(r for r, _ in wal_t) == sorted(committed), 'committed answers and WAL transfers differ (lost or ghost update)')
    bal = {k: v for k, v in zip(A, [200, 150, 150, 200, 150, 150])}
    for rid, (f, t, amt) in committed.items():
        bal[f] -= amt
        bal[t] += amt
    c = Client(s.engine, st, g)
    for k in A:
        require(c.get('t1', k).num('balance') == bal[k], 'balance of %s: engine %r, from the committed answers %d' % (k, c.get('t1', k), bal[k]))
    c.conservation('t1', 'L1', A, 1000)
    c.close()
    fold_wal(st).check_conservation()
    n_ins = sum(1 for x in out if x[0] == 'INSUFFICIENT_FUNDS')
    return '50 processes, 100 transfers on overlapping pairs: %d committed, %d refused overdraft; balances = committed answers; total 1000; %.1fs' % (
        len(committed), n_ins, time.time() - t0)


def case_race_claim(s):
    st, g = s.store('race-claim')
    procs = [subprocess.Popen([str(s.engine), 'serve', str(st)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=ENV) for _ in range(50)]
    for i, p in enumerate(procs):
        p.stdin.write(('DO ledger_graph claim c%d u%d 1 reg:u%d * names %s\n' % (i, i, i, rnd_case('winner', i))).encode())
        p.stdin.flush()
    outs = []
    for p in procs:
        o, _ = p.communicate(timeout=600)
        outs.append(Answer(o.decode().strip()))
    codes = collections.Counter(a.code for a in outs)
    require(codes['COMMITTED'] == 1 and codes['DUPLICATE_KEY'] == 49, 'claim race of 50 tenants: %r' % dict(codes))
    winner = [i for i, a in enumerate(outs) if a.code == 'COMMITTED'][0]
    for a in outs:
        if a.code == 'DUPLICATE_KEY':
            require('u%d' % winner not in a.line, 'a refusal names the holder: %r' % a)
    c = Client(s.engine, st, g)
    held = [i for i in range(50) if c.get('u%d' % i, 'reg:u%d' % i).f.get('claims') == '1']
    c.close()
    require(held == [winner], 'holders after the race: %r' % held)
    recs, _ = parse_wal(wal_of(st))
    require(len(effects(recs)) == 1, 'claim race wrote %d records' % len(effects(recs)))
    return '50 tenants race one name (mixed case, ascii_fold): exactly 1 holder, 49 DUPLICATE_KEY naming nobody'


def rnd_case(name, i):
    return ''.join(ch.upper() if (i >> j) & 1 else ch for j, ch in enumerate(name))


def case_kill9(s):
    st, g = s.store('kill9')
    A = ['a%d' % i for i in range(4)]
    c = Client(s.engine, st, g)
    c.do('t1', 'open', A, 'L1 250 250 250 250', 'COMMITTED')
    c.close()
    rnd = random.Random(9)
    answered = []
    lock = threading.Lock()
    for rno in range(5):
        sessions = [Session(s.engine, st) for _ in range(3)]

        def feed(ses, tag):
            try:
                for i in range(100000):
                    f, t = rnd.sample(A, 2)
                    keys = sorted([f, t])
                    hs = [ses.ask('GET t1 %s' % k).f['hash'] for k in keys]
                    rid = 'k%s-%d' % (tag, i)
                    a = ses.ask('DO ledger_graph transfer %s t1 2 %s %s %s %s L1 %s %s %d' % (rid, keys[0], hs[0], keys[1], hs[1], f, t, rnd.randint(1, 90)))
                    with lock:
                        answered.append(a)
            except Exception:  # noqa: BLE001  (the kill ends the session)
                pass
        threads = [threading.Thread(target=feed, args=(ses, '%d-%d' % (rno, j)), daemon=True) for j, ses in enumerate(sessions)]
        for t in threads:
            t.start()
        time.sleep(rnd.uniform(0.5, 2.0))
        for ses in sessions:
            ses.p.send_signal(signal.SIGKILL)
        for ses in sessions:
            ses.p.wait()
        for t in threads:
            t.join(30)
        time.sleep(0.1)
    one(s.engine, 'state', st, expect='STATE')
    m = fold_wal(st)
    m.check_conservation()
    recs, _ = parse_wal(wal_of(st))
    ids = {rid for _, rid, _, _, _ in effects(recs)}
    lost = [a for a in answered if a.code == 'COMMITTED' and a.f['request_id'] not in ids]
    require(not lost, 'committed answers missing from the WAL: %r' % lost[:3])
    c = Client(s.engine, st, g)
    for k in A:
        require(c.get('t1', k).f['balance'] == m.describe(k)['balance'], 'balance of %s after kills' % k)
    c.conservation('t1', 'L1', A, 1000)
    c.close()
    n = sum(1 for a in answered if a.code == 'COMMITTED')
    require(n >= 5, 'NOT RUN: too few commits before the kills (%d)' % n)
    return '5 bursts of 3 killed processes: %d answered commits all in the WAL; %d records; total 1000; model fold equal' % (n, len(recs))


CASES = [('policy', case_policy), ('ledger', case_ledger), ('registry', case_registry), ('graph', case_graph),
         ('chain', case_chain), ('hostile', case_hostile), ('model', case_model), ('replay', case_replay),
         ('race_ledger', case_race_ledger), ('race_claim', case_race_claim), ('kill9', case_kill9)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('engine')
    ap.add_argument('--case', action='append', choices=[n for n, _ in CASES])
    ap.add_argument('--work', default=None)
    ap.add_argument('--steps', type=int, default=3000)
    ap.add_argument('--keep', action='store_true')
    args = ap.parse_args()
    if not os.access(args.engine, os.X_OK):
        print('cannot start: %s is missing' % args.engine)
        return 2
    work = Path(tempfile.mkdtemp(prefix='pv2-p7-', dir=args.work))
    os.chmod(work, 0o700)
    suite = Suite(Path(args.engine).resolve(), work, args.steps)
    failed = 0
    for name, fn in CASES:
        if args.case and name not in args.case:
            continue
        t = time.time()
        try:
            detail = fn(suite)
            print('PASS %-12s %6.1fs %s' % (name, time.time() - t, detail), flush=True)
        except Failed as e:
            failed += 1
            print('FAIL %-12s %6.1fs %s' % (name, time.time() - t, str(e).replace('\n', ' ')[:600]), flush=True)
        except Exception as e:  # noqa: BLE001  (a crash of the suite is a failure, never a pass)
            failed += 1
            print('FAIL %-12s %6.1fs suite error %s: %s' % (name, time.time() - t, type(e).__name__, str(e)[:400]), flush=True)
    if not args.keep:
        shutil.rmtree(work, ignore_errors=True)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
