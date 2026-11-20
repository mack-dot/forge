#!/usr/bin/env python3
"""FINITE TEST of primitive 9, part A (src/primitives_v2/farkas.rs: NATIVE CHECK, not proved). It proves nothing.

Usage: python3 tests/primitives_v2/test_farkas.py <engine> [--case NAME]... [--work DIR] [--dafny-py DIR]
                                                  [--random N] [--seed S]

<engine> is the production build of the primitives engine. --dafny-py names the output folder of
  dafny build --target py src/primitives_v2/dafny/FarkasCert.dfy --output <DIR>/farkas
(the folder that holds FarkasCert.py and _dafny/). Without it, case `differential` builds it itself with the pinned
Dafny (it first waits until no other Dafny process runs: poll 30 s, at most 60 min) and records the command and its
exit code. If no Dafny-compiled predicate is available, `differential` FAILS with NOT RUN.

Case `differential` compares, on every system: (1) the Dafny predicate FarkasCert.Accepts compiled by the pinned
Dafny's Python back end (the compiled code is the Dafny compiler's output: trusted, not proved equal to the source),
(2) the engine, and (3) this file's own big-integer transcription (which can be wrong in the same way as the engine;
it only names the expected refusal reason). Agreement rule: engine INFEASIBILITY_PROVED <=> Accepts; every engine
refusal has Accepts false, except OVERFLOW, which may stand for Accepts true (the engine fails closed on an i128
overflow; the Dafny predicate has unbounded integers). Counted and printed.
A case that cannot run FAILS with NOT RUN. Exit 0: every selected case passed. 1: a case failed. 2: no start.
All timings are indicative (the machine is shared).
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import re
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
DAFNY = '/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/dafny'
DAFNY_CWD = '/Users/mackianni/forge'
SOURCE = ROOT / 'src/primitives_v2/dafny/FarkasCert.dfy'
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}
ANSWER = re.compile(r'^([A-Z][A-Z0-9_]{1,47})((?: [A-Za-z0-9_.:@+-]+=[A-Za-z0-9._~:/@$\[\]+,%-]*)*)(?: -- ([ -~]*))?$')
I64 = (-(1 << 63), (1 << 63) - 1)
EXITS = {'OK': 0, 'MALFORMED_REQUEST': 12, 'CERT_REJECTED': 10, 'SHAPE': 10, 'OVERFLOW': 10, 'MALFORMED_POLICY': 25,
         'CORRUPT_WAL': 17, 'INITIALIZED': 0, 'STATE': 0}


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

    def __repr__(self):
        return self.line[:300]


def doc(A, b, y):
    return json.dumps({'A': A, 'b': b, 'y': y}, separators=(',', ':'))


def canon_system(A, b):
    return '{"A":[%s],"b":[%s]}' % (','.join('[%s]' % ','.join(str(v) for v in r) for r in A), ','.join(str(v) for v in b))


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


class Engine:
    """One `serve` process per batch of lines on a fresh store."""

    def __init__(self, engine, work):
        self.engine, self.work, self.n = engine, Path(work), 0

    def store(self):
        self.n += 1
        d = self.work / ('st-%d' % self.n)
        d.parent.mkdir(parents=True, exist_ok=True)
        os.chmod(d.parent, 0o700)
        p = subprocess.run([self.engine, 'init', str(d)], capture_output=True, env=ENV)
        require(p.returncode == 0, 'init exit %d %r' % (p.returncode, p.stdout))
        return d

    def batch(self, lines, store=None):
        st = store or self.store()
        data = ''.join(l + '\n' for l in lines).encode()
        p = subprocess.run([self.engine, 'serve', str(st)], input=data, capture_output=True, env=ENV, timeout=3600)
        out = p.stdout.decode(errors='replace').split('\n')
        if out and out[-1] == '':
            out.pop()
        require(len(out) == len(lines), 'serve answered %d lines for %d requests (exit %d, stderr %r)'
                % (len(out), len(lines), p.returncode, p.stderr[-300:]))
        return [Answer(x) for x in out], p.returncode, st

    def one(self, line):
        st = self.store()
        p = subprocess.run([self.engine, 'serve', str(st)], input=(line + '\n').encode(), capture_output=True, env=ENV, timeout=600)
        a = Answer(p.stdout.decode(errors='replace').rstrip('\n'))
        require(p.returncode == EXITS.get(a.code, 10), 'exit %d does not match %r' % (p.returncode, a))
        return a


def check_line(A, b, y, rid='c1'):
    return 'DO farkas check %s t1 0 %s' % (rid, doc(A, b, y))


def expect(s, A, b, y, code, **fields):
    a = s.eng.one(check_line(A, b, y))
    require(a.code == code, 'A=%s b=%s y=%s: expected %s, got %r' % (A, b, y, code, a))
    for k, v in fields.items():
        require(a.f.get(k) == str(v), 'A=%s b=%s y=%s: expected %s=%s, got %r' % (A, b, y, k, v, a))
    return a


# ---- the reference transcription (big integers) ------------------------------------------------------------------
def reference(A, b, y):
    """(outcome, field) of the Rust order of checks with UNBOUNDED integers; ('SHAPE', why) for shape faults."""
    m = len(A)
    if not 1 <= m <= 64:
        return 'SHAPE', 'ROWS'
    n = len(A[0])
    if not 1 <= n <= 64:
        return 'SHAPE', 'COLS'
    if any(len(r) != n for r in A):
        return 'SHAPE', 'ROW_LEN'
    if len(b) != m:
        return 'SHAPE', 'B_LEN'
    if len(y) != m:
        return 'SHAPE', 'Y_LEN'
    if any(not I64[0] <= v <= I64[1] for v in [x for r in A for x in r] + b + y):
        return 'SHAPE', 'ENTRY_RANGE'
    for i, v in enumerate(y):
        if v < 0:
            return 'Y_NEGATIVE', i
    for j in range(n):
        if sum(y[i] * A[i][j] for i in range(m)) > 0:
            return 'YTA_POSITIVE', j
    if sum(y[i] * b[i] for i in range(m)) > 0:
        return 'PROVED', None
    return 'YTB_NOT_POSITIVE', None


def overflows(A, b, y):
    """True when a running sum of the engine's order (i128, checked) leaves the i128 range."""
    lo, hi = -(1 << 127), (1 << 127) - 1
    if reference(A, b, y)[0] in ('SHAPE', 'Y_NEGATIVE'):
        return False          # the engine refuses before any sum
    m, n = len(A), len(A[0])
    for col in [[A[i][j] for i in range(m)] for j in range(n)] + [b]:
        s = 0
        for i in range(m):
            s += y[i] * col[i]
            if not lo <= s <= hi:
                return True
        if col is not b and s > 0:
            return False      # the engine stops at the first positive column
    return False


