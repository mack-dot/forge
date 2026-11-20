#!/usr/bin/env python3
"""FINITE TEST of primitive 8, `taint_egress` (src/primitives_v2/taint.rs). It proves nothing about the module.

Usage: python3 tests/primitives_v2/test_taint.py <engine> [--case NAME]... [--work DIR] [--random N] [--seed S] [--keep]

<engine> is the production build (build/primitives_v2/primitives-engine). The module needs no test seam.
Every document goes through `serve` on a real store, as one request line:
    DO taint_egress check <request_id> <tenant> 0 <policy> <destination> <json>

Cases: policy (policy files refused or accepted at init), wire (args, unknown policy or destination, exit codes,
no record, request id stays fresh, digest), table (>= 80 documents with exact expected answers, among them the nine
leaking shapes of the MCP proxy review translated to this model), order (shuffled keys: the same answer), leak (no
refusal holds a secret value or a secret key, raw or percent-decoded or normalized), limits (each bound at the
limit and one over), evasions (the known-limits table of taint.rs: each row's ACTUAL result), differential (random
documents against the independent Python reference walk `Ref` below).

The reference walk was written by the same author as the module, from the same written rules: both can share one
misreading. All times are indicative: the machine is shared and loaded.
A case that cannot run FAILS with NOT RUN in its message; it never passes.
Exit 0: every selected case passed. 1: at least one failed. 2: the suite could not start.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import re
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.parse import unquote

sys.dont_write_bytecode = True
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}
ANSWER = re.compile(r'^([A-Z][A-Z0-9_]{1,47})((?: [A-Za-z0-9_.:@+-]+=[A-Za-z0-9._~:/@$\[\]+,%-]*)*)(?: -- ([ -~]*))?$')
EXITS = {'OK': 0, 'MALFORMED_REQUEST': 12, 'MODULE_FAULT': 29, 'NOT_IMPLEMENTED': 27}
MAX_DEPTH, MAX_NODES, MAX_NESTED, MAX_KEY = 32, 16384, 4, 256
VOLATILE = ('now_ms', 'skew_ms', 'verdict')


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
        self.f = dict(tok.split('=', 1) for tok in m.group(2).split())
        if self.code == 'OK':
            self.code = self.f.get('verdict', 'OK')

    def stable(self, drop=()):
        return (self.code, {k: v for k, v in self.f.items() if k not in VOLATILE + tuple(drop)})

    def __repr__(self):
        return self.line


# ---- documents ----------------------------------------------------------------------------------------------------
class Pairs(list):
    """An object as a list of (key, value) pairs: keeps duplicates and order."""


def enc(v):
    """Strict JSON text, ASCII only (\\u escapes), keys in the given order, duplicates kept."""
    if isinstance(v, Pairs):
        return '{' + ','.join(json.dumps(k, ensure_ascii=True) + ':' + enc(x) for k, x in v) + '}'
    if isinstance(v, dict):
        return '{' + ','.join(json.dumps(k, ensure_ascii=True) + ':' + enc(x) for k, x in v.items()) + '}'
    if isinstance(v, list):
        return '[' + ','.join(enc(x) for x in v) + ']'
    return json.dumps(v, ensure_ascii=True)


def js(v):
    """A string value that holds the JSON text of v (nested JSON in a string)."""
    return enc(v)


def deep(n, leaf):
    """n nested arrays around leaf: the leaf is at depth n."""
    v = leaf
    for _ in range(n):
        v = [v]
    return v


# ---- policies -----------------------------------------------------------------------------------------------------
POLICIES = {
    'med': {'mode': 'detect', 'labels': ['INTERNAL'],
            'fields': [{'path': 'ssn', 'labels': ['PII']}, {'path': '$.patients[].notes', 'labels': ['PHI']},
                       {'path': 'api_key', 'labels': ['SECRET_KEY']}, {'path': 'billing.card', 'labels': ['PII']},
                       {'path': 'cards[]', 'labels': ['PII']}, {'path': 'internal_note', 'labels': ['INTERNAL']},
                       {'path': 'acme_rows', 'labels': ['TENANT:acme']}],
            'destinations': {'PUBLIC_HTTP': [], 'LLM_STDOUT': ['PII'], 'TENANT:*': ['PII', 'PHI', 'INTERNAL'],
                             'AUDIT': ['TENANT:*', 'PII', 'PHI', 'SECRET_KEY']}},
    'meds': {'mode': 'strict', 'labels': [],
             'fields': [{'path': '$.id', 'labels': []}, {'path': '$.tenant_id', 'labels': []},
                        {'path': '$.patients[].name', 'labels': []}, {'path': '$.patients[].ssn', 'labels': ['PII']},
                        {'path': '$.patients[].notes', 'labels': ['PHI']}, {'path': '$.meta', 'labels': []},
                        {'path': 'note', 'labels': []}],
             'destinations': {'PUBLIC_HTTP': [], 'LLM_STDOUT': ['PII'], 'TENANT:*': ['PII', 'PHI']}},
    'wrap': {'mode': 'detect', 'labels': [], 'fields': [{'path': '$', 'labels': ['PII']}],
             'destinations': {'PUBLIC_HTTP': [], 'LLM_STDOUT': ['PII']}},
}


def policy_text(name, body):
    d = {'primitive': 'taint_egress', 'version': 1, 'name': name}
    d.update(body)
    return json.dumps(d)


# ---- the independent reference walk (Python; same written rules, separate code) -----------------------------------
WS = set([0x9, 0xA, 0xB, 0xC, 0xD, 0x20, 0x85, 0xA0, 0x1680, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000] + list(range(0x2000, 0x200B)))
IGN = [(0xAD, 0xAD), (0x34F, 0x34F), (0x61C, 0x61C), (0x115F, 0x1160), (0x17B4, 0x17B5), (0x180B, 0x180F),
       (0x200B, 0x200F), (0x202A, 0x202E), (0x2060, 0x206F), (0x3164, 0x3164), (0xFE00, 0xFE0F), (0xFEFF, 0xFEFF),
       (0xFFA0, 0xFFA0), (0xFFF0, 0xFFF8), (0x1BCA0, 0x1BCA3), (0x1D173, 0x1D17A), (0xE0000, 0xE0FFF)]
FIXED = ('PHI', 'PII', 'SECRET_KEY')
CANON = re.compile(r'^[A-Za-z0-9_-]{1,24}$')


def r_ign(c):
    o = ord(c)
    return any(a <= o <= b for a, b in IGN)


def r_norm(k):
    out = []
    for c in k:
        o = ord(c)
        if 0xFF01 <= o <= 0xFF5E:
            c = chr(o - 0xFEE0)
        if c in '_- ':
            continue
        out.append(c.lower() if 'A' <= c <= 'Z' else c)
    return ''.join(out)


def r_jsonlike(s):
    i = 0
    while i < len(s) and (ord(s[i]) in WS or r_ign(s[i])):
        i += 1
    return s[i:i + 1] in ('{', '[', '"')


class RObj(list):
    pass


class RBad(Exception):
    pass


def r_parse(text):
    """Strict JSON as the engine's parser: duplicate keys, lone surrogates, NaN, depth > 64 refused."""
    def hook(ps):
        seen = set()
        for k, _ in ps:
            if k in seen:
                raise RBad()
            seen.add(k)
        return RObj(ps)

    def const(_):
        raise RBad()
    try:
        v = json.loads(text, object_pairs_hook=hook, parse_constant=const)
    except (ValueError, RBad, RecursionError):
        return RBad
    stack = [(v, 0)]
    while stack:
        n, d = stack.pop()
        if d > 64:
            return RBad
        if isinstance(n, RObj):
            for k, x in n:
                if any(0xD800 <= ord(c) <= 0xDFFF for c in k):
                    return RBad
                stack.append((x, d + 1))
        elif isinstance(n, list):
            stack.extend((x, d + 1) for x in n)
        elif isinstance(n, str) and any(0xD800 <= ord(c) <= 0xDFFF for c in n):
            return RBad
    return v


