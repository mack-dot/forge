#!/usr/bin/env python3
"""Fault-injection suite of the native silicon sink (goal 19, Phase 3).

A FINITE TEST on one machine. It proves nothing. A SIGKILL is not a power loss: the page cache survives it.
The order of the durable writes is therefore observed at the system-call boundary with a dyld interposer
(tests/silicon_sink/interpose.c), and a failed sync is injected there.

The suite gets every executable as an argument, so that the same checks run on changed copies of the sink
(scripts/exit_silicon_sink.py, case mutations). It reads the ledger files with its OWN transcription of the
record format (zlib CRC-32, FNV-1a-128 in Python). After every commit it reads both files directly, before
the sink runs again. After a kill or a damaged file it first starts the sink once (its recovery) and then
reads the files. That transcription and the sink can be wrong in the same way.

Cases: basic, conformance, frames, ids, recovery, rollback, trace, dispatch, lock, crash, race, flood, latency.
Exit code 0: every selected case passed. 1: at least one case failed. 2: the suite could not run.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import random
import resource
import select
import shutil
import struct
import subprocess
import sys
import time
import traceback
import zlib

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
RECORDED = ROOT / 'tests/m1-conformance/recorded-m1-cases.json'
RECORDED_SHA256 = 'cc5543460c0577561c60b0f3850f47ef0bfc4a59b48365f2946f89e343a7911f'
BINARY_SHA256 = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
REC = 64
MAX_MONEY = 9223372036854775807
REASONS = ['duplicate_charge', 'service_not_delivered', 'returned_item']
REJECT_FRAME = b'(refund-result-v1 False 0 "" "" "" 0)'
COMMITTED, USAGE, CAKEML_REJECTED, BAD_FRAME, MALFORMED_ID, STALE, DUPLICATE, EPOCH_REGRESSION = 0, 2, 10, 11, 12, 13, 14, 15
MALFORMED_REQUEST, CORRUPT_WAL, IO_ERROR, OUTCOME_UNKNOWN, DISPATCH_FAILED = 16, 17, 18, 19, 20
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}
KILL_POINTS = ['a', 'b', 'c', 'r', 'd', 'e']
# a: before the WAL write; b: inside the record; c: after the write, before the sync; r: after the WAL sync,
# before the ratchet; d: after both syncs, before the dispatch; e: inside the dispatch line.
COMMITTED_AT = {'a': False, 'b': False, 'c': True, 'r': True, 'd': True, 'e': True}
LATENCY_BOUND_MS = 250.0
FLOOD_RSS_BOUND = 50 * 1024 * 1024
FNV_OFFSET, FNV_PRIME, MASK128 = 0x6c62272e07bb014262b821756295c58d, 0x0000000001000000000000000000013b, (1 << 128) - 1


class Failed(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Failed(message)


# ---------------------------------------------------------------------------------------------------------
# The suite's own reading of the two files (a transcription of the record format; not the sink's code).

def fnv128(data):
    value = FNV_OFFSET
    for byte in data:
        value = ((value ^ byte) * FNV_PRIME) & MASK128
    return value


def canonical_id(data):
    return 1 <= len(data) <= 24 and all(chr(b).isascii() and (chr(b).isalnum() or b in b'_-') for b in data)


def record(kind, epoch, pre, ident, amount):
    body = b'FSW' + kind + struct.pack('<Q', epoch) + pre.to_bytes(16, 'little') + ident.ljust(24, b'\0') + struct.pack('<Q', amount)
    return body + struct.pack('<I', zlib.crc32(body) & 0xffffffff)


def read_wal(ledger):
    """Strict: every byte of the file must belong to a valid record."""
    data = (Path(ledger) / 'ledger.wal').read_bytes()
    require(len(data) >= REC and len(data) % REC == 0, 'WAL: %d bytes is not a whole number of records' % len(data))
    state = {'effects': [], 'ids': set(), 'tail': 0, 'bytes': data, 'hashes': []}
    for index in range(len(data) // REC):
        r = data[index * REC:(index + 1) * REC]
        ident = r[28:52].split(b'\0')[0]
        amount, epoch = struct.unpack('<Q', r[52:60])[0], struct.unpack('<Q', r[4:12])[0]
        require(r[:3] == b'FSW' and struct.unpack('<I', r[60:])[0] == zlib.crc32(r[:60]) & 0xffffffff, 'WAL record %d: magic or CRC' % index)
        require(epoch == index and int.from_bytes(r[12:28], 'little') == state['tail'], 'WAL record %d: epoch or chain' % index)
        require(canonical_id(ident) and r[28 + len(ident):52] == b'\0' * (24 - len(ident)), 'WAL record %d: id' % index)
        if index == 0:
            require(r[3:4] == b'G' and amount <= MAX_MONEY, 'WAL record 0: not a genesis record')
            state.update(charge=ident.decode(), original=amount, remaining=amount)
        else:
            require(r[3:4] in (b'1', b'2', b'3') and amount <= state['remaining'], 'WAL record %d: kind or amount' % index)
            require(ident not in state['ids'], 'WAL record %d: request id %r is committed twice' % (index, ident))
            state['ids'].add(ident)
            state['remaining'] -= amount
            state['effects'].append((REASONS[r[3] - ord('1')], ident.decode(), amount))
        state['tail'], state['epoch'] = fnv128(r), index
        state['hashes'].append(state['tail'])
    return state


def ratchet_max(ledger):
    data = (Path(ledger) / 'ledger.epoch').read_bytes()
    require(len(data) % 12 == 0, 'ratchet: %d bytes is not a whole number of entries' % len(data))
    entries = [data[i:i + 12] for i in range(0, len(data), 12)]
    valid = [struct.unpack('<Q', e[:8])[0] for e in entries if struct.unpack('<I', e[8:])[0] == zlib.crc32(e[:8]) & 0xffffffff]
    require(valid, 'ratchet: no valid entry')
    return max(valid)


def frame(amount, reason, charge, request):
    return '(refund-result-v1 True %s %s %s %s 1)' % (amount, reason, charge, request)


# ---------------------------------------------------------------------------------------------------------
# Processes.

class Suite:
    def __init__(self, args):
        self.sink, self.kill_sink, self.binary = args.sink, args.kill_sink, args.binary
        self.interposer, self.work, self.quick = args.interposer, Path(args.work).resolve(), args.quick
        self.seed, self.flood_bytes = args.seed, args.flood_bytes
        self.counter = 0

    def folder(self, name):
        self.counter += 1
        path = self.work / ('%03d-%s' % (self.counter, name))
        path.mkdir(parents=True)
        return path

    def ledger(self, name, charge='charge-1', original=1000):
        path = str(self.folder(name))
        done = subprocess.run([self.sink, path, 'init', charge, str(original)], capture_output=True, env=ENV, timeout=60)
        require(done.returncode == 0 and done.stdout.startswith(b'STATE 0 '), 'init %s: exit %d, %r %r' % (name, done.returncode, done.stdout, done.stderr))
        return path

    def clone(self, ledger, name):
        path = self.folder(name)
        for part in ('ledger.wal', 'ledger.epoch'):
            shutil.copyfile(Path(ledger) / part, path / part)
        return str(path)

    def serve(self, ledger, lines, sink=None, binary=None, env=None, timeout=120):
        data = b''.join(line if isinstance(line, bytes) else line.encode() for line in lines)
        done = subprocess.run([sink or self.sink, ledger, 'serve', binary or self.binary], input=data, capture_output=True,
                              env=ENV if env is None else env, timeout=timeout)
        return done.returncode, done.stdout, done.stderr

    def start(self, ledger, line, sink=None, env=None):
        process = subprocess.Popen([sink or self.sink, ledger, 'serve', self.binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, env=ENV if env is None else env)
        if line is not None:
            process.stdin.write(line.encode())
            process.stdin.close()
        return process

    def command(self, ledger, name):
        done = subprocess.run([self.sink, ledger, name], capture_output=True, env=ENV, timeout=120)
        return done.returncode, done.stdout

    def state(self, ledger):
        code, out = self.command(ledger, 'state')
        if code != 0:
            return code, None
        fields = out.decode().split()
        require(len(fields) == 6 and fields[0] == 'STATE', 'state: unexpected output %r' % out)
        return 0, {'epoch': int(fields[1]), 'tail': fields[2], 'charge': fields[3], 'original': int(fields[4]), 'remaining': int(fields[5])}

    def must_state(self, ledger):
        code, state = self.state(ledger)
        require(code == 0, 'state: exit %d' % code)
        return state


def finish(process):
    out, err = process.stdout.read(), process.stderr.read()
    return process.wait(), out, err


def request(state, request_id, amount, reason='returned_item', flags=(True, True, True), **changed):
    value = dict(state, **changed)
    return '%s (%s %s %s %s %s %s %s)\n' % (value['tail'], value['charge'], request_id, value['original'], value['remaining'],
                                            ' '.join('True' if flag else 'False' for flag in flags), amount, reason)


def files(ledger):
    return (Path(ledger) / 'ledger.wal').read_bytes(), (Path(ledger) / 'ledger.epoch').read_bytes()


def committed_lines(out):
    """Complete COMMITTED lines only: a dispatch is a whole line."""
    return [line for line in out.split(b'\n')[:-1] if line.startswith(b'COMMITTED ')]


def expect(suite, ledger, line, code, what, **options):
    """One request. A commit must add exactly one record and one COMMITTED line; a refusal must change nothing."""
    before = files(ledger)
    got, out, err = suite.serve(ledger, [line], **options)
    require(got == code, '%s: exit %d, expected %d; stdout %r stderr %r' % (what, got, code, out[:300], err[:300]))
    if code == COMMITTED:
        require(len(committed_lines(out)) == 1 and out.count(b'\n') == 1, '%s: not exactly one COMMITTED line: %r' % (what, out))
        require(len(files(ledger)[0]) == len(before[0]) + REC, '%s: the WAL did not grow by one record' % what)
        # The files as the commit left them, before the sink runs again: the record is the request that was sent.
        sent = (line.decode() if isinstance(line, bytes) else line).strip().replace('(', '').replace(')', '').split(' ')
        wal = read_wal(ledger)
        require(wal['effects'][-1] == (sent[9], sent[2], int(sent[8])), '%s: the record %r is not the request that was sent' % (what, wal['effects'][-1]))
        require(wal['charge'] == sent[1] and wal['remaining'] == int(sent[4]) - int(sent[8]) and wal['bytes'][:len(before[0])] == before[0],
                '%s: charge, remaining amount or earlier records are wrong after the commit' % what)
        require(ratchet_max(ledger) == wal['epoch'], '%s: after the commit the ratchet is %d and the WAL epoch %d' % (what, ratchet_max(ledger), wal['epoch']))
        require(out.decode() == 'COMMITTED %d %032x %s\n' % (wal['epoch'], wal['tail'], frame(sent[8], sent[9], sent[1], sent[2])), '%s: COMMITTED line %r' % (what, out))
    else:
        require(not committed_lines(out), '%s: a refusal printed a COMMITTED line: %r' % (what, out))
        require(out.startswith(b'REJECT %d ' % code), '%s: no REJECT %d line: %r' % (what, code, out))
        require(files(ledger) == before, '%s: a refusal changed the ledger files' % what)
    return out


def check_ledger(suite, ledger, what):
    """Start the sink once (its recovery), then read both files with the suite's own reader."""
    state = suite.must_state(ledger)
    try:
        wal = read_wal(ledger)
        top = ratchet_max(ledger)
    except Failed as error:
        raise Failed('%s: after recovery: %s' % (what, error))
    seen = (wal['epoch'], '%032x' % wal['tail'], wal['charge'], wal['original'], wal['remaining'])
    require(seen == (state['epoch'], state['tail'], state['charge'], state['original'], state['remaining']),
            '%s: the sink reports %r, the files hold %r' % (what, state, seen))
    require(top == wal['epoch'], '%s: ratchet %d, WAL epoch %d' % (what, top, wal['epoch']))
    require(sum(effect[2] for effect in wal['effects']) == wal['original'] - wal['remaining'], '%s: money does not add up' % what)
    code, out = suite.command(ledger, 'replay')
    lines = ['REPLAY %d' % len(wal['effects'])] + ['EFFECT ' + frame(a, reason, wal['charge'], rid) for reason, rid, a in wal['effects']]
    require(code == 0 and out.decode() == '\n'.join(lines) + '\n', '%s: replay differs from the committed effects' % what)
    return wal