# ---- cases ---------------------------------------------------------------------------------------------------------
def case_witnesses(s):
    A1, B1 = [[1], [-1]], [1, 0]
    expect(s, A1, B1, [1, 1], 'OK', verdict='INFEASIBILITY_PROVED', rows=1 + 1, cols=1, scope='nonneg_integer_x')
    expect(s, A1, B1, [1, 2], 'OK', verdict='INFEASIBILITY_PROVED')
    expect(s, A1, B1, [2, 1], 'CERT_REJECTED', reason='YTA_POSITIVE', col=0, claim='INFEASIBILITY_NOT_PROVED')
    expect(s, A1, B1, [-1, -1], 'CERT_REJECTED', reason='Y_NEGATIVE', row=0)
    expect(s, A1, B1, [0, 1], 'CERT_REJECTED', reason='YTB_NOT_POSITIVE')
    expect(s, A1, B1, [1], 'SHAPE', why='Y_LEN')
    expect(s, A1, B1, [1 << 63, 1 << 63], 'SHAPE', why='ENTRY_RANGE')
    expect(s, [[1]], [1], [1], 'CERT_REJECTED', reason='YTA_POSITIVE')     # feasible system 2
    for y in ([1, 1], [1, 0], [0, 1], [2, 2], [3, 1], [1, 3], [5, 5]):      # system 3: integer-infeasible, no certificate
        a = s.eng.one(check_line([[2], [-2]], [1, -1], y))
        require(a.code == 'CERT_REJECTED', 'system 3 y=%s must be refused: %r' % (y, a))
    return 'the concrete systems of FarkasCertWitness: 2 accepted, 6 refused with their reason, system 3 never accepted'