class RStr:
    """A string value after expansion: `inner` is its parsed JSON, or RBad for an opaque string, or None."""
    def __init__(self, s, inner):
        self.s, self.inner = s, inner


class Ref:
    def __init__(self, body):
        self.mode, self.custom = body['mode'], set(body['labels'])
        self.rules, self.names = [], {'value', 'tenantid'}
        for r in body['fields']:
            p = r['path']
            anch = p.startswith('$')
            rest = p[1:] if anch else p
            segs = []
            for tok in re.findall(r'\[\]|[^.\[]+', rest):
                segs.append(None if tok == '[]' else r_norm(tok))
            self.names |= {s for s in segs if s is not None}
            self.rules.append((anch, segs, set(r['labels'])))
        self.dests = {k: set(v) for k, v in body['destinations'].items()}

    def known(self, s):
        return s in FIXED or s in self.custom or (s.startswith('TENANT:') and CANON.match(s[7:]) is not None)

    @staticmethod
    def seq(r, l):
        return (r is None and l is None) or (r is not None and r == l)

    def matches(self, rule, lp):
        anch, segs, _ = rule
        if anch:
            return len(segs) == len(lp) and all(self.seq(a, b) for a, b in zip(segs, lp))
        return len(segs) <= len(lp) and all(self.seq(a, b) for a, b in zip(segs, lp[len(lp) - len(segs):]))

    def extends(self, rule, lp):
        anch, segs, _ = rule
        return anch and len(segs) > len(lp) and all(self.seq(a, b) for a, b in zip(segs, lp))

    def allowed(self, dest, label):
        if label.startswith('TENANT:') and CANON.match(label[7:]):
            if dest.startswith('TENANT:'):
                return label == dest
            return 'TENANT:*' in self.dests[dest] or label in self.dests[dest]
        key = 'TENANT:*' if dest.startswith('TENANT:') else dest
        return label in self.dests[key]

    # expansion: (tree, nodes, max depth, nested over)
    def expand(self, v, depth, level, st):
        st['nodes'] += 1
        st['depth'] = max(st['depth'], depth)
        if isinstance(v, RObj):
            return RObj((k, self.expand(x, depth + 1, level, st)) for k, x in v)
        if isinstance(v, list):
            return [self.expand(x, depth + 1, level, st) for x in v]
        if isinstance(v, str) and r_jsonlike(v):
            if level + 1 > MAX_NESTED:
                st['over'] = True
                return RStr(v, None)
            p = r_parse(v)
            if p is RBad:
                return RStr(v, RBad)
            return RStr(v, self.expand(p, depth, level + 1, st))
        if isinstance(v, str):
            return RStr(v, None)
        return v

    def check(self, pol, dest, text):
        if pol not in POLICY_NAMES:
            return ('UNKNOWN_POLICY', {})
        key = 'TENANT:*' if dest.startswith('TENANT:') else dest
        if key not in self.dests:
            return ('UNKNOWN_DESTINATION', {})
        doc = r_parse(text)
        if doc is RBad:
            return ('MALFORMED_REQUEST', {'why': 'BAD_JSON'})
        st = {'nodes': 0, 'depth': 0, 'over': False}
        tree = self.expand(doc, 0, 0, st)
        if st['nodes'] > MAX_NODES:
            return ('TAINT_LIMIT', {'why': 'TOO_MANY_NODES', 'max': str(MAX_NODES)})
        if st['depth'] > MAX_DEPTH:
            return ('TAINT_LIMIT', {'why': 'TOO_DEEP', 'max': str(MAX_DEPTH)})
        if st['over']:
            return ('TAINT_LIMIT', {'why': 'NESTED_TOO_DEEP', 'max': str(MAX_NESTED)})
        self.f = {'s': [], 'b': [], 'u': []}
        self.dest = dest
        self.visit(tree, '$', [], frozenset(), False, False, None)
        for cls in ('s', 'b', 'u'):
            if self.f[cls]:
                code, fields = self.f[cls][0]
                out = dict(fields)
                out['more'] = str(len(self.f[cls]) - 1)
                return (code, out)
        return ('ALLOW', {'policy': pol, 'destination': dest, 'mode': self.mode,
                          'sha256': hashlib.sha256(text.encode()).hexdigest(), 'bytes': str(len(text)), 'nodes': str(st['nodes'])})

    @staticmethod
    def unwrap(v):
        hops = 0
        while isinstance(v, RStr) and v.inner is not None and v.inner is not RBad:
            v, hops = v.inner, hops + 1
        return v, hops

    def keyfault(self, k, n):
        if len(k.encode()) > MAX_KEY:
            return 'TOO_LONG'
        if any(ord(c) < 0x20 or 0x7F <= ord(c) <= 0x9F for c in k):
            return 'CONTROL'
        if any(r_ign(c) for c in k):
            return 'IGNORABLE'
        if r_jsonlike(k):
            return 'JSON_LIKE'
        if n not in ('tenantid', '$taint') and ('tenantid' in n or '$taint' in n):
            return 'CARRIER_NAME'
        return None

    def visit(self, v, path, lp, inh, covered, supp, kf):
        add = lambda cls, code, **kw: self.f[cls].append((code, dict({'json_path': path}, **kw)))  # noqa: E731
        if kf:
            add('s', 'UNSAFE_KEY', why=kf)
        v, hops = self.unwrap(v)
        path += '@' * hops
        if isinstance(v, RStr) and v.inner is RBad:
            add('s', 'OPAQUE_JSON')
        own, matched = set(), False
        for r in self.rules:
            if self.matches(r, lp):
                matched = True
                own |= r[2]
        cval = None
        if isinstance(v, RObj):
            norms = [r_norm(k) for k, _ in v]
            if len(set(norms)) != len(norms):
                add('s', 'AMBIGUOUS_KEY')
            if '$taint' in norms:
                res = self.carrier(v, norms)
                if res[0] == 'ok':
                    own |= res[1]
                    cval = res[2]
                elif res[0] == 'unknown':
                    add('s', 'UNKNOWN_LABEL')
                else:
                    add('s', 'MALFORMED_CARRIER', why=res[1])
            for (k, x), n in zip(v, norms):
                if n == 'tenantid':
                    if isinstance(x, RStr) and x.inner is None and CANON.match(x.s):
                        own.add('TENANT:' + x.s)
                    else:
                        add('s', 'MALFORMED_CARRIER', why='TENANT_ID')
        fresh = sorted(own - inh)
        for lab in fresh:
            if not self.allowed(self.dest, lab):
                add('b', 'TAINT_EGRESS_BLOCKED', label='TENANT' if lab.startswith('TENANT:') else lab)
        inh2 = inh | own
        cov = covered or matched
        container = isinstance(v, (RObj, list))
        if self.mode == 'strict' and not supp and not cov and not (container and (not lp or any(self.extends(r, lp) for r in self.rules))):
            add('u', 'UNLABELLED_FIELD')
            supp = True
        if isinstance(v, RObj):
            if cval is not None:
                self.visit(cval, path + '.value', lp, inh2, cov, supp, None)
            else:
                order = sorted(range(len(v)), key=lambda i: v[i][0].encode())
                for rank, i in enumerate(order):
                    k, x = v[i]
                    n = norms[i]
                    kf2 = self.keyfault(k, n)
                    seg = ('.' + n) if (kf2 is None and n in self.names) else ('.~%d' % rank)
                    self.visit(x, path + seg, lp + [n], inh2, cov, supp, kf2)
        elif isinstance(v, list):
            for i, x in enumerate(v):
                self.visit(x, path + '[%d]' % i, lp + [None], inh2, cov, supp, None)

    def carrier(self, v, norms):
        if len(v) != 2 or norms.count('$taint') == 0:
            return ('bad', 'SHAPE')
        ti = norms.index('$taint')
        vi = 1 - ti
        if norms[vi] != 'value':
            return ('bad', 'SHAPE')
        arr, _ = self.unwrap(v[ti][1])
        if not isinstance(arr, list) or isinstance(arr, RObj):
            return ('bad', 'LABELS_NOT_ARRAY')
        labels, unknown = set(), False
        for it in arr:
            it2, hops = self.unwrap(it)
            if isinstance(it2, RStr):
                if hops == 0 and it2.inner is None and self.known(it2.s):
                    labels.add(it2.s)
                else:
                    unknown = True
            else:
                return ('bad', 'LABEL_NOT_STRING')
        if unknown:
            return ('unknown',)
        return ('ok', labels, v[vi][1])