# ---------------------------------------------------------------------------------------------------------
# Cases.

def case_basic(suite):
    ledger = suite.ledger('basic', original=100)
    state = suite.must_state(ledger)
    require(state == {'epoch': 0, 'tail': '%032x' % fnv128(record(b'G', 0, 0, b'charge-1', 100)), 'charge': 'charge-1', 'original': 100, 'remaining': 100},
            'genesis state %r' % state)
    again = subprocess.run([suite.sink, ledger, 'init', 'charge-2', '5'], capture_output=True, env=ENV)
    require(again.returncode == IO_ERROR and read_wal(ledger)['charge'] == 'charge-1', 'a second init must fail and leave the ledger')
    for bad in (['x'], [ledger], [ledger, 'serve'], [ledger, 'state', 'extra'], [ledger, 'init', 'c'], []):
        require(subprocess.run([suite.sink] + bad, capture_output=True, env=ENV).returncode == USAGE, 'usage: %r' % bad)
    for charge, original in (('', '1'), ('a b', '1'), ('x' * 25, '1'), ('c', '01'), ('c', '-1'), ('c', str(MAX_MONEY + 1)), ('c', '')):
        folder = str(suite.folder('bad-init'))
        done = subprocess.run([suite.sink, folder, 'init', charge, original], capture_output=True, env=ENV)
        require(done.returncode == MALFORMED_ID and not os.listdir(folder), 'init %r %r must be refused' % (charge, original))
    # init beside one leftover file: refused; it makes no file and no working ledger.
    for leftover in ('ledger.epoch', 'ledger.wal'):
        folder = suite.folder('leftover-init')
        (folder / leftover).write_bytes(files(ledger)[leftover == 'ledger.epoch'])
        done = subprocess.run([suite.sink, str(folder), 'init', 'charge-9', '7'], capture_output=True, env=ENV)
        require(done.returncode == IO_ERROR and os.listdir(folder) == [leftover], 'init beside a leftover %s: exit %d, files %r' % (leftover, done.returncode, os.listdir(folder)))
        require(suite.state(str(folder))[0] == IO_ERROR, 'a folder with only %s must not be a working ledger' % leftover)
    # The rejection frame (37 bytes) is longer than the accept frame of a short request: it must still be read as a rejection.
    short = suite.ledger('basic-short', charge='c', original=5)
    expect(suite, short, request(suite.must_state(short), 'r', 1, 'x'), CAKEML_REJECTED, 'short request with a reason that is not approved')
    expect(suite, short, request(suite.must_state(short), 'r', 6, 'x'), CAKEML_REJECTED, 'short request above the remaining amount')
    # Commits with each reason; the COMMITTED line carries the exact frame and the new tail.
    spent = 0
    for index, reason in enumerate(REASONS):
        out = expect(suite, ledger, request(state, 'rq-%d' % index, 10 + index, reason), COMMITTED, 'commit ' + reason)
        spent += 10 + index
        state = suite.must_state(ledger)
        require(out.decode() == 'COMMITTED %d %s %s\n' % (index + 1, state['tail'], frame(10 + index, reason, 'charge-1', 'rq-%d' % index)), 'COMMITTED line %r' % out)
        require(state['remaining'] == 100 - spent and state['epoch'] == index + 1, 'state after commit %r' % state)
    # Refusals. Each must leave both files byte-identical (checked in expect).
    expect(suite, ledger, request(state, 'rq-0', 1), DUPLICATE, 'committed id again')
    expect(suite, ledger, request(state, 'rq-0', 1, tail='0' * 32), DUPLICATE, 'committed id again with an old hash')
    expect(suite, ledger, request(state, 'rq-new', 1, tail='0' * 32), STALE, 'wrong state hash')
    expect(suite, ledger, request(state, 'rq-new', 1, tail='%032x' % fnv128(b'x')), STALE, 'another state hash')
    expect(suite, ledger, request(state, 'rq-new', 1, remaining=state['remaining'] + 1), STALE, 'claims one more than remains')
    expect(suite, ledger, request(state, 'rq-new', 1, remaining=100), STALE, 'claims the full original amount remains')
    expect(suite, ledger, request(state, 'rq-new', 1, remaining=state['remaining'] - 1), STALE, 'claims less than remains')
    expect(suite, ledger, request(state, 'rq-new', 100, remaining=100), STALE, 'claims 100 remain and asks for 100')
    expect(suite, ledger, request(state, 'rq-new', 1, original=101), STALE, 'claims another original amount')
    expect(suite, ledger, request(state, 'rq-new', 1, charge='charge-2'), STALE, 'names another charge')
    expect(suite, ledger, request(state, 'rq-new', state['remaining'] + 1), CAKEML_REJECTED, 'amount above remaining')
    expect(suite, ledger, request(state, 'rq-new', 1, 'other'), CAKEML_REJECTED, 'reason not approved')
    expect(suite, ledger, request(state, 'rq-new', 1, 'Returned_item'), CAKEML_REJECTED, 'reason in another case')
    expect(suite, ledger, request(state, 'rq-new', 1, 'returned_items'), CAKEML_REJECTED, 'reason with a suffix')
    for flags in ((False, True, True), (True, False, True), (True, True, False), (False, False, False)):
        expect(suite, ledger, request(state, 'rq-new', 1, flags=flags), CAKEML_REJECTED, 'flags %r' % (flags,))
    good = request(state, 'rq-new', 1)
    hash_, wire = good.rstrip('\n').split(' ', 1)
    malformed = [wire + '\n', hash_ + wire + '\n', hash_.upper().replace('0', 'A') + ' ' + wire + '\n', hash_[:31] + ' ' + wire + '\n', hash_ + '0 ' + wire + '\n',
                 hash_ + '  ' + wire + '\n', ' ' + good, hash_ + ' ' + wire + ' \n', hash_ + ' ' + wire[1:] + '\n', hash_ + ' ' + wire[:-1] + '\n',
                 hash_ + ' ' + wire.replace(' ', '  ', 1) + '\n', hash_ + ' ' + wire.replace(' ', '\t') + '\n', good.rstrip('\n') + '\r\n', '\n', ' \n', '()\n',
                 hash_ + ' ()\n', hash_ + ' ' + wire[:-1] + ' extra)\n', hash_ + ' ' + wire.replace(' returned_item', '') + '\n',
                 hash_ + ' ' + wire.replace('True True True', 'true True True') + '\n', hash_ + ' ' + wire.replace('True True True', '1 1 1') + '\n',
                 good.rstrip('\n').encode() + b'\xff\n', b'\xff\xfe' + good.encode(), good.replace('returned_item', 'returned item'), good.replace('returned_item', '"returned_item"')]
    for amount in ('01', '+1', '-1', '~1', '1.0', '1e0', '0x1', ' 1', '', str(MAX_MONEY + 1), '9' * 20, '١'):
        malformed.append(request(state, 'rq-new', amount))
        malformed.append(request(state, 'rq-new', 1, remaining=amount))
        malformed.append(request(state, 'rq-new', 1, original=amount))
    for index, line in enumerate(malformed):
        expect(suite, ledger, line, MALFORMED_REQUEST, 'malformed line %d %r' % (index, line[:80]))
    expect(suite, ledger, good.rstrip('\n'), MALFORMED_REQUEST, 'a line with no line end')
    # Stream mode: several lines, one answer per line, exit code of the last line.
    before = files(ledger)
    lines = [request(state, 'rq-s1', 1), 'garbage\n', request(state, 'rq-s2', 1), request(state, 'rq-0', 1)]
    code, out, _ = suite.serve(ledger, lines)
    answers = out.split(b'\n')
    require(code == DUPLICATE and len(answers) == 5 and answers[0].startswith(b'COMMITTED ') and answers[1].startswith(b'REJECT 16 ')
            and answers[2].startswith(b'REJECT 13 ') and answers[3].startswith(b'REJECT 14 '), 'stream answers %r exit %d' % (answers, code))
    require(len(files(ledger)[0]) == len(before[0]) + REC, 'stream: exactly one record')
    code, out, _ = suite.serve(ledger, [])
    require(code == USAGE and out == b'', 'no request line: exit %d' % code)
    # Line lengths at the bound: 255 bytes is a (malformed) line; 256 and more is OVERSIZED; the next line is always read.
    for length in (254, 255, 256, 257, 511, 512, 4096):
        work = suite.clone(ledger, 'basic-length')
        code, out, _ = suite.serve(work, [b'y' * length + b'\n', request(suite.must_state(work), 'rq-len', 1)])
        answers = out.split(b'\n')
        require(code == 0 and len(answers) == 3 and answers[0].startswith(b'REJECT 16 ') and (b'OVERSIZED' in answers[0]) == (length > 255)
                and answers[1].startswith(b'COMMITTED '), 'a line of %d bytes and then a valid request: exit %d, answers %r' % (length, code, answers))
    # Zero is an approved amount: it commits, and it changes the state hash.
    state = suite.must_state(ledger)
    expect(suite, ledger, request(state, 'rq-zero', 0), COMMITTED, 'zero amount')
    expect(suite, ledger, request(state, 'rq-zero-2', 0), STALE, 'second zero amount on the old hash')
    # Money bounds: the full amount, then nothing more.
    top = suite.ledger('basic-max', original=MAX_MONEY)
    state = suite.must_state(top)
    expect(suite, top, request(state, 'rq-all', MAX_MONEY), COMMITTED, 'refund of MaxMoney')
    state = suite.must_state(top)
    require(state['remaining'] == 0, 'remaining after the full refund')
    expect(suite, top, request(state, 'rq-more', 1), CAKEML_REJECTED, 'one more unit')
    expect(suite, top, request(state, 'rq-nil', 0), COMMITTED, 'zero on an empty charge')
    wal = check_ledger(suite, ledger, 'basic')
    check_ledger(suite, top, 'basic-max')
    return {'commits': len(wal['effects']) + 2, 'malformed_lines': len(malformed) + 1, 'wal_sha256': hashlib.sha256(wal['bytes']).hexdigest()}, {}