def case_grammar(s):
    ok = '{"A":[[1],[-1]],"b":[1,0],"y":[1,1]}'
    bad = {
        'FARKAS_JSON': ['{', 'nothing', '{"A":[[01]],"b":[1],"y":[1]}', '{"A":[[1]],"b":[1],"y":[1]} x', ''],
        'FARKAS_KEYS': ['{"A":[[1],[-1]],"b":[1,0]}', '{"A":[[1],[-1]],"b":[1,0],"y":[1,1],"z":1}', '[1]',
                        '{"A":[1],"b":[1],"y":[1]}', '{"A":[[1]],"b":1,"y":[1]}', '{"a":[[1]],"b":[1],"y":[1]}'],
        'FARKAS_NUMBER': ['{"A":[[1.0]],"b":[1],"y":[1]}', '{"A":[[1e0]],"b":[1],"y":[1]}', '{"A":[[-0]],"b":[1],"y":[1]}',
                          '{"A":[["1"]],"b":[1],"y":[1]}', '{"A":[[true]],"b":[1],"y":[1]}',
                          '{"A":[[null]],"b":[1],"y":[1]}'],
    }
    n = 0
    for why, docs in bad.items():
        for text in docs:
            line = 'DO farkas check g1 t1 0 ' + text if text else 'DO farkas check g1 t1 0'
            a = s.eng.one(line)
            require(a.code == 'MALFORMED_REQUEST' and a.f.get('why') == why, '%r: expected MALFORMED_REQUEST why=%s, got %r' % (text, why, a))
            n += 1
    a = s.eng.one('DO farkas check g1 t1 0 {"A":[[1],[-1]],"A":[[1],[-1]],"b":[1,0],"y":[1,1]}')
    require(a.code == 'MALFORMED_REQUEST', 'duplicate key: %r' % a)
    a = s.eng.one('DO farkas check g1 t1 1 k1 * ' + ok)
    require(a.code == 'MALFORMED_REQUEST' and a.f.get('why') == 'KEY_COUNT', 'a key: %r' % a)
    shapes = [([], [], [], 'ROWS'), ([[1]] * 65, [0] * 65, [0] * 65, 'ROWS'), ([[]], [1], [1], 'COLS'),
              ([[1] * 65], [1], [1], 'COLS'), ([[1], [3, 4]], [1, 0], [1, 1], 'ROW_LEN'), ([[1, 2], [3]], [1, 0], [1, 1], 'ROW_LEN'),
              ([[1], [-1]], [1], [1, 1], 'B_LEN'), ([[1], [-1]], [1, 0, 5], [1, 1], 'B_LEN'), ([[1], [-1]], [1, 0], [1, 1, 1], 'Y_LEN'),
              ([[-1], [1]], [1, 0], [1, 1], None)]
    for A, b, y, why in shapes:
        if why is None:
            continue
        a = s.eng.one(check_line(A, b, y))
        require(a.code == 'SHAPE' and a.f.get('why') == why, 'A=%s b=%s y=%s: expected SHAPE why=%s, got %r' % (str(A)[:40], b[:3], y[:3], why, a))
        n += 1
    # A system whose short b would be accepted if the lengths were not compared: rows 2 and 3 forbid nothing.
    a = s.eng.one(check_line([[-1], [0], [0]], [1], [1, 0, 0]))
    require(a.code == 'SHAPE' and a.f.get('why') == 'B_LEN', 'short b: expected SHAPE why=B_LEN, got %r' % a)
    for v, where in (((1 << 63), 'A'), (-(1 << 63) - 1, 'b'), ((1 << 64), 'y')):
        A, b, y = [[-1]], [1], [1]
        {'A': A[0], 'b': b, 'y': y}[where][0] = v
        a = s.eng.one(check_line(A, b, y))
        require(a.code == 'SHAPE' and a.f.get('why') == 'ENTRY_RANGE' and a.f.get('in') == where, '%s=%d: expected SHAPE why=ENTRY_RANGE, got %r' % (where, v, a))
        n += 1
    a = s.eng.one(check_line([[-(1 << 63)]], [(1 << 63) - 1], [1]))
    require(a.code == 'OK', 'the i64 limits are in range: %r' % a)
    return '%d malformed or out-of-shape inputs refused with their reason; the i64 limits accepted' % (n + 3)