POLICY_NAMES = set(POLICIES)
REFS = {k: Ref(v) for k, v in POLICIES.items()}


# ---- the engine ---------------------------------------------------------------------------------------------------
class Suite:
    def __init__(self, engine, work):
        self.engine, self.work, self.n, self.store = engine, Path(work), 0, None
        self.answers = []  # every (doc text, answer line) seen, for the leak case

    def run(self, *args, inp=None, timeout=600):
        p = subprocess.run([str(self.engine)] + [str(a) for a in args], input=inp, capture_output=True, env=ENV, timeout=timeout)
        return p.returncode, p.stdout.decode(errors='replace')

    def folder(self, name):
        self.n += 1
        d = self.work / ('%s-%d' % (name, self.n))
        d.mkdir(mode=0o700)
        return d

    def init(self, policies):
        d = self.folder('st')
        args = ['init', d / 'st']
        for name, body in policies.items():
            p = d / ('%s.json' % name)
            p.write_text(body if isinstance(body, str) else policy_text(name, body))
            args += ['--policy', p]
        code, out = self.run(*args)
        return d / 'st', code, out.strip()

    def main_store(self):
        if self.store is None:
            st, code, out = self.init(POLICIES)
            require(code == 0 and out.startswith('INITIALIZED'), 'NOT RUN: the store did not init: %r' % out)
            self.store = st
        return self.store

    def batch(self, items):
        """items: (policy, destination, json text). One serve process; returns Answers in order, checks exit codes."""
        st = self.main_store()
        lines = ['DO taint_egress check r%d t1 0 %s %s %s' % (i, p, d, t) for i, (p, d, t) in enumerate(items)]
        for ln in lines:
            require(len(ln) <= 65536 and all(0x20 <= ord(c) < 0x7f for c in ln), 'suite: a request line is not printable or too long')
        code, out = self.run('serve', st, inp=('\n'.join(lines) + '\n').encode())
        got = out.splitlines()
        require(len(got) == len(items), 'serve answered %d lines for %d requests (exit %d)' % (len(got), len(items), code))
        ans = [Answer(x) for x in got]
        last = ans[-1].code
        require(code == (0 if last == 'ALLOW' else EXITS.get(last, 10)), 'serve exit %d does not match the last answer %r' % (code, ans[-1]))
        for (_, _, t), a in zip(items, ans):
            self.answers.append((t, a.line))
        return ans


def expect(a, want, label):
    code = want[0]
    require(a.code == code, '%s: expected %s, got %r' % (label, code, a.line))
    for k, v in (want[1] if len(want) > 1 else {}).items():
        require(a.f.get(k) == v, '%s: expected %s=%s, got %r' % (label, k, v, a.line))


# ---- case: policy -------------------------------------------------------------------------------------------------
def case_policy(s):
    base = POLICIES['med']
    bad = {
        'unknown key': dict(base, extra=1),
        'missing mode': {k: v for k, v in base.items() if k != 'mode'},
        'mode word': dict(base, mode='allow'),
        'custom label lower': dict(base, labels=['internal']),
        'custom label fixed': dict(base, labels=['PII']),
        'custom label dup': dict(base, labels=['X1', 'X1']),
        'rule unknown label': dict(base, fields=[{'path': 'ssn', 'labels': ['NOPE']}]),
        'rule dup label': dict(base, fields=[{'path': 'ssn', 'labels': ['PII', 'PII']}]),
        'rule extra key': dict(base, fields=[{'path': 'ssn', 'labels': [], 'x': 1}]),
        'rule path dot': dict(base, fields=[{'path': 'a..b', 'labels': []}]),
        'rule path leading []': dict(base, fields=[{'path': '[].a', 'labels': []}]),
        'rule path empty': dict(base, fields=[{'path': '', 'labels': []}]),
        'rule path only separators': dict(base, fields=[{'path': '_-', 'labels': []}]),
        'rule path quote': dict(base, fields=[{'path': 'a"b', 'labels': []}]),
        'rule dup after normalization': dict(base, fields=[{'path': 'ssn', 'labels': []}, {'path': 'S_S_N', 'labels': ['PII']}]),
        'rule tenant wildcard': dict(base, fields=[{'path': 'a', 'labels': ['TENANT:*']}]),
        'dest empty': dict(base, destinations={}),
        'dest lower': dict(base, destinations={'public': []}),
        'dest TENANT bare': dict(base, destinations={'TENANT': []}),
        'tenant label in tenant dest': dict(base, destinations={'TENANT:*': ['TENANT:a']}),
        'any tenant in tenant dest': dict(base, destinations={'TENANT:*': ['TENANT:*']}),
        'dest unknown label': dict(base, destinations={'PUBLIC_HTTP': ['CREDIT']}),
        'dest dup label': dict(base, destinations={'PUBLIC_HTTP': ['PII', 'PII']}),
        'too many rules': dict(base, fields=[{'path': 'k%d' % i, 'labels': []} for i in range(257)]),
    }
    for name, body in bad.items():
        st, code, out = s.init({'p1': body})
        require(code == 25 and out.startswith('MALFORMED_POLICY'), 'policy %r: expected MALFORMED_POLICY exit 25, got %d %r' % (name, code, out))
        require(not st.exists(), 'policy %r: a refused init left a store' % name)
    st, code, out = s.init({'p1': dict(base, fields=[{'path': 'k%d' % i, 'labels': []} for i in range(256)])})
    require(code == 0, '256 rules must be accepted: %r' % out)
    st, code, out = s.init(POLICIES)
    require(code == 0, 'the suite policies must be accepted: %r' % out)
    return '%d bad policies refused (exit 25, no store); 256 rules and the suite policies accepted' % len(bad)


