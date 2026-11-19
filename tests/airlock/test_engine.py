#!/usr/bin/env python3
"""FINITE TEST of the forge-airlock engine (Goal 20). It proves nothing about the engine.

Usage: python3 tests/airlock/test_engine.py <engine> <kill-engine> [--case NAME]... [--node PATH] [--work DIR] [--interposer DYLIB]

Cases trace and dispatch: the test interposer tests/airlock/interpose.c (built with /usr/bin/cc if --interposer is
absent) records the order of system calls in the engine process and makes one sync or write fail. Case lock: one
process holds the store lock at kill point a; two others must wait. Case pin: the model pin and O_NOFOLLOW of
booking_check.cjs with files next to the built model. These four cases exist for the EXIT mutations.

The engine binaries come in as arguments, so the same cases can run on changed copies (mutation runs).
The suite reads the WAL with its OWN transcription of the record format (zlib CRC-32, FNV-1a-128 in Python);
that transcription and the engine can be wrong in the same way. A SIGKILL is not a power loss.
Helper processes: the real CakeML refund binary (a private 0700 copy named `refund`), the real Node helpers
src/airlock/node/cosign.cjs and booking_check.cjs with the built model build/airlock/checker/model.cjs. Some cases
also use STAND-IN helper processes written to a temp folder: they are test doubles of the HELPER PROCESS, used only
to drive the engine's wiring (bad frames, wrong output, a helper that refuses a valid input). They are labelled.
A case that cannot run FAILS with NOT RUN in its message; it never passes.
Exit 0: every selected case passed. 1: at least one failed. 2: the suite could not start.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
import zlib

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
FIX = ROOT / 'tests/airlock/fixtures'
BINARY = ROOT / 'proposals/forge2-m1-conformance/artifacts/refund-arm64-macho'
BINARY_SHA256 = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
RECORDED = ROOT / 'tests/m1-conformance/recorded-m1-cases.json'
HELPERS = ROOT / 'src/airlock/node'
MODEL = ROOT / 'build/airlock/checker/model.cjs'
MAX_MONEY = 9223372036854775807
MAX_LINE = 65536
ZERO = '0' * 32
CODES = {'OK': 0, 'USAGE': 2, 'REJECTED_POLICY': 10, 'REQUIRE_HUMAN_COSIGN': 11, 'MALFORMED_REQUEST': 12, 'STALE_STATE_HASH': 13,
         'DUPLICATE_REQUEST_ID': 14, 'EPOCH_REGRESSION': 15, 'TENANT_ISOLATION_BREACH': 16, 'CORRUPT_WAL': 17, 'IO_ERROR': 18,
         'OUTCOME_UNKNOWN': 19, 'DISPATCH_FAILED': 20, 'UNKNOWN_KEY': 21, 'HELPER_FAILED': 22, 'BAD_FRAME': 23,
         'DROPPED_OBLIGATION': 24, 'MALFORMED_POLICY': 25}
FNV_OFFSET, FNV_PRIME, MASK = 0x6c62272e07bb014262b821756295c58d, 0x0000000001000000000000000000013b, (1 << 128) - 1
EFFECT_KINDS = ('OPEN_MONEY', 'REFUND', 'OPEN_SAGA', 'SAGA', 'OPEN_INVENTORY', 'BOOK')
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}
VALID_CERT = {'A': [['1', '1']], 'c': ['3'], 'w': ['5', '2'], 'x': ['1', '1'], 'y': ['0'], 'z': ['5', '2'], 'alpha_bps': '0'}


class Failed(Exception):
    pass


def require(cond, msg):
    if not cond:
        raise Failed(msg)


def fnv128(data):
    h = FNV_OFFSET
    for b in data:
        h = ((h ^ b) * FNV_PRIME) & MASK
    return h


def read_wal(store):
    """The suite's own strict reader: every byte must belong to a valid, chained record."""
    data = (Path(store) / 'airlock.wal').read_bytes()
    pos, tail, records = 0, 0, []
    while pos < len(data):
        require(len(data) - pos >= 36, 'WAL: %d stray bytes at the end' % (len(data) - pos))
        magic, epoch, prev, length = data[pos:pos + 4], struct.unpack('<Q', data[pos + 4:pos + 12])[0], int.from_bytes(data[pos + 12:pos + 28], 'little'), struct.unpack('<I', data[pos + 28:pos + 32])[0]
        rec = data[pos:pos + 36 + length]
        require(len(rec) == 36 + length, 'WAL: a record is cut')
        require(magic == b'FAR1' and epoch == len(records) and prev == tail, 'WAL record %d: magic, epoch or chain' % len(records))
        require(struct.unpack('<I', rec[-4:])[0] == zlib.crc32(rec[:-4]) & 0xffffffff, 'WAL record %d: CRC' % len(records))
        payload = rec[32:-4].decode('ascii')
        tail = fnv128(rec)
        records.append((epoch, payload, tail))
        pos += len(rec)
    require(records and records[0][1].startswith('GENESIS 1 '), 'WAL: no genesis record')
    return records


def effects(store):
    return [p for _, p, _ in read_wal(store) if p.split(' ')[0] in EFFECT_KINDS]


def ratchet_max(store):
    data = (Path(store) / 'airlock.epoch').read_bytes()
    vals = [struct.unpack('<Q', data[i:i + 8])[0] for i in range(0, len(data) - len(data) % 12, 12)
            if struct.unpack('<I', data[i + 8:i + 12])[0] == zlib.crc32(data[i:i + 8]) & 0xffffffff]
    require(vals, 'ratchet: no valid entry')
    return max(vals)


def files(store):
    return {p.name: p.read_bytes() for p in sorted(Path(store).iterdir())}


class Suite:
    def __init__(self, a):
        self.engine, self.kill_engine, self.node = str(Path(a.engine).resolve()), str(Path(a.kill_engine).resolve()), a.node
        self.work = Path(tempfile.mkdtemp(prefix='airlock-', dir=a.work))
        self.n = 0
        self.refund = None
        self.interposer = str(Path(a.interposer).resolve()) if a.interposer else None

    def folder(self, name):
        self.n += 1
        p = self.work / ('%03d-%s' % (self.n, name))
        p.mkdir()
        return p

    def run(self, args, stdin=b'', engine=None, env=None, timeout=120):
        p = subprocess.run([engine or self.engine] + [str(x) for x in args], input=stdin, capture_output=True, env=env or ENV, timeout=timeout)
        return p.returncode, p.stdout.decode('utf-8', 'replace'), p.stderr.decode('utf-8', 'replace')

    def store(self, name, policies=('money-parametric', 'money-ambiguous', 'saga-payout', 'inventory-seats'), pubkey=None, store_id=None):
        path = self.folder(name) / 'store'
        args = ['init', path, '--store-id', store_id or ('st-' + name)[:24]]
        for p in policies:
            args += ['--policy', FIX / (p + '.json')]
        if pubkey:
            args += ['--cosign-pubkey', pubkey]
        code, out, err = self.run(args)
        require(code == 0 and out.startswith('INITIALIZED '), 'init %s: %d %r %r' % (name, code, out, err))
        return path

    def serve(self, store, lines, extra=(), engine=None, env=None, raw=False):
        data = lines if raw else b''.join((l if isinstance(l, bytes) else l.encode()) + b'\n' for l in lines)
        code, out, err = self.run(['serve', store] + list(extra), data, engine, env)
        return code, out.split('\n')[:-1], err

    def one(self, store, line, expect, extra=()):
        """One request; the first token of the answer must be `expect`. Returns the answer tokens."""
        code, out, err = self.serve(store, [line], extra)
        require(len(out) == 1, 'one answer expected for %r: %r %r' % (line[:80], out, err))
        tok = out[0].split(' ')
        want = 0 if expect in ('COMMITTED', 'OK', 'LEASE_OPENED', 'STATE') else CODES[expect]
        require(tok[0] == expect and code == want, '%r: expected %s (exit %d), got exit %d %r' % (line[:100], expect, want, code, out[0][:200]))
        return tok

    def h(self, store, tenant, key):
        code, out, _ = self.run(['get', store, tenant, key])
        require(code == 0 and out.startswith('OK '), 'get %s %s: %d %r' % (tenant, key, code, out))
        return out.split(' ')[1]

    def get(self, store, tenant, key):
        code, out, _ = self.run(['get', store, tenant, key])
        require(code == 0, 'get: %r' % out)
        return dict(t.split('=', 1) for t in out.split()[3:])

    def refund_binary(self):
        if self.refund is None:
            require(BINARY.exists(), 'NOT RUN: the refund binary is missing')
            require(hashlib.sha256(BINARY.read_bytes()).hexdigest() == BINARY_SHA256, 'NOT RUN: the refund binary is not the pinned one')
            d = self.folder('bin')
            self.refund = d / 'refund'
            shutil.copyfile(BINARY, self.refund)
            os.chmod(self.refund, 0o700)
        return self.refund

    def node_ok(self):
        require(Path(self.node).exists(), 'NOT RUN: node %s is missing' % self.node)
        for f in ('cosign.cjs', 'booking_check.cjs'):
            require((HELPERS / f).exists(), 'NOT RUN: helper %s is missing' % f)
        return ['--node', self.node, '--helpers', HELPERS]

    def standin(self, name, files_):
        """STAND-IN helper processes (test doubles of the helper process; wiring only)."""
        d = self.folder('standin-' + name)
        for fname, text in files_.items():
            (d / fname).write_text(text)
            os.chmod(d / fname, 0o700)
        return d


# ------------------------------------------------------------------------------------------------- cases