def case_digest(s):
    A, b, y = [[1, 0], [-1, -2]], [3, 0], [2, 2]
    a = expect(s, A, b, y, 'OK', verdict='INFEASIBILITY_PROVED')
    require(a.f.get('system_sha256') == sha(canon_system(A, b)), 'system_sha256 is not the SHA-256 of the canonical system: %r' % a)
    require(a.f.get('cert_sha256') == sha('{"y":[%s]}' % ','.join(map(str, y))), 'cert_sha256 is not the SHA-256 of y: %r' % a)
    b2 = [4, 0]       # same A and y, other b: still proved, the system digest must change
    a2 = expect(s, A, b2, y, 'OK', verdict='INFEASIBILITY_PROVED')
    require(a2.f.get('system_sha256') != a.f.get('system_sha256'), 'the system digest is not bound to b: %r / %r' % (a, a2))
    A3 = [[1, 0], [-1, -3]]   # other A: the digest must change
    a3 = expect(s, A3, b, y, 'OK', verdict='INFEASIBILITY_PROVED')
    require(a3.f.get('system_sha256') != a.f.get('system_sha256'), 'the system digest is not bound to A')
    a4 = expect(s, A, b, [3, 3], 'OK', verdict='INFEASIBILITY_PROVED')
    require(a4.f.get('cert_sha256') != a.f.get('cert_sha256') and a4.f.get('system_sha256') == a.f.get('system_sha256'),
            'the certificate digest is not bound to y: %r' % a4)
    spaced = 'DO farkas check d1 t1 0 { "y" : [2, 2], "b" : [3, 0], "A" : [[1, 0], [-1, -2]] }'
    a5 = s.eng.one(spaced)
    require(a5.f.get('system_sha256') == a.f.get('system_sha256'), 'key order and spaces changed the digest: %r' % a5)
    r = expect(s, A, b, [1, 0], 'CERT_REJECTED')
    require(r.f.get('system_sha256') == a.f.get('system_sha256'), 'a refusal carries the system digest: %r' % r)
    return 'system_sha256 = SHA-256 of the canonical system (bound to A and b), cert_sha256 bound to y'


def case_overflow(s):
    M = (1 << 63) - 1
    cases = [
        ([[0], [0], [0]], [-M, -M, -M], [M, M, M], None),           # y.b ~ -1.5 * 2^127: wraps to a positive value
        ([[-M], [-M], [-M]], [1, 1, 1], [M, M, M], 0),              # column sum ~ -1.5 * 2^127
        ([[0, -M], [0, -M], [0, -M]], [1, 1, 1], [M, M, M], 1),     # the second column overflows
    ]
    for A, b, y, col in cases:
        a = s.eng.one(check_line(A, b, y))
        require(a.code == 'OVERFLOW', 'A=%s b=%s y=%s: expected OVERFLOW, got %r' % (A, b, y, a))
        require(a.f.get('claim') == 'INFEASIBILITY_NOT_PROVED' and a.f.get('col') == (None if col is None else str(col)), 'overflow fields: %r' % a)
    a = s.eng.one(check_line([[-M], [-M]], [M, M], [M, M]))   # the largest sums that fit: |sum| < 2^127
    require(a.code == 'OK', 'two products of 2^126 fit in i128: %r' % a)
    return '3 overflowing sums refused with OVERFLOW (never proved); the largest sums that fit are proved'