# ---- case: wire ---------------------------------------------------------------------------------------------------
def case_wire(s):
    st = s.main_store()
    before = (st / 'primitives.wal').read_bytes()
    doc = '{"a": [1, 2, {"b": "x"}]}'
    lines = ['DO taint_egress check same t1 0 med PUBLIC_HTTP %s' % doc, 'DO taint_egress check same t1 0 med PUBLIC_HTTP %s' % doc,
             'DO taint_egress check w1 t1 0 med PUBLIC_HTTP', 'DO taint_egress check w2 t1 0 med',
             'DO taint_egress check w3 t1 0 nope PUBLIC_HTTP {}', 'DO taint_egress check w4 t1 0 med NOPE {}',
             'DO taint_egress check w5 t1 0 wrap TENANT:a {}', 'DO taint_egress check w6 t1 0 med TENANT:a b c {}',
             'DO taint_egress check w7 t1 0 med public_http {}', 'DO taint_egress check w8 t1 0 med TENANT:a {"a":1,"a":2}',
             'DO taint_egress check w9 t1 0 med TENANT:a {"a":1} x', 'DO taint_egress check w10 t1 0 med TENANT {}',
             'DO taint_egress check w11 t1 1 k %s med PUBLIC_HTTP {}' % ('0' * 64), 'DO taint_egress check w12 t1 0 med TENANT:* {}']
    code, out = s.run('serve', st, inp=('\n'.join(lines) + '\n').encode())
    a = [Answer(x) for x in out.splitlines()]
    require(len(a) == len(lines), 'wire: %d answers for %d lines' % (len(a), len(lines)))
    expect(a[0], ('ALLOW', {'sha256': hashlib.sha256(doc.encode()).hexdigest(), 'bytes': str(len(doc)), 'nodes': '6', 'mode': 'detect',
                            'policy': 'med', 'destination': 'PUBLIC_HTTP'}), 'allow fields')
    expect(a[1], ('ALLOW',), 'the same request id twice (a stateless answer leaves it fresh)')
    expect(a[2], ('MALFORMED_REQUEST', {'why': 'TAINT_ARGS'}), 'no document')
    expect(a[3], ('MALFORMED_REQUEST', {'why': 'TAINT_ARGS'}), 'no destination')
    expect(a[4], ('UNKNOWN_POLICY',), 'unknown policy')
    expect(a[5], ('UNKNOWN_DESTINATION',), 'unknown destination')
    expect(a[6], ('UNKNOWN_DESTINATION',), 'a tenant destination where the policy has no TENANT:*')
    expect(a[7], ('MALFORMED_REQUEST', {'why': 'BAD_JSON', 'error': 'BAD_VALUE'}), 'text before the document')
    expect(a[8], ('MALFORMED_REQUEST', {'why': 'TAINT_ARGS'}), 'a lower-case destination')
    expect(a[9], ('MALFORMED_REQUEST', {'why': 'BAD_JSON', 'error': 'DUPLICATE_KEY'}), 'a duplicate key')
    expect(a[10], ('MALFORMED_REQUEST', {'why': 'BAD_JSON', 'error': 'TRAILING_BYTES'}), 'trailing bytes')
    expect(a[11], ('MALFORMED_REQUEST', {'why': 'TAINT_ARGS'}), 'the bare word TENANT')
    expect(a[12], ('MALFORMED_REQUEST', {'why': 'KEY_COUNT'}), 'a key given to the stateless op')
    expect(a[13], ('MALFORMED_REQUEST', {'why': 'TAINT_ARGS'}), 'TENANT:* as a destination')
    require((st / 'primitives.wal').read_bytes() == before, 'a stateless check wrote to the WAL')
    for ln, want in ((lines[0], 0), (lines[4], 10), (lines[2], 12)):
        code, out = s.run('serve', st, inp=(ln + '\n').encode())
        require(code == want, 'exit %d for %r, expected %d' % (code, out.strip(), want))
    return '14 wire lines; ALLOW carries sha256 and bytes of the exact document; exits 0, 10, 12; no WAL byte written; id stays fresh'


# ---- case: table --------------------------------------------------------------------------------------------------
S1, S2, S3 = 'MARK_SSN_078051120', 'MARK_KEY_sk_live_4eC39H', 'MARK_PHI_diabetic'
KEYSECRET = 'MARK_KEYNAME_sk_live_zz9'
BETA = {'name': 'MARK_BETA_patient', 'MARK': 'MARK_BETA_PHI'}
B = 'MARK_tb'  # a foreign tenant id: it must never be echoed


def T(name, pol, dest, doc, *want):
    return (name, pol, dest, doc if isinstance(doc, str) else enc(doc), want)


def bl(path, label, more=0):
    return ('TAINT_EGRESS_BLOCKED', {'json_path': path, 'label': label, 'more': str(more)})


def un(path, more=0):
    return ('UNLABELLED_FIELD', {'json_path': path, 'more': str(more)})


def st_(code, path, more=0, **kw):
    return (code, dict({'json_path': path, 'more': str(more)}, **kw))