def reference_eligible(original, remaining, flags, amount, reason):
    """A transcription of the refund rule for requests inside the sink's grammar. Not proved; a third opinion."""
    return all(flags) and 0 <= remaining <= original <= MAX_MONEY and 0 <= amount <= remaining and reason in REASONS


def case_conformance(suite):
    raw = RECORDED.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == RECORDED_SHA256, 'the recorded fixture file is not the pinned one')
    classes = {'committed_with_hol_bytes': 0, 'rejected_by_binary': 0, 'refused_by_sink_grammar': 0}
    templates = {}

    def prepared(charge, original, remaining):
        """A ledger in the state (charge, original, remaining). The set-up refund goes through the sink too."""
        key = (charge, original, remaining)
        if key not in templates:
            ledger = suite.ledger('conf', charge=charge, original=original)
            if remaining < original:
                expect(suite, ledger, request(suite.must_state(ledger), 'zz-setup', original - remaining), COMMITTED, 'set-up refund')
            templates[key] = ledger
        return templates[key]

    for fixture in json.loads(raw)['typed']:
        v, name = fixture['inputs'], fixture['name']
        fields = [v['charge'], v['request'], v['original'], v['remaining'], v['amount'], v['reason']]
        numbers = [v['original'], v['remaining'], v['amount']]
        in_grammar = (canonical_id(v['charge'].encode()) and canonical_id(v['request'].encode()) and canonical_id(v['reason'].encode())
                      and all(n.isascii() and n.isdigit() and str(int(n)) == n and int(n) <= MAX_MONEY for n in numbers))
        flags = (v['enabled'], v['opened'], v['candidate'])
        if not in_grammar:
            # The sink is narrower than the binary: it refuses these lines itself, before the binary runs.
            ledger = prepared('charge-1', 100, 60)
            state = suite.must_state(ledger)
            line = ('%s (%s %s %s %s %s %s %s)\n' % (state['tail'], fields[0], fields[1], fields[2], fields[3],
                                                    ' '.join('True' if flag else 'False' for flag in flags), fields[4], fields[5])).encode()
            before = files(ledger)
            code, out, _ = suite.serve(ledger, [line])
            answers = out.split(b'\n')[:-1]
            require(answers and all(a.startswith((b'REJECT 12 ', b'REJECT 16 ')) for a in answers) and files(ledger) == before,
                    'fixture %s: outside the grammar, but not refused by the sink: %r' % (name, out))
            classes['refused_by_sink_grammar'] += 1
            continue
        original, remaining, amount = (int(n) for n in numbers)
        state_possible = 0 <= remaining <= original
        ledger = prepared(v['charge'], original, remaining) if state_possible else prepared(v['charge'], original, original)
        if fixture['expected']['ok']:
            ledger = suite.clone(ledger, 'conf-' + name)
        state = dict(suite.must_state(ledger), remaining=remaining)
        line = request(state, v['request'], amount, v['reason'], flags)
        require(fixture['expected']['ok'] == reference_eligible(original, remaining, flags, amount, v['reason']), 'fixture %s: the reference disagrees with the record' % name)
        if fixture['expected']['ok']:
            out = expect(suite, ledger, line, COMMITTED, 'fixture ' + name)
            require(out.split(b' ', 3)[3].rstrip(b'\n') == bytes.fromhex(fixture['hol_stdout_hex']), 'fixture %s: frame differs from the HOL-written bytes' % name)
            classes['committed_with_hol_bytes'] += 1
        else:
            expect(suite, ledger, line, CAKEML_REJECTED, 'fixture ' + name)
            classes['rejected_by_binary'] += 1
    # Boundary vectors inside the grammar. The expected answer comes from the reference predicate.
    vectors = []
    for original in (0, 1, 100, MAX_MONEY):
        for remaining in sorted({0, 1, original // 2, original - 1, original} & set(range(0, original + 1)) if original < 1000 else {0, 1, original - 1, original}):
            for amount in sorted({0, 1, remaining - 1, remaining, remaining + 1, original, MAX_MONEY} - {-1, MAX_MONEY + 1}):
                vectors.append((original, remaining, (True, True, True), amount, 'returned_item'))
            for flags in [(a, b, c) for a in (True, False) for b in (True, False) for c in (True, False)][1:]:
                vectors.append((original, remaining, flags, 0, 'duplicate_charge'))
            for reason in REASONS + ['returned_items', 'Returned_item', 'returned-item', 'duplicate', 'other', 'True', '0', 'refund-result-v1']:
                vectors.append((original, remaining, (True, True, True), min(1, remaining), reason))
    accepted = 0
    for index, (original, remaining, flags, amount, reason) in enumerate(vectors):
        ledger = prepared('charge-b', original, remaining)
        eligible = reference_eligible(original, remaining, flags, amount, reason)
        if eligible:
            ledger = suite.clone(ledger, 'conf-vector')
            accepted += 1
        state = suite.must_state(ledger)
        out = expect(suite, ledger, request(state, 'rq-v', amount, reason, flags), COMMITTED if eligible else CAKEML_REJECTED, 'vector %d %r' % (index, vectors[index]))
        if eligible:
            require(out.split(b' ', 3)[3] == (frame(amount, reason, 'charge-b', 'rq-v') + '\n').encode(), 'vector %d: frame' % index)
            check_ledger(suite, ledger, 'vector %d' % index)
    return dict(classes, fixtures=22, boundary_vectors=len(vectors), boundary_committed=accepted), {}


def stub(suite, name, body):
    path = suite.folder('stub') / 'refund'
    path.write_text('#!/bin/sh\n' + body + '\n')
    path.chmod(0o700)
    return str(path)


def case_frames(suite):
    """Stand-ins for the binary show what the sink accepts as a decision. The real binary gives none of the bad outputs."""
    base = suite.ledger('frames', original=100)
    state = suite.must_state(base)
    line = request(state, 'rq-f', 40)
    good = frame(40, 'returned_item', 'charge-1', 'rq-f')
    drain = '/bin/cat >/dev/null; '
    emit = lambda text: "printf '%%s' '%s'" % text
    stubs = [
        ('exact frame (control: a stand-in that prints the frame is believed; the binary is trusted)', drain + emit(good), COMMITTED),
        ('cut after 23 bytes', drain + emit(good[:23]), BAD_FRAME),
        ('cut by one byte', drain + emit(good[:-1]), BAD_FRAME),
        ('one more byte', drain + emit(good + 'X'), BAD_FRAME),
        ('line end after the frame', drain + emit(good) + "; printf '\\n'", BAD_FRAME),
        ('two frames', drain + emit(good + good), BAD_FRAME),
        ('space before the frame', drain + emit(' ' + good), BAD_FRAME),
        ('exact frame, exit status 1', drain + emit(good) + '; exit 1', BAD_FRAME),
        ('exact frame, exit status 255', drain + emit(good) + '; exit 255', BAD_FRAME),
        ('exact frame, text on stderr', drain + emit(good) + '; printf warn >&2', BAD_FRAME),
        ('exact frame, then killed by a signal', drain + emit(good) + '; kill -9 $$', BAD_FRAME),
        ('no output, exit status 0', drain + 'exit 0', BAD_FRAME),
        ('no output, exit status 1', drain + 'exit 1', BAD_FRAME),
        ('rejection frame', drain + emit(REJECT_FRAME.decode()), CAKEML_REJECTED),
        ('rejection frame and one more byte', drain + emit(REJECT_FRAME.decode() + 'X'), BAD_FRAME),
        ('rejection frame, exit status 1', drain + emit(REJECT_FRAME.decode()) + '; exit 1', BAD_FRAME),
        ('frame for another request id', drain + emit(frame(40, 'returned_item', 'charge-1', 'rq-g')), BAD_FRAME),
        ('frame for another amount', drain + emit(frame(41, 'returned_item', 'charge-1', 'rq-f')), BAD_FRAME),
        ('frame for another reason', drain + emit(frame(40, 'duplicate_charge', 'charge-1', 'rq-f')), BAD_FRAME),
        ('frame for another charge', drain + emit(frame(40, 'returned_item', 'charge-2', 'rq-f')), BAD_FRAME),
        ('frame with intent count 2', drain + emit(good[:-2] + '2)'), BAD_FRAME),
        ('frame that says False with the fields', drain + emit(good.replace('True', 'False')), BAD_FRAME),
        ('endless output', drain + 'while :; do printf AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA; done', BAD_FRAME),
        ('does not read its input, exits 1', 'exit 1', BAD_FRAME),
    ]
    for name, body, code in stubs:
        expect(suite, suite.clone(base, 'frames-case'), line, code, 'stand-in: ' + name, binary=stub(suite, name, body), timeout=60)
    missing = str(suite.folder('stub') / 'refund')
    expect(suite, base, line, IO_ERROR, 'the binary path does not exist', binary=missing)
    plain = Path(missing)
    plain.write_text('not a program\n')
    expect(suite, base, line, IO_ERROR, 'the binary path is not executable', binary=missing)
    # An accepted reason that is not approved (only a stand-in can do this): the sink has no record kind for it.
    odd = request(state, 'rq-f', 40, 'other')
    expect(suite, base, odd, BAD_FRAME, 'stand-in accepts an unapproved reason', binary=stub(suite, 'odd', drain + emit(frame(40, 'other', 'charge-1', 'rq-f'))))
    # An accepted amount above the remaining amount (only a stand-in can do this): refused by the sink's own arithmetic.
    over = request(state, 'rq-f', 101)
    expect(suite, base, over, BAD_FRAME, 'stand-in accepts more than remains', binary=stub(suite, 'over', drain + emit(frame(101, 'returned_item', 'charge-1', 'rq-f'))))
    return {'stand_ins': len(stubs) + 4}, {}


def case_ids(suite):
    ledger = suite.ledger('ids', original=1000)
    state = suite.must_state(ledger)
    bad_ids = [b'', b'x' * 25, b'x' * 100, b'rq\x00', b'rq\x00x', b'\x00', b'rq\tx', b'rq\r', b'rq\x0b', b'rq\x0c', b'rq\x1f', b'rq\x7f',
               'rq x'.encode(), 'rq​'.encode(), 'rq x'.encode(), '１'.encode(), 'rqé'.encode(), b'rq\xff', b'"rq"', b"'rq'",
               b'rq(', b'rq)', b'(rq)', b'rq.1', b'rq/1', b'rq:1', b'rq+1', b'rq~1', b'rq*', b'rq=1', b'rq,1', b'rq;1', b'rq\\1', b'rq@1', b'rq#1', b'~1', b'rq%00']
    for ident in bad_ids:
        line = b'%s (charge-1 %s 1000 1000 True True True 1 returned_item)\n' % (state['tail'].encode(), ident)
        expect(suite, ledger, line, MALFORMED_ID, 'request id %r' % ident)
        line = b'%s (%s rq-ok 1000 1000 True True True 1 returned_item)\n' % (state['tail'].encode(), ident)
        expect(suite, ledger, line, MALFORMED_ID, 'charge id %r' % ident)
    # A space is the field separator: an id with a space gives a line with a wrong number of fields.
    for ident in (b'rq 1', b' rq', b'rq '):
        line = b'%s (charge-1 %s 1000 1000 True True True 1 returned_item)\n' % (state['tail'].encode(), ident)
        expect(suite, ledger, line, MALFORMED_REQUEST, 'request id with a space %r' % ident)
    # No folding and no number reading: ids that look alike are different ids, and each is single-use.
    alike = ['rq-1', 'RQ-1', 'Rq-1', 'rq_1', '1', '01', '001', '0', '00', 'x' * 24, 'x' * 23, 'True', 'refund-result-v1']
    for ident in alike:
        expect(suite, ledger, request(suite.must_state(ledger), ident, 1), COMMITTED, 'id %r' % ident)
    state = suite.must_state(ledger)
    for ident in alike:
        expect(suite, ledger, request(state, ident, 1), DUPLICATE, 'id %r again' % ident)
    wal = check_ledger(suite, ledger, 'ids')
    require([effect[1] for effect in wal['effects']] == alike, 'the WAL does not hold the raw ids in order')
    return {'refused_ids': 2 * len(bad_ids) + 3, 'distinct_alike_ids': len(alike), 'wal_sha256': hashlib.sha256(wal['bytes']).hexdigest()}, {}


def flips(data, start, quick):
    """Single-bit changes of one record: every bit, or one bit per byte in quick mode."""
    for bit in range(0, REC * 8, 8 if quick else 1):
        changed = bytearray(data)
        changed[start + bit // 8] ^= 1 << ((bit * 5 + bit // 8) % 8 if quick else bit % 8)
        yield bytes(changed)


def case_recovery(suite):
    """File surgery: what the sink does with a damaged ledger. No process is killed here."""
    base = suite.ledger('recovery', original=1000)
    for index in range(3):
        expect(suite, base, request(suite.must_state(base), 'rq-%d' % index, 5 + index), COMMITTED, 'recovery set-up')
    wal, ratchet = files(base)
    model = read_wal(base)
    following = record(b'3', 4, model['tail'], b'rq-next', 7)
    ledger = suite.clone(base, 'recovery-work')
    wal_path, ratchet_path = Path(ledger) / 'ledger.wal', Path(ledger) / 'ledger.epoch'

    def damaged(new_wal, new_ratchet=None):
        wal_path.write_bytes(new_wal)
        ratchet_path.write_bytes(ratchet if new_ratchet is None else new_ratchet)

    def answer_of(what, code, unchanged=True):
        before = files(ledger)
        got, _ = suite.command(ledger, 'state')
        require(got == code, '%s: state gives exit %d, expected %d' % (what, got, code))
        if code != 0:
            got, out, _ = suite.serve(ledger, [request(dict(epoch=3, tail='%032x' % model['tail'], charge='charge-1', original=1000, remaining=model['remaining']), 'rq-x', 1)])
            require(got == code and not committed_lines(out), '%s: a request gives exit %d, expected %d' % (what, got, code))
            require(not unchanged or files(ledger) == before, '%s: a refused ledger was changed' % what)

    # A. A torn append: 1 to 63 bytes of the next record, and 64 bytes that are not a valid record.
    torn = 0
    for length in range(1, REC):
        for tail in ((following[:length],) if suite.quick else (following[:length], bytes([length]) * length)):
            damaged(wal + tail)
            answer_of('torn tail of %d bytes' % length, 0)
            require(files(ledger)[0] == wal, 'torn tail of %d bytes: the WAL is not cut back to its valid records' % length)
            torn += 1
    for name, tail in (('zero bytes', b'\0' * REC), ('0xff bytes', b'\xff' * REC), ('record with a wrong CRC', following[:-1] + bytes([following[-1] ^ 1])),
                       ('record with a wrong chain', record(b'3', 4, 5, b'rq-next', 7)), ('record with a wrong epoch', record(b'3', 5, model['tail'], b'rq-next', 7)),
                       ('the last record once more', wal[-REC:]), ('record with a committed id', record(b'3', 4, model['tail'], b'rq-1', 7)),
                       ('record above the remaining amount', record(b'3', 4, model['tail'], b'rq-next', 1001)), ('genesis kind', record(b'G', 4, model['tail'], b'rq-next', 7)),
                       ('record with a byte after the id', record(b'3', 4, model['tail'], b'rq-next\0X', 7)), ('record with kind 4', record(b'4', 4, model['tail'], b'rq-next', 7)),
                       ('record with an id outside the character set', record(b'3', 4, model['tail'], b'rq next', 7))):
        damaged(wal + tail)
        answer_of('torn 64 bytes: ' + name, 0)
        require(files(ledger)[0] == wal, 'torn 64 bytes (%s): the WAL is not cut back' % name)
        torn += 1
    expect(suite, ledger, request(suite.must_state(ledger), 'rq-after-torn', 1), COMMITTED, 'commit after a torn tail')
    check_ledger(suite, ledger, 'after a torn tail')
    # B. A whole valid record that was written and not synced (the state after a kill at point c) is adopted.
    damaged(wal + following)
    answer_of('valid unsynced record', 0)
    require(check_ledger(suite, ledger, 'adopted record')['epoch'] == 4, 'a valid appended record must be adopted')
    # C. More than 64 bytes that are not valid: not one torn append. Refused; the files stay as they are.
    for extra in (65, 127, 128, 640):
        damaged(wal + b'\x55' * extra)
        answer_of('%d bytes of rubbish' % extra, CORRUPT_WAL)
    for name, data in (('empty WAL', b''), ('63 bytes', wal[:63]), ('WAL that starts with record 1', wal[REC:]), ('records 1 and 2 exchanged', wal[:REC] + wal[2 * REC:3 * REC] + wal[REC:2 * REC] + wal[3 * REC:]),
                       ('genesis record with an amount above MaxMoney', record(b'G', 0, 0, b'charge-1', MAX_MONEY + 1)), ('genesis record with kind 1', record(b'1', 0, 0, b'charge-1', 1000))):
        damaged(data)
        answer_of(name, CORRUPT_WAL)
    # D. Single-bit changes. In the genesis record or a middle record: CORRUPT_WAL. In the last record, which the
    #    ratchet knows: the ledger is now shorter than its ratchet: EPOCH_REGRESSION. Never a silent acceptance.
    bits = 0
    for start, code in ((0, CORRUPT_WAL), (REC, CORRUPT_WAL), (2 * REC, CORRUPT_WAL), (3 * REC, EPOCH_REGRESSION)):
        for changed in flips(wal, start, suite.quick):
            damaged(changed)
            answer_of('one bit changed in record %d' % (start // REC), code)
            bits += 1
    # E. A WAL that lost whole records (cut, or an older copy): EPOCH_REGRESSION.
    for records in (1, 2, 3):
        damaged(wal[:records * REC])
        answer_of('WAL cut to %d records' % records, EPOCH_REGRESSION)
    # F. One record replaced by another valid record: the chain of the next record breaks.
    replaced = wal[:2 * REC] + record(b'1', 2, fnv128(wal[REC:2 * REC]), b'rq-evil', 1) + wal[3 * REC:]
    damaged(replaced)
    answer_of('record 2 replaced by a valid record', EPOCH_REGRESSION)
    # G. The ratchet file.
    damaged(wal, ratchet + b'\x01\x02\x03\x04\x05')
    answer_of('torn ratchet entry', 0)
    require(len(files(ledger)[1]) % 12 == 0 and ratchet_max(ledger) == 3, 'a torn ratchet entry must be cut')
    damaged(wal, ratchet[:-12])
    answer_of('ratchet one entry behind (kill between the two syncs)', 0)
    require(ratchet_max(ledger) == 3, 'the ratchet must catch up')
    damaged(wal, ratchet[:-1] + bytes([ratchet[-1] ^ 1]))
    answer_of('last ratchet entry with a wrong CRC', 0)
    require(ratchet_max(ledger) == 3, 'the ratchet must be repaired')
    damaged(wal, b'')
    answer_of('empty ratchet', CORRUPT_WAL)
    damaged(wal, b'\x99' * 24)
    answer_of('ratchet with no valid entry', CORRUPT_WAL)
    entry = lambda epoch: struct.pack('<Q', epoch) + struct.pack('<I', zlib.crc32(struct.pack('<Q', epoch)) & 0xffffffff)
    damaged(wal, ratchet + entry(9))
    answer_of('ratchet ahead of the WAL', EPOCH_REGRESSION)
    damaged(wal[:2 * REC], ratchet + entry(1))
    answer_of('ratchet whose last entry is lower than an earlier entry, WAL cut to that lower epoch', EPOCH_REGRESSION)
    for missing in (wal_path, ratchet_path):
        damaged(wal)
        missing.unlink()
        got, _ = suite.command(ledger, 'state')
        require(got == IO_ERROR, 'missing %s: exit %d' % (missing.name, got))
        got, out, _ = suite.serve(ledger, [request(dict(tail='%032x' % model['tail'], charge='charge-1', original=1000, remaining=model['remaining']), 'rq-x', 1)])
        require(got == IO_ERROR and not committed_lines(out), 'missing %s: a request gives exit %d' % (missing.name, got))
    # H. LIMIT, recorded as observed: a rewritten suffix with a recomputed chain is a valid ledger. FNV-1a-128
    #    is not authentication. Who can write the files is trusted.
    forged = wal[:2 * REC] + record(b'1', 2, fnv128(wal[REC:2 * REC]), b'rq-evil', 1)
    forged += record(b'1', 3, fnv128(forged[-REC:]), b'rq-evil-2', 1)
    damaged(forged)
    got, _ = suite.command(ledger, 'state')
    require(got == 0, 'a rewritten suffix with a recomputed chain: exit %d (the recorded limit is exit 0)' % got)
    return {'torn_tails': torn, 'single_bit_changes': bits, 'rewritten_suffix_with_recomputed_chain_accepted': True}, {}


def case_rollback(suite):
    ledger = suite.ledger('rollback', original=100)
    states = [suite.must_state(ledger)]
    backups = [files(ledger)]
    for index in range(3):
        expect(suite, ledger, request(states[-1], 'rq-%d' % index, 30), COMMITTED, 'rollback set-up')
        states.append(suite.must_state(ledger))
        backups.append(files(ledger))
    wal_path, ratchet_path = Path(ledger) / 'ledger.wal', Path(ledger) / 'ledger.epoch'
    refused = 0
    # An old copy of the WAL alone (the usual restore of one file): every command and every request is refused.
    for age in (0, 1, 2):
        wal_path.write_bytes(backups[age][0])
        ratchet_path.write_bytes(backups[3][1])
        code, _ = suite.command(ledger, 'state')
        require(code == EPOCH_REGRESSION, 'WAL of epoch %d with the present ratchet: state exit %d' % (age, code))
        code, _ = suite.command(ledger, 'replay')
        require(code == EPOCH_REGRESSION, 'WAL of epoch %d with the present ratchet: replay exit %d' % (age, code))
        for name, line in (('the refund that was rolled back', request(states[age], 'rq-%d' % age, 30)), ('a new refund', request(states[age], 'rq-new', 30)),
                           ('a refund on the later hash', request(states[3], 'rq-new', 10))):
            expect(suite, ledger, line, EPOCH_REGRESSION, 'restored WAL of epoch %d: %s' % (age, name))
            refused += 1
    # An old ratchet with the present WAL is the state after a kill between the two syncs: it is repaired.
    wal_path.write_bytes(backups[3][0])
    ratchet_path.write_bytes(backups[1][1])
    require(suite.must_state(ledger)['epoch'] == 3 and ratchet_max(ledger) == 3, 'an old ratchet with the present WAL must be repaired')
    # LIMIT, recorded as observed: both files restored together. The sink cannot see it.
    wal_path.write_bytes(backups[1][0])
    ratchet_path.write_bytes(backups[1][1])
    require(suite.must_state(ledger) == states[1], 'both files restored: the sink was expected to report the old state (recorded limit)')
    # A client that saw the later state is still protected: its request names a state that is not the present one.
    expect(suite, ledger, request(states[3], 'rq-new', 10), STALE, 'both files restored: request on the later hash')
    expect(suite, ledger, request(states[1], 'rq-1', 30), COMMITTED, 'both files restored: the rolled-back refund commits again (recorded limit)')
    return {'refused_after_wal_restore': refused, 'restore_of_both_files_detected': False}, {}


def trace_of(suite, ledger, arguments, data=b'', **variables):
    """Runs the sink under the interposer. Returns the exit code, stdout, and the traced calls on the two ledger
    files, on the ledger folder and on stdout, in their order."""
    path = suite.folder('trace') / 'trace.log'
    env = dict(ENV, DYLD_INSERT_LIBRARIES=suite.interposer, SINK_TRACE=str(path), **variables)
    done = subprocess.run([suite.sink, ledger] + arguments, input=data, capture_output=True, env=env, timeout=120)
    events = path.read_text().splitlines() if path.exists() else []
    names = ('ledger.wal', 'ledger.epoch', 'stdout', Path(ledger).name)
    return done.returncode, done.stdout, [event.replace(Path(ledger).name, 'FOLDER') for event in events if event.split()[1] in names]


# The calls of one commit on a clean ledger, in the required order. The lock ends with `close ledger.wal`.
COMMIT_CALLS = ['flock ledger.wal', 'write ledger.wal 64', 'fullfsync ledger.wal 0', 'write ledger.epoch 12', 'fullfsync ledger.epoch 0',
                'close ledger.wal', 'close ledger.epoch']
INIT_CALLS = ['write ledger.epoch 12', 'fullfsync ledger.epoch 0', 'write ledger.wal 64', 'fullfsync ledger.wal 0', 'close ledger.wal', 'fullfsync FOLDER 0',
              'close ledger.epoch']


def case_trace(suite):
    """System-call order of init, of one commit and of one recovery; failed syncs and writes; the environment of
    the binary. The order is observed for these traced runs only, not for every commit of the other cases."""
    require(b'SINK_KILL_AT' not in Path(suite.sink).read_bytes(), 'the production sink contains the kill-point seam')
    require(b'SINK_KILL_AT' in Path(suite.kill_sink).read_bytes(), 'control: the kill build does not contain the seam')
    # init: both files and the folder are synced before the answer. A failed sync: refused, no file stays, init works again.
    folder = str(suite.folder('trace-init'))
    code, out, events = trace_of(suite, folder, ['init', 'charge-1', '100'])
    require(code == 0 and events == INIT_CALLS + ['write stdout %d' % len(out)], 'system-call order of init:\n  observed %r\n  expected %r' % (events, INIT_CALLS))
    for number, name in ((1, 'ratchet'), (2, 'WAL'), (3, 'folder')):
        folder = str(suite.folder('trace-init-fault'))
        code, out, events = trace_of(suite, folder, ['init', 'charge-1', '100'], SINK_FAIL_SYNC=str(number))
        require(code == IO_ERROR and out.startswith(b'REJECT 18 ') and os.listdir(folder) == [], 'init with a failed sync of the %s: exit %d, files %r' % (name, code, os.listdir(folder)))
        require(subprocess.run([suite.sink, folder, 'init', 'charge-1', '100'], capture_output=True, env=ENV).returncode == 0, 'init again after a failed sync of the ' + name)
    ledger = suite.ledger('trace', original=100)
    state = suite.must_state(ledger)
    # The binary runs with an empty environment. Control first: with the loader variable, the binary itself is forged.
    refused = '(charge-1 rq-forge 100 100 False True True 5 returned_item)'
    forge = dict(DYLD_INSERT_LIBRARIES=suite.interposer, SINK_FORGE='1')
    direct = subprocess.run([suite.binary], input=refused.encode(), capture_output=True, env=dict(forge, CML_HEAP_SIZE='256', CML_STACK_SIZE='256'), timeout=60)
    require(direct.stdout.decode() == frame(5, 'returned_item', 'charge-1', 'rq-forge'), 'control: the loader variable did not forge the frame: %r' % direct.stdout)
    plain = subprocess.run([suite.binary], input=refused.encode(), capture_output=True, env=dict(CML_HEAP_SIZE='256', CML_STACK_SIZE='256'), timeout=60)
    require(plain.stdout == REJECT_FRAME, 'control: the binary must reject this request: %r' % plain.stdout)
    expect(suite, suite.clone(ledger, 'trace-forge'), request(state, 'rq-forge', 5, flags=(False, True, True)), CAKEML_REJECTED,
           'loader variable in the environment of the sink', env=dict(ENV, **forge))
    # One commit on a clean ledger: lock, record, sync, ratchet entry, sync, lock released, and only then the answer.
    code, out, events = trace_of(suite, ledger, ['serve', suite.binary], request(state, 'rq-t', 5).encode())
    require(code == 0 and len(committed_lines(out)) == 1 and out.count(b'\n') == 1, 'traced commit: exit %d %r' % (code, out))
    require(events == COMMIT_CALLS + ['write stdout %d' % len(out)], 'system-call order of a commit:\n  observed %r\n  expected %r' % (events, COMMIT_CALLS))
    # The production sink ignores the kill-point variable.
    code, out, err = suite.serve(ledger, [request(suite.must_state(ledger), 'rq-seam', 1)], env=dict(ENV, SINK_KILL_AT='a'))
    require(code == 0 and err == b'', 'the production sink must ignore SINK_KILL_AT: exit %d stderr %r' % (code, err))
    # A refusal on a clean ledger makes no write, no cut and no sync on a ledger file.
    code, out, events = trace_of(suite, ledger, ['serve', suite.binary], request(state, 'rq-stale', 1).encode())
    closes = ['close ledger.epoch', 'close ledger.wal']  # after a refusal the order of the two closes has no meaning
    require(code == STALE and len(events) == 4 and events[0] == 'flock ledger.wal' and sorted(events[1:3]) == closes and events[3] == 'write stdout %d' % len(out),
            'system calls of a stale request: %r' % events)
    code, out, events = trace_of(suite, ledger, ['serve', suite.binary], request(suite.must_state(ledger), 'rq-no', 1, 'other').encode())
    require(code == CAKEML_REJECTED and events == ['write stdout %d' % len(out)], 'system calls of a rejected request: %r' % events)
    # Recovery (a torn tail of 10 bytes, the ratchet one entry behind): cut, sync of the WAL, ratchet entry, sync, then the answer.
    wal, ratchet = files(ledger)

    def needs_recovery():
        work = suite.clone(ledger, 'trace-recovery')
        (Path(work) / 'ledger.wal').write_bytes(wal + b'x' * 10)
        (Path(work) / 'ledger.epoch').write_bytes(ratchet[:-12])
        return work

    work = needs_recovery()
    code, out, events = trace_of(suite, work, ['state'])
    want = ['flock ledger.wal', 'ftruncate ledger.epoch %d' % (len(ratchet) - 12), 'ftruncate ledger.wal %d' % len(wal), 'fullfsync ledger.wal 0', 'write ledger.epoch 12',
            'fullfsync ledger.epoch 0', 'close ledger.wal', 'close ledger.epoch', 'write stdout %d' % len(out)]
    require(code == 0 and events == want and files(work) == (wal, ratchet), 'system-call order of a recovery:\n  observed %r\n  expected %r' % (events, want))
    for number, name in ((1, 'WAL'), (2, 'ratchet')):
        code, out, events = trace_of(suite, needs_recovery(), ['state'], SINK_FAIL_SYNC=str(number))
        require(code == IO_ERROR and out.startswith(b'REJECT 18 ') and b'STATE' not in out, 'recovery with a failed sync of the %s: exit %d, %r' % (name, code, out))
    # Faults in a commit. Two request lines are sent: after a fault the sink must read no further line.
    faults = 0

    def fault(name, code, **variables):
        work = suite.clone(ledger, 'trace-fault')
        state = suite.must_state(work)
        before = files(work)
        got, out, events = trace_of(suite, work, ['serve', suite.binary], (request(state, 'rq-f', 2) + request(state, 'rq-f2', 2)).encode(), **variables)
        require(got == code and not committed_lines(out) and out.startswith(b'REJECT %d ' % code), '%s: exit %d, expected %d, %r' % (name, got, code, out))
        require(out.count(b'\n') == 1, '%s: the sink answered a further line after the fault: %r' % (name, out))
        require(not any(event.startswith('write stdout') for event in events[:-1]), '%s: an answer was written before the end: %r' % (name, events))
        return work, state, before, events

    # The WAL sync fails: the record is cut off again (and that cut is synced). Nothing is committed; the request can run again.
    work, state, before, events = fault('failed sync of the WAL', IO_ERROR, SINK_FAIL_SYNC='1')
    undo = ['fullfsync ledger.wal -1', 'ftruncate ledger.wal %d' % len(before[0]), 'fullfsync ledger.wal 0']
    require(events[-6:-3] == undo and sorted(events[-3:-1]) == closes and files(work) == before, 'failed sync of the WAL: the record must be cut off again: %r' % events)
    expect(suite, work, request(state, 'rq-f', 2), COMMITTED, 'request again after a failed sync of the WAL')
    # The WAL sync fails and the sync of the cut fails too: the sink cannot know the outcome and says so.
    work, state, before, events = fault('failed sync of the WAL and of its undo', OUTCOME_UNKNOWN, SINK_FAIL_SYNC_FROM='1')
    check_ledger(suite, work, 'after a failed undo')
    code, out, _ = suite.serve(work, [request(suite.must_state(work), 'rq-f', 2)])
    require(code in (COMMITTED, DUPLICATE), 'request again after a failed undo: exit %d' % code)
    # The WAL write fails (nothing written), and a short write (30 bytes written, then no space): nothing stays.
    for name, variables in (('failed write of the record', dict(SINK_FAIL_WRITE='1')), ('short write of the record', dict(SINK_FAIL_WRITE='1', SINK_SHORT_WRITE='30'))):
        work, state, before, events = fault(name, IO_ERROR, **variables)
        require(files(work) == before and ('write ledger.wal 30 SHORT' in events) == ('SINK_SHORT_WRITE' in variables), '%s: files or events %r' % (name, events))
        expect(suite, work, request(state, 'rq-f', 2), COMMITTED, 'request again after a ' + name)
        faults += 1
    # The ratchet entry fails (its write, or its sync) after the record is durable: no dispatch, and the sink says that the
    # outcome is open. The record stays; the next start adopts it; the request again is a duplicate; replay prints it.
    for name, variables in (('failed sync of the ratchet', dict(SINK_FAIL_SYNC='2')), ('failed write of the ratchet entry', dict(SINK_FAIL_WRITE='2'))):
        work, state, before, events = fault(name, OUTCOME_UNKNOWN, **variables)
        require(files(work)[0][:len(before[0])] == before[0] and len(files(work)[0]) == len(before[0]) + REC, '%s: the WAL must hold the one new record' % name)
        require(check_ledger(suite, work, 'after a ' + name)['effects'][-1] == ('returned_item', 'rq-f', 2), '%s: the record must be adopted at the next start' % name)
        expect(suite, work, request(suite.must_state(work), 'rq-f', 2), DUPLICATE, 'request again after a ' + name)
        faults += 1
    return {'commit_system_calls': COMMIT_CALLS + ['write stdout'], 'init_system_calls': INIT_CALLS + ['write stdout'], 'recovery_traced': True,
            'injected_faults': faults + 2 + 3 + 2, 'loader_variable_reaches_binary': False}, {}


def case_dispatch(suite):
    """The answer line cannot be written because its reader is gone. A commit of that line stays committed and is
    not dispatched; the sink ends with DISPATCH_FAILED and reads no further line."""
    ledger = suite.ledger('dispatch', original=100)
    state = suite.must_state(ledger)
    tail, lines = read_wal(ledger)['tail'], []
    for index in range(3):  # each request names the state that the one before it makes (the suite's own arithmetic)
        lines.append(request(dict(state, tail='%032x' % tail, remaining=100 - 10 * index), 'rq-d%d' % index, 10))
        tail = fnv128(record(b'3', index + 1, tail, b'rq-d%d' % index, 10))
    control = suite.clone(ledger, 'dispatch-control')
    code, out, _ = suite.serve(control, lines)
    require(code == 0 and len(committed_lines(out)) == 3 and read_wal(control)['tail'] == tail, 'control: three requests in one stream must commit: exit %d %r' % (code, out))

    def without_reader(work, data):
        read_end, write_end = os.pipe()
        os.close(read_end)
        try:
            return subprocess.run([suite.sink, work, 'serve', suite.binary], input=data, stdout=write_end, stderr=subprocess.PIPE, env=ENV, timeout=120).returncode
        finally:
            os.close(write_end)

    code = without_reader(ledger, ''.join(lines).encode())
    require(code == DISPATCH_FAILED, 'three requests, no reader for the answers: exit %d, expected %d' % (code, DISPATCH_FAILED))
    wal = check_ledger(suite, ledger, 'dispatch')
    require([effect[1] for effect in wal['effects']] == ['rq-d0'], 'after a failed answer the sink must read no further line: committed %r' % wal['effects'])
    expect(suite, ledger, request(suite.must_state(ledger), 'rq-d0', 10), DUPLICATE, 'the request of the failed answer again')
    work = suite.clone(control, 'dispatch-refusal')
    before = files(work)
    code = without_reader(work, (request(state, 'rq-stale', 1) + request(suite.must_state(work), 'rq-live', 1)).encode())
    require(code == DISPATCH_FAILED and files(work) == before, 'a refusal with no reader: exit %d; the next line must not be read' % code)
    return {'answers_without_reader': 2, 'committed_and_not_dispatched': 1, 'lines_read_after_the_failed_answer': 0}, {}


def wait_marker(process, marker, timeout=60.0):
    descriptor, seen, deadline = process.stderr.fileno(), b'', time.monotonic() + timeout
    while marker not in seen:
        left = deadline - time.monotonic()
        require(left > 0 and select.select([descriptor], [], [], left)[0], 'kill point %r not reached in time; stderr %r' % (marker, seen))
        chunk = os.read(descriptor, 4096)
        if not chunk:
            raise Failed('the process ended before kill point %r: exit %r, stdout %r, stderr %r' % (marker, process.wait(), process.stdout.read(), seen))
        seen += chunk


def case_lock(suite):
    """A process that holds the lock stops every other command. The holder waits at a kill point. That the other
    processes are blocked is seen by a wait of 3 seconds (an observation in time). That a process reads the ledger
    only AFTER it has the lock is seen without a time bound: two processes wait for the same state; after the kill
    of the holder exactly one of them may commit, and the other one must find the new record."""
    ledger = suite.ledger('lock', original=100)
    state = suite.must_state(ledger)
    before = files(ledger)
    holder = suite.start(ledger, request(state, 'rq-holder', 1), sink=suite.kill_sink, env=dict(ENV, SINK_KILL_AT='a'))
    try:
        wait_marker(holder, b'AT a\n')
        waiters = [suite.start(ledger, request(state, 'rq-waiter-%d' % number, 1)) for number in (1, 2)]
        time.sleep(3.0)
        ended = [waiter.poll() for waiter in waiters]
        require(ended == [None, None], 'a second process ended (exit codes %r) while another process held the ledger lock' % ended)
        require(files(ledger) == before, 'the ledger changed while the lock holder waited before its write')
        reader = subprocess.Popen([suite.sink, ledger, 'state'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=ENV)
        try:
            reader.wait(timeout=1.0)
            raise Failed('the state command ended while another process held the ledger lock')
        except subprocess.TimeoutExpired:
            pass
    finally:
        holder.kill()
        holder.wait()
    require(holder.returncode == -9, 'the lock holder was not ended by SIGKILL')
    results = [finish(waiter) for waiter in waiters]
    codes = sorted(result[0] for result in results)
    require(codes == [COMMITTED, STALE] and sum(len(committed_lines(result[1])) for result in results) == 1,
            'exactly one of the two waiting processes may commit, the other must read the ledger AFTER it has the lock: exit codes %r' % codes)
    require(reader.wait(timeout=60) == 0, 'the waiting state command must end after the kill')
    reader.stdout.read()
    wal = check_ledger(suite, ledger, 'lock')
    require(len(wal['effects']) == 1 and wal['effects'][0][1] in ('rq-waiter-1', 'rq-waiter-2'), 'exactly one waiting request may be committed: %r' % wal['effects'])
    # The holder has WRITTEN its record and not synced it (point c). After its kill the waiting process adopts that
    # record and must get STALE_STATE_HASH.
    late = suite.ledger('lock-late', original=100)
    state = suite.must_state(late)
    holder = suite.start(late, request(state, 'rq-holder', 1), sink=suite.kill_sink, env=dict(ENV, SINK_KILL_AT='c'))
    try:
        wait_marker(holder, b'AT c\n')
        waiter = suite.start(late, request(state, 'rq-waiter', 1))
        try:
            waiter.wait(timeout=3.0)
            raise Failed('a second process ended (exit %d) while another process held the ledger lock after its write' % waiter.returncode)
        except subprocess.TimeoutExpired:
            pass
    finally:
        holder.kill()
        holder.wait()
    code, out, _ = finish(waiter)
    require(code == STALE and not committed_lines(out), 'after the kill of a holder that had written, the waiting process must get STALE_STATE_HASH: exit %d %r' % (code, out))
    wal = check_ledger(suite, late, 'lock-late')
    require([effect[1] for effect in wal['effects']] == ['rq-holder'], 'only the record of the lock holder may be in the WAL: %r' % wal['effects'])
    return {'other_processes_blocked': True, 'exactly_one_of_two_waiting_processes_commits': True}, {}


def case_crash(suite):
    """SIGKILL at six chosen points (a build of the same source with the kill-point seam), and blind SIGKILLs at
    random times on the production build. After every kill: recovery, the suite's own reading of both files, the
    interrupted request again."""
    rng = random.Random(suite.seed)
    ledger = suite.ledger('crash', original=10 ** 9)
    per_point = 2 if suite.quick else 20
    plan = KILL_POINTS * per_point
    rng.shuffle(plan)
    dispatched = {}

    def account(out, who):
        for line in committed_lines(out):
            fields = line.decode().split(' ')
            amount, request_id = int(fields[5]), fields[8]
            require(request_id not in dispatched, '%s: request %s was dispatched twice' % (who, request_id))
            dispatched[request_id] = amount

    def settle(wal, what):
        for request_id, amount in dispatched.items():
            require(('returned_item', request_id, amount) in wal['effects'], '%s: %s was dispatched but is not a committed record' % (what, request_id))
        require(sum(dispatched.values()) <= wal['original'] - wal['remaining'], '%s: more money dispatched than committed' % what)

    def again(victim_id, amount, committed, what):
        state = suite.must_state(ledger)
        code, out, _ = suite.serve(ledger, [request(state, victim_id, amount)])
        require(code == (DUPLICATE if committed else COMMITTED), '%s: the interrupted request again gives exit %d (committed before: %s)' % (what, code, committed))
        account(out, what)
        code, out, _ = suite.serve(ledger, [request(suite.must_state(ledger), victim_id, amount)])
        require(code == DUPLICATE and not committed_lines(out), '%s: a third run gives exit %d' % (what, code))

    for index, point in enumerate(plan):
        what = 'kill %d at point %s' % (index, point)
        state, amount = suite.must_state(ledger), rng.randint(0, 3)
        victim_id = 'k%04d-v' % index
        env = dict(ENV, SINK_KILL_AT=point, SINK_KILL_SPLIT=str(rng.randint(1, REC - 1)))
        victim = suite.start(ledger, request(state, victim_id, amount), sink=suite.kill_sink, env=env)
        try:
            wait_marker(victim, ('AT %s\n' % point).encode())
            others = [suite.start(ledger, request(state, 'k%04d-c%d' % (index, n), amount)) for n in range(rng.randint(1, 3))]
            time.sleep(rng.uniform(0, 0.003))
        finally:
            victim.kill()
        code, out, _ = finish(victim)
        require(code == -9, '%s: the victim was not ended by SIGKILL (exit %d)' % (what, code))
        require(not committed_lines(out) and (out != b'') == (point == 'e') and b'\n' not in out, '%s: output of the victim %r' % (what, out))
        results = [finish(other) for other in others]
        codes = sorted(result[0] for result in results)
        for result in results:
            account(result[1], what)
        wal = check_ledger(suite, ledger, what)
        ids = {effect[1] for effect in wal['effects']}
        require((victim_id in ids) == COMMITTED_AT[point], '%s: the request of the victim is %scommitted' % (what, '' if victim_id in ids else 'not '))
        if point == 'e':
            epoch = 1 + [effect[1] for effect in wal['effects']].index(victim_id)
            whole = ('COMMITTED %d %032x %s\n' % (epoch, wal['hashes'][epoch], frame(amount, 'returned_item', wal['charge'], victim_id))).encode()
            require(whole.startswith(out) and 0 < len(out) < len(whole), '%s: the cut answer %r is not a part of %r' % (what, out, whole))
        if COMMITTED_AT[point]:
            require(codes == [STALE] * len(others), '%s: exit codes of the other processes %r' % (what, codes))
        else:
            require(codes == [COMMITTED] + [STALE] * (len(others) - 1), '%s: exit codes of the other processes %r' % (what, codes))
        require(wal['epoch'] == state['epoch'] + 1, '%s: %d records were added, expected 1' % (what, wal['epoch'] - state['epoch']))
        settle(wal, what)
        again(victim_id, amount, COMMITTED_AT[point], what)
    blind, landed, index = (10 if suite.quick else 100), {'committed': 0, 'not_committed': 0, 'ended_before_the_kill': 0}, -1
    while landed['committed'] + landed['not_committed'] < blind:  # only a kill of a process that still ran counts
        index += 1
        require(index < 20 * blind, 'blind kills: too few kills hit a running process: %r' % landed)
        what = 'blind kill %d' % index
        state, amount, count = suite.must_state(ledger), rng.randint(0, 3), rng.randint(2, 4)
        ids = ['b%04d-%d' % (index, n) for n in range(count)]
        processes = [suite.start(ledger, None) for _ in ids]
        for process, request_id in zip(processes, ids):
            process.stdin.write(request(state, request_id, amount).encode())
        for process in processes:
            process.stdin.close()
        time.sleep(rng.uniform(0, 0.02))
        chosen = rng.randrange(count)
        alive = processes[chosen].poll() is None
        processes[chosen].kill()
        results = [finish(process) for process in processes]
        for result in results:
            account(result[1], what)
        wal = check_ledger(suite, ledger, what)
        new = [effect[1] for effect in wal['effects'][state['epoch']:]]
        require(len(new) == 1 and new[0] in ids, '%s: new records %r, expected exactly one of %r' % (what, new, ids))
        for number, result in enumerate(results):
            allowed = (COMMITTED, STALE, -9) if number == chosen else (COMMITTED, STALE)
            require(result[0] in allowed, '%s: process %d ended with %d' % (what, number, result[0]))
            require(result[0] != COMMITTED or ids[number] == new[0], '%s: process %d reports a commit that is not in the WAL' % (what, number))
        settle(wal, what)
        committed = ids[chosen] == new[0]
        landed['ended_before_the_kill' if not alive else 'committed' if committed else 'not_committed'] += 1
        again(ids[chosen], amount, committed, what)
    wal = check_ledger(suite, ledger, 'crash, end')
    undelivered = len(wal['effects']) - len(dispatched)
    return ({'kills_at_points': len(plan), 'per_point': per_point, 'points': KILL_POINTS, 'blind_kills_of_a_running_process': blind},
            {'records': len(wal['effects']), 'dispatched': len(dispatched), 'committed_but_not_dispatched': undelivered, 'blind_kill_landing': landed,
             'blind_kill_attempts': index + 1})


def race(suite, ledger, count, amount, same_id):
    state = suite.must_state(ledger)
    processes = [subprocess.Popen([suite.sink, ledger, 'serve', suite.binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=ENV)
                 for _ in range(count)]
    lines = [request(state, 'race' if same_id else 'race-%d-%03d' % (state['epoch'], n), amount).encode() for n in range(count)]

    def release(pair):
        pair[0].stdin.write(pair[1])
        pair[0].stdin.close()

    with ThreadPoolExecutor(max_workers=count) as pool:
        list(pool.map(release, zip(processes, lines)))
    results = [(process.stdout.read(), process.wait()) for process in processes]
    codes = [code for _, code in results]
    lost = STALE if not same_id else None
    require(codes.count(COMMITTED) == 1, 'race of %d: %d commits, expected exactly 1 (codes %r)' % (count, codes.count(COMMITTED), sorted(set(codes))))
    if same_id:
        require(all(code in (COMMITTED, STALE, DUPLICATE) for code in codes), 'race of %d with one request id: codes %r' % (count, sorted(set(codes))))
    else:
        require(codes.count(lost) == count - 1, 'race of %d: %d processes got STALE_STATE_HASH, expected %d (codes %r)' % (count, codes.count(lost), count - 1, sorted(set(codes))))
    lines_out = [line for out, _ in results for line in committed_lines(out)]
    require(len(lines_out) == 1, 'race of %d: %d COMMITTED lines' % (count, len(lines_out)))
    wal = check_ledger(suite, ledger, 'race')
    require(wal['epoch'] == state['epoch'] + 1 and wal['remaining'] == state['remaining'] - amount, 'race of %d: the ledger moved by more than one refund' % count)
    return amount


def case_race(suite):
    """100 processes at once for one balance. Exactly one commit; every other process gets STALE_STATE_HASH."""
    ledger = suite.ledger('race', original=1000)
    count = 100
    rounds = [(count, 250, False)] if suite.quick else [(count, 250, False), (count, 250, False), (count, 500, False)]
    refunded = sum(race(suite, ledger, n, amount, same) for n, amount, same in rounds)
    require(suite.must_state(ledger)['remaining'] == 1000 - refunded, 'race: total refunded is not the sum of the single winners')
    zero = suite.ledger('race-zero', original=1000)
    race(suite, zero, count, 0, False)  # the amount 0 leaves the balance; only the state hash stops the others
    if not suite.quick:
        race(suite, suite.ledger('race-same-id', original=1000), count, 10, True)
        last = suite.ledger('race-last-unit', original=1)
        race(suite, last, count, 1, False)
        require(suite.must_state(last)['remaining'] == 0, 'race for the last unit')
    return {'processes': count, 'rounds_positive': len(rounds), 'rounds_zero_amount': 1, 'total_refunded_equals_winners': True}, {}


def flood_into(command, env, total, tail=b''):
    """Writes `total` bytes with no line end, then `tail`. Returns what the process did."""
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    chunk, sent, descriptor, started, broken = b'A' * (1 << 20), 0, process.stdin.fileno(), time.monotonic(), False
    try:
        while sent < total:
            sent += os.write(descriptor, chunk[:min(len(chunk), total - sent)])
        seconds = time.monotonic() - started
        asked = time.monotonic()
        os.write(descriptor, tail)
    except BrokenPipeError:
        broken, seconds, asked = True, time.monotonic() - started, time.monotonic()
    answers = []
    if tail and not broken:
        answers.append(process.stdout.readline())
        answers.append(process.stdout.readline())
        latency = (time.monotonic() - asked) * 1000.0
    else:
        latency = None
    try:
        process.stdin.close()
    except BrokenPipeError:
        pass
    rest, err = process.stdout.read(1 << 16), process.stderr.read(1 << 16)
    _, status, usage = os.wait4(process.pid, 0)
    process.returncode = os.waitstatus_to_exitcode(status)
    return {'sent': sent, 'seconds': seconds, 'answers': answers, 'rest': rest, 'stderr': err, 'exit': process.returncode, 'latency_ms': latency,
            'peak_rss': usage.ru_maxrss, 'broken_pipe': broken}


def case_flood(suite):
    """A flood with no line end into the sink, then one valid request on the next byte. Then the same flood
    straight into the binary: an observation, with no bound on its memory."""
    total = suite.flood_bytes
    ledger = suite.ledger('flood', original=100)
    state = suite.must_state(ledger)
    line = request(state, 'rq-after-flood', 40)
    seen = flood_into([suite.sink, ledger, 'serve', suite.binary], ENV, total, b'\n' + line.encode())
    require(not seen['broken_pipe'] and seen['sent'] == total, 'flood: the sink stopped reading after %d bytes' % seen['sent'])
    require(seen['answers'][0].startswith(b'REJECT 16 MALFORMED_REQUEST: OVERSIZED'), 'flood: first answer %r' % seen['answers'][0])
    require(seen['answers'][1] == ('COMMITTED 1 %s %s\n' % ('%032x' % read_wal(ledger)['tail'], frame(40, 'returned_item', 'charge-1', 'rq-after-flood'))).encode(),
            'flood: the request on the next byte was not committed: %r' % seen['answers'][1])
    require(seen['exit'] == 0 and seen['rest'] == b'' and seen['stderr'] == b'', 'flood: the sink ended with %d, %r %r' % (seen['exit'], seen['rest'], seen['stderr']))
    require(seen['peak_rss'] < FLOOD_RSS_BOUND, 'flood: peak resident memory of the sink %d bytes, bound %d' % (seen['peak_rss'], FLOOD_RSS_BOUND))
    require(seen['latency_ms'] < LATENCY_BOUND_MS, 'flood: the next request took %.1f ms, bound %.0f ms' % (seen['latency_ms'], LATENCY_BOUND_MS))
    check_ledger(suite, ledger, 'flood')
    measured = {'flood_bytes': total, 'flood_seconds': round(seen['seconds'], 3), 'flood_gib_per_second': round(total / (1 << 30) / max(seen['seconds'], 1e-9), 2),
                'sink_peak_rss_bytes': seen['peak_rss'], 'next_request_latency_ms': round(seen['latency_ms'], 3)}
    result = {'flood_bytes': total, 'sink_answers': ['REJECT 16 OVERSIZED', 'COMMITTED'], 'sink_rss_below_50_mib': True, 'next_request_below_250_ms': True}
    if not suite.quick:
        raw = flood_into([suite.binary], {'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}, total)
        require(b'refund-result-v1 True' not in raw['rest'], 'raw flood: the binary printed an authorization: %r' % raw['rest'][:200])
        require(raw['rest'] == b'' and raw['exit'] != 0, 'raw flood: the binary ended with %d and printed %r (recorded observation: exit 1, no output)' % (raw['exit'], raw['rest'][:200]))
        result['raw_binary_observation'] = {'authorized': False, 'stdout_empty': True, 'exit_nonzero': True, 'rss_bound_asserted': False}
        measured['raw_binary'] = {'bytes_taken_before_it_ended': raw['sent'], 'took_all_bytes': not raw['broken_pipe'], 'exit': raw['exit'], 'peak_rss_bytes': raw['peak_rss'],
                                  'seconds': round(raw['seconds'], 3), 'stderr': raw['stderr'].decode(errors='replace').strip()}
    return result, measured


def case_latency(suite):
    """Commit latency of one sink process: write one line, read one answer. Real process start, real F_FULLFSYNC."""
    count = 20 if suite.quick else 200
    ledger = suite.ledger('latency', original=10 ** 6)
    state = suite.must_state(ledger)
    process = suite.start(ledger, None)
    times = []
    started = time.monotonic()
    for index in range(count):
        line = request(state, 'lat-%04d' % index, 1).encode()
        begin = time.perf_counter()
        process.stdin.write(line)
        process.stdin.flush()
        answer = process.stdout.readline()
        times.append((time.perf_counter() - begin) * 1000.0)
        fields = answer.decode().split(' ')
        require(fields[0] == 'COMMITTED' and int(fields[1]) == index + 1, 'latency: answer %d is %r' % (index, answer))
        state = dict(state, tail=fields[2], remaining=state['remaining'] - 1, epoch=index + 1)
    elapsed = time.monotonic() - started
    process.stdin.close()
    require(finish(process)[0] == 0, 'latency: the sink did not end with 0')
    times.sort()
    p50, p99 = times[len(times) // 2], times[min(len(times) - 1, (len(times) * 99) // 100)]
    require(p50 < LATENCY_BOUND_MS and p99 < LATENCY_BOUND_MS, 'latency: p50 %.1f ms, p99 %.1f ms, bound %.0f ms' % (p50, p99, LATENCY_BOUND_MS))
    wal = check_ledger(suite, ledger, 'latency')
    return ({'commits': count, 'p50_and_p99_below_250_ms': True, 'wal_sha256': hashlib.sha256(wal['bytes']).hexdigest()},
            {'commits': count, 'min_ms': round(times[0], 3), 'p50_ms': round(p50, 3), 'p90_ms': round(times[(len(times) * 9) // 10], 3), 'p99_ms': round(p99, 3),
             'max_ms': round(times[-1], 3), 'commits_per_second': round(count / elapsed, 1)})


CASES = {'basic': case_basic, 'conformance': case_conformance, 'frames': case_frames, 'ids': case_ids, 'recovery': case_recovery, 'rollback': case_rollback,
         'trace': case_trace, 'dispatch': case_dispatch, 'lock': case_lock, 'crash': case_crash, 'race': case_race, 'flood': case_flood, 'latency': case_latency}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--sink', required=True, help='the production build of the sink')
    parser.add_argument('--kill-sink', required=True, help='the build of the same source with --cfg kill_points')
    parser.add_argument('--binary', required=True, help='a private executable copy of the refund binary; its name must be "refund"')
    parser.add_argument('--interposer', required=True, help='the built tests/silicon_sink/interpose.c')
    parser.add_argument('--work', required=True, help='a new folder for the ledgers of this run')
    parser.add_argument('--cases', default=','.join(CASES))
    parser.add_argument('--quick', action='store_true', help='fewer kills and rounds (used for the changed copies of the sink)')
    parser.add_argument('--fail-fast', action='store_true')
    parser.add_argument('--flood-bytes', type=int, default=10737418240)
    parser.add_argument('--seed', type=int, default=20261119)
    parser.add_argument('--record', help='write the results (no times, no sizes) to this JSON file')
    parser.add_argument('--measurements', help='write the measured times and sizes to this JSON file')
    args = parser.parse_args()
    names = args.cases.split(',')
    try:
        for name in names:
            require(name in CASES, 'unknown case ' + name)
        for key in ('sink', 'kill_sink', 'binary', 'interposer'):
            require(Path(getattr(args, key)).is_file(), 'missing file ' + getattr(args, key))
            setattr(args, key, str(Path(getattr(args, key)).resolve()))
        require(Path(args.binary).name == 'refund', 'the copy of the binary must be named "refund"')
        require(hashlib.sha256(Path(args.binary).read_bytes()).hexdigest() == BINARY_SHA256, 'the refund binary is not the pinned one (b8ed5ec2...)')
        require(not Path(args.work).exists(), 'the work folder exists already')
        soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
        resource.setrlimit(resource.RLIMIT_NOFILE, (min(4096, hard) if hard != resource.RLIM_INFINITY else 4096, hard))
        suite = Suite(args)
        suite.work.mkdir(parents=True)
    except Failed as error:
        print('SUITE ERROR: %s' % error)
        return 2
    results, measurements, failed = {}, {}, []
    for name in names:
        try:
            results[name], measurements[name] = CASES[name](suite)
            print('PASS %-12s %s' % (name, json.dumps(results[name], sort_keys=True)), flush=True)
        except Failed as error:
            failed.append(name)
            results[name] = {'failed': str(error)}
            print('FAIL %-12s %s' % (name, error), flush=True)
        except Exception:  # an error of the suite itself is a failure of the case, never a pass
            failed.append(name)
            results[name] = {'failed': 'error in the suite: ' + traceback.format_exc(limit=4)}
            print('FAIL %-12s error in the suite\n%s' % (name, traceback.format_exc()), flush=True)
        if failed and args.fail_fast:
            break
    require_same = hashlib.sha256(Path(args.binary).read_bytes()).hexdigest() == BINARY_SHA256
    if not require_same:
        failed.append('binary-identity')
        print('FAIL the refund binary changed during the run')
    if args.record:
        Path(args.record).write_text(json.dumps({'cases': results, 'failed': failed, 'quick': args.quick, 'seed': args.seed}, indent=2, sort_keys=True) + '\n')
    if args.measurements:
        Path(args.measurements).write_text(json.dumps(measurements, indent=2, sort_keys=True) + '\n')
    print('SUITE %s: %d of %d cases passed' % ('FAILED' if failed else 'PASSED', len(results) - len([n for n in failed if n in results]), len(names)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