def case_stateless(s):
    st = s.eng.store()
    good = check_line([[1], [-1]], [1, 0], [1, 1], 'same')
    answers, code, st = s.eng.batch([good] * 5 + [check_line([[1]], [1], [1], 'same')], st)
    require(all(a.code == 'OK' for a in answers[:5]), 'the same request id must be usable again: %r' % answers[:5])
    rep = subprocess.run([s.engine, 'replay', str(st)], capture_output=True, env=ENV)
    require(rep.returncode == 0 and rep.stdout.decode().startswith('REPLAY records=1\n'), 'a check wrote a record: %r' % rep.stdout[:200])
    pol = s.work / 'farkas-policy.json'
    pol.write_text('{"primitive":"farkas","version":1,"name":"f"}')
    p = subprocess.run([s.engine, 'init', str(s.work / 'polstore'), '--policy', str(pol)], capture_output=True, env=ENV)
    require(p.returncode == 25 and p.stdout.startswith(b'MALFORMED_POLICY'), 'a farkas policy file must be refused: %r' % p.stdout)
    return 'six checks: no record (WAL = genesis only), request id stays fresh; a farkas policy file refused at init'


# ---- the differential test ----------------------------------------------------------------------------------------
def slot_busy():
    """A process whose command line names the pinned Dafny, Holmake, hol or z3-4.12.1 holds the slot; a shell, pgrep,
    grep, ps, tail or sleep that merely NAMES the text does not (`pgrep -f 'dafny/dafny'` matched such shells)."""
    p = subprocess.run(['ps', '-ax', '-o', 'pid=,command='], capture_output=True, text=True)
    for line in p.stdout.splitlines():
        pid, _, cmd = line.strip().partition(' ')
        first = os.path.basename(cmd.split(' ', 1)[0]).lstrip('-')
        if not pid.isdigit() or int(pid) == os.getpid() or first in ('sh', 'bash', 'zsh', 'pgrep', 'grep', 'ps', 'tail', 'sleep'):
            continue
        if re.search(r'dafny/dafny|Holmake|/hol |z3-4\.12\.1', cmd):
            return True
    return False


def wait_slot():
    waited = 0
    while slot_busy():
        if waited >= 3600:
            return False
        time.sleep(30)
        waited += 30
    return True


def dafny_py(s):
    if s.args.dafny_py:
        return Path(s.args.dafny_py)
    out = s.work / 'dafny-py'
    if not Path(DAFNY).is_file() or not wait_slot():
        return None
    argv = [DAFNY, 'build', '--target', 'py', str(SOURCE), '--no-verify', '--output', str(out / 'farkas')]
    p = subprocess.run(argv, cwd=DAFNY_CWD, capture_output=True)
    print('  dafny build (cwd %s): %s -> exit %d' % (DAFNY_CWD, ' '.join(argv), p.returncode), flush=True)
    return out / 'farkas-py' if p.returncode == 0 else None


def load_accepts(folder):
    sys.path.insert(0, str(folder))
    import _dafny  # noqa: E402  (the Dafny Python runtime, from the build output)
    import FarkasCert  # noqa: E402  (compiled from src/primitives_v2/dafny/FarkasCert.dfy)

    def accepts(A, b, y):
        S = _dafny.SeqWithoutIsStrInference
        return bool(FarkasCert.default__.CheckCert(S([S(r) for r in A]), S(b), S(y)))
    return accepts