ALLOW = ('ALLOW',)
P, L, A = 'PUBLIC_HTTP', 'LLM_STDOUT', 'TENANT:a'
TABLE = [
    T('t01 unlabelled field', 'med', P, {'a': 1}, ALLOW),
    T('t02 ssn to public', 'med', P, {'ssn': S1}, bl('$.ssn', 'PII')),
    T('t03 ssn to llm (PII allowed)', 'med', L, {'ssn': S1}, ALLOW),
    T('t04 SSN upper case', 'med', P, {'SSN': S1}, bl('$.ssn', 'PII')),
    T('t05 S-S-N hyphens', 'med', P, {'S-S-N': S1}, bl('$.ssn', 'PII')),
    T('t06 s_s_n underscores', 'med', P, {'s_s_n': S1}, bl('$.ssn', 'PII')),
    T('t07 \\u0073sn escape decoded by the parser', 'med', P, '{"\\u0073\\u0053n":"%s"}' % S1, bl('$.ssn', 'PII')),
    T('t08 fullwidth ssn', 'med', P, {'ｓｓｎ': S1}, bl('$.ssn', 'PII')),
    T('t09 ssn with a space', 'med', P, {'s sn ': S1}, bl('$.ssn', 'PII')),
    T('t10 nested objects', 'med', P, {'a': {'b': {'c': {'ssn': S1}}}}, bl('$.~0.~0.~0.ssn', 'PII')),
    T('t11 object in array', 'med', P, {'rows': [1, {'ssn': S1}]}, bl('$.~0[1].ssn', 'PII')),
    T('t12 arrays of arrays', 'med', P, [[[{'ssn': S1}]]], bl('$[0][0][0].ssn', 'PII')),
    T('t13 nested JSON in a string', 'med', P, {'note': js({'ssn': S1})}, bl('$.~0@.ssn', 'PII')),
    T('t14 double-encoded JSON', 'med', P, {'n': json.dumps(js({'ssn': S1}))}, bl('$.~0@@.ssn', 'PII')),
    T('t15 JSON array in a string', 'med', P, {'n': js([{'api_key': S2}])}, bl('$.~0@[0].apikey', 'SECRET_KEY')),
    T('t16 anchored path', 'med', P, {'patients': [{'notes': S3}]}, bl('$.patients[0].notes', 'PHI')),
    T('t17 anchored path, other root', 'med', P, {'x': {'patients': [{'notes': S3}]}}, ALLOW),
    T('t18 anchored path needs the array', 'med', P, {'patients': {'notes': S3}}, ALLOW),
    T('t19 carrier', 'med', P, {'a': {'$taint': ['PHI'], 'value': S3}}, bl('$.~0', 'PHI')),
    T('t20 carrier to tenant (PHI allowed)', 'med', A, {'a': {'$taint': ['PHI'], 'value': S3}}, ALLOW),
    T('t21 carrier covers below', 'med', A, {'$taint': ['SECRET_KEY'], 'value': {'deep': [{'x': S2}]}}, bl('$', 'SECRET_KEY')),
    T('t22 carrier label and the same label below', 'med', P, {'$taint': ['PII'], 'value': {'ssn': S1}}, bl('$', 'PII')),
    T('t23 carrier PHI, PII below', 'med', P, {'$taint': ['PHI'], 'value': {'ssn': S1}}, bl('$', 'PHI', 1)),
    T('t24 carrier two labels', 'med', P, {'$taint': ['PII', 'PHI'], 'value': 1}, bl('$', 'PHI', 1)),
    T('t25 carrier unknown label', 'med', P, {'a': {'$taint': ['CREDIT'], 'value': 1}}, st_('UNKNOWN_LABEL', '$.~0')),
    T('t26 carrier label not a string', 'med', P, {'a': {'$taint': [1], 'value': 1}}, st_('MALFORMED_CARRIER', '$.~0', why='LABEL_NOT_STRING')),
    T('t27 carrier extra key', 'med', P, {'a': {'$taint': ['PII'], 'value': 1, 'x': 2}}, st_('MALFORMED_CARRIER', '$.~0', why='SHAPE')),
    T('t28 carrier labels not an array', 'med', P, {'a': {'$taint': 'PII', 'value': 1}}, st_('MALFORMED_CARRIER', '$.~0', why='LABELS_NOT_ARRAY')),
    T('t29 carrier $TAINT spelling', 'med', P, {'a': {'$TAINT': ['PHI'], 'VALUE': S3}}, bl('$.~0', 'PHI')),
    T('t30 carrier with no label', 'med', P, {'a': {'$taint': [], 'value': S3}}, ALLOW),
    T('t31 own tenant', 'med', A, {'tenant_id': 'a', 'x': 1}, ALLOW),
    T('t32 foreign tenant at the root', 'med', A, {'tenant_id': B}, bl('$', 'TENANT')),
    T('t33 foreign tenant nested (Goal 20 hole)', 'med', A, {'tenant_id': 'a', 'rows': [{'tenant_id': B, 'n': BETA}]}, bl('$.~0[0]', 'TENANT')),
    T('t34 tenantId spelling', 'med', A, {'tenantId': B}, bl('$', 'TENANT')),
    T('t35 TENANT-ID spelling', 'med', A, {'x': {'TENANT-ID': B}}, bl('$.~0', 'TENANT')),
    T('t36 tenant_id not a string', 'med', A, {'tenant_id': 5}, st_('MALFORMED_CARRIER', '$', why='TENANT_ID')),
    T('t37 tenant_id not canonical', 'med', A, {'tenant_id': 'a b'}, st_('MALFORMED_CARRIER', '$', why='TENANT_ID')),
    T('t38 tenant label to public', 'med', P, {'tenant_id': 'a'}, bl('$', 'TENANT')),
    T('t39 tenant label to AUDIT (TENANT:* allowed)', 'med', 'AUDIT', {'tenant_id': B, 'ssn': S1}, ALLOW),
    T('t40 tenant carrier to another tenant', 'med', A, {'r': {'$taint': ['TENANT:' + B], 'value': 1}}, bl('$.~0', 'TENANT')),
    T('t41 tenant carrier to its tenant', 'med', 'TENANT:' + B, {'r': {'$taint': ['TENANT:' + B], 'value': 1}}, ALLOW),
    T('t42 rule with a tenant label, its tenant', 'med', 'TENANT:acme', {'acme_rows': [1]}, ALLOW),
    T('t43 rule with a tenant label, other tenant', 'med', A, {'acme_rows': [1]}, bl('$.acmerows', 'TENANT')),
    T('t44 custom label to public', 'med', P, {'internal_note': 'x'}, bl('$.internalnote', 'INTERNAL')),
    T('t45 custom label to tenant', 'med', A, {'internal_note': 'x'}, ALLOW),
    T('t46 keys equal after normalization', 'med', L, {'ssn': S1, 'SSN': 'x'}, st_('AMBIGUOUS_KEY', '$')),
    T('t47 raw duplicate key', 'med', P, '{"ssn":"%s","ssn":"x"}' % S1, ('MALFORMED_REQUEST', {'why': 'BAD_JSON', 'error': 'DUPLICATE_KEY'})),
    T('t48 duplicate key in nested JSON', 'med', P, {'n': '{"a":1,"a":2}'}, st_('OPAQUE_JSON', '$.~0', error='DUPLICATE_KEY')),
    T('t49 zero-width key', 'med', P, {'s​sn': S1}, st_('UNSAFE_KEY', '$.~0', why='IGNORABLE')),
    T('t50 control byte key', 'med', P, {'k\u0001': 1}, st_('UNSAFE_KEY', '$.~0', why='CONTROL')),
    T('t51 key of 257 bytes', 'med', P, {'k' * 257: 1}, st_('UNSAFE_KEY', '$.~0', why='TOO_LONG')),
    T('t52 key of 256 bytes', 'med', P, {'k' * 256: 1}, ALLOW),
    T('t53 key of 256 bytes, multibyte', 'med', P, {'é' * 128: 1}, ALLOW),
    T('t54 key of 258 bytes, multibyte', 'med', P, {'é' * 129: 1}, st_('UNSAFE_KEY', '$.~0', why='TOO_LONG')),
    T('t55 bidi override key', 'med', P, {'‮ssn': 1}, st_('UNSAFE_KEY', '$.~0', why='IGNORABLE')),
    T('t56 three PII fields: first and count', 'med', P, {'ssn': S1, 'x': {'ssn': S1}, 'y': [{'ssn': S1}]}, bl('$.ssn', 'PII', 2)),
    T('t57 order is by key bytes', 'med', P, {'zz': {'ssn': S1}, 'aa': {'api_key': S2}}, bl('$.~0.apikey', 'SECRET_KEY', 1)),
    T('t58 structure before taint', 'med', P, {'ssn': S1, 'k​': 2}, st_('UNSAFE_KEY', '$.~0')),
    T('t59 value key echoed', 'med', P, {'value': {'ssn': S1}}, bl('$.value.ssn', 'PII')),
    T('t60 suffix rule', 'med', P, {'x': {'billing': {'card': '4111'}}}, bl('$.~0.billing.card', 'PII')),
    T('t61 suffix rule, part only', 'med', P, {'card': '4111'}, ALLOW),
    T('t62 suffix through nested JSON', 'med', P, {'billing': js({'card': '4111'})}, bl('$.billing@.card', 'PII')),
    T('t63 suffix through a carrier', 'med', P, {'billing': {'$taint': [], 'value': {'card': '4111'}}}, bl('$.billing.value.card', 'PII')),
    T('t64 array element rule', 'med', P, {'cards': ['4111', '5500']}, bl('$.cards[0]', 'PII', 1)),
    T('t65 root rule', 'wrap', P, {'a': 1}, bl('$', 'PII')),
    T('t66 root rule to llm', 'wrap', L, [1, 2], ALLOW),
    T('t67 number under a labelled name', 'med', P, {'ssn': 78051120}, bl('$.ssn', 'PII')),
    T('t68 null under a labelled name', 'med', P, {'ssn': None}, bl('$.ssn', 'PII')),
    T('t69 empty object under a labelled name', 'med', P, {'ssn': {}}, bl('$.ssn', 'PII')),
    T('t70 empty object', 'med', P, {}, ALLOW),
    T('t71 bare string', 'med', P, '"x"', ALLOW),
    T('t72 bare number', 'med', P, '5', ALLOW),
    T('t73 nested JSON with JSON white space', 'med', P, {'n': '  \n' + js({'ssn': S1})}, bl('$.~0@.ssn', 'PII')),
    T('t74 nested JSON after NBSP', 'med', P, {'n': ' ' + js({'ssn': S1})}, st_('OPAQUE_JSON', '$.~0', error='BAD_VALUE')),
    T('t75 quoted words', 'med', P, {'q': '"quoted" words'}, st_('OPAQUE_JSON', '$.~0', error='TRAILING_BYTES')),
    T('t76 [draft] note', 'med', P, {'q': '[draft] note'}, st_('OPAQUE_JSON', '$.~0', error='BAD_VALUE')),
    T('t77 JSON after text is plain text', 'med', P, {'q': 'note ' + js({'ssn': S1})}, ALLOW),
    T('t78 secret in a key name', 'med', P, {KEYSECRET: {'ssn': S1}}, bl('$.~0.ssn', 'PII')),
    T('t79 strict: covered document', 'meds', P, {'id': 1, 'tenant_id': 'a', 'patients': [{'name': 'n'}], 'meta': {'x': [1, {'y': 2}]}}, bl('$', 'TENANT')),
    T('t80 strict: covered document to tenant', 'meds', A, {'id': 1, 'tenant_id': 'a', 'patients': [{'name': 'n', 'ssn': S1}], 'meta': {'x': [1]}}, ALLOW),
    T('t81 strict: extra field', 'meds', P, {'id': 1, 'extra': 2}, un('$.~0')),
    T('t82 strict: unanchored note', 'meds', P, {'patients': [{'name': 'n', 'note': 'x'}], 'meta': {'note': 1}}, ALLOW),
    T('t83 strict: unknown key in a patient', 'meds', P, {'patients': [{'name': 'n', 'dob': 'x'}]}, un('$.patients[0].~0')),
    T('t84 strict: bare string', 'meds', P, '"x"', un('$')),
    T('t85 strict: empty array root', 'meds', P, '[]', ALLOW),
    T('t86 strict: a carrier does not cover', 'meds', P, {'z': {'$taint': [], 'value': 1}}, un('$.~0')),
    T('t87 strict: taint before unlabelled', 'meds', P, {'extra': 1, 'patients': [{'ssn': S1}]}, bl('$.patients[0].ssn', 'PII')),
    T('t88 strict: prefix must be a container', 'meds', P, {'patients': 'x'}, un('$.patients')),
    T('t89 strict: count', 'meds', P, {'a': 1, 'b': 2}, un('$.~0', 1)),
    T('t90 strict: an uncovered object counts once', 'meds', P, {'x': {'y': 1, 'z': 2}}, un('$.~0')),
    T('t91 strict: nested JSON under a covered name', 'meds', P, {'meta': js({'anything': [1, 2]})}, ALLOW),
    T('t92 strict: own tenant', 'meds', A, {'tenant_id': 'a', 'id': 1}, ALLOW),
    T('t93 strict: carrier value leaf under a prefix', 'meds', P, {'patients': {'$taint': [], 'value': 1}}, un('$.patients.value')),
    # the nine leaking result shapes of the MCP proxy review (REVIEW-B finding 2), translated, and its control
    T('r0 control: own label', 'med', A, {'tenant_id': 'a', 'n': 'ok'}, ALLOW),
    T('r1 free text TENANT-ID: b in a value (detect)', 'med', A, {'tenant_id': 'a', 'note': 'TENANT-ID: %s %s' % (B, BETA['MARK'])}, ALLOW),
    T('r1s same, strict, uncovered name', 'meds', A, {'tenant_id': 'a', 'comment': 'TENANT-ID: %s %s' % (B, BETA['MARK'])}, un('$.~0')),
    T('r2 free text tenantId: b (detect)', 'med', A, {'tenant_id': 'a', 'note': 'tenantId: %s %s' % (B, BETA['MARK'])}, ALLOW),
    T('r3 non-strict nested JSON (trailing comma)', 'med', A, {'tenant_id': 'a', 'note': '{"tenantId":"%s","MARK":"%s",}' % (B, BETA['MARK'])}, st_('OPAQUE_JSON', '$.~0', error='BAD_KEY')),
    T('r4 nested JSON with duplicate tenantId', 'med', A, {'tenant_id': 'a', 'note': '{"tenantId":"a","tenantId":"%s"}' % B}, st_('OPAQUE_JSON', '$.~0', error='DUPLICATE_KEY')),
    T('r4b nested JSON, tenantId and tenant_id', 'med', A, {'tenant_id': 'a', 'note': '{"tenantId":"a","tenant_id":"%s"}' % B}, st_('AMBIGUOUS_KEY', '$.~0@')),
    T('r5 nested JSON, \\u005f key, trailing text', 'med', A, {'tenant_id': 'a', 'note': '{"tenant\\u005fid":"%s"} end' % B}, st_('OPAQUE_JSON', '$.~0', error='TRAILING_BYTES')),
    T('r5b nested JSON, \\u005f key', 'med', A, {'tenant_id': 'a', 'note': '{"tenant\\u005fid":"%s"}' % B}, bl('$.~0@', 'TENANT')),
    T('r6 nested JSON after a form feed', 'med', A, {'tenant_id': 'a', 'note': '\f{"tenantId":"%s"}' % B}, st_('OPAQUE_JSON', '$.~0', error='BAD_VALUE')),
    T('r7 foreign record in an object key', 'med', A, {'tenant_id': 'a', js(dict({'tenant_id': B}, **BETA)): 'a'}, st_('UNSAFE_KEY', '$.~1', why='JSON_LIKE')),
    T('r8 plain text in an object key', 'med', A, {'tenant_id': 'a', 'x': {'tenant_id=%s %s' % (B, BETA['MARK']): 'a'}}, st_('UNSAFE_KEY', '$.~1.~0', why='CARRIER_NAME')),
    T('r9 depth 70 nested JSON text', 'med', A, {'tenant_id': 'a', 'note': '[' * 70 + '{"tenantId":"%s"}' % B + ']' * 70}, st_('OPAQUE_JSON', '$.~0', error='TOO_DEEP')),
    T('r9b depth 31 nested JSON text', 'med', A, {'tenant_id': 'a', 'note': '[' * 30 + '{"tenantId":"%s"}' % B + ']' * 30}, bl('$.~0@' + '[0]' * 30, 'TENANT')),
    T('r9c depth 40 nested JSON text', 'med', A, {'tenant_id': 'a', 'note': '[' * 40 + '{"tenantId":"%s"}' % B + ']' * 40}, ('TAINT_LIMIT', {'why': 'TOO_DEEP', 'max': '32'})),
]


