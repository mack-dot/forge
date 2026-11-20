#!/usr/bin/env python3
"""FINITE TEST of the primitives engine v2 (src/primitives_v2/). It proves nothing about the engine.

Usage: python3 tests/primitives_v2/test_engine.py <engine> <seams-engine> [--case NAME]... [--big-gib N] [--work DIR]
                                                  [--interposer DYLIB] [--keep]

<engine> is the production build (build/primitives_v2/primitives-engine). <seams-engine> is the `--cfg test_seams`
build (build/primitives_v2_test/primitives-engine-seams); it reads PRIMITIVES_TEST_CLOCK (a file `<wall_ms>
<mono_ms>`) and PRIMITIVES_TEST_PAUSE_AT, and it has the test module `cas_probe`. Cases that need a fixed clock run
on the seams build; case `seams` checks that the production build ignores both variables and has no `cas_probe`.

The suite reads the WAL with its OWN transcription of the record format (zlib CRC-32, hashlib SHA-256); that
transcription and the engine can be wrong in the same way. A SIGKILL is not a power loss. Case `trace` loads the
read-only test interposer tests/airlock/interpose.c (built with /usr/bin/cc into the work folder if --interposer is
absent) to see the F_FULLFSYNC of the WAL before the answer, and to make that sync fail.
All times are indicative: the machine is shared and loaded.
A case that cannot run FAILS with NOT RUN in its message; it never passes.
Exit 0: every selected case passed. 1: at least one failed. 2: the suite could not start.
"""