def fix_cert(rnd, A, b, y):
    """Makes (A, b, y) pass every clause except y >= 0, using a row with y_i > 0 (y must have one)."""
    m, n = len(A), len(A[0])
    pos = [i for i in range(m) if y[i] > 0]
    for j in range(n):
        c = sum(y[i] * A[i][j] for i in range(m))
        if c > 0:
            i = rnd.choice(pos)
            A[i][j] -= -(-c // y[i])
    t = sum(y[i] * b[i] for i in range(m))
    if t <= 0:
        i = rnd.choice(pos)
        b[i] += (-t) // y[i] + 1


def systems(rnd, count):
    out = []
    small = lambda: rnd.randint(-9, 9)
    for k in range(count):
        m, n = rnd.choice([1, 1, 2, 2, 3, 4, 5, 8]), rnd.choice([1, 1, 2, 3, 4, 6])
        A = [[small() for _ in range(n)] for _ in range(m)]
        b = [small() for _ in range(m)]
        y = [rnd.randint(0, 5) for _ in range(m)]
        kind = k % 8
        if kind in (1, 2, 3, 4, 5, 6) and m >= 1:
            y[rnd.randrange(m)] = rnd.randint(1, 5)
            fix_cert(rnd, A, b, y)                      # a valid certificate
            if kind == 2:                                # y^T b exactly 0 (needs a row with y_i = 1)
                i = rnd.randrange(m)
                y[i] = 1
                fix_cert(rnd, A, b, y)
                b[i] -= sum(y[r] * b[r] for r in range(m))
            elif kind == 3 and n >= 2:                   # a later column exactly +1 (first column stays fine)
                i = rnd.randrange(m)
                y[i] = 1
                fix_cert(rnd, A, b, y)
                j = rnd.randrange(1, n)
                A[i][j] += 1 - sum(y[r] * A[r][j] for r in range(m))
            elif kind == 4:                              # one column exactly 0
                i = rnd.randrange(m)
                y[i] = 1
                fix_cert(rnd, A, b, y)
                j = rnd.randrange(n)
                A[i][j] -= sum(y[r] * A[r][j] for r in range(m))
            elif kind == 5 and m >= 2:                   # one negative y_i, every other clause holds
                i = rnd.randrange(m)
                others = [r for r in range(m) if r != i]
                y[rnd.choice(others)] = rnd.randint(1, 5)
                y[i] = -rnd.randint(1, 5)
                fix_cert(rnd, A, b, y)
            elif kind == 6:                              # large entries near the i64 limits
                big = rnd.choice([1 << 40, 1 << 62, (1 << 63) - 1])
                A = [[v * big // 9 for v in r] for r in A]
                b = [v * big // 9 for v in b]
                y = [max(v, 0) for v in y]
                if not any(y):
                    y[0] = 1
                fix_cert(rnd, A, b, y)
                A = [[max(I64[0], min(I64[1], v)) for v in r] for r in A]
                b = [max(I64[0], min(I64[1], v)) for v in b]
        out.append((A, b, y))
    # Edge systems: every witness of the Dafny file, sizes at the bounds.
    out += [([[1], [-1]], [1, 0], [1, 1]), ([[1], [-1]], [1, 0], [0, 1]), ([[1]], [1], [1]), ([[2], [-2]], [1, -1], [1, 1]),
            ([[-1] * 64] * 64, [1] * 64, [1] * 64), ([[0] * 64], [1], [1]), ([[0]], [0], [1]), ([[0]], [1], [0])]
    M = (1 << 63) - 1
    out += [([[0], [0], [0]], [-M, -M, -M], [M, M, M]), ([[-M], [-M], [-M]], [1, 1, 1], [M, M, M]),
            ([[0], [0], [0]], [M, M, -M], [M, M, M]), ([[-M]], [M], [M]), ([[1 << 63]], [1], [1]), ([[-1]], [-(1 << 63) - 1], [1]),
            ([[-1], [-1]], [1], [1, 1]), ([[-1]], [1], [1, 1]), ([[-1, 0], [-1]], [1, 1], [1, 1])]
    return out


def case_differential(s):
    folder = dafny_py(s)
    require(folder is not None and (folder / 'FarkasCert.py').is_file(), 'NOT RUN: no Dafny-compiled FarkasCert (pinned Dafny missing, slot not free, or build failed)')
    accepts = load_accepts(folder)
    rnd = random.Random(s.args.seed)
    items = systems(rnd, s.args.random)
    lines = [check_line(A, b, y, 'x%d' % k) for k, (A, b, y) in enumerate(items)]
    answers = []
    for start in range(0, len(lines), 2000):
        part, _, _ = s.eng.batch(lines[start:start + 2000])
        answers += part
    stats = {'proved': 0, 'refused': 0, 'overflow_fail_closed': 0, 'overflow_accepts_true': 0}
    kinds = {}
    for (A, b, y), a in zip(items, answers):
        d = accepts(A, b, y)
        ref, field = reference(A, b, y)
        where = 'A=%s b=%s y=%s' % (str(A)[:120], str(b)[:60], str(y)[:60])
        if a.code == 'OK':
            require(d, '%s: Dafny Accepts=false but engine INFEASIBILITY_PROVED' % where)
            require(ref == 'PROVED', '%s: reference %s but engine proved' % (where, ref))
            stats['proved'] += 1
        elif a.code == 'OVERFLOW':
            require(overflows(A, b, y), '%s: engine OVERFLOW but no i128 overflow in the reference order' % where)
            stats['overflow_accepts_true' if d else 'overflow_fail_closed'] += 1
        else:
            require(not d, '%s: Dafny Accepts=true but engine refused: %r' % (where, a))
            require(not overflows(A, b, y), '%s: the reference order overflows i128 but the engine gave %s' % (where, a.code))
            if a.code == 'SHAPE':
                require(ref == 'SHAPE' and a.f.get('why') == field, '%s: reference %s %s, engine %r' % (where, ref, field, a))
            else:
                require(a.code == 'CERT_REJECTED' and a.f.get('reason') == ref, '%s: reference %s, engine %r' % (where, ref, a))
                if ref == 'Y_NEGATIVE':
                    require(a.f.get('row') == str(field), '%s: row %s, engine %r' % (where, field, a))
                if ref == 'YTA_POSITIVE':
                    require(a.f.get('col') == str(field), '%s: col %s, engine %r' % (where, field, a))
            stats['refused'] += 1
        kinds[a.code if a.code != 'CERT_REJECTED' else a.f.get('reason')] = kinds.get(a.code if a.code != 'CERT_REJECTED' else a.f.get('reason'), 0) + 1
        require('FEASIBLE' not in a.line.replace('INFEASIBILITY', ''), 'an answer says FEASIBLE: %r' % a)
    require(stats['proved'] >= len(items) // 10 and stats['refused'] >= len(items) // 10, 'too few of one class: %r' % stats)
    return '%d systems: Dafny-compiled Accepts and engine agree; %r; by answer %s' % (len(items), stats, sorted(kinds.items()))


CASES = [('witnesses', case_witnesses), ('grammar', case_grammar), ('digest', case_digest), ('overflow', case_overflow),
         ('stateless', case_stateless), ('differential', case_differential)]


class Suite:
    pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('engine')
    ap.add_argument('--case', action='append')
    ap.add_argument('--work')
    ap.add_argument('--dafny-py')
    ap.add_argument('--random', type=int, default=4000)
    ap.add_argument('--seed', type=int, default=20261120)
    args = ap.parse_args()
    if not os.access(args.engine, os.X_OK):
        print('suite error: no engine at %s' % args.engine)
        return 2
    s = Suite()
    s.args, s.engine = args, str(Path(args.engine).resolve())
    s.work = Path(tempfile.mkdtemp(prefix='p9-farkas-', dir=args.work))
    os.chmod(s.work, 0o700)
    s.eng = Engine(s.engine, s.work / 'stores')
    failed = 0
    for name, fn in CASES:
        if args.case and name not in args.case:
            continue
        t = time.time()
        try:
            msg = fn(s)
            print('PASS %-13s %6.1fs %s' % (name, time.time() - t, msg), flush=True)
        except Failed as e:
            failed += 1
            print('FAIL %-13s %6.1fs %s' % (name, time.time() - t, e), flush=True)
        except Exception as e:  # a crash of the suite is a failure, never a pass
            failed += 1
            print('FAIL %-13s %6.1fs suite error: %s: %s' % (name, time.time() - t, type(e).__name__, e), flush=True)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