def run_table(s, table):
    ans = s.batch([(p, d, t) for _, p, d, t, _ in table])
    bad = []
    for (name, p, d, t, want), a in zip(table, ans):
        try:
            expect(a, want[0], name)
        except Failed as e:
            bad.append(str(e))
    return ans, bad


def case_table(s):
    names = [x[0] for x in TABLE]
    require(len(set(names)) == len(names), 'suite: a table name is used twice')
    ans, bad = run_table(s, TABLE)
    require(not bad, '%d of %d rows wrong: %s' % (len(bad), len(TABLE), ' | '.join(bad)[:1500]))
    allow = sum(1 for a in ans if a.code == 'ALLOW')
    return '%d documents (%d ALLOW, %d refused), each with its exact code, json_path, label and count' % (len(TABLE), allow, len(TABLE) - allow)


# ---- case: order --------------------------------------------------------------------------------------------------
def shuffled(v, rng):
    """The same document with the keys of every object (also inside nested JSON strings) in a random order."""
    if isinstance(v, RObj):
        items = [(k, shuffled(x, rng)) for k, x in v]
        rng.shuffle(items)
        return Pairs(items)
    if isinstance(v, list):
        return [shuffled(x, rng) for x in v]
    if isinstance(v, str) and r_jsonlike(v):
        p = r_parse(v)
        if p is not RBad and isinstance(p, (RObj, list)):
            return enc(shuffled(p, rng))
    return v


def case_order(s):
    rng = random.Random(8)
    items, base = [], []
    for name, p, d, t, want in TABLE:
        doc = r_parse(t)
        if doc is RBad:
            continue
        base.append(len(items))
        items.append((p, d, t))
        for _ in range(5):
            items.append((p, d, enc(shuffled(doc, rng))))
    ans = s.batch(items)
    bad = 0
    msgs = []
    for i in range(len(items)):
        b = max(x for x in base if x <= i)
        if ans[i].stable(drop=('sha256', 'bytes')) != ans[b].stable(drop=('sha256', 'bytes')):
            bad += 1
            msgs.append('%r vs %r' % (ans[b].line[:120], ans[i].line[:120]))
    require(bad == 0, '%d shuffled documents changed the answer: %s' % (bad, ' | '.join(msgs)[:1200]))
    return '%d documents, 5 key orders each: the same code and fields every time' % len(base)