import argparse
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
import zlib

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
HDR = 68
MAGIC = b'PV2R'
WAL = 'primitives.wal'
MAX_LINE = 65536
U64 = (1 << 64) - 1
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}
EXITS = {'COMMITTED': 0, 'OK': 0, 'STATE': 0, 'INITIALIZED': 0, 'TTL_OPEN': 0, 'USAGE': 2, 'MALFORMED_REQUEST': 12,
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
        require(m is not None, 'answer breaks the wire grammar `CODE k=v... [-- detail]`: %r' % line)
        self.line, self.code, self.detail = line, m.group(1), m.group(3) or ''
        self.f = dict(tok.split('=', 1) for tok in m.group(2).split())

    def __repr__(self):
        return self.line

    def num(self, k):
        """The decimal field k; -1 when it is missing or not a decimal (the caller's check then fails with its text)."""
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
    """Every complete record; raises Failed on any fault (a torn tail is returned as `rest`)."""
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
        out.append({'seq': seq, 'now': now, 'wall': wall, 'payload': rec[HDR:HDR + n].decode(), 'start': i, 'end': i + len(rec)})
        prev = hashlib.sha256(rec).digest()
        i += len(rec)
    return out, data[i:]


def wal_of(store):
    return (Path(store) / WAL).read_bytes()


# ---- processes ----------------------------------------------------------------------------------------------------
class Suite:
    def __init__(self, engine, seams, work, big_gib, interposer):
        self.engine, self.seams, self.work, self.big_gib, self.interposer = engine, seams, Path(work), big_gib, interposer
        self.n = 0

    def folder(self, name):
        self.n += 1
        d = self.work / ('%s-%d' % (name, self.n))
        d.mkdir(mode=0o700)
        return d

    def run(self, engine, *args, env=None, inp=None, timeout=600):
        p = subprocess.run([str(engine)] + [str(a) for a in args], input=inp, capture_output=True, env=env or ENV, timeout=timeout)
        return p.returncode, p.stdout.decode(errors='replace')

    def one(self, engine, *args, env=None, expect=None, why=None):
        code, out = self.run(engine, *args, env=env)
        a = Answer(out.rstrip('\n'))
        require(code == EXITS.get(a.code, 10), 'exit %d does not match the answer %r' % (code, a.line))
        if expect:
            require(a.code == expect, '%s: expected %s, got %r' % (why or args[0], expect, a.line))
        return a

    def policy(self, d, name, **kw):
        body = {'max_ops_per_window': '2', 'max_volume_per_window': '1000', 'window_ms': '1000', 'cooldown_after': '0', 'cooldown_ms': '0'}
        body.update({k: str(v) for k, v in kw.items()})
        text = '{"primitive": "rate_window", "version": 1, "name": "%s", %s}' % (name, ', '.join('"%s": "%s"' % kv for kv in body.items()))
        p = d / ('%s.json' % name)
        p.write_text(text)
        return p

    def store(self, engine, d, policies=(), env=None):
        s = d / 'st'
        args = ['init', s, '--store-id', 'st1']
        for p in policies:
            args += ['--policy', p]
        a = self.one(engine, *args, env=env, expect='INITIALIZED')
        return s, a


class Clock:
    def __init__(self, d, wall, mono=0):
        self.path = d / 'clock'
        self.set(wall, mono)

    def set(self, wall, mono=0):
        tmp = self.path.with_suffix('.tmp')
        tmp.write_text('%d %d\n' % (wall, mono))
        os.replace(tmp, self.path)

    def env(self, **extra):
        return dict(ENV, PRIMITIVES_TEST_CLOCK=str(self.path), **extra)


class Session:
    def __init__(self, engine, store, env=None):
        self.p = subprocess.Popen([str(engine), 'serve', str(store)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, env=env or ENV, bufsize=0)

    def send(self, line):
        self.p.stdin.write(line.encode() + b'\n')

    def read(self, timeout=120):
        buf = b''
        end = time.monotonic() + timeout
        while not buf.endswith(b'\n'):
            left = end - time.monotonic()
            r, _, _ = select.select([self.p.stdout], [], [], max(left, 0))
            if not r:
                return None
            c = self.p.stdout.read(1)
            if not c:
                return None
            buf += c
        return Answer(buf[:-1].decode())

    def ask(self, line, expect=None):
        self.send(line)
        a = self.read()
        require(a is not None, 'no answer to %r' % line)
        if expect:
            require(a.code == expect, '%r: expected %s, got %r' % (line, expect, a.line))
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


def once(engine, st, env, line, expect=None):
    """One request in a new serve process, which then ends (a restart before every request)."""
    ses = Session(engine, st, env)
    try:
        return ses.ask(line, expect)
    finally:
        ses.close()


def acquire(rid, key, vol, policy='api', tenant='t1', h='*'):
    return 'DO rate_window acquire %s %s 1 %s %s %s %s' % (rid, tenant, key, h, policy, vol)


# ---- cases --------------------------------------------------------------------------------------------------------
def case_init(s):
    d = s.folder('init')
    pol = s.policy(d, 'api')
    st, a = s.store(s.engine, d, [pol])
    require(len(a.f['genesis']) == 64 and a.f['build'] == 'production', 'INITIALIZED fields: %r' % a.line)
    require(os.stat(st).st_mode & 0o777 == 0o700, 'store folder mode %o' % (os.stat(st).st_mode & 0o777))
    for f in os.listdir(st):
        require(os.stat(st / f).st_mode & 0o777 == 0o600, 'file %s mode %o' % (f, os.stat(st / f).st_mode & 0o777))
    s.one(s.engine, 'init', st, '--policy', pol, expect='IO_ERROR')
    bad = {'unknown key': '{"primitive":"rate_window","version":1,"name":"x","max_ops_per_window":"1","max_volume_per_window":"1","window_ms":"1","cooldown_after":"0","cooldown_ms":"0","extra":"1"}',
           'version 2': '{"primitive":"rate_window","version":2,"name":"x","max_ops_per_window":"1","max_volume_per_window":"1","window_ms":"1","cooldown_after":"0","cooldown_ms":"0"}',
           'number': '{"primitive":"rate_window","version":1,"name":"x","max_ops_per_window":1,"max_volume_per_window":"1","window_ms":"1","cooldown_after":"0","cooldown_ms":"0"}',
           'zero ops': '{"primitive":"rate_window","version":1,"name":"x","max_ops_per_window":"0","max_volume_per_window":"1","window_ms":"1","cooldown_after":"0","cooldown_ms":"0"}',
           'cooldown 0 ms': '{"primitive":"rate_window","version":1,"name":"x","max_ops_per_window":"1","max_volume_per_window":"1","window_ms":"1","cooldown_after":"2","cooldown_ms":"0"}',
           'u64+1': '{"primitive":"rate_window","version":1,"name":"x","max_ops_per_window":"1","max_volume_per_window":"18446744073709551616","window_ms":"1","cooldown_after":"0","cooldown_ms":"0"}',
           'duplicate key': '{"primitive":"rate_window","primitive":"rate_window","version":1,"name":"x","max_ops_per_window":"1","max_volume_per_window":"1","window_ms":"1","cooldown_after":"0","cooldown_ms":"0"}',
           'stub primitive': '{"primitive":"ledger_graph","version":1,"name":"x"}'}
    for why, text in bad.items():
        p = d / 'bad.json'
        p.write_text(text)
        s.one(s.engine, 'init', d / 'bad', '--policy', p, expect='MALFORMED_POLICY')
        require(not (d / 'bad').exists(), '%s: a refused init left a folder' % why)
        require(not any(x.startswith('bad.init-') for x in os.listdir(d)), '%s: a refused init left a temporary folder' % why)
    s.one(s.engine, 'state', st, expect='STATE')
    os.chmod(st, 0o750)
    a = s.one(s.engine, 'state', st, expect='UNSAFE_STORE', why='folder 0750')
    require(a.f.get('why') == 'FOLDER_MODE', 'folder 0750: %r' % a.line)
    os.chmod(st, 0o700)
    os.chmod(st / WAL, 0o640)
    a = s.one(s.engine, 'state', st, expect='UNSAFE_STORE')
    require(a.f.get('why') == 'FILE_MODE', 'WAL 0640: %r' % a.line)
    os.chmod(st / WAL, 0o600)
    os.chmod(st / 'policy-api.json', 0o604)
    s.one(s.engine, 'state', st, expect='CORRUPT_WAL')
    os.chmod(st / 'policy-api.json', 0o600)
    real = st / 'real.wal'
    os.rename(st / WAL, real)
    os.symlink(real, st / WAL)
    s.one(s.engine, 'state', st, expect='UNSAFE_STORE')
    os.unlink(st / WAL)
    os.rename(real, st / WAL)
    text = (st / 'policy-api.json').read_bytes()
    (st / 'policy-api.json').write_bytes(text.replace(b'"1000"', b'"1001"', 1))
    a = s.one(s.engine, 'state', st, expect='CORRUPT_WAL')
    require(a.f.get('why') == 'POLICY_CHANGED', 'changed policy: %r' % a.line)
    (st / 'policy-api.json').write_bytes(text)
    s.one(s.engine, 'state', st, expect='STATE')
    link = d / 'link'
    os.symlink(st, link)
    s.one(s.engine, 'state', link, expect='UNSAFE_STORE')
    return 'modes 0700/0600, 8 bad policies, folder/file mode, symlinks, policy pin'


def filled_store(s, engine, d, n=5, env=None):
    pol = s.policy(d, 'api', max_ops_per_window=100, window_ms=100000, cooldown_after=2, cooldown_ms=1)
    st, _ = s.store(engine, d, [pol], env=env)
    ses = Session(engine, st, env)
    for i in range(n):
        ses.ask(acquire('r%d' % i, 'k%d' % (i % 2), i + 1), 'COMMITTED')
    require(ses.close() == 0, 'serve exit')
    return st


def case_flip(s):
    d = s.folder('flip')
    st = filled_store(s, s.engine, d)
    good = wal_of(st)
    recs, rest = parse_wal(good)
    require(len(recs) == 6 and rest == b'', 'suite parser: 6 records expected')
    for i in range(len(good)):
        bad = bytearray(good)
        bad[i] ^= 0xff
        (st / WAL).write_bytes(bytes(bad))
        code, out = s.run(s.engine, 'state', st)
        a = Answer(out.strip())
        require(code == 17 and a.code == 'CORRUPT_WAL', 'flip at offset %d of %d was not refused: %r' % (i, len(good), out.strip()))
        require(wal_of(st) == bytes(bad), 'flip at offset %d: the engine changed a refused WAL' % i)
    (st / WAL).write_bytes(good)
    s.one(s.engine, 'state', st, expect='STATE')
    return '%d offsets, each CORRUPT_WAL, file untouched' % len(good)


def case_splice(s):
    d = s.folder('splice')
    st = filled_store(s, s.engine, d)
    good = wal_of(st)
    recs, _ = parse_wal(good)
    r = [good[x['start']:x['end']] for x in recs]
    variants = {
        'removed middle record': b''.join(r[:3] + r[4:]),
        'reordered records': b''.join(r[:2] + [r[3], r[2]] + r[4:]),
        'last record twice': good + r[-1],
        'genesis only twice': r[0] + r[0],
        'no genesis': b''.join(r[1:]),
        'empty file': b'',
    }
    last = recs[-1]
    prev = hashlib.sha256(r[-1]).digest()
    forged = {
        'time goes back': ('E rate_window acquire f1 t1 C 1 k0 | A api 1', last['now'] - 1, last['now'] - 1),
        'wall after engine time': ('E rate_window acquire f1 t1 C 1 k0 | A api 1', last['now'], last['now'] + 1),
        'request id used twice': ('E rate_window acquire r1 t1 C 1 k0 | A api 1', last['now'], last['now']),
        'key of another tenant': ('E rate_window acquire f1 t2 C 1 k0 | A api 1', last['now'], last['now']),
        'keys out of order': ('E rate_window acquire f1 t1 C 2 k1 k0 | A api 1', last['now'], last['now']),
        'unknown primitive': ('E nothing acquire f1 t1 C 1 k9 | A api 1', last['now'], last['now']),
        'stub primitive record': ('E ledger_graph claim f1 t1 C 1 k9 | x', last['now'], last['now']),
        'rejection that fitted': ('E rate_window acquire f1 t1 R 1 k0 | X api 1', last['now'], last['now']),
        'policy mismatch': ('E rate_window acquire f1 t1 C 1 k0 | A other 1', last['now'], last['now']),
        'volume as text': ('E rate_window acquire f1 t1 C 1 k0 | A api 01', last['now'], last['now']),
    }
    for why, (payload, now, wall) in forged.items():
        variants[why] = good + record(len(recs), now, wall, prev, payload.encode())
    ok = record(len(recs), last['now'], last['now'], prev, b'E rate_window acquire f1 t1 C 1 k0 | A api 1')
    (st / WAL).write_bytes(good + ok)
    s.one(s.engine, 'state', st, expect='STATE')  # the suite's own writer makes a record the engine accepts
    for why, data in variants.items():
        (st / WAL).write_bytes(data)
        code, out = s.run(s.engine, 'state', st)
        require(code == 17 and out.startswith('CORRUPT_WAL'), '%s: not refused: %r' % (why, out.strip()))
    # a commit beyond the window cap, forged with a valid chain: the fold re-checks the decision
    d2 = s.folder('splice-cap')
    pol = s.policy(d2, 'api', max_ops_per_window=2, window_ms=100000)
    st2, _ = s.store(s.engine, d2, [pol])
    ses = Session(s.engine, st2)
    ses.ask(acquire('a1', 'k', 1), 'COMMITTED')
    ses.ask(acquire('a2', 'k', 1), 'COMMITTED')
    ses.ask(acquire('a3', 'k', 1), 'RATE_LIMIT_EXCEEDED')
    ses.close()
    data = wal_of(st2)
    recs2, _ = parse_wal(data)
    extra = record(len(recs2), recs2[-1]['now'], recs2[-1]['now'], hashlib.sha256(data[recs2[-1]['start']:]).digest(), b'E rate_window acquire a3 t1 C 1 k | A api 1')
    (st2 / WAL).write_bytes(data + extra)
    code, out = s.run(s.engine, 'state', st2)
    require(code == 17 and 'COMMIT_DID_NOT_FIT' in out, 'forged third commit in a window of 2: not refused: %r' % out.strip())
    return '%d spliced or forged WALs refused, including a forged commit over the cap' % (len(variants) + 1)


def case_torn(s):
    d = s.folder('torn')
    st = filled_store(s, s.engine, d)
    good = wal_of(st)
    recs, _ = parse_wal(good)
    start, end = recs[-1]['start'], recs[-1]['end']
    for cut in range(start + 1, end):
        (st / WAL).write_bytes(good[:cut])
        a = s.one(s.engine, 'state', st, expect='STATE')
        require(a.num('seq') == len(recs) - 2, 'cut at %d: seq %s' % (cut, a.f['seq']))
        require(wal_of(st) == good[:start], 'cut at %d: the torn record was not cut off exactly' % cut)
    ses = Session(s.engine, st)
    ses.ask(acquire('after', 'k0', 1), 'COMMITTED')
    ses.close()
    s.one(s.engine, 'state', st, expect='STATE')
    base = wal_of(st)
    bad_tails = {'garbage': b'XXXX', 'magic, wrong seq': MAGIC + struct.pack('<Q', 99),
                 'full header, bad header check': record(len(parse_wal(base)[0]), 1, 1, b'\0' * 32, b'abc')[:HDR - 1] + b'\0' + b'ab'}
    for why, tail in bad_tails.items():
        (st / WAL).write_bytes(base + tail)
        code, out = s.run(s.engine, 'state', st)
        require(code == 17, '%s tail: not refused: %r' % (why, out.strip()))
        require(wal_of(st) == base + tail, '%s tail: the engine changed a refused WAL' % why)
    return 'torn tails cut at %d lengths; 3 non-record tails refused' % (end - start - 1)


def case_lock(s):
    d = s.folder('lock')
    clock = Clock(d, 1000000)
    pol = s.policy(d, 'api', max_ops_per_window=100)
    st, _ = s.store(s.seams, d, [pol], env=clock.env())
    holder = Session(s.seams, st, clock.env(PRIMITIVES_TEST_PAUSE_AT='locked'))
    holder.send(acquire('h1', 'k', 1))
    line = b''
    end = time.monotonic() + 60
    while not line.endswith(b'\n') and time.monotonic() < end:
        r, _, _ = select.select([holder.p.stderr], [], [], 1)
        if r:
            c = holder.p.stderr.read(1)
            if not c:
                break
            line += c
    require(line == b'AT locked\n', 'NOT RUN: the holder did not reach the pause point: %r' % line)
    other = Session(s.seams, st, clock.env())
    other.send(acquire('o1', 'k', 1))
    waited = other.read(timeout=2)
    require(waited is None, 'a second process answered while the first held the lock: %r' % waited)
    holder.kill()
    a = other.read(timeout=120)
    require(a is not None and a.code == 'COMMITTED' and a.num('seq') == 1, 'after the holder died: %r' % a)
    other.close()
    prod = Session(s.engine, s.store(s.engine, s.folder('lock-prod'), [pol])[0], dict(ENV, PRIMITIVES_TEST_PAUSE_AT='locked'))
    a = prod.ask(acquire('p1', 'k', 1))
    require(a.code == 'COMMITTED', 'the production build paused or failed with PRIMITIVES_TEST_PAUSE_AT: %r' % a)
    prod.close()
    return 'second process waited while the lock was held; production ignores the pause seam'


def burst(engine, st, lines, env=None):
    procs = [subprocess.Popen([str(engine), 'serve', str(st)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env or ENV) for _ in lines]
    for p, line in zip(procs, lines):
        p.stdin.write(line.encode() + b'\n')
        p.stdin.flush()
    outs = []
    for p in procs:
        out, _ = p.communicate(timeout=600)
        outs.append(Answer(out.decode().strip()))
    return outs


def case_race(s):
    d = s.folder('race')
    pol = s.policy(d, 'api', max_ops_per_window=1000, window_ms=1000000)
    st, _ = s.store(s.engine, d, [pol])
    a = s.one(s.engine, 'get', st, 't1', 'k', expect='OK')
    h = a.f['hash']
    outs = burst(s.engine, st, [acquire('c%d' % i, 'k', 1, h=h) for i in range(50)])
    codes = sorted(o.code for o in outs)
    require(codes.count('COMMITTED') == 1 and codes.count('STALE_STATE_HASH') == 49, 'CAS race of 50: %r' % {c: codes.count(c) for c in set(codes)})
    outs = burst(s.engine, st, [acquire('same', 'k', 1) for _ in range(50)])
    codes = sorted(o.code for o in outs)
    require(codes.count('COMMITTED') == 1 and codes.count('DUPLICATE_REQUEST_ID') == 49, 'duplicate-id race of 50: %r' % {c: codes.count(c) for c in set(codes)})
    recs, rest = parse_wal(wal_of(st))
    ids = [r['payload'].split(' ')[3] for r in recs[1:]]
    require(len(recs) == 3 and rest == b'' and len(set(ids)) == len(ids), 'WAL after the races: %d records' % len(recs))
    return '50-process CAS race: 1 commit, 49 stale; 50-process id race: 1 commit, 49 duplicate'


def case_multikey(s):
    d = s.folder('multikey')
    clock = Clock(d, 5000)
    env = clock.env()
    pol = s.policy(d, 'api')
    st, init = s.store(s.seams, d, [pol], env=env)
    g = init.f['genesis']
    ses = Session(s.seams, st, env)
    a = ses.ask('DO cas_probe put p1 t1 3 a %s b %s c %s 7' % (g, g, g), 'COMMITTED')
    h = a.f['hash.a']
    require(a.f['hash.b'] == h == a.f['hash.c'], 'one record must set the hash of all keys: %r' % a)
    recs, _ = parse_wal(wal_of(st))
    require(h == hashlib.sha256(wal_of(st)[recs[-1]['start']:recs[-1]['end']]).hexdigest(), 'the state hash is not the SHA-256 of the record')
    for k in 'abc':
        g2 = ses.ask('GET t1 %s' % k, 'OK')
        require(g2.f['hash'] == h and g2.f['value'] == '7', 'GET %s: %r' % (k, g2))
    a = ses.ask('DO cas_probe put p2 t1 2 a %s b %s 8' % (h, g), 'STALE_STATE_HASH')
    require(a.f['stale'] == '1' and a.f['hash.b'] == h and 'hash.a' not in a.f, 'stale answer: %r' % a)
    a = ses.ask('DO cas_probe put p2 t1 3 a %s b %s c %s 8' % (h, g, h), 'STALE_STATE_HASH')
    require(len(parse_wal(wal_of(st))[0]) == 2, 'a refused multi-key request wrote a record')
    ses.ask('DO cas_probe put p3 t1 2 b %s a %s 8' % (h, h), 'MALFORMED_REQUEST')
    ses.ask('DO cas_probe put p3 t1 2 a %s a %s 8' % (h, h), 'MALFORMED_REQUEST')
    ses.ask('DO cas_probe put p3 t1 2 a * b * 8', 'MALFORMED_REQUEST')
    ses.ask('DO cas_probe put x1 t2 1 z %s 1' % g, 'COMMITTED')
    a = ses.ask('DO cas_probe put p4 t1 2 a %s z %s 9' % (h, g), 'TENANT_ISOLATION_BREACH')
    ses.ask('GET t1 z', 'TENANT_ISOLATION_BREACH')
    ses.ask(acquire('q1', 'rk', 1), 'COMMITTED')
    a = ses.ask('GET t1 rk', 'OK')
    a = ses.ask('DO cas_probe put p5 t1 2 a %s rk %s 9' % (h, a.f['hash']), 'MALFORMED_REQUEST')
    require(a.f['why'] == 'KEY_KIND', 'a key of another primitive: %r' % a)
    a = ses.ask('DO cas_probe put p6 t1 3 a %s b %s c %s 9' % (h, h, h), 'COMMITTED')
    require(a.f['hash.a'] == a.f['hash.b'] == a.f['hash.c'] != h, 'second multi-key commit: %r' % a)
    ses.close()
    s.one(s.engine, 'state', s.store(s.engine, s.folder('mk-prod'), [pol])[0], expect='STATE')
    a = Answer(s.run(s.engine, 'serve', s.store(s.engine, s.folder('mk-prod2'), [pol])[0], inp=('DO cas_probe put p1 t1 1 a %s 1\n' % g).encode())[1].strip())
    require(a.code == 'MALFORMED_REQUEST' and a.f['why'] == 'UNKNOWN_PRIMITIVE', 'the production build knows cas_probe: %r' % a)
    return 'one record for 3 keys; stale/order/duplicate/*/tenant/kind refuse all keys; production has no cas_probe'


def case_lines(s):
    d = s.folder('lines')
    pol = s.policy(d, 'api', max_ops_per_window=100, window_ms=100000)
    st, _ = s.store(s.engine, d, [pol])
    ses = Session(s.engine, st)
    for line, why in [('DO  rate_window', 'SPACING'), (' STATE', 'SPACING'), ('STATE ', 'SPACING'), ('STATE\tx', 'NON_ASCII'),
                      ('NOPE', 'UNKNOWN_VERB'), ('DO rate_window acquire r t 1 k * api 1 ', 'SPACING'),
                      ('DO rate_window acquire r t 1 k ABC api 1', 'BAD_HASH'), ('DO rate_window acquire r t 17 k * api 1', 'KEY_COUNT'),
                      ('DO rate_window acquire r t 2 k * l * api 1', 'KEY_COUNT'), ('DO rate_window acquire r-toolong-0123456789abcdef t 1 k * api 1', 'BAD_REQUEST_ID'),
                      ('DO rate_window acquire r t 1 k=1 * api 1', 'BAD_KEY'), ('DO rate_window grab r t 1 k * api 1', 'UNKNOWN_OP'),
                      ('DO rate_window acquire r t 1 k * api 1 5', 'RATE_ARGS'), ('DO rate_window acquire r t 1 k * api 01', 'RATE_ARGS'),
                      ('GET t1 k extra', 'FIELDS')]:
        a = ses.ask(line, 'MALFORMED_REQUEST')
        require(a.f['why'] == why, '%r: expected why=%s, got %r' % (line, why, a))
    ses.p.stdin.write(b'STATE\xff\n')
    require(ses.read().f['why'] == 'NON_ASCII', 'a non-ASCII byte')
    ses.ask('DO rate_window acquire r1 t1 1 k * api ' + '9' * 2, 'COMMITTED')
    exact = 'DO rate_window acquire r2 t1 1 k * api 1 ' + 'x' * (MAX_LINE - len('DO rate_window acquire r2 t1 1 k * api 1 '))
    require(len(exact) == MAX_LINE, 'suite: exact line length')
    a = ses.ask(exact, 'MALFORMED_REQUEST')
    require(a.f['why'] == 'RATE_ARGS', 'a line of exactly MAX_LINE bytes must be read as a line: %r' % a)
    a = ses.ask(exact + 'x', 'MALFORMED_REQUEST')
    require(a.f['why'] == 'OVERSIZED', 'MAX_LINE + 1: %r' % a)
    a = ses.ask('STATE')
    require(a.code == 'STATE', 'after an oversized line, the next line was not read as itself: %r' % a)
    ses.close()
    # The big line: N GiB of one line, then a valid request. RSS of the engine is sampled with ps.
    size = int(s.big_gib * (1 << 30))
    p = subprocess.Popen([str(s.engine), 'serve', str(st)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=ENV)
    peak, stop = [0], threading.Event()

    def sample():
        while not stop.is_set():
            out = subprocess.run(['/bin/ps', '-o', 'rss=', '-p', str(p.pid)], capture_output=True, text=True).stdout.strip()
            if out.isdigit():
                peak[0] = max(peak[0], int(out))
            time.sleep(0.2)
    t = threading.Thread(target=sample)
    t.start()
    chunk, sent, t0 = b'A' * (1 << 20), 0, time.monotonic()
    try:
        while sent < size:
            n = min(len(chunk), size - sent)
            p.stdin.write(chunk[:n])
            sent += n
        p.stdin.write(b'\n' + acquire('after-big', 'k', 1).encode() + b'\nSTATE\n')
        p.stdin.close()
        out = p.stdout.read()
        p.wait(timeout=3600)
    finally:
        stop.set()
        t.join()
    secs = time.monotonic() - t0
    got = [Answer(x) for x in out.decode().splitlines()]
    require(len(got) == 3 and got[0].code == 'MALFORMED_REQUEST' and got[0].f['why'] == 'OVERSIZED' and got[1].code == 'COMMITTED',
            'answers after a %d-byte line: %r' % (size, got[:4]))
    require(0 < peak[0] < 32 * 1024, 'engine RSS peak %d KiB during the big line (bound 32768 KiB)' % peak[0])
    noend = subprocess.run([str(s.engine), 'serve', str(st)], input=b'STATE', capture_output=True, env=ENV)
    require(Answer(noend.stdout.decode().strip()).f.get('why') == 'NO_LINE_END', 'bytes with no LF at EOF')
    return '15 grammar faults; MAX_LINE exact/+1; %.2f GiB line: RSS peak %d KiB, %.0f s (indicative)' % (s.big_gib, peak[0], secs)


def case_seams(s):
    d = s.folder('seams')
    clock = Clock(d, 5)
    pol = s.policy(d, 'api')
    st, a = s.store(s.engine, d, [pol], env=clock.env())
    real = int(time.time() * 1000)
    require(abs(a.num('now_ms') - real) < 600000, 'production init took the seam clock: %r' % a)
    code, out = s.run(s.engine, 'serve', st, env=clock.env(), inp=(acquire('s1', 'k', 1) + '\n').encode())
    a = Answer(out.strip())
    require(a.code == 'COMMITTED' and abs(a.num('now_ms') - real) < 600000, 'production took PRIMITIVES_TEST_CLOCK: %r' % a)
    recs, _ = parse_wal(wal_of(st))
    require(all(abs(r['now'] - real) < 600000 for r in recs), 'production WAL times are not real times')
    s2, _ = s.store(s.seams, s.folder('seams-test'), [pol], env=clock.env())
    a = s.one(s.engine, 'state', s2, expect='CORRUPT_WAL', why='production opened a test-seams store')
    require(a.f['why'] == 'BUILD_MISMATCH', 'production opened a test-seams store: %r' % a)
    a = s.one(s.seams, 'state', st, env=clock.env(), expect='CORRUPT_WAL', why='test-seams build opened a production store')
    require(a.f['why'] == 'BUILD_MISMATCH', 'test-seams build opened a production store: %r' % a)
    a = s.one(s.seams, 'state', s2, env=clock.env(), expect='STATE')
    require(a.num('now_ms') == 5, 'seam build did not take the seam clock: %r' % a)
    return 'production ignores PRIMITIVES_TEST_CLOCK; each build refuses the other build\'s store'


def case_clock_setback(s):
    d = s.folder('setback')
    clock = Clock(d, 1000000)
    env = clock.env()
    pol = s.policy(d, 'api', max_ops_per_window=2, window_ms=1000)
    st, _ = s.store(s.seams, d, [pol], env=env)
    for rid in ('a1', 'a2'):
        once(s.seams, st, env, acquire(rid, 'k', 1), 'COMMITTED')
    clock.set(500000)
    ses = Session(s.seams, st, env)
    a = ses.ask(acquire('b1', 'k', 1), 'RATE_LIMIT_EXCEEDED')
    require(a.num('now_ms') == 1000000 and a.num('retry_after_ms') == 1000 and a.num('skew_ms') == 500000, 'clock set back 500 s: %r' % a)
    a = ses.ask('STATE', 'STATE')
    require(a.num('skew_ms') == 500000 and a.num('wall_ms') == 500000 and a.num('now_ms') == 1000000, 'STATE with a clock set back: %r' % a)
    ses.close()
    clock.set(0)
    a = once(s.seams, st, env, acquire('b2', 'k', 1), 'RATE_LIMIT_EXCEEDED')
    require(a.num('retry_after_ms') == 1000, 'clock set back to 0 in a new process: %r' % a)
    clock.set(1000999)
    a = once(s.seams, st, env, acquire('b3', 'k', 1), 'RATE_LIMIT_EXCEEDED')
    require(a.num('retry_after_ms') == 1, 'at +999: %r' % a)
    clock.set(1001000)
    once(s.seams, st, env, acquire('b4', 'k', 1), 'COMMITTED')
    # Monotonic floor inside ONE process: the wall clock goes back to 0, the monotonic clock goes on.
    clock.set(2000000, 0)
    ses = Session(s.seams, st, env)
    ses.ask(acquire('m1', 'm', 1), 'COMMITTED')
    ses.ask(acquire('m2', 'm', 1), 'COMMITTED')
    clock.set(0, 999)
    a = ses.ask(acquire('m3', 'm', 1), 'RATE_LIMIT_EXCEEDED')
    require(a.num('now_ms') == 2000999 and a.num('retry_after_ms') == 1, 'monotonic floor after 999 ms: %r' % a)
    clock.set(0, 1000)
    a = ses.ask(acquire('m4', 'm', 1), 'COMMITTED')
    require(a.num('now_ms') == 2001000 and a.num('skew_ms') == 2001000, 'monotonic floor after 1000 ms: %r' % a)
    ses.close()
    clock.set(0, 50000)
    a = once(s.seams, st, env, 'STATE', 'STATE')
    require(a.num('now_ms') == 2001000, 'a monotonic reading must not carry into a new process: %r' % a)
    recs, _ = parse_wal(wal_of(st))
    times = [r['now'] for r in recs]
    require(times == sorted(times) and all(r['wall'] <= r['now'] for r in recs), 'WAL times: %r' % times)
    require(recs[-1]['wall'] == 0 and recs[-1]['now'] == 2001000, 'the record keeps the raw wall reading and the engine time')
    return 'set back 500 s and to 0: no window reopens; skew reported; monotonic floor in one process only'


def case_clock_request(s):
    d = s.folder('creq')
    clock = Clock(d, 1000000)
    env = clock.env()
    pol = s.policy(d, 'api', max_ops_per_window=1, window_ms=1000)
    st, _ = s.store(s.seams, d, [pol], env=env)
    ses = Session(s.seams, st, env)
    ses.ask(acquire('a1', 'k', 1), 'COMMITTED')
    for extra in ('99999999999', 'now_ms=99999999999', '1000000 1000'):
        a = ses.ask(acquire('a2', 'k', 1) + ' ' + extra)
        require(a.code == 'MALFORMED_REQUEST', 'a request field was taken as a time (%r): %r' % (extra, a))
    a = ses.ask(acquire('a3', 'k', 1), 'RATE_LIMIT_EXCEEDED')
    require(a.num('now_ms') == 1000000, 'now_ms: %r' % a)
    ses.close()
    return 'time-like request fields are refused; the engine time stays the clock'


def rate_store(s, name, **kw):
    d = s.folder(name)
    clock = Clock(d, kw.pop('wall', 10000000))
    pol = s.policy(d, 'api', **kw)
    st, _ = s.store(s.seams, d, [pol], env=clock.env())
    return d, clock, st


def case_boundary(s):
    d, clock, st = rate_store(s, 'boundary', max_ops_per_window=2, window_ms=1000)
    env = clock.env()
    T = 10000000
    ses = Session(s.seams, st, env)
    seq = []

    def at(t, rid, code):
        clock.set(t)
        a = ses.ask(acquire(rid, 'k', 1), code)
        seq.append(a)
        return a
    at(T, 'a1', 'COMMITTED')
    at(T + 300, 'a2', 'COMMITTED')
    a = at(T + 999, 'a3', 'RATE_LIMIT_EXCEEDED')
    require(a.num('retry_after_ms') == 1, 'at T+999: %r' % a)
    at(T + 1000, 'a4', 'COMMITTED')
    a = at(T + 1299, 'a5', 'RATE_LIMIT_EXCEEDED')
    require(a.num('retry_after_ms') == 1, 'at T+1299: %r' % a)
    at(T + 1300, 'a6', 'COMMITTED')
    # n-1 / n on many schedules (volumes too): the retry at now+n-1 is refused with retry 1, at now+n it commits.
    rnd = random.Random(20261120)
    checked = 0
    for trial in range(12):
        d2, c2, st2 = rate_store(s, 'nn%d' % trial, max_ops_per_window=rnd.randint(1, 4), max_volume_per_window=100, window_ms=rnd.randint(1, 5000))
        e2 = c2.env()
        ses2 = Session(s.seams, st2, e2)
        t, i = 10000000, 0
        while checked < (trial + 1) * 3:
            i += 1
            t += rnd.randint(0, 700)
            c2.set(t)
            vol = rnd.randint(1, 60)
            a = ses2.ask(acquire('x%d' % i, 'k', vol))
            if a.code == 'COMMITTED':
                continue
            require(a.code == 'RATE_LIMIT_EXCEEDED', 'n/n-1 trial %d: %r' % (trial, a))
            n = a.num('retry_after_ms')
            c2.set(t + n - 1)
            b = ses2.ask(acquire('y%d' % i, 'k', vol))
            require(b.code == 'RATE_LIMIT_EXCEEDED' and b.num('retry_after_ms') == 1, 'trial %d: the retry at n-1=%d was not refused with retry 1: %r' % (trial, n - 1, b))
            c2.set(t + n)
            ses2.ask(acquire('z%d' % i, 'k', vol), 'COMMITTED')
            t += n
            checked += 1
        ses2.close()
    ses.close()
    return 'exact expiry at window_ms; %d random n-1/n retries (ops and volume)' % checked


def case_volume(s):
    d, clock, st = rate_store(s, 'volume', max_ops_per_window=10, max_volume_per_window=100, window_ms=1000)
    T = 10000000
    ses = Session(s.seams, st, clock.env())
    for i, (dt, v) in enumerate([(0, 30), (100, 30), (200, 30)]):
        clock.set(T + dt)
        ses.ask(acquire('v%d' % i, 'k', v), 'COMMITTED')
    clock.set(T + 300)
    a = ses.ask(acquire('w1', 'k', 40), 'RATE_LIMIT_EXCEEDED')
    require(a.num('retry_after_ms') == 700, 'volume 40 needs the first event gone (T+1000): %r' % a)
    a = ses.ask(acquire('w2', 'k', 80), 'RATE_LIMIT_EXCEEDED')
    require(a.num('retry_after_ms') == 900, 'volume 80 needs all three gone (T+1200): %r' % a)
    ses.ask(acquire('w3', 'k', 10), 'COMMITTED')
    seq = ses.ask('GET t1 k', 'OK')
    a = ses.ask(acquire('w4', 'k', 101), 'VOLUME_ABOVE_CAP')
    require(ses.ask('GET t1 k', 'OK').f['hash'] == seq.f['hash'], 'VOLUME_ABOVE_CAP wrote a record')
    require(seq.f['volume'] == '100' and seq.f['ops'] == '4', 'GET fields: %r' % seq)
    clock.set(T + 1000)
    ses.ask(acquire('w5', 'k', 30), 'COMMITTED')
    ses.close()
    return 'volume cap with multi-event retry; VOLUME_ABOVE_CAP writes nothing'


def case_cooldown(s):
    d, clock, st = rate_store(s, 'cooldown', max_ops_per_window=1, window_ms=10000, cooldown_after=3, cooldown_ms=5000)
    T = 10000000
    ses = Session(s.seams, st, clock.env())
    clock.set(T)
    ses.ask(acquire('c0', 'k', 1), 'COMMITTED')
    for i in (1, 2, 3):
        clock.set(T + i)
        a = ses.ask(acquire('c%d' % i, 'k', 1), 'RATE_LIMIT_EXCEEDED')
        require(a.f.get('seq') == str(1 + i), 'rejection %d must be a durable record: %r' % (i, a))
    n_before = len(parse_wal(wal_of(st))[0])
    clock.set(T + 4)
    a = ses.ask(acquire('d1', 'k', 1), 'COOLDOWN_ACTIVE')
    require(a.num('retry_after_ms') == 4999, 'cooldown retry: %r' % a)
    for i in range(100):
        ses.ask(acquire('e%d' % i, 'k', 1), 'COOLDOWN_ACTIVE')
    require(len(parse_wal(wal_of(st))[0]) == n_before, 'refusals during a cooldown grew the WAL')
    ses.close()
    clock.set(T + 5002)
    a = once(s.seams, st, clock.env(), acquire('d2', 'k', 1), 'COOLDOWN_ACTIVE')
    require(a.num('retry_after_ms') == 1, 'restart before the cooldown end: %r' % a)
    clock.set(T + 5003)
    a = once(s.seams, st, clock.env(), acquire('d3', 'k', 1), 'RATE_LIMIT_EXCEEDED')
    require(a.num('retry_after_ms') == 4997, 'after the cooldown: %r' % a)
    ses = Session(s.seams, st, clock.env())
    g = ses.ask('GET t1 k', 'OK')
    require(g.f['rejections'] == '1' and g.f['cooldown_ms_left'] == '0', 'GET after the cooldown: %r' % g)
    clock.set(T + 10000)
    ses.ask(acquire('d4', 'k', 1), 'COMMITTED')
    require(ses.ask('GET t1 k', 'OK').f['rejections'] == '0', 'a commit resets the count')
    ses.close()
    # no cooldown: a refusal writes nothing; a fresh key that can never fit writes nothing
    d2, c2, st2 = rate_store(s, 'nocool', max_ops_per_window=1, window_ms=10000)
    ses = Session(s.seams, st2, c2.env())
    ses.ask(acquire('n0', 'k', 1), 'COMMITTED')
    for i in range(50):
        ses.ask(acquire('n%d' % (i + 1), 'k', 1), 'RATE_LIMIT_EXCEEDED')
        ses.ask(acquire('f%d' % i, 'fresh%d' % i, 5000), 'VOLUME_ABOVE_CAP')
    ses.close()
    require(len(parse_wal(wal_of(st2))[0]) == 2, 'refusal-only traffic grew the WAL without a cooldown')
    return 'cooldown after 3 durable rejections, exact expiry across restarts, 0 records during cooldown'


SCRIPT = [(0, 'k', 1), (10, 'k', 1), (20, 'k', 1), (30, 'k', 1), (40, 'j', 5), (500, 'k', 1), (2000, 'k', 1),
          (2001, 'k', 1), (2002, 'k', 1), (2003, 'k', 1), (2500, 'k', 1), (3999, 'k', 1), (4000, 'k', 1), (7003, 'k', 1),
          (7004, 'k', 1), (9000, 'k', 1), (9001, 'j', 96), (9002, 'j', 95)]


def strip(a):
    return (a.code, tuple(sorted((k, v) for k, v in a.f.items() if not k.startswith('hash.'))))


def case_restart(s):
    results = []
    for mode in ('one process', 'process per request'):
        d, clock, st = rate_store(s, 'restart', max_ops_per_window=2, max_volume_per_window=100, window_ms=1000, cooldown_after=2, cooldown_ms=3000)
        T = 10000000
        ses = Session(s.seams, st, clock.env()) if mode == 'one process' else None
        out = []
        for i, (dt, k, v) in enumerate(SCRIPT):
            clock.set(T + dt, 0)
            if ses:
                out.append(strip(ses.ask(acquire('r%d' % i, k, v))))
            else:
                one = Session(s.seams, st, clock.env())
                out.append(strip(one.ask(acquire('r%d' % i, k, v))))
                one.kill()  # SIGKILL after each answer
        if ses:
            ses.close()
        results.append(out)
    require(results[0] == results[1], 'answers differ after restarts:\n%r\n%r' % (results[0], results[1]))
    codes = [r[0] for r in results[0]]
    require('COOLDOWN_ACTIVE' in codes and 'RATE_LIMIT_EXCEEDED' in codes and 'COMMITTED' in codes, 'script covers too little: %r' % codes)
    return '%d answers equal with one process and with a SIGKILLed process per request' % len(SCRIPT)


def case_kill9(s):
    d = s.folder('kill9')
    W, CAP = 300, 5
    pol = s.policy(d, 'api', max_ops_per_window=CAP, max_volume_per_window=1000, window_ms=W, cooldown_after=2, cooldown_ms=100)
    st, _ = s.store(s.engine, d, [pol])
    rnd = random.Random(9)
    answered = []
    for rnd_no in range(4):
        procs = []
        for pno in range(3):
            p = subprocess.Popen([str(s.engine), 'serve', str(st)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=ENV, bufsize=0)
            procs.append(p)

            def feed(p=p, tag='%d-%d' % (rnd_no, pno)):
                try:
                    for i in range(100000):
                        p.stdin.write((acquire('q%s-%d' % (tag, i), 'k%d' % (i % 2), 1) + '\n').encode())
                except OSError:
                    pass

            def collect(p=p):
                for line in iter(p.stdout.readline, b''):
                    answered.append(line.decode().strip())
            threading.Thread(target=feed, daemon=True).start()
            threading.Thread(target=collect, daemon=True).start()
        time.sleep(rnd.uniform(0.3, 1.5))
        for p in procs:
            p.send_signal(signal.SIGKILL)
        for p in procs:
            p.wait()
        time.sleep(0.2)
    a = s.one(s.engine, 'state', st, expect='STATE')
    recs, rest = parse_wal(wal_of(st))
    require(rest == b'', 'state must have cut any torn tail')
    commits = {}
    rejections = {}
    for r in recs[1:]:
        t = r['payload'].split(' ')
        (commits if t[5] == 'C' else rejections).setdefault(t[7], []).append(r['now'])
    worst = 0
    for k, times in commits.items():
        lo = 0
        for hi in range(len(times)):
            while times[lo] + W <= times[hi]:
                lo += 1
            worst = max(worst, hi - lo + 1)
    require(worst <= CAP, 'a window of %d ms holds %d commits (cap %d) by the WAL times' % (W, worst, CAP))
    ids = set(r['payload'].split(' ')[3] for r in recs[1:])
    got = [Answer(x) for x in answered if x]
    lost = [x for x in got if x.code in ('COMMITTED', 'RATE_LIMIT_EXCEEDED') and 'seq' in x.f and x.f['request_id'] not in ids]
    require(not lost, 'answered records missing from the WAL: %r' % lost[:3])
    require(sum(len(v) for v in commits.values()) > CAP, 'NOT RUN: too few commits to test (%d)' % sum(len(v) for v in commits.values()))
    ncommit = sum(len(v) for v in commits.values())
    return '%d records, %d commits, worst window %d <= %d by WAL times; %d answers all in the WAL' % (len(recs), ncommit, worst, CAP, len(got))


def case_u64(s):
    M = str(U64)
    d, clock, st = rate_store(s, 'u64', max_ops_per_window=3, max_volume_per_window=M, window_ms=M, cooldown_after=1, cooldown_ms=M)
    ses = Session(s.seams, st, clock.env())
    ses.ask(acquire('u1', 'k', M), 'COMMITTED')
    a = ses.ask(acquire('u2', 'k', 1), 'RATE_LIMIT_EXCEEDED')
    require(a.f['retry_after_ms'] == 'never', 'an event that never expires: %r' % a)
    a = ses.ask(acquire('u3', 'k', 1), 'COOLDOWN_ACTIVE')
    require(a.num('retry_after_ms') == U64 - 10000000, 'saturated cooldown: %r' % a)
    ses.ask(acquire('u4', 'j', str(U64 + 1)), 'MALFORMED_REQUEST')
    ses.ask(acquire('u5', 'j', '0'), 'COMMITTED')
    ses.ask(acquire('u6', 'j', M), 'COMMITTED')
    ses.close()
    d2, c2, st2 = rate_store(s, 'u64b', wall=U64 - 500, max_ops_per_window=1, window_ms=1000)
    ses = Session(s.seams, st2, c2.env())
    ses.ask(acquire('w1', 'k', 1), 'COMMITTED')
    c2.set(U64)
    a = ses.ask(acquire('w2', 'k', 1), 'RATE_LIMIT_EXCEEDED')
    require(a.f['retry_after_ms'] == 'never' and a.num('now_ms') == U64, 'expiry past u64::MAX: %r' % a)
    ses.close()
    s.one(s.seams, 'state', st2, env=c2.env(), expect='STATE')
    return 'u64::MAX volume, window and cooldown; expiry overflow gives never; 2^64 refused'


def case_cosign_ttl(s):
    d, clock, st = rate_store(s, 'ttl', wall=1000)
    env = clock.env()
    a = s.one(s.seams, 'cosign-ttl', st, 1000, 5000, env=env, expect='TTL_OPEN')
    require(a.f['left_ms'] == '0' and a.f['signature'] == 'NOT_CHECKED', 'not_after == now: %r' % a)
    a = s.one(s.seams, 'cosign-ttl', st, 999, 5000, env=env, expect='COSIGN_EXPIRED')
    require(a.f['expired_by_ms'] == '1', 'one ms late: %r' % a)
    s.one(s.seams, 'cosign-ttl', st, 6001, 5000, env=env, expect='COSIGN_TTL_TOO_LONG')
    s.one(s.seams, 'cosign-ttl', st, 6000, 5000, env=env, expect='TTL_OPEN')
    clock.set(2000)
    once(s.seams, st, env, acquire('t1', 'k', 1), 'COMMITTED')
    clock.set(500)
    a = s.one(s.seams, 'cosign-ttl', st, 1500, 5000, env=env, expect='COSIGN_EXPIRED', why='a clock set back revived a token')
    require(a.f['expired_by_ms'] == '500' and a.f['skew_ms'] == '1500', 'a clock set back revived a token: %r' % a)
    code, out = s.run(s.seams, 'cosign-message', st, 'r1', '*', 1500, 'DO rate_window acquire r1 t1 1 k * api 1', env=env)
    lines = out.split('\n')
    require(code == 0 and len(lines) == 8 and lines[0] == 'forge-primitives-cosign-v1' and lines[5] == '1500' and lines[7] == '', 'cosign message: %r' % out)
    code, out = s.run(s.seams, 'cosign-message', st, 'r1', '*', 1500, 'bad\x01', env=env)
    require(code == 12, 'a non-printable action: %r' % out)
    st2, _ = s.store(s.engine, s.folder('ttl-prod'), [])
    real = int(time.time() * 1000)
    a = s.one(s.engine, 'cosign-ttl', st2, real + 600000, 3600000, expect='TTL_OPEN')
    require(abs(a.num('now_ms') - real) < 600000, 'production TTL clock: %r' % a)
    return 'TTL inclusive at not_after; max TTL; set-back clock keeps a token expired; signature NOT checked (stub)'


def case_stubs(s):
    d = s.folder('stubs')
    st, init = s.store(s.engine, d, [])
    g = init.f['genesis']
    ses = Session(s.engine, st)
    for line in ['DO ledger_graph transfer s1 t1 2 a %s b %s x' % (g, g), 'DO ledger_graph claim s2 t1 1 a %s x' % g,
                 'DO taint_egress check s3 t1 0 {"a":1}', 'DO farkas check s4 t1 0 {}']:
        a = ses.ask(line, 'NOT_IMPLEMENTED')
        require(ses.p.poll() is None, 'serve ended after NOT_IMPLEMENTED')
    ses.close()
    code, _ = s.run(s.engine, 'serve', st, inp=b'DO farkas check s5 t1 0 {}\n')
    require(code == 27, 'NOT_IMPLEMENTED exit code %d' % code)
    require(len(parse_wal(wal_of(st))[0]) == 1, 'a stub wrote a record')
    return 'ledger_graph, taint_egress, farkas answer NOT_IMPLEMENTED (exit 27) and write nothing'


def build_interposer(s):
    if s.interposer:
        return s.interposer
    out = s.work / 'interpose.dylib'
    src = ROOT / 'tests/airlock/interpose.c'
    p = subprocess.run(['/usr/bin/cc', '-dynamiclib', '-O1', '-Wall', '-Wextra', '-Werror', str(src), '-o', str(out)], capture_output=True, text=True)
    require(p.returncode == 0, 'NOT RUN: the interposer did not build: %s' % p.stderr[-500:])
    return out


def case_trace(s):
    dylib = build_interposer(s)
    d = s.folder('trace')
    pol = s.policy(d, 'api', max_ops_per_window=10, window_ms=100000)
    st, _ = s.store(s.engine, d, [pol])
    log = d / 'trace.log'
    env = dict(ENV, DYLD_INSERT_LIBRARIES=str(dylib), AIRLOCK_TRACE=str(log))
    code, out = s.run(s.engine, 'serve', st, env=env, inp=(acquire('t1', 'k', 1) + '\n').encode())
    require(code == 0 and out.startswith('COMMITTED'), 'traced commit: %r' % out)
    lines = log.read_text().splitlines() if log.exists() else []
    require(any(x.startswith('flock ') for x in lines), 'NOT RUN: the interposer saw no call (DYLD_INSERT_LIBRARIES not honoured?)')
    sync = [i for i, x in enumerate(lines) if x == 'fullfsync %s 0' % WAL]
    answer = [i for i, x in enumerate(lines) if x.startswith('write stdout')]
    require(sync and answer and sync[0] < answer[0], 'no F_FULLFSYNC of the WAL before the answer: %r' % lines)
    before = wal_of(st)
    log.unlink()
    env2 = dict(env, AIRLOCK_FAIL_SYNC='1')
    code, out = s.run(s.engine, 'serve', st, env=env2, inp=(acquire('t2', 'k', 1) + '\n').encode())
    require(code == 18 and out.startswith('IO_ERROR'), 'a failed WAL sync must answer IO_ERROR: %r' % out)
    require(wal_of(st) == before, 'a record whose sync failed stayed in the WAL')
    s.one(s.engine, 'state', st, expect='STATE')
    return 'F_FULLFSYNC of the WAL before the answer; a failed sync answers IO_ERROR and cuts the record'


CASES = [('init', case_init), ('flip', case_flip), ('splice', case_splice), ('torn', case_torn), ('lock', case_lock),
         ('race', case_race), ('multikey', case_multikey), ('lines', case_lines), ('seams', case_seams),
         ('clock_setback', case_clock_setback), ('clock_request', case_clock_request), ('boundary', case_boundary),
         ('volume', case_volume), ('cooldown', case_cooldown), ('restart', case_restart), ('kill9', case_kill9),
         ('u64', case_u64), ('cosign_ttl', case_cosign_ttl), ('stubs', case_stubs), ('trace', case_trace)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('engine')
    ap.add_argument('seams')
    ap.add_argument('--case', action='append', choices=[n for n, _ in CASES])
    ap.add_argument('--big-gib', type=float, default=10.0, help='size of the big line of case lines (default 10 GiB)')
    ap.add_argument('--work', default=None)
    ap.add_argument('--interposer', default=None)
    ap.add_argument('--keep', action='store_true')
    args = ap.parse_args()
    for b in (args.engine, args.seams):
        if not os.access(b, os.X_OK):
            print('cannot start: %s is missing' % b)
            return 2
    work = Path(tempfile.mkdtemp(prefix='pv2-', dir=args.work))
    os.chmod(work, 0o700)
    suite = Suite(Path(args.engine).resolve(), Path(args.seams).resolve(), work, args.big_gib, args.interposer)
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
            print('FAIL %-13s %6.1fs %s' % (name, time.time() - t, str(e).replace('\n', ' ')[:600]), flush=True)
        except Exception as e:  # noqa: BLE001  (a crash of the suite is a failure, never a pass)
            failed += 1
            print('FAIL %-13s %6.1fs suite error %s: %s' % (name, time.time() - t, type(e).__name__, str(e)[:400]), flush=True)
    if not args.keep:
        shutil.rmtree(work, ignore_errors=True)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