def case_init(s):
    p = s.store('init')
    before = files(p)
    code, out, _ = s.run(['init', p, '--store-id', 'other', '--policy', FIX / 'money-parametric.json'])
    require(code == 18 and 'STORE_EXISTS' in out and files(p) == before, 'second init must be refused and change nothing: %d %r' % (code, out))
    recs = read_wal(p)
    require(len(recs) == 1 and recs[0][1].startswith('GENESIS 1 st-init - 4 store-refunds money '), 'genesis: %r' % recs[0][1])
    require(ratchet_max(p) == 0, 'ratchet of a new store')
    d = s.folder('init-bad')
    bad = {'unknown-key.json': b'{"airlock":"inventory","version":1,"name":"x","max_alpha_bps":"0","extra":1}',
           'dup-key.json': b'{"airlock":"inventory","version":1,"name":"x","name":"y","max_alpha_bps":"0"}',
           'version.json': b'{"airlock":"inventory","version":2,"name":"x","max_alpha_bps":"0"}',
           'alpha.json': b'{"airlock":"inventory","version":1,"name":"x","max_alpha_bps":"10001"}',
           'amount.json': b'{"airlock":"money","version":1,"name":"x","profile":"parametric","rules":[{"reason":"A","verdict":"COMMIT","max_amount":"01"}]}',
           'canon-rules.json': b'{"airlock":"money","version":1,"name":"x","profile":"canonical-refund","rules":[]}',
           'saga-state.json': b'{"airlock":"saga","version":1,"name":"x","states":["A"],"initial":"B","in_flight":[],"transitions":[]}',
           'surrogate.json': b'{"airlock":"inventory","version":1,"name":"\\ud800","max_alpha_bps":"0"}',
           'trailing.json': b'{"airlock":"inventory","version":1,"name":"x","max_alpha_bps":"0"} x'}
    for name, text in bad.items():
        (d / name).write_bytes(text)
        code, out, _ = s.run(['init', d / ('st-' + name), '--store-id', 's', '--policy', d / name])
        require(code == 25 and out.startswith('MALFORMED_POLICY'), 'policy %s must be refused: %d %r' % (name, code, out))
    require(sorted(x.name for x in d.iterdir()) == sorted(bad), 'a refused init left a folder: %r' % sorted(x.name for x in d.iterdir()))
    code, out, _ = s.run(['init', d / 'st-key', '--store-id', 's', '--cosign-pubkey', 'AB' * 32])
    require(code == 12, 'an uppercase public key must be refused: %r' % out)
    # a SIGKILL inside init (after every file is synced, before the rename) leaves no store; init then works
    target = d / 'st-killed'
    proc = subprocess.Popen([s.kill_engine, 'init', target, '--store-id', 'k'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=dict(ENV, AIRLOCK_KILL_AT='i'))
    line = proc.stderr.readline()
    require(line == b'AT i\n', 'kill point i not reached: %r' % line)
    proc.send_signal(signal.SIGKILL)
    proc.wait()
    require(not target.exists(), 'a killed init left the store path')
    code, out, _ = s.run(['init', target, '--store-id', 'k'])
    require(code == 0, 'init after a killed init: %r' % out)
    return 'second init refused; 9 bad policies refused, no folder left; kill inside init leaves no store'


def case_recovery(s):
    p = s.store('rec')
    s.one(p, 'OPEN_MONEY t1 k1 r1 store-refunds 1000', 'COMMITTED')
    good = files(p)
    wal = p / 'airlock.wal'
    torn_tails = [b'F', b'FAR1' + b'\0' * 20, None]
    for tail in torn_tails:
        shutil.rmtree(p)
        p.mkdir()
        for n, b in good.items():
            (p / n).write_bytes(b)
        if tail is None:  # a header that declares a payload running past the end
            rec = good['airlock.wal'][-60:]
            tail = struct.pack('<4sQ16sI', b'FAR1', 2, b'\0' * 16, 100) + b'xx'
        wal.write_bytes(good['airlock.wal'] + tail)
        code, out, _ = s.run(['state', p])
        require(code == 0 and out.startswith('STATE 1 '), 'torn tail %r not recovered: %d %r' % (tail[:8], code, out))
        require(wal.read_bytes() == good['airlock.wal'], 'recovery must cut exactly the torn tail')
    s.one(p, 'REFUND t1 k1 r2 %s DUPLICATE_CHARGE 5' % s.h(p, 't1', 'k1'), 'COMMITTED')
    good = files(p)
    data = good['airlock.wal']
    # a flipped bit in a middle record
    for at in (40, len(read_wal(p)[0][1]) + 36 + 10):
        bad = bytearray(data)
        bad[at] ^= 1
        wal.write_bytes(bytes(bad))
        code, out, _ = s.run(['state', p])
        require(code == 17 and out.startswith('CORRUPT_WAL'), 'bit flip at %d: %d %r' % (at, code, out))
    # a whole extra record that does not chain
    wal.write_bytes(data + data[-80:])
    code, out, _ = s.run(['state', p])
    require(code in (17,), 'garbage record at the end: %d %r' % (code, out))
    # a flipped bit in the LAST record (it was ratcheted): CORRUPT_WAL, never adopted
    bad = bytearray(data)
    bad[-6] ^= 1
    wal.write_bytes(bytes(bad))
    code, out, _ = s.run(['state', p])
    require(code == 17, 'bit flip in the last record: %d %r' % (code, out))
    # epoch regression: an older WAL with the present ratchet
    wal.write_bytes(data)
    old = data
    s.one(p, 'REFUND t1 k1 r3 %s DUPLICATE_CHARGE 5' % s.h(p, 't1', 'k1'), 'COMMITTED')
    wal.write_bytes(old)
    for cmd in (['state', p], ['replay', p], ['get', p, 't1', 'k1']):
        code, out, _ = s.run(cmd)
        require(code == 15 and out.startswith('EPOCH_REGRESSION'), 'restored WAL, %s: %d %r' % (cmd[0], code, out))
    code, out, _ = s.serve(p, ['STATE', 'STATE'])
    require(code == 15 and len(out) == 1, 'serve must end at EPOCH_REGRESSION: %r' % out)
    # a changed policy file
    q = s.store('rec-pol')
    pf = q / 'policy-store-refunds.json'
    pf.write_bytes(pf.read_bytes().replace(b'"2000"', b'"9000"'))
    code, out, _ = s.run(['state', q])
    require(code == 17 and 'POLICY_CHANGED' in out, 'changed policy file: %d %r' % (code, out))
    # no genesis / empty WAL / missing ratchet
    q2 = s.store('rec-empty')
    (q2 / 'airlock.wal').write_bytes(b'')
    code, out, _ = s.run(['state', q2])
    require(code == 17, 'empty WAL: %d %r' % (code, out))
    return '3 torn tails cut; 2 bit flips, an extra record, a flip in the last record refused; restored WAL refused (15); changed policy refused'


def case_cas(s):
    p = s.store('cas')
    s.one(p, 'OPEN_MONEY t1 k1 r1 store-refunds 1000', 'COMMITTED')
    h1 = s.h(p, 't1', 'k1')
    tok = s.one(p, 'OPEN_MONEY t1 k1 r2 store-refunds 1000', 'STALE_STATE_HASH')
    require(tok[1] == h1, 'an open of an existing key names its hash')
    s.one(p, 'OPEN_MONEY t1 k2 r1 store-refunds 1000', 'DUPLICATE_REQUEST_ID')
    tok = s.one(p, 'REFUND t1 k1 r3 %s DUPLICATE_CHARGE 10' % h1, 'COMMITTED')
    h2 = tok[3]
    require(h2 == s.h(p, 't1', 'k1') and h2 != h1, 'COMMITTED names the new state hash')
    s.one(p, 'REFUND t1 k1 r4 %s DUPLICATE_CHARGE 10' % h1, 'STALE_STATE_HASH')
    s.one(p, 'REFUND t1 k1 r3 %s DUPLICATE_CHARGE 10' % h2, 'DUPLICATE_REQUEST_ID')
    s.one(p, 'REFUND t1 k1 r4 %s NOPE 10' % h2, 'REJECTED_POLICY')
    s.one(p, 'REFUND t1 k1 r4 %s DUPLICATE_CHARGE 10' % h2, 'COMMITTED')  # a refusal consumed no request id
    s.one(p, 'REFUND t1 nokey r5 %s DUPLICATE_CHARGE 10' % h2, 'UNKNOWN_KEY')
    s.one(p, 'REFUND t1 k1 r5 %s DUPLICATE_CHARGE 10' % h2.upper(), 'MALFORMED_REQUEST')
    # two stores, same requests: different state hashes (the store id is in the genesis record)
    q = s.store('cas2')
    s.one(q, 'OPEN_MONEY t1 k1 r1 store-refunds 1000', 'COMMITTED')
    require(s.h(q, 't1', 'k1') != h1, 'two stores gave the same state hash')
    require(len(effects(p)) == 3, 'effects: %r' % effects(p))
    return 'stale open, stale refund, duplicate ids, refusal keeps the id fresh, unknown key, cross-store hashes differ'


def case_tenant(s):
    p = s.store('tenant')
    s.one(p, 'OPEN_MONEY tA k1 r1 store-refunds 1000', 'COMMITTED')
    s.one(p, 'OPEN_SAGA tA s1 r2 payout', 'COMMITTED')
    h, hs = s.h(p, 'tA', 'k1'), s.h(p, 'tA', 's1')
    before = files(p)
    for line in ['REFUND tB k1 r3 %s DUPLICATE_CHARGE 10' % h, 'OPEN_MONEY tB k1 r3 store-refunds 1000', 'GET tB k1',
                 'SAGA tB s1 r3 %s IN_FLIGHT stripe i1' % hs, 'OPEN_INVENTORY tB s1 r3 seats 3']:
        s.one(p, line, 'TENANT_ISOLATION_BREACH')
    code, out, _ = s.run(['get', p, 'tB', 'k1'])
    require(code == 16, 'get under another tenant: %r' % out)
    require(files(p) == before, 'a breach changed the store')
    s.one(p, 'REFUND tA k1 r3 %s DUPLICATE_CHARGE 10' % h, 'COMMITTED')
    return '5 cross-tenant requests and 1 get refused; store unchanged'


def case_money(s):
    p = s.store('money')
    s.one(p, 'OPEN_MONEY t1 k1 r0 store-refunds 1000 shipping_paid=10', 'COMMITTED')
    n = [0]

    def ref(reason, amount, expect, key='k1'):
        n[0] += 1
        return s.one(p, 'REFUND t1 %s m%d %s %s %s' % (key, n[0], s.h(p, 't1', key), reason, amount), expect)
    require(ref('DUPLICATE_CHARGE', 0, 'REJECTED_POLICY')[1] == 'ZERO_AMOUNT', 'zero')
    require(ref('DUPLICATE_CHARGE', 1001, 'REJECTED_POLICY')[1] == 'TOTAL_CAP', 'cap+1')
    ref('DUPLICATE_CHARGE', 1, 'COMMITTED')
    require(ref('SHIPPING', 80, 'REJECTED_POLICY')[1] == 'REASON_CAP', 'shipping 80 > 10')
    ref('SHIPPING', 10, 'COMMITTED')
    require(ref('SHIPPING', 1, 'REJECTED_POLICY')[1] == 'REASON_CAP', 'shipping total 11 > 10')
    require(ref('UNKNOWN', 1, 'REJECTED_POLICY')[1] == 'NO_RULE', 'no rule')
    require(ref('GOODWILL', 2001, 'REJECTED_POLICY')[1] == 'TOTAL_CAP', 'goodwill above remaining')
    ref('GOODWILL', 989, 'COMMITTED')  # exactly the remaining: 1000 - 1 - 10
    require(s.get(p, 't1', 'k1')['remaining'] == '0', 'remaining after the cap')
    require(ref('DUPLICATE_CHARGE', 1, 'REJECTED_POLICY')[1] == 'TOTAL_CAP', 'cap reached')
    # MaxMoney
    s.one(p, 'OPEN_MONEY t1 big r-big store-refunds %d' % MAX_MONEY, 'COMMITTED')
    s.one(p, 'OPEN_MONEY t1 big2 r-big2 store-refunds %d' % (MAX_MONEY + 1), 'MALFORMED_REQUEST')
    ref('DUPLICATE_CHARGE', MAX_MONEY + 1, 'MALFORMED_REQUEST', 'big')
    ref('DUPLICATE_CHARGE', MAX_MONEY, 'COMMITTED', 'big')
    require(s.get(p, 't1', 'big')['remaining'] == '0', 'MaxMoney refund')
    for bad in ('01', '+1', '-1', '1.0', '1e3', ' 1'):
        s.one(p, 'REFUND t1 k1 mx %s DUPLICATE_CHARGE %s' % (s.h(p, 't1', 'k1'), bad), 'MALFORMED_REQUEST')
    # ambiguous rules: the most restrictive verdict wins
    s.one(p, 'OPEN_MONEY t1 amb r-amb ambiguous 100000', 'COMMITTED')
    for amount, want, det in ((499, 'COMMITTED', None), (500, 'REQUIRE_HUMAN_COSIGN', 'COSIGN_REQUIRED'), (950, 'REJECTED_POLICY', 'RULE'), (1000, 'REQUIRE_HUMAN_COSIGN', 'COSIGN_REQUIRED')):
        tok = ref('GOODWILL', amount, want, 'amb')
        require(det is None or tok[1] == det, 'ambiguous %d: %r' % (amount, tok))
    # eval: the same function, no store
    lines = ['EVAL GOODWILL 0 100 0', 'EVAL GOODWILL 1 100 0', 'EVAL GOODWILL 2000 5000 0', 'EVAL GOODWILL 2001 5000 0', 'EVAL GOODWILL 101 100 0',
             'EVAL SHIPPING 10 100 0 shipping_paid=10', 'EVAL SHIPPING 11 100 0 shipping_paid=10', 'EVAL SHIPPING 1 100 0', 'EVAL X 1 100 0',
             'EVAL GOODWILL 1 %d 0' % MAX_MONEY, 'EVAL GOODWILL 1 %d 0' % (MAX_MONEY + 1), 'garbage']
    code, out, _ = s.run(['eval', FIX / 'money-parametric.json'], ('\n'.join(lines) + '\n').encode())
    want = ['REJECTED_POLICY ZERO_AMOUNT', 'COMMIT', 'COMMIT', 'REQUIRE_HUMAN_COSIGN', 'REJECTED_POLICY TOTAL_CAP', 'COMMIT', 'REJECTED_POLICY REASON_CAP',
            'REJECTED_POLICY REASON_CAP', 'REJECTED_POLICY NO_RULE', 'COMMIT']
    got = out.split('\n')[:-1]
    require(got[:10] == want and got[10].startswith('MALFORMED_REQUEST') and got[11].startswith('MALFORMED_REQUEST'), 'eval: %r' % got)
    code, out, _ = s.run(['eval', FIX / 'money-canonical.json'], b'')
    require(code == 25, 'eval of the canonical profile must be refused: %r' % out)
    return 'boundaries 0, 1, cap, cap+1, MaxMoney, MaxMoney+1; reason cap; most restrictive wins; eval agrees (12 lines)'


def case_canonical(s):
    binary = s.refund_binary()
    p = s.store('canon', policies=('money-canonical',))
    s.one(p, 'OPEN_MONEY t1 charge-1 r0 canonical 100', 'COMMITTED')
    s.one(p, 'OPEN_MONEY t1 charge-x r0x canonical 100 a=1', 'MALFORMED_REQUEST')
    ex = ['--refund-binary', binary]
    h = s.h(p, 't1', 'charge-1')
    for reason, amount, want in (('returned_item', 101, 'CAKEML_REJECTED'), ('other_reason', 10, 'CAKEML_REJECTED'), ('returned_item', 0, 'ZERO_AMOUNT')):
        tok = s.one(p, 'REFUND t1 charge-1 rq-1 %s %s %s' % (h, reason, amount), 'REJECTED_POLICY', ex)
        require(tok[1] == want, '%s %s: %r' % (reason, amount, tok))
    s.one(p, 'REFUND t1 charge-1 rq-1 %s returned_item 40' % h, 'HELPER_FAILED')  # no binary given
    tok = s.one(p, 'REFUND t1 charge-1 request-1 %s returned_item 40' % h, 'COMMITTED', ex)
    for r, amt in (('duplicate_charge', 30), ('service_not_delivered', 30)):
        s.one(p, 'REFUND t1 charge-1 rq-%s %s %s %d' % (r[:3], s.h(p, 't1', 'charge-1'), r, amt), 'COMMITTED', ex)
    tok = s.one(p, 'REFUND t1 charge-1 rq-z %s returned_item 1' % s.h(p, 't1', 'charge-1'), 'REJECTED_POLICY', ex)
    require(tok[1] == 'CAKEML_REJECTED', 'remaining 0: %r' % tok)
    # the recorded HOL-written cases inside the grammar: the binary's verdict decides
    rec = json.loads(RECORDED.read_bytes())['typed']
    checked = 0
    for f in rec:
        v = f['inputs']
        if not (v['enabled'] and v['opened'] and v['candidate']):
            continue  # the engine always sends three True flags (PROTOCOL.md)
        try:
            o, r_, a = int(v['original']), int(v['remaining']), int(v['amount'])
        except ValueError:
            continue
        if not (str(o) == v['original'] and str(r_) == v['remaining'] and str(a) == v['amount'] and 0 < r_ <= o <= MAX_MONEY and 0 < a <= MAX_MONEY):
            continue
        if not all(len(x) <= 24 and x.replace('-', '').replace('_', '').isalnum() and x.isascii() for x in (v['charge'], v['request'], v['reason'])):
            continue
        q = s.store('canon-rec-%d' % checked, policies=('money-canonical',))
        s.one(q, 'OPEN_MONEY t1 %s z-open canonical %d' % (v['charge'], o), 'COMMITTED')
        if r_ < o:
            s.one(q, 'REFUND t1 %s zz-setup %s returned_item %d' % (v['charge'], s.h(q, 't1', v['charge']), o - r_), 'COMMITTED', ex)
        line = 'REFUND t1 %s %s %s %s %s' % (v['charge'], v['request'], s.h(q, 't1', v['charge']), v['reason'], v['amount'])
        if f['expected']['ok']:
            s.one(q, line, 'COMMITTED', ex)
            frame = bytes.fromhex(f['hol_stdout_hex']).decode()
            require(frame == '(refund-result-v1 True %s %s %s %s 1)' % (v['amount'], v['reason'], v['charge'], v['request']), 'HOL frame differs from the engine expectation')
        else:
            require(s.one(q, line, 'REJECTED_POLICY', ex)[1] == 'CAKEML_REJECTED', 'recorded case %s' % f['name'])
        checked += 1
    require(checked >= 3, 'NOT RUN: fewer than 3 recorded cases fit the grammar (%d)' % checked)
    # STAND-IN refund binaries (test doubles of the helper process): only the exact frame with a clean exit commits
    good = '(refund-result-v1 True 5 returned_item charge-1 rq-f 1)'
    d = s.standin('frames', {
        'longer': '#!/bin/sh\nprintf \'%s \'\n' % good, 'stderr': '#!/bin/sh\nprintf \'%s\'\necho x >&2\n' % good,
        'exit1': '#!/bin/sh\nprintf \'%s\'\nexit 1\n' % good, 'other-id': '#!/bin/sh\nprintf \'%s\'\n' % good.replace('rq-f', 'rq-g'),
        'nothing': '#!/bin/sh\nexit 0\n', 'lf': '#!/bin/sh\nprintf \'%s\\n\'\n' % good})
    q = s.store('canon-frames', policies=('money-canonical',))
    s.one(q, 'OPEN_MONEY t1 charge-1 r0 canonical 100', 'COMMITTED')
    hq = s.h(q, 't1', 'charge-1')
    for name in ('longer', 'stderr', 'exit1', 'other-id', 'nothing', 'lf'):
        s.one(q, 'REFUND t1 charge-1 rq-f %s returned_item 5' % hq, 'BAD_FRAME', ['--refund-binary', d / name])
    s.one(q, 'REFUND t1 charge-1 rq-f %s returned_item 5' % hq, 'HELPER_FAILED', ['--refund-binary', d / 'missing'])
    require(len(effects(q)) == 1, 'a bad frame committed')
    return 'real binary: 3 rejections, 3 commits, remaining 0 rejected; %d recorded HOL cases agree; 6 stand-in bad frames refused' % checked


def keygen(s, name):
    d = s.folder('key-' + name)
    p = subprocess.run([s.node, HELPERS / 'cosign.cjs', 'keygen', d / 'key'], capture_output=True, env=ENV)
    require(p.returncode == 0, 'keygen: %r' % p.stderr)
    return d / 'key', p.stdout.decode().strip()


def sign(s, key, message):
    p = subprocess.run([s.node, HELPERS / 'cosign.cjs', 'sign', key], input=message, capture_output=True, env=ENV)
    require(p.returncode == 0, 'sign: %r' % p.stderr)
    return p.stdout.decode().strip()


def case_cosign(s):
    ex = s.node_ok()
    key, pub = keygen(s, 'human')
    key2, pub2 = keygen(s, 'other')
    p = s.store('cosign', pubkey=pub, store_id='store-a')
    q = s.store('cosign-b', pubkey=pub, store_id='store-b')
    for st in (p, q):
        s.one(st, 'OPEN_MONEY t1 o1 r0 store-refunds 10000', 'COMMITTED')
    h = s.h(p, 't1', 'o1')
    action = 'REFUND t1 o1 r1 %s GOODWILL 7500' % h
    code, msg, _ = s.run(['cosign-message', p, action])
    require(code == 0 and msg == 'forge-airlock-cosign-v1\nstore-a\nr1\n%s\n%s\n' % (h, action), 'cosign message: %r' % msg)
    code, out, _ = s.run(['cosign-message', p, action + ' ' + 'a' * 128])
    require(code == 12, 'a signed action is not a cosign action')
    sig = sign(s, key, msg.encode())
    tok = s.one(p, action, 'REQUIRE_HUMAN_COSIGN', ex)
    require(tok[1] == 'COSIGN_REQUIRED', 'no signature')
    wrong = {
        'wrong key': sign(s, key2, msg.encode()),
        'other request id': sign(s, key, msg.replace('\nr1\n', '\nr9\n').replace(' r1 ', ' r9 ').encode()),
        'other pre_state_hash': sign(s, key, msg.replace(h, '1' * 32).encode()),
        'altered action': sign(s, key, msg.replace('7500', '7501').encode()),
        'flipped signature': ('0' if sig[0] != '0' else '1') + sig[1:],
    }
    for why, bad in wrong.items():
        tok = s.one(p, action + ' ' + bad, 'REQUIRE_HUMAN_COSIGN', ex)
        require(tok[1] == 'COSIGN_INVALID', '%s: %r' % (why, tok))
    # replay on another store: same request id and hash text do not exist there, and the store id differs
    hq = s.h(q, 't1', 'o1')
    sig_q = sign(s, key, msg.replace(h, hq).encode())  # signed for store-a's message with store-b's hash
    for replayed in (sig_q, sig):  # store-a's signature (with either hash) never commits on store-b
        tok = s.one(q, 'REFUND t1 o1 r1 %s GOODWILL 7500 %s' % (hq, replayed), 'REQUIRE_HUMAN_COSIGN', ex)
        require(tok[1] == 'COSIGN_INVALID', 'replay on another store: %r' % tok)
    require(len(effects(q)) == 1, 'replay committed on store-b')
    # helper failures are refusals, never commits
    s.one(p, action + ' ' + sig, 'HELPER_FAILED')  # no node, no helpers
    s.one(p, action + ' ' + sig, 'HELPER_FAILED', ['--node', '/nonexistent/node', '--helpers', HELPERS])
    s.one(p, action + ' ' + sig, 'HELPER_FAILED', ['--node', s.node, '--helpers', s.folder('empty')])
    d = s.standin('cosign', {'cosign.cjs': 'process.stdout.write("VALID\\n"); process.stderr.write("x");'})
    s.one(p, action + ' ' + sig, 'HELPER_FAILED', ['--node', s.node, '--helpers', d])
    d = s.standin('cosign2', {'cosign.cjs': 'process.stdout.write("VALID");'})
    s.one(p, action + ' ' + sig, 'HELPER_FAILED', ['--node', s.node, '--helpers', d])
    d = s.standin('cosign3', {'cosign.cjs': 'process.stdout.write("VALID\\n"); process.exitCode = 3;'})
    s.one(p, action + ' ' + sig, 'HELPER_FAILED', ['--node', s.node, '--helpers', d])
    require(len(effects(p)) == 1, 'a refusal committed')
    tok = s.one(p, action + ' ' + sig, 'COMMITTED', ex)
    require(tok[-1] == '1', 'the record marks the cosign')
    s.one(p, action + ' ' + sig, 'DUPLICATE_REQUEST_ID', ex)
    # a store with no pinned key
    r = s.store('cosign-nokey')
    s.one(r, 'OPEN_MONEY t1 o1 r0 store-refunds 10000', 'COMMITTED')
    tok = s.one(r, 'REFUND t1 o1 r1 %s GOODWILL 7500 %s' % (s.h(r, 't1', 'o1'), sig), 'REQUIRE_HUMAN_COSIGN', ex)
    require(tok[1] == 'NO_COSIGN_KEY', 'no key: %r' % tok)
    return 'real cosign.cjs: valid commits; wrong key, other id, other hash, altered action, flipped sig, other store refused; 6 helper failures refused'


def case_saga(s):
    p = s.store('saga')
    s.one(p, 'OPEN_SAGA t1 pay1 r0 payout', 'COMMITTED')
    s.one(p, 'OPEN_SAGA t1 pay2 r0b store-refunds', 'MALFORMED_REQUEST')
    n = [0]

    def mv(rest, expect):
        n[0] += 1
        return s.one(p, 'SAGA t1 pay1 s%d %s %s' % (n[0], s.h(p, 't1', 'pay1'), rest), expect)
    require(mv('SETTLED', 'REJECTED_POLICY')[1] == 'NO_TRANSITION', 'PAID -> SETTLED')
    require(mv('IN_FLIGHT', 'REJECTED_POLICY')[1] == 'PAIR_REQUIRED', 'in flight without a pair')
    require(mv('BOGUS', 'REJECTED_POLICY')[1] == 'UNKNOWN_STATE', 'unknown state')
    mv('IN_FLIGHT stripe idem-1', 'COMMITTED')
    h_inflight = s.h(p, 't1', 'pay1')
    require(mv('IN_FLIGHT paypal idem-2', 'REJECTED_POLICY')[1] == 'PROCESSOR_IN_FLIGHT', 'failover while in flight')
    require(mv('IN_FLIGHT stripe idem-9', 'REJECTED_POLICY')[1] == 'PROCESSOR_IN_FLIGHT', 'other idempotency key')
    require(mv('SETTLED paypal idem-1', 'REJECTED_POLICY')[1] == 'PROCESSOR_IN_FLIGHT', 'settle by another processor')
    require(mv('SETTLED', 'REJECTED_POLICY')[1] == 'PROCESSOR_IN_FLIGHT', 'settle with no pair')
    require(mv('IN_FLIGHT stripe idem-1', 'REJECTED_POLICY')[1] == 'NO_TRANSITION', 'retry of the same move')
    s.one(p, 'SAGA t1 pay1 s-old %s IN_FLIGHT stripe idem-1' % s.h(p, 't1', 'pay1').replace('0', '1', 1).replace('a', 'b', 1), 'STALE_STATE_HASH')
    mv('CONFIRMED_REJECTED stripe idem-1', 'COMMITTED')
    require(s.get(p, 't1', 'pay1')['processor'] == '-', 'pair cleared after leaving flight')
    mv('IN_FLIGHT paypal idem-2', 'COMMITTED')  # failover after a confirmed rejection is allowed
    mv('SETTLED paypal idem-2', 'COMMITTED')
    require(mv('IN_FLIGHT paypal idem-3', 'REJECTED_POLICY')[1] == 'NO_TRANSITION', 'SETTLED is final')
    s.one(p, 'SAGA t1 pay1 s99 %s IN_FLIGHT stripe' % s.h(p, 't1', 'pay1'), 'MALFORMED_REQUEST')
    got = [e.split(' ')[4:] for e in effects(p) if e.startswith('SAGA ')]
    require(got == [['IN_FLIGHT', 'stripe', 'idem-1'], ['CONFIRMED_REJECTED', '-', '-'], ['IN_FLIGHT', 'paypal', 'idem-2'], ['SETTLED', '-', '-']], 'saga effects: %r' % got)
    require(h_inflight != s.h(p, 't1', 'pay1'), 'hash')
    return 'NO_TRANSITION, PAIR_REQUIRED, UNKNOWN_STATE, 4 x PROCESSOR_IN_FLIGHT, failover after CONFIRMED_REJECTED, 4 effects'


def cert_line(s, p, req, cert, key='inv'):
    return 'BOOK t1 %s %s %s %s' % (key, req, s.h(p, 't1', key), json.dumps(cert, separators=(',', ':')))


def case_inventory(s):
    ex = s.node_ok()
    require(MODEL.exists(), 'NOT RUN: the checker model %s is missing' % MODEL)
    ex = ex + ['--checker', MODEL]
    p = s.store('inv')
    s.one(p, 'OPEN_INVENTORY t1 inv r0 seats 3', 'COMMITTED')
    s.one(p, 'OPEN_INVENTORY t1 inv2 r0b seats 1,1', 'COMMITTED')
    s.one(p, 'OPEN_INVENTORY t1 inv3 r0c seats 1,,1', 'MALFORMED_REQUEST')
    tok = s.one(p, cert_line(s, p, 'b1', VALID_CERT), 'COMMITTED', ex)
    require(tok[-2:] == ['11', '1'], 'BOOK record: %r' % tok)
    require(s.get(p, 't1', 'inv')['remaining'] == '1', 'remaining after booking')
    stale_c = dict(VALID_CERT)
    require(s.one(p, cert_line(s, p, 'b2', stale_c), 'REJECTED_POLICY', ex)[1] == 'CAPACITY_MISMATCH', 'c must be the present capacity')
    # the B5 witness instance of BookingDualCert.dfy on inv2 (capacities 1,1)
    A0, W0 = [['1', '1', '0'], ['1', '0', '1']], ['3', '2', '2']
    base = {'A': A0, 'c': ['1', '1'], 'w': W0, 'y': ['2', '2'], 'z': ['0', '0', '0']}
    cases = [(dict(base, x=['1', '1', '0'], alpha_bps='0'), 'OVERBOOKED'),
             (dict(base, x=['0', '1', '1'], y=['1', '1'], alpha_bps='0'), 'DUAL_INFEASIBLE'),
             (dict(base, x=['1', '0', '0'], alpha_bps='0'), 'GAP_TOO_LARGE'),
             (dict(base, x=['1', '0', '0'], alpha_bps='2499'), 'GAP_TOO_LARGE'),
             (dict(base, x=['0', '2', '0'], alpha_bps='0'), 'NOT_BINARY'),
             (dict(base, x=['0', '1', '1'], alpha_bps='2501'), 'ALPHA_ABOVE_POLICY')]
    for cert, why in cases:
        tok = s.one(p, cert_line(s, p, 'b3', cert, 'inv2'), 'REJECTED_POLICY', ex)
        require(tok[1] == why, '%s: %r' % (why, tok))
    for bad in ('{"A":[["1","1","0"]]}', '{"A":[],"c":[],"w":[],"x":[],"y":[],"z":[],"alpha_bps":"0"}', json.dumps(dict(base, x=['0', '1', '1'], alpha_bps=0)),
                json.dumps(dict(base, x=['0', '1', '1'], alpha_bps='0')).replace('"y"', '"y","y":["1"]', 0) + 'x'):
        s.one(p, 'BOOK t1 inv2 b3 %s %s' % (s.h(p, 't1', 'inv2'), bad), 'MALFORMED_REQUEST', ex)
    dup = '{"A":[["1","1","0"],["1","0","1"]],"c":["1","1"],"w":["3","2","2"],"x":["0","1","1"],"y":["2","2"],"y":["2","2"],"z":["0","0","0"],"alpha_bps":"0"}'
    s.one(p, 'BOOK t1 inv2 b3 %s %s' % (s.h(p, 't1', 'inv2'), dup), 'MALFORMED_REQUEST', ex)
    # STAND-IN booking helper (a test double of the helper process): the engine must obey a REJECT and a bad answer
    good = dict(base, x=['0', '1', '1'], alpha_bps='0')
    d = s.standin('book', {'booking_check.cjs': 'process.stdout.write("REJECT\\n"); process.exitCode = 1;'})
    tok = s.one(p, cert_line(s, p, 'b4', good, 'inv2'), 'REJECTED_POLICY', ['--node', s.node, '--helpers', d, '--checker', MODEL])
    require(tok[1] == 'CHECKER_REJECTED', 'the helper must be consulted: %r' % tok)
    d = s.standin('book2', {'booking_check.cjs': 'process.stdout.write("ACCEPT\\n"); process.stderr.write("w");'})
    s.one(p, cert_line(s, p, 'b4', good, 'inv2'), 'HELPER_FAILED', ['--node', s.node, '--helpers', d, '--checker', MODEL])
    s.one(p, cert_line(s, p, 'b4', good, 'inv2'), 'HELPER_FAILED', ['--node', s.node, '--helpers', HELPERS])  # no model
    tok = s.one(p, cert_line(s, p, 'b4', dict(base, x=['1', '0', '0'], alpha_bps='2500'), 'inv2'), 'COMMITTED', ex)  # quarter gap accepted
    require(s.get(p, 't1', 'inv2')['remaining'] == '0,0', 'remaining: %r' % s.get(p, 't1', 'inv2'))
    require(len([e for e in effects(p) if e.startswith('BOOK')]) == 2, 'BOOK effects')
    return 'real booking_check.cjs + model: 2 commits; 7 native rejections; 5 malformed; stand-in REJECT obeyed; 2 helper failures'


def case_leases(s):
    p = s.store('lease')
    s.one(p, 'OPEN_MONEY t1 k1 r0 store-refunds 1000 shipping_paid=10', 'COMMITTED')
    for r, dl in (('L1', 100), ('L2', 200), ('L3', 300), ('L4', 400), ('L5', 500)):
        tok = s.one(p, 'OPEN_LEASE %s %d' % (r, dl), 'LEASE_OPENED')
    s.one(p, 'OPEN_LEASE L1 100', 'DUPLICATE_REQUEST_ID')
    s.one(p, 'OPEN_LEASE r0 100', 'DUPLICATE_REQUEST_ID')
    h = s.h(p, 't1', 'k1')
    s.one(p, 'REFUND t1 k1 L1 %s DUPLICATE_CHARGE 5' % h, 'COMMITTED')  # closes L1
    h = s.h(p, 't1', 'k1')
    tok = s.one(p, 'REFUND t1 k1 L2 %s SHIPPING 80' % h, 'REJECTED_POLICY')  # closes L2
    require(tok[2:3] == ['LEASE_CLOSED'], 'the answer names the close: %r' % tok)
    tok = s.one(p, 'REFUND t1 k1 L3 %s GOODWILL 5000' % h, 'REJECTED_POLICY')  # TOTAL_CAP closes L3
    s.one(p, 'REFUND t1 k1 L4 %s DUPLICATE_CHARGE 5' % ZERO, 'STALE_STATE_HASH')  # does NOT close L4
    s.one(p, 'REFUND t1 k1 L4 %s DUPLICATE_CHARGE 01' % h, 'MALFORMED_REQUEST')  # does NOT close L4
    s.one(p, 'REFUND t1 k1 r0 %s DUPLICATE_CHARGE 5' % h, 'DUPLICATE_REQUEST_ID')
    closes = [e for _, e, _ in read_wal(p) if e.startswith('CLOSE ')]
    require(closes == ['CLOSE L2 REJECTED_POLICY REASON_CAP', 'CLOSE L3 REJECTED_POLICY TOTAL_CAP'], 'close records: %r' % closes)
    code, out, _ = s.run(['leases', p])
    require(code == 0 and out == 'LEASES 2\nLEASE L4 400\nLEASE L5 500\n', 'list: %r' % out)
    code, out, _ = s.run(['leases', p, '--sweep', '--now', '450'])
    require(code == 24 and out == 'SWEEP 2 1 now=450\nDROPPED_OBLIGATION L4 400\n', 'sweep: %d %r' % (code, out))
    code, out, _ = s.run(['leases', p, '--sweep', '--now', '400'])
    require(code == 0 and out == 'SWEEP 2 0 now=400\n', 'deadline itself is not past: %r' % out)
    before = files(p)
    s.run(['leases', p, '--sweep', '--now', '9999'])
    require(files(p) == before, 'a sweep wrote to the store')
    # REQUIRE_HUMAN_COSIGN closes a lease too; a later commit of a closed id is still possible (id stays fresh)
    s.one(p, 'OPEN_LEASE L6 600', 'LEASE_OPENED')
    s.one(p, 'REFUND t1 k1 L6 %s GOODWILL 2001' % h, 'REJECTED_POLICY')
    s.one(p, 'OPEN_MONEY t1 k2 r-k2 store-refunds 100000', 'COMMITTED')
    s.one(p, 'OPEN_LEASE L7 700', 'LEASE_OPENED')
    tok = s.one(p, 'REFUND t1 k2 L7 %s GOODWILL 2001' % s.h(p, 't1', 'k2'), 'REQUIRE_HUMAN_COSIGN')
    require('LEASE_CLOSED' in tok, 'cosign closes: %r' % tok)
    code, out, _ = s.run(['leases', p])
    require(out.startswith('LEASES 2\n'), 'leases after closes: %r' % out)
    code, out, _ = s.run(['leases', p, '--now', '5'])
    require(code == 2, '--now without --sweep is a usage error')
    return '5 leases; commit, REJECTED_POLICY x3, REQUIRE_HUMAN_COSIGN close; stale and malformed do not; sweep exact and read-only'


def case_read(s):
    p = s.store('read')
    rows_ok = ['{"tenant_id":"tA","x":1.5e3,"n":null,"s":"\\u00e9\\ud83d\\ude00"}', '{"a":[1,{"tenant_id":"tB"}],"tenant_id":"tA"}', '  {"tenant_id" : "tA"}  ']
    bad = {'missing': '{"x":1}', 'mismatch': '{"tenant_id":"tB"}', 'number': '{"tenant_id":1}', 'case': '{"tenant_id":"ta"}',
           'dup': '{"tenant_id":"tA","tenant_id":"tB"}', 'dup-other': '{"tenant_id":"tA","x":1,"x":2}', 'array': '[{"tenant_id":"tA"}]',
           'trailing': '{"tenant_id":"tA"} {}', 'escaped': '{"tenant_\\u0069d":"tB"}', 'nul': '{"tenant_id":"tA\\u0000"}',
           'lone': '{"tenant_id":"tA","s":"\\ud800"}', 'raw-ctl': '{"tenant_id":"tA","s":"a\tb"}', 'bad-num': '{"tenant_id":"tA","n":01}',
           'empty': '', 'deep': '[' * 70 + ']' * 70}
    code, out, _ = s.serve(p, ['READ tA %d' % len(rows_ok)] + rows_ok + ['STATE'])
    require(out[0] == 'OK 3' and out[1].startswith('STATE '), 'good rows: %r' % out)
    for name, row in bad.items():
        code, out, _ = s.serve(p, ['READ tA 3', rows_ok[0], row, rows_ok[1], 'STATE'])
        require(out[0].startswith('TENANT_ISOLATION_BREACH ROW 1') and out[1].startswith('STATE '), 'row %s: %r' % (name, out))
    # 'escaped': i is "i": the key IS tenant_id after unescaping, with another tenant
    for header in ('READ ta- 1', 'READ %s 1' % ('t' * 25), 'READ t/1 1'):
        code, out, _ = s.serve(p, [header, '{"tenant_id":"%s"}' % header.split(' ')[1], 'STATE'])
        require(out[0].startswith('TENANT_ISOLATION_BREACH TENANT_NOT_CANONICAL') or header == 'READ ta- 1', 'tenant %r: %r' % (header, out))
    code, out, _ = s.serve(p, ['READ  1', '{}', 'STATE'])
    require(out[0].startswith('TENANT_ISOLATION_BREACH TENANT_NOT_CANONICAL') and out[1].startswith('STATE'), 'empty tenant: %r' % out)
    code, out, _ = s.serve(p, ['READ tA 0', 'STATE'])
    require(out[0] == 'OK 0', 'zero rows: %r' % out)
    code, out, _ = s.serve(p, ['READ tA 100001'])
    require(out[0].startswith('MALFORMED_REQUEST'), 'too many rows: %r' % out)
    code, out, _ = s.serve(p, ['READ tA 2', rows_ok[0]])
    require(out == ['TENANT_ISOLATION_BREACH ROWS_MISSING 1 of 2 rows came'], 'missing rows: %r' % out)
    big = '{"tenant_id":"tA","p":"%s"}' % ('x' * (MAX_LINE + 10))
    code, out, _ = s.serve(p, ['READ tA 2', big, rows_ok[0], 'STATE'])
    require(out[0].startswith('TENANT_ISOLATION_BREACH ROW 0 OVERSIZED') and out[1].startswith('STATE'), 'oversized row: %r' % out)
    code, out, _ = s.serve(p, [b'READ tA 1', b'{"tenant_id":"tA","s":"\xff"}', b'STATE'])
    require(out[0].startswith('TENANT_ISOLATION_BREACH ROW 0 NOT_UTF8'), 'bad UTF-8: %r' % out)
    return '3 good rows; 15 bad rows refused with 0 rows; bad tenants; zero rows; missing rows; oversized row; stream stays in step'


def case_lines(s):
    p = s.store('lines')
    s.one(p, 'OPEN_MONEY t1 k1 r0 store-refunds 1000', 'COMMITTED')
    good = 'REFUND t1 k1 r1 %s DUPLICATE_CHARGE 5' % s.h(p, 't1', 'k1')
    for size in (MAX_LINE - 1, MAX_LINE, MAX_LINE + 1, MAX_LINE + 2, 4 * MAX_LINE):
        code, out, _ = s.serve(p, [b'X' * size, b'STATE'])
        want = 'MALFORMED_REQUEST OVERSIZED' if size > MAX_LINE else 'MALFORMED_REQUEST UNKNOWN_VERB'
        require(len(out) == 2 and out[0].startswith(want) and out[1].startswith('STATE'), 'line of %d bytes: %r' % (size, [o[:60] for o in out]))
    garbage = [b'\x00', b'\xff\xfe', b'REFUND\tt1', b'refund t1', b'OPEN_MONEY t1 k1 r0 store-refunds 1000\r', b'STATE ', b' STATE', b'',
               ('OPEN_MONEY t1 ké r9 store-refunds 1').encode(), b'GET t1 k1 extra', b'OPEN_LEASE x 01']
    code, out, _ = s.serve(p, garbage + [b'STATE'])
    require(len(out) == len(garbage) + 1 and all(o.startswith('MALFORMED_REQUEST') for o in out[:-1]), 'garbage: %r' % out)
    code, out, _ = s.serve(p, (good + '\nSTATE').encode(), raw=True)
    require(out[0].startswith('COMMITTED') and out[1] == 'MALFORMED_REQUEST NO_LINE_END' and code == 12, 'no line end: %r' % out)
    code, out, _ = s.serve(p, b'', raw=True)
    require(code == 2 and out == [], 'empty input: exit 2')
    require(len(effects(p)) == 2, 'garbage committed something')
    return 'line bounds 65535..262144; 11 garbage lines refused; no line end; empty input'


def case_replay(s):
    p = s.store('replay')
    s.one(p, 'OPEN_MONEY t1 k1 r0 store-refunds 1000', 'COMMITTED')
    s.one(p, 'OPEN_LEASE x1 5', 'LEASE_OPENED')
    s.one(p, 'REFUND t1 k1 x1 %s DUPLICATE_CHARGE 5' % s.h(p, 't1', 'k1'), 'COMMITTED')
    code, out, _ = s.run(['replay', p])
    want = 'REPLAY 2\nEFFECT 1 OPEN_MONEY t1 k1 r0 store-refunds 1000\nEFFECT 3 REFUND t1 k1 x1 DUPLICATE_CHARGE 5 0\n'
    require(code == 0 and out == want, 'replay: %r' % out)
    return 'effects in order; lease records are not effects'


def case_race(s):
    p = s.store('race')
    s.one(p, 'OPEN_MONEY t1 k1 r0 store-refunds 1000', 'COMMITTED')
    h = s.h(p, 't1', 'k1')
    procs = [subprocess.Popen([s.engine, 'serve', p], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=ENV) for _ in range(50)]
    for i, pr in enumerate(procs):
        pr.stdin.write(('REFUND t1 k1 race-%d %s DUPLICATE_CHARGE 600\n' % (i, h)).encode())
    for pr in procs:
        pr.stdin.close()
    answers = []
    for pr in procs:
        answers.append(pr.stdout.read().decode().split(' ')[0])
        pr.stderr.read()
        pr.wait(timeout=120)
    c, st = answers.count('COMMITTED'), answers.count('STALE_STATE_HASH')
    require(c == 1 and st == 49, 'race: %d COMMITTED, %d STALE: %r' % (c, st, sorted(set(answers))))
    require(len([e for e in effects(p) if e.startswith('REFUND')]) == 1, 'WAL effects: %r' % effects(p))
    return '50 processes, one pre_state_hash: 1 COMMITTED, 49 STALE_STATE_HASH, 1 REFUND record'


KILL_POINTS = {'a': False, 'b': False, 'c': True, 'r': True, 'd': True, 'e': True}


def case_kill(s):
    results = []
    for point, durable in KILL_POINTS.items():
        for split in ((None, 1, 40) if point in 'be' else (None,)):
            p = s.store('kill-%s%s' % (point, split or ''))
            s.one(p, 'OPEN_MONEY t1 k1 r0 store-refunds 1000', 'COMMITTED')
            h = s.h(p, 't1', 'k1')
            line = 'REFUND t1 k1 rk %s DUPLICATE_CHARGE 7' % h
            env = dict(ENV, AIRLOCK_KILL_AT=point)
            if split is not None:
                env['AIRLOCK_KILL_SPLIT'] = str(split)
            proc = subprocess.Popen([s.kill_engine, 'serve', p], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
            proc.stdin.write((line + '\n').encode())
            proc.stdin.flush()
            got = proc.stderr.readline()
            require(got == ('AT %s\n' % point).encode(), 'kill point %s not reached: %r' % (point, got))
            proc.send_signal(signal.SIGKILL)
            out = proc.stdout.read().decode()
            proc.wait()
            if point in 'abcrd':
                require(out == '', 'kill at %s: an answer left before the dispatch point: %r' % (point, out))
            else:
                require(out and 'COMMITTED rk '.startswith(out[:13]) and not out.endswith('\n'), 'kill at e: not a strict prefix: %r' % out)
            code, st, _ = s.run(['state', p])  # recovery
            require(code == 0, 'recovery after kill at %s: %d %r' % (point, code, st))
            recs = read_wal(p)  # strict: no half record may stay
            refunds = [e for e in effects(p) if e.startswith('REFUND')]
            require(len(refunds) == (1 if durable else 0), 'kill at %s: %d REFUND records' % (point, len(refunds)))
            require(ratchet_max(p) == len(recs) - 1, 'kill at %s: ratchet %d, records %d' % (point, ratchet_max(p), len(recs)))
            again = s.one(p, line, 'DUPLICATE_REQUEST_ID' if durable else 'COMMITTED')
            results.append(point + (str(split) if split else ''))
    # a kill while a lease CLOSE record is written: the lease is closed or open, never half
    p = s.store('kill-close')
    s.one(p, 'OPEN_MONEY t1 k1 r0 store-refunds 1000', 'COMMITTED')
    s.one(p, 'OPEN_LEASE L1 5', 'LEASE_OPENED')
    proc = subprocess.Popen([s.kill_engine, 'serve', p], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=dict(ENV, AIRLOCK_KILL_AT='b'))
    proc.stdin.write(('REFUND t1 k1 L1 %s NOPE 7\n' % s.h(p, 't1', 'k1')).encode())
    proc.stdin.flush()
    require(proc.stderr.readline() == b'AT b\n', 'kill point b in CLOSE not reached')
    proc.send_signal(signal.SIGKILL)
    proc.wait()
    code, out, _ = s.run(['leases', p])
    require(code == 0 and out == 'LEASES 1\nLEASE L1 5\n', 'torn CLOSE: %r' % out)
    read_wal(p)
    return 'SIGKILL at %s and inside CLOSE: no half record, no answer before both syncs, retry gives the right code' % ','.join(results)


# ------------------------------------------------------------------------------- system-call order (interposer)
# A SIGKILL keeps the page cache, so case kill cannot see a missing sync. These cases load the test interposer
# tests/airlock/interpose.c into the engine process (DYLD_INSERT_LIBRARIES) to record the order of flock, read,
# write, fcntl(F_FULLFSYNC), ftruncate, close and rename, and to make one sync or write fail. What they show: the
# order of the calls in the engine process for the traced requests. Not shown: that the drive stores the data.

INTERPOSER_SOURCE = ROOT / 'tests/airlock/interpose.c'


def interposer(s):
    """The built interposer: --interposer, or a build of tests/airlock/interpose.c with /usr/bin/cc in the work folder."""
    if s.interposer is None:
        out = s.folder('interposer') / 'interpose.dylib'
        p = subprocess.run(['/usr/bin/cc', '-dynamiclib', '-O1', '-Wall', '-Wextra', '-Werror', '-o', str(out), str(INTERPOSER_SOURCE)],
                           capture_output=True, env=ENV)
        require(p.returncode == 0 and out.exists(), 'NOT RUN: the interposer did not build: %r' % p.stderr[-300:])
        s.interposer = str(out)
    return s.interposer


def traced(s, args, stdin=b'', **variables):
    """Runs the engine under the interposer. Returns (exit code, answer lines, events without reads of policy files)."""
    path = s.folder('trace') / 'calls'
    code, out, err = s.run(args, stdin, env=dict(ENV, DYLD_INSERT_LIBRARIES=interposer(s), AIRLOCK_TRACE=str(path), **variables))
    events = path.read_text().splitlines() if path.exists() else []
    require(events, 'NOT RUN: the interposer saw no call (exit %d %r)' % (code, err[-200:]))
    return code, out.split('\n')[:-1], events


def calls(events, parent=None):
    """The durable-order view: no reads, no close of a policy file; lengths of writes and cuts as N (the ratchet entry
    stays 12); the temporary folder of init as TMP and its parent folder as PARENT."""
    out = []
    for e in events:
        t = e.split(' ')
        if t[0] == 'read' or (t[0] == 'close' and t[1].startswith('policy-')):
            continue
        t = ['TMP' if '.init-' in x else 'PARENT' if x == parent else x for x in t]
        if t[0] in ('write', 'ftruncate') and not (t[1] == 'airlock.epoch' and t[2] == '12'):
            t[2] = 'N'
        out.append(' '.join(t[:4] if t[-1] in ('SHORT', 'FAILED') else t[:3]))
    return out


COMMIT_ORDER = ['flock airlock.wal 2', 'write airlock.wal N', 'fullfsync airlock.wal 0', 'write airlock.epoch 12', 'fullfsync airlock.epoch 0',
                'close airlock.wal', 'close airlock.epoch', 'write stdout N']
RECOVERY_ORDER = ['flock airlock.wal 2', 'ftruncate airlock.epoch N', 'ftruncate airlock.wal N', 'fullfsync airlock.wal 0', 'write airlock.epoch 12',
                  'fullfsync airlock.epoch 0', 'close airlock.wal', 'close airlock.epoch', 'write stdout N']


def lock_first(events, what):
    store = [e for e in events if e.split(' ')[1].startswith('airlock.')]
    require(store and store[0] == 'flock airlock.wal 2', '%s: a store file was read before the exclusive lock: %r' % (what, store[:3]))


def case_trace(s):
    # init: every file synced, then the folder, then the rename, then the parent folder, then the answer
    d = s.folder('trace-init')
    target = d / 'store'
    code, out, events = traced(s, ['init', target, '--store-id', 'tr', '--policy', FIX / 'money-parametric.json'])
    want = ['write policy-store-refunds.json N', 'fullfsync policy-store-refunds.json 0', 'write airlock.epoch 12', 'fullfsync airlock.epoch 0',
            'write airlock.wal N', 'fullfsync airlock.wal 0', 'fullfsync TMP 0', 'close airlock.wal', 'close airlock.epoch', 'rename TMP store',
            'fullfsync PARENT 0', 'write stdout N']
    got = calls(events, d.name)
    require(code == 0 and got == want, 'system-call order of init: %r' % got)
    # init with a failed sync: no store, no temporary folder; init works again. Sync 5 is the parent folder after the
    # rename: the engine undoes the store (empties and syncs the WAL, renames the folder back, removes it, syncs the
    # parent again) and answers IO_ERROR.
    for k in (1, 2, 3, 4, 5):
        d = s.folder('trace-init-fail-%d' % k)
        code, out, _ = traced(s, ['init', d / 'store', '--store-id', 'tr', '--policy', FIX / 'money-parametric.json'], AIRLOCK_FAIL_SYNC=str(k))
        left = sorted(x.name for x in d.iterdir())
        require(code == 18 and out[:1] and out[0].startswith('IO_ERROR') and left == [], 'init with a failed sync %d: exit %d %r, left %r' % (k, code, out, left))
        code, out, _ = s.run(['init', d / 'store', '--store-id', 'tr', '--policy', FIX / 'money-parametric.json'])
        require(code == 0, 'init after a failed sync %d: %r' % (k, out))
    # every sync from the parent-folder sync on fails: the undo cannot finish. OUTCOME_UNKNOWN (19); the store is gone,
    # or it stays with an empty WAL that every command refuses (CORRUPT_WAL, 17); never a working store behind a refusal
    d = s.folder('trace-init-fail-from-5')
    code, out, _ = traced(s, ['init', d / 'store', '--store-id', 'tr', '--policy', FIX / 'money-parametric.json'], AIRLOCK_FAIL_SYNC_FROM='5')
    require(code == 19 and out[:1] and out[0].startswith('OUTCOME_UNKNOWN'), 'init whose undo fails: expected OUTCOME_UNKNOWN (19), got exit %d %r' % (code, out))
    if (d / 'store').exists():
        code, out, _ = s.run(['state', d / 'store'])
        require(code == 17, 'init whose undo fails left a store that opens: state exit %d %r' % (code, out))

    p = s.store('trace')
    s.one(p, 'OPEN_MONEY t1 k1 r0 store-refunds 1000 shipping_paid=10', 'COMMITTED')
    h = s.h(p, 't1', 'k1')
    # a commit: lock -> record -> F_FULLFSYNC -> ratchet entry -> F_FULLFSYNC -> files closed (lock released) -> answer
    before = (p / 'airlock.wal').stat().st_size
    code, out, events = traced(s, ['serve', p], ('REFUND t1 k1 c1 %s DUPLICATE_CHARGE 5\n' % h).encode())
    lock_first(events, 'traced commit')
    require(calls(events) == COMMIT_ORDER, 'system-call order of a commit: %r' % calls(events))
    require(code == 0 and len(out) == 1 and out[0].startswith('COMMITTED c1 '), 'traced commit: %d %r' % (code, out))
    written = [int(e.split(' ')[2]) for e in events if e.startswith('write airlock.wal ')]
    require(written == [(p / 'airlock.wal').stat().st_size - before], 'traced commit: the write is not the whole record: %r' % written)
    # a refusal writes nothing and syncs nothing
    code, out, events = traced(s, ['serve', p], ('REFUND t1 k1 c2 %s DUPLICATE_CHARGE 5\n' % h).encode())
    require(out[:1] and out[0].startswith('STALE_STATE_HASH') and calls(events) == ['flock airlock.wal 2', 'close airlock.wal', 'close airlock.epoch', 'write stdout N'],
            'a refusal must not write or sync: %r %r' % (out, calls(events)))
    # a lease close is a durable record with the same order
    s.one(p, 'OPEN_LEASE L1 5', 'LEASE_OPENED')
    h = s.h(p, 't1', 'k1')
    code, out, events = traced(s, ['serve', p], ('REFUND t1 k1 L1 %s NOPE 5\n' % h).encode())
    require(out[:1] and 'LEASE_CLOSED' in out[0] and calls(events) == COMMIT_ORDER, 'system-call order of a lease close: %r %r' % (out, calls(events)))
    # a recovery: lock -> cut the torn tail -> F_FULLFSYNC -> ratchet entry -> F_FULLFSYNC -> answer
    good = files(p)
    (p / 'airlock.wal').write_bytes(good['airlock.wal'] + b'FAR1')
    code, out, events = traced(s, ['state', p])
    lock_first(events, 'traced recovery')
    require(code == 0 and calls(events) == RECOVERY_ORDER and (p / 'airlock.wal').read_bytes() == good['airlock.wal'],
            'system-call order of a recovery: %d %r' % (code, calls(events)))
    # a recovery whose WAL sync fails: refused; the next start recovers
    (p / 'airlock.wal').write_bytes(good['airlock.wal'] + b'FAR1')
    code, out, events = traced(s, ['state', p], AIRLOCK_FAIL_SYNC='1')
    require(code == 18 and out[:1] and out[0].startswith('IO_ERROR'), 'recovery with a failed sync of the WAL must refuse: %d %r' % (code, out))
    code, out, _ = s.run(['state', p])
    require(code == 0, 'recovery after a failed recovery sync: %r' % out)

    # faults of one commit. Two lines each: the stream must end at the fault.
    h = s.h(p, 't1', 'k1')
    req = 'REFUND t1 k1 f1 %s DUPLICATE_CHARGE 5' % h
    lines = (req + '\nOPEN_MONEY t1 k9 f9 store-refunds 5\n').encode()
    for why, variables, answer, stays in (('failed sync of the WAL', dict(AIRLOCK_FAIL_SYNC='1'), 'IO_ERROR', False),
                                          ('failed write of the record', dict(AIRLOCK_FAIL_WRITE='1'), 'IO_ERROR', False),
                                          ('short write of 30 bytes', dict(AIRLOCK_FAIL_WRITE='1', AIRLOCK_SHORT_WRITE='30'), 'IO_ERROR', False),
                                          ('failed sync of the WAL and of the cut', dict(AIRLOCK_FAIL_SYNC_FROM='1'), 'OUTCOME_UNKNOWN', None),
                                          ('failed sync of the ratchet', dict(AIRLOCK_FAIL_SYNC='2'), 'OUTCOME_UNKNOWN', True),
                                          ('failed write of the ratchet entry', dict(AIRLOCK_FAIL_WRITE='2'), 'OUTCOME_UNKNOWN', True)):
        q = s.store('trace-fault')
        s.one(q, 'OPEN_MONEY t1 k1 r0 store-refunds 1000 shipping_paid=10', 'COMMITTED')
        r = req.replace(h, s.h(q, 't1', 'k1'))
        before = files(q)
        code, out, events = traced(s, ['serve', q], lines.replace(req.encode(), r.encode()), **variables)
        require(len(out) == 1 and out[0].split(' ')[0] == answer and code == CODES[answer], '%s: expected one %s line, got exit %d %r' % (why, answer, code, out))
        require(not any(o.startswith('COMMITTED') for o in out), '%s: COMMITTED after a failed sync or write' % why)
        if stays is False:
            require(files(q) == before, '%s: the record must be cut off again (the files changed)' % why)
            s.one(q, r, 'COMMITTED')
        elif stays is True:
            require(len([e for e in effects(q) if e.startswith('REFUND')]) == 1, '%s: the durable record must stay' % why)
            s.one(q, r, 'DUPLICATE_REQUEST_ID')
        require('k9' not in s.run(['replay', q])[1], '%s: the stream went on after the fault' % why)
    return 'order of init, commit, refusal, lease close, recovery; init fails cleanly at syncs 1-5, undo fault 19; 6 commit faults; recovery fault'


def case_dispatch(s):
    """An answer that cannot be written: DISPATCH_FAILED (20); the commit of that line stays; no further line is read."""
    p = s.store('dispatch')
    s.one(p, 'OPEN_MONEY t1 k1 r0 store-refunds 1000', 'COMMITTED')
    lines = ('REFUND t1 k1 d1 %s DUPLICATE_CHARGE 5\nOPEN_MONEY t1 k2 d2 store-refunds 5\n' % s.h(p, 't1', 'k1')).encode()
    proc = subprocess.Popen([s.engine, 'serve', p], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=ENV)
    proc.stdout.close()  # no reader for the answers
    proc.stdin.write(lines)
    proc.stdin.close()
    code = proc.wait(timeout=60)
    proc.stderr.read()
    got = [e.split(' ')[0] + ' ' + e.split(' ')[3] for e in effects(p)]
    require(code == 20, 'no reader for the answers: exit %d, expected 20 (DISPATCH_FAILED)' % code)
    require(got == ['OPEN_MONEY r0', 'REFUND d1'], 'the stream must end at the first answer that could not be written: effects %r' % got)
    return 'no reader: exit 20, the commit stays, the next line is not read'


def case_lock(s):
    """Two waiting processes and one holder of the lock (two-waiter design of Goal 19). No answer may come while the
    holder lives; after its kill exactly one waiter commits and the other is STALE. Waits: 5 s, then 60 s at most."""
    p = s.store('lock')
    s.one(p, 'OPEN_MONEY t1 k1 r0 store-refunds 1000', 'COMMITTED')
    h = s.h(p, 't1', 'k1')
    start = lambda engine, req, env: subprocess.Popen([engine, 'serve', p], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    holder = start(s.kill_engine, 'h', dict(ENV, AIRLOCK_KILL_AT='a'))
    holder.stdin.write(('REFUND t1 k1 holder %s DUPLICATE_CHARGE 5\n' % h).encode())
    holder.stdin.flush()
    require(holder.stderr.readline() == b'AT a\n', 'NOT RUN: the holder did not reach kill point a')
    waiters = []
    for i in (1, 2):
        w = start(s.engine, 'w', ENV)
        w.stdin.write(('REFUND t1 k1 wait-%d %s DUPLICATE_CHARGE 5\n' % (i, h)).encode())
        w.stdin.close()
        waiters.append(w)
    until = time.monotonic() + 5.0  # with the lock no waiter can answer; without it both answer within milliseconds
    while time.monotonic() < until and all(w.poll() is None for w in waiters):
        time.sleep(0.05)
    early = [w.poll() for w in waiters]
    holder.send_signal(signal.SIGKILL)
    holder.wait()
    answers = []
    for w in waiters:
        answers.append(w.stdout.read().decode().split(' ')[0])
        w.stderr.read()
        w.wait(timeout=60)
    require(early == [None, None], 'a waiting process answered while another process held the store lock: exit codes %r, answers %r' % (early, answers))
    require(sorted(answers) == ['COMMITTED', 'STALE_STATE_HASH'], 'exactly one of the two waiting processes may commit: %r' % answers)
    refunds = [e for e in effects(p) if e.startswith('REFUND')]
    require(len(refunds) == 1, 'WAL effects after the kill: %r' % refunds)
    return 'holder at point a; 2 waiters blocked for 5 s; after the kill: 1 COMMITTED, 1 STALE_STATE_HASH'


def case_pin(s):
    """The model pin and O_NOFOLLOW of booking_check.cjs, through the engine and directly. The substituted model and the
    link lie NEXT TO the built model (build/airlock/checker), where Node finds node_modules: a check that fails only
    for a missing module would hide a missing pin. The substituted model is the real model plus one line that makes
    VerifyCertifiedBooking accept everything. Both files are removed at the end of the case."""
    ex = s.node_ok()
    require(MODEL.exists(), 'NOT RUN: the checker model %s is missing' % MODEL)
    sub, link = MODEL.parent / ('substituted-%d.cjs' % os.getpid()), MODEL.parent / ('link-%d.cjs' % os.getpid())
    sub.write_bytes(MODEL.read_bytes() + b'\nmodule.exports.BookingDualCert.__default.VerifyCertifiedBooking = function () { return true; };\n')
    link.symlink_to(MODEL.name)
    try:
        over = json.dumps({'A': [['1', '1', '0'], ['1', '0', '1']], 'c': ['1', '1'], 'w': ['3', '2', '2'], 'x': ['1', '1', '0'], 'y': ['2', '2'],
                           'z': ['0', '0', '0'], 'alpha_bps': '0'}).encode()
        for model, why in ((sub, 'a substituted model'), (link, 'a symbolic link to the model')):
            p = subprocess.run([s.node, HELPERS / 'booking_check.cjs', model], input=over, capture_output=True, env=ENV, timeout=60)
            require(p.returncode == 2 and p.stdout == b'', 'booking_check.cjs must refuse %s (exit 2): exit %d %r' % (why, p.returncode, p.stdout))
        p = subprocess.run([s.node, HELPERS / 'booking_check.cjs', MODEL], input=over, capture_output=True, env=ENV, timeout=60)
        require(p.returncode == 1 and p.stdout == b'REJECT\n', 'control: the pinned model must reject the overbooking: exit %d %r' % (p.returncode, p.stdout))
        q = s.store('pin')
        s.one(q, 'OPEN_INVENTORY t1 inv r0 seats 1,1', 'COMMITTED')
        good = {'A': [['1', '1', '0'], ['1', '0', '1']], 'c': ['1', '1'], 'w': ['3', '2', '2'], 'x': ['0', '1', '1'], 'y': ['2', '2'], 'z': ['0', '0', '0'], 'alpha_bps': '0'}
        for model, why in ((sub, 'a substituted checker model'), (link, 'a symbolic link to the checker model')):
            s.one(q, cert_line(s, q, 'b1', good), 'HELPER_FAILED', ex + ['--checker', model])
        s.one(q, cert_line(s, q, 'b1', good), 'COMMITTED', ex + ['--checker', MODEL])
    except Failed as e:
        raise Failed('the model pin or O_NOFOLLOW: %s' % e)
    finally:
        sub.unlink(missing_ok=True)
        link.unlink(missing_ok=True)
    return 'substituted model and link refused directly and through the engine (HELPER_FAILED); the pinned model commits'


# ------------------------------------------------------------------------------- crafted files and stand-in helpers
def wal_record(epoch, prev, payload):
    """A record in the layout of PROTOCOL.md section 4, written by the suite (CRC and chain correct)."""
    head = b'FAR1' + struct.pack('<Q', epoch) + prev.to_bytes(16, 'little') + struct.pack('<I', len(payload)) + payload
    return head + struct.pack('<I', zlib.crc32(head) & 0xffffffff)


def ratchet_entry(value):
    v = struct.pack('<Q', value)
    return v + struct.pack('<I', zlib.crc32(v) & 0xffffffff)


def case_crafted(s):
    """Records with a correct CRC and chain that the fold must still refuse (CORRUPT_WAL), and a ratchet whose last
    entry is lower than its highest entry (the highest one counts: EPOCH_REGRESSION)."""
    p = s.store('crafted')
    s.one(p, 'OPEN_MONEY t1 k1 r0 store-refunds 1000', 'COMMITTED')
    s.one(p, 'OPEN_INVENTORY t1 inv r1 seats 3', 'COMMITTED')
    good = files(p)
    recs = read_wal(p)
    epoch, tail = recs[-1][0] + 1, recs[-1][2]

    def restore():
        for n, b in good.items():
            (p / n).write_bytes(b)
    restore()
    (p / 'airlock.wal').write_bytes(good['airlock.wal'] + wal_record(epoch, tail, b'REFUND t1 k1 x1 DUPLICATE_CHARGE 1 0'))
    code, out, _ = s.run(['state', p])
    require(code == 0 and out.startswith('STATE %d ' % epoch), 'control: a valid crafted record must be adopted: %d %r' % (code, out))
    bad = {'a refund above the remaining amount': b'REFUND t1 k1 x1 DUPLICATE_CHARGE 1001 0',
           'a refund under another tenant': b'REFUND t2 k1 x1 DUPLICATE_CHARGE 1 0',
           'a refund with a used request id': b'REFUND t1 k1 r0 DUPLICATE_CHARGE 1 0',
           'a zero refund': b'REFUND t1 k1 x1 DUPLICATE_CHARGE 0 0',
           'a close with no open lease': b'CLOSE x1 REJECTED_POLICY NO_RULE',
           'a booking that raises the remaining capacity': b'BOOK t1 inv x1 1 4',
           'a second open of a key': b'OPEN_MONEY t1 k1 x1 store-refunds 5'}
    for why, payload in bad.items():
        restore()
        (p / 'airlock.wal').write_bytes(good['airlock.wal'] + wal_record(epoch, tail, payload))
        code, out, _ = s.run(['state', p])
        require(code == 17 and out.startswith('CORRUPT_WAL'), 'crafted record (%s) must be CORRUPT_WAL: %d %r' % (why, code, out))
    restore()
    (p / 'airlock.epoch').write_bytes(good['airlock.epoch'] + ratchet_entry(epoch + 7) + ratchet_entry(1))
    code, out, _ = s.run(['state', p])
    require(code == 15 and out.startswith('EPOCH_REGRESSION'), 'a ratchet whose last entry is lower than its highest: %d %r' % (code, out))
    restore()
    return '1 crafted record adopted; %d crafted records refused by the fold; ratchet maximum, not last entry' % len(bad)


def case_native_bound(s):
    """STAND-IN refund binaries (test doubles of the helper process) that accept what the native check must refuse:
    an amount above the remaining amount, and a reason outside the three approved reasons."""
    p = s.store('native-bound', policies=('money-canonical',))
    s.one(p, 'OPEN_MONEY t1 charge-1 r0 canonical 100', 'COMMITTED')
    h = s.h(p, 't1', 'charge-1')
    d = s.standin('accepts', {
        'over': "#!/bin/sh\ncat > /dev/null\nprintf '%s' '(refund-result-v1 True 101 returned_item charge-1 rq-o 1)'\n",
        'reason': "#!/bin/sh\ncat > /dev/null\nprintf '%s' '(refund-result-v1 True 5 goodwill charge-1 rq-r 1)'\n"})
    for name, line in (('over', 'REFUND t1 charge-1 rq-o %s returned_item 101' % h), ('reason', 'REFUND t1 charge-1 rq-r %s goodwill 5' % h)):
        code, out, _ = s.serve(p, [line], ['--refund-binary', d / name])
        require(code == 23 and out[:1] and out[0].startswith('BAD_FRAME'), 'a binary that accepts %s: expected BAD_FRAME (exit 23), got exit %d %r' % (
            'above the remaining amount' if name == 'over' else 'an unapproved reason', code, out))
    require(len(effects(p)) == 1, 'a stand-in accept committed: %r' % effects(p))
    return 'stand-in accepts above remaining and with an unapproved reason -> BAD_FRAME; 0 effects'


def case_helper_env(s):
    """A variable of the engine environment must not reach a helper process (cleared environment). STAND-IN helpers
    say VALID / accept only when the probe variable reaches them."""
    ex = s.node_ok()
    env = dict(ENV, AIRLOCK_LEAK_PROBE='1')
    d = s.standin('env', {
        'cosign.cjs': 'const v = process.env.AIRLOCK_LEAK_PROBE; process.stdout.write(v ? "VALID\\n" : "INVALID\\n"); process.exitCode = v ? 0 : 1;',
        'refund': "#!/bin/sh\ncat > /dev/null\nif [ -n \"$AIRLOCK_LEAK_PROBE\" ]; then printf '%s' '(refund-result-v1 True 5 returned_item charge-1 rq-e 1)'; "
                  "else printf '%s' '(refund-result-v1 False 0 \"\" \"\" \"\" 0)'; fi\n"})
    p = s.store('helper-env', pubkey='ab' * 32)
    s.one(p, 'OPEN_MONEY t1 o1 r0 store-refunds 10000', 'COMMITTED')
    line = 'REFUND t1 o1 g1 %s GOODWILL 7500 %s' % (s.h(p, 't1', 'o1'), 'c' * 128)
    code, out, _ = s.serve(p, [line], ['--node', s.node, '--helpers', d], env=env)
    require(out[:1] and out[0] == 'REQUIRE_HUMAN_COSIGN COSIGN_INVALID', 'the cosign helper saw a variable of the engine environment: exit %d %r' % (code, out))
    q = s.store('helper-env-c', policies=('money-canonical',))
    s.one(q, 'OPEN_MONEY t1 charge-1 r0 canonical 100', 'COMMITTED')
    code, out, _ = s.serve(q, ['REFUND t1 charge-1 rq-e %s returned_item 5' % s.h(q, 't1', 'charge-1')], ['--refund-binary', d / 'refund'], env=env)
    require(out[:1] and out[0] == 'REJECTED_POLICY CAKEML_REJECTED', 'the refund binary saw a variable of the engine environment: exit %d %r' % (code, out))
    require(len(effects(p)) == 1 and len(effects(q)) == 1, 'a helper with a leaked variable committed')
    return 'probe variable in the engine environment reached neither the cosign helper nor the refund binary'


CASES = [('init', case_init), ('recovery', case_recovery), ('cas', case_cas), ('tenant', case_tenant), ('money', case_money),
         ('canonical', case_canonical), ('cosign', case_cosign), ('saga', case_saga), ('inventory', case_inventory), ('leases', case_leases),
         ('read', case_read), ('lines', case_lines), ('replay', case_replay), ('race', case_race), ('kill', case_kill),
         ('trace', case_trace), ('dispatch', case_dispatch), ('lock', case_lock), ('pin', case_pin),
         ('crafted', case_crafted), ('native_bound', case_native_bound), ('helper_env', case_helper_env)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('engine')
    ap.add_argument('kill_engine')
    ap.add_argument('--case', action='append', choices=[n for n, _ in CASES])
    ap.add_argument('--node', default='/opt/homebrew/bin/node')
    ap.add_argument('--work', default=None)
    ap.add_argument('--interposer', default=None, help='a built tests/airlock/interpose.c (else the trace case builds it)')
    ap.add_argument('--keep', action='store_true')
    a = ap.parse_args()
    for b in (a.engine, a.kill_engine):
        if not Path(b).exists():
            print('cannot start: %s is missing' % b)
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
                print('PASS %-10s %5.1fs %s' % (name, time.time() - t, detail), flush=True)
            except Failed as e:
                failed += 1
                print('FAIL %-10s %5.1fs %s' % (name, time.time() - t, e), flush=True)
            except Exception as e:  # a fault of the suite is a failure, never a pass
                failed += 1
                print('FAIL %-10s %5.1fs suite error %s: %s' % (name, time.time() - t, type(e).__name__, e), flush=True)
    finally:
        if not a.keep:
            shutil.rmtree(s.work, ignore_errors=True)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