# ---- case: leak ---------------------------------------------------------------------------------------------------
def secrets_of(text):
    out = set()
    v = r_parse(text)
    stack = [v]
    while stack:
        n = stack.pop()
        if isinstance(n, RObj):
            for k, x in n:
                stack.append(k)
                stack.append(x)
        elif isinstance(n, list):
            stack.extend(n)
        elif isinstance(n, str):
            if 'MARK' in n:
                for m in re.findall(r'MARK[A-Za-z0-9_]*', n):
                    out.add(m)
            if r_jsonlike(n):
                p = r_parse(n)
                if p is not RBad:
                    stack.append(p)
    return out


def case_leak(s):
    s.answers = []
    run_table(s, TABLE)
    run_table(s, EVASIONS_T)
    checked = refusals = 0
    found = []
    for text, line in s.answers:
        if line.startswith('OK '):
            continue
        refusals += 1
        sec = secrets_of(text) if r_parse(text) is not RBad else set(re.findall(r'MARK[A-Za-z0-9_]*', text))
        hay = [line, unquote(line), r_norm(unquote(line))]
        for m in sec:
            checked += 1
            for needle in {m, r_norm(m), m[4:], r_norm(m[4:])}:
                if len(needle) >= 4 and any(needle in h for h in hay):
                    found.append('%s in %r' % (m, line[:120]))
    require(refusals >= 60, 'NOT RUN: only %d refusals to search' % refusals)
    require(checked >= 60, 'NOT RUN: only %d secret checks' % checked)
    require(not found, 'a refusal holds a secret: %s' % ' | '.join(found)[:1200])
    return '%d refusals searched for %d secret occurrences (values and keys; raw, percent-decoded, normalized, without the MARK prefix): 0 found' % (refusals, checked)


# ---- case: limits -------------------------------------------------------------------------------------------------
def nested_levels(n, leaf):
    """leaf wrapped in n levels of JSON-in-a-string: {"n": "<json of {"n": ...}>"}."""
    v = leaf
    for _ in range(n):
        v = {'n': js(v)}
    return v


def case_limits(s):
    wide_ok = '[' + ','.join(['0'] * (MAX_NODES - 1)) + ']'
    wide_over = '[' + ','.join(['0'] * MAX_NODES) + ']'
    rows = [
        T('depth 32', 'med', P, deep(32, 1), ALLOW),
        T('depth 33', 'med', P, deep(33, 1), ('TAINT_LIMIT', {'why': 'TOO_DEEP', 'max': '32'})),
        T('depth 32 through a nested string', 'med', P, deep(16, js(deep(16, 1))), ALLOW),
        T('depth 33 through a nested string', 'med', P, deep(16, js(deep(17, 1))), ('TAINT_LIMIT', {'why': 'TOO_DEEP', 'max': '32'})),
        T('depth 65 refused by the parser', 'med', P, deep(65, 1), ('MALFORMED_REQUEST', {'why': 'BAD_JSON', 'error': 'TOO_DEEP'})),
        T('nodes 16384', 'med', P, wide_ok, ('ALLOW', {'nodes': str(MAX_NODES)})),
        T('nodes 16385', 'med', P, wide_over, ('TAINT_LIMIT', {'why': 'TOO_MANY_NODES', 'max': str(MAX_NODES)})),
        T('nodes 16385 through nested strings', 'med', P, '[' + ','.join(['0'] * (MAX_NODES - 4)) + ',' + json.dumps(js([0, 0])) + ']',
          ('TAINT_LIMIT', {'why': 'TOO_MANY_NODES', 'max': str(MAX_NODES)})),
        T('nodes 16384 through nested strings', 'med', P, '[' + ','.join(['0'] * (MAX_NODES - 5)) + ',' + json.dumps(js([0, 0])) + ']',
          ('ALLOW', {'nodes': str(MAX_NODES)})),
        T('nested levels 4', 'med', P, nested_levels(4, {'ssn': S1}), bl('$.~0@.~0@.~0@.~0@.ssn', 'PII')),
        T('nested levels 5', 'med', P, nested_levels(5, {'ssn': S1}), ('TAINT_LIMIT', {'why': 'NESTED_TOO_DEEP', 'max': '4'})),
        T('key 256 bytes', 'med', P, {'k' * 256: 1}, ALLOW),
        T('key 257 bytes', 'med', P, {'k' * 257: 1}, st_('UNSAFE_KEY', '$.~0', why='TOO_LONG')),
    ]
    _, bad = run_table(s, rows)
    require(not bad, ' | '.join(bad)[:1500])
    return 'depth 32/33 (also through a nested string), nodes 16384/16385 (also through nested strings), levels 4/5, key 256/257 bytes'


# ---- case: evasions (the known-limits table of taint.rs; each row is the ACTUAL result) ---------------------------
EVASIONS = [
    ('E01 secret under an unlabelled, allowed name (detect)', 'med', P, {'comment': S1}, ALLOW),
    ('E01s same, strict, name not covered', 'meds', P, {'comment': S1}, un('$.~0')),
    ('E01c same, strict, under a covered name', 'meds', P, {'meta': {'x': S1}}, ALLOW),
    ('E02 base64 value under an unlabelled name', 'med', P, {'blob': 'TUFSS19TU05fMDc4MDUxMTIw'}, ALLOW),
    ('E03 hex value', 'med', P, {'blob': '4d41524b5f53534e'}, ALLOW),
    ('E04 percent-encoded key', 'med', P, {'ss%6E': S1}, ALLOW),
    ('E05 HTML entity key', 'med', P, {'&#115;sn': S1}, ALLOW),
    ('E06 literal \\x key', 'med', P, {'\\x73sn': S1}, ALLOW),
    ('E07 \\u escape key (decoded)', 'med', P, '{"\\u0073sn":"%s"}' % S1, bl('$.ssn', 'PII')),
    ('E08 compressed secret (gzip+base64) under an unlabelled name', 'med', P, {'blob': 'H4sIAAAAAAAA//N0dPZWCA4O9vMMMDAwNjQ0NgYAJ/8RvBYAAAA='}, ALLOW),
    ('E09 split secret', 'med', P, {'a': S1[:10], 'b': S1[10:]}, ALLOW),
    ('E10 number as a carrier', 'med', P, {'n': 78051120}, ALLOW),
    ('E11 Cyrillic homoglyph key', 'med', P, {'ѕsn': S1}, ALLOW),
    ('E11s same, strict', 'meds', P, {'ѕsn': S1}, un('$.~0')),
    ('E12 zero-width key', 'med', P, {'ss​n': S1}, st_('UNSAFE_KEY', '$.~0', why='IGNORABLE')),
    ('E13 fullwidth key', 'med', P, {'ｓｓｎ': S1}, bl('$.ssn', 'PII')),
    ('E14 NFC and NFD keys side by side', 'med', P, {'café': 1, 'café': S1}, ALLOW),
    ('E15 array of pairs', 'med', P, {'kv': [['ssn', S1]]}, ALLOW),
    ('E15s same, strict', 'meds', P, {'kv': [['ssn', S1]]}, un('$.~0')),
    ('E16 very deep document', 'med', P, deep(40, S1), ('TAINT_LIMIT', {'why': 'TOO_DEEP', 'max': '32'})),
    ('E17 very wide document', 'med', P, [0] * 20000, ('TAINT_LIMIT', {'why': 'TOO_MANY_NODES', 'max': str(MAX_NODES)})),
    ('E18 carrier omitted by the author', 'med', A, {'tenant_id': 'a', 'rows': [{'name': BETA['name']}]}, ALLOW),
    ('E19 label name unknown to the policy', 'med', P, {'x': {'$taint': ['CREDIT_CARD'], 'value': S1}}, st_('UNKNOWN_LABEL', '$.~0')),
    ('E20 Kelvin sign K in a key (no Unicode case fold)', 'med', P, {'api_Key': S2}, ALLOW),
    ('E21 tenant id hidden in free text', 'med', A, {'tenant_id': 'a', 'note': 'tenant %s' % B}, ALLOW),
    ('E22 label by the key name only: secret in a sibling', 'med', P, {'ssn_hint': S1}, ALLOW),
]
EVASIONS_T = [T(*e) for e in EVASIONS]


def case_evasions(s):
    ans, bad = run_table(s, EVASIONS_T)
    require(not bad, ' | '.join(bad)[:1500])
    return '%d evasions; results as in the known-limits table of taint.rs' % len(EVASIONS_T)


# ---- case: differential -------------------------------------------------------------------------------------------
KEYS = ['ssn', 'SSN', 's-s-n', 'Ssn', 'api_key', 'apiKey', 'API-KEY', 'notes', 'patients', 'billing', 'card', 'cards', 'tenant_id',
        'tenantId', 'TENANT_ID', 'value', 'Value', '$taint', 'id', 'name', 'note', 'meta', 'x', 'y', 'z', 'aa', 'zz',
        'ｓｓｎ', 's​sn', 'tenant_id_old', '{k}', 'é', 'café', 'café', 'k\u0001', 'internal_note',
        'acme_rows', 'a.b', 'a[0]', 'MARK_KEY_sk', ' ', '', 'k' * 257, '"q', 'ѕsn']
LABELS = ['PII', 'PHI', 'SECRET_KEY', 'INTERNAL', 'TENANT:a', 'TENANT:b', 'TENANT:acme', 'CREDIT', 'pii']
DESTS = ['PUBLIC_HTTP', 'LLM_STDOUT', 'AUDIT', 'TENANT:a', 'TENANT:b', 'TENANT:acme', 'NOPE']


def gen(rng, depth, budget):
    budget[0] -= 1
    r = rng.random()
    if depth <= 0 or budget[0] <= 0 or r < 0.3:
        c = rng.random()
        if c < 0.25:
            return rng.choice([0, 1, -5, 3.5, 78051120, True, False, None])
        if c < 0.55:
            return rng.choice(['x', 'MARK_v', 'a', 'b', 'acme', 'a b', '', '[draft]', '"q" w', ' {', '\f{}', ' [1]'])
        if c < 0.8:
            inner = gen(rng, rng.randint(0, 3), budget)
            t = enc(inner)
            if rng.random() < 0.2:
                t = t + rng.choice([' end', ',', '}'])
            return t
        return json.dumps(enc(gen(rng, 2, budget)))
    if r < 0.45:
        return [gen(rng, depth - 1, budget) for _ in range(rng.randint(0, 4))]
    if r < 0.55:
        labs = [rng.choice(LABELS) for _ in range(rng.randint(0, 2))]
        if rng.random() < 0.1:
            labs.append(1)
        pairs = [('$taint' if rng.random() < 0.9 else '$TAINT', labs), ('value' if rng.random() < 0.9 else 'val', gen(rng, depth - 1, budget))]
        if rng.random() < 0.1:
            pairs.append(('x', 1))
        rng.shuffle(pairs)
        return Pairs(pairs)
    n = rng.randint(0, 4)
    used, pairs = set(), []
    for _ in range(n):
        k = rng.choice(KEYS)
        if k in used:
            continue
        used.add(k)
        if k in ('tenant_id', 'tenantId', 'TENANT_ID') and rng.random() < 0.7:
            pairs.append((k, rng.choice(['a', 'b', 'acme', 5, 'a b'])))
        else:
            pairs.append((k, gen(rng, depth - 1, budget)))
    return Pairs(pairs)


def case_differential(s):
    rng = random.Random(s.seed)
    items = []
    for i in range(s.random):
        if i % 97 == 5:
            doc = deep(rng.choice([31, 32, 33]), {'ssn': 1})
        elif i % 89 == 7:
            doc = nested_levels(rng.choice([3, 4, 5]), {'tenant_id': 'b'})
        else:
            doc = gen(rng, rng.randint(1, 6), [60])
        t = enc(doc)
        if rng.random() < 0.02:
            t = t[:-1] if len(t) > 1 else t
        if len(t) > 60000:
            continue
        pol = rng.choice(['med', 'meds', 'wrap', 'med', 'meds'])
        valid = [d for d in DESTS if (d[:7] == 'TENANT:' and 'TENANT:*' in POLICIES[pol]['destinations']) or d in POLICIES[pol]['destinations']]
        items.append((pol, rng.choice(DESTS) if rng.random() < 0.05 else rng.choice(valid), t))
    ans = []
    for i in range(0, len(items), 1000):
        ans += s.batch(items[i:i + 1000])
    bad, codes = [], {}
    for (p, d, t), a in zip(items, ans):
        want = REFS[p].check(p, d, t)
        got = a.stable(drop=('error',))
        codes[a.code] = codes.get(a.code, 0) + 1
        if got[0] != want[0] or {k: v for k, v in got[1].items()} != {k: v for k, v in want[1].items()}:
            bad.append('%s %s %s: engine %r, reference %r' % (p, d, t[:100], a.line[:160], want))
    require(len(items) >= 1000, 'NOT RUN: only %d random documents' % len(items))
    require(len(codes) >= 8, 'NOT RUN: the random documents reached only %d codes: %r' % (len(codes), codes))
    require(not bad, '%d of %d differ: %s' % (len(bad), len(items), ' || '.join(bad[:4])))
    return '%d random documents (seed %d), engine == reference on every code and field; codes %s' % (
        len(items), s.seed, ','.join('%s:%d' % kv for kv in sorted(codes.items())))


CASES = [('policy', case_policy), ('wire', case_wire), ('table', case_table), ('order', case_order), ('leak', case_leak),
         ('limits', case_limits), ('evasions', case_evasions), ('differential', case_differential)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('engine')
    ap.add_argument('--case', action='append', choices=[n for n, _ in CASES])
    ap.add_argument('--work', default=None)
    ap.add_argument('--random', type=int, default=4000)
    ap.add_argument('--seed', type=int, default=20261120)
    ap.add_argument('--keep', action='store_true')
    args = ap.parse_args()
    if not os.access(args.engine, os.X_OK):
        print('cannot start: %s is missing' % args.engine)
        return 2
    work = Path(tempfile.mkdtemp(prefix='pv2-taint-', dir=args.work))
    os.chmod(work, 0o700)
    suite = Suite(Path(args.engine).resolve(), work)
    suite.random, suite.seed = args.random, args.seed
    failed = 0
    for name, fn in CASES:
        if args.case and name not in args.case:
            continue
        t = time.time()
        try:
            detail = fn(suite)
            print('PASS %-13s %6.1fs %s' % (name, time.time() - t, detail), flush=True)
        except Failed as e:
            failed += 1
            print('FAIL %-13s %6.1fs %s' % (name, time.time() - t, str(e).replace('\n', ' ')[:1600]), flush=True)
        except Exception as e:  # noqa: BLE001  (a crash of the suite is a failure, never a pass)
            failed += 1
            print('FAIL %-13s %6.1fs suite error %s: %s' % (name, time.time() - t, type(e).__name__, str(e)[:400]), flush=True)
    if not args.keep:
        shutil.rmtree(work, ignore_errors=True)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
