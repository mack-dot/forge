#!/usr/bin/env python3
"""Wave Gate 3: the "skeptic gauntlet" demo. Three acts on the REAL components of Slices 1, 2 and 3.

Nothing here is mocked, canned or simulated: every line that this script prints comes from a process
that it started in this run (the pinned Dafny, the clearing tool, the Slice 1 issuer and sink, the
Slice 3 swap runner with three optimizers under the operating-system sandbox) or from a file that
such a process wrote. The script holds expectations and compares; it decides no proof.

What a pass means: in THIS run the listed attacks had the listed results. It is a FINITE DEMONSTRATION.
A run of this script is not a proof and adds no evidence class. The proofs that the acts rest on are
the source proofs of Slices 1 to 3 (their EXIT scripts check them); this script does not run them
again, except where Act 1 starts Dafny through the clearing tool. end_to_end stays false.

  Act 1  Spec Clearing: the approved refund spec (NO_CHOICE), a rewritten variant (EQUIVALENT), a
         capped variant (DIVERGES, with a before/after example), a planted loose spec (CHOICE).
  Act 2  Finality barrage against the Slice 1 issuer and sink: out-of-policy proposals, a forged token,
         a race of several processes for one balance, replays of a settled request id, a flood of
         bytes with no line end (--flood-mb), then one valid refund.
  Act 3  Three optimizers in three languages against one compiled certificate checker core.

Usage: python3 scripts/demo_gauntlet.py [--flood-mb N] [--acts 1,2,3]
  --flood-mb N   size of the flood in MiB (default 600; 10240 is 10 GiB; at most 1048576). Below 512 the
                 memory bound of the flood means nothing and is NOT CHECKED; the run is then REDUCED.
  --acts         the acts to run (default 1,2,3). The demo is complete only with all three.
Exit codes: 0 all three acts with the full checks; 1 a required result was not observed; 2 a missing tool or
a crash; 3 a PARTIAL or REDUCED run in which every check that ran held (not a pass of the demo).
Environment: macOS arm64, the pinned Node first in PATH, rustc in PATH (it builds optimizer v2).
Raw outputs go to build/demo-gauntlet/ (ignored by git). Nothing is written under results/.
"""

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import select
import shutil
import subprocess
import sys
import threading
import time
import traceback

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
sys.path.insert(0, str(ROOT))
from common import canonical, digest, read_json  # noqa: E402
from backends import dafny  # noqa: E402  (the gate's own Dafny path and options)

CLEARING = 'scripts/spec_clearing.py'
# subject of clearing/subjects.json -> the verdict that the demo requires, and what it shows
ACT1 = [
    ('refund', 'NO_CHOICE', 'the approved refund spec leaves no choice to an implementation'),
    ('refund-rewrite', 'EQUIVALENT', 'a rewritten variant of the spec allows the same results for every input'),
    ('refund-cap', 'DIVERGES', 'a variant with a cap allows another result: one concrete before/after example'),
    ('refund-loose', 'CHOICE', 'a planted loose spec: two verified implementations differ at one input'),
]
REFUND_CORE = 'impl/RefundFinality.dfy'
REFUND_FOOTER = b'\nmodule.exports = { RefundFinality, Refund, runtime: _dafny };\n'
SLICE1_RECORD = 'proposals/forge2-slice1-refund-finality/records/evidence.json'
ISSUER = 'ts/refund-finality/minter.ts'
SPEC_LOCK = 'spec/refund/spec.lock'
SINK_TOOL = 'tests/demo-gauntlet/sink_tool.ts'
COMMIT = 'tests/refund-finality/commit_cli.ts'
DOMAIN = 'FORGE_REFUND_FINALITY_SLICE1_V1'
RACERS, REPLAYS = 8, 12
STALE = "stored state is not the token's pre-state"
BOOKING_CORE = 'impl/BookingCertificate.dfy'
BOOKING_FOOTER = b'\nmodule.exports = { BookingCertificate, BookingDualCert, runtime: _dafny };\n'
SLICE3_RECORD = 'proposals/forge2-slice3-runtime-certificates/records/evidence.json'
SWAP = 'tests/booking-certificate/swap.ts'
RUST_SOURCE = 'guests/booking/v2_fast.rs'
ADVERSARY_MODES = ['overbook', 'forged-certificate', 'double-book']
# The issuer keeps at most 64 KiB of one line. Its memory must not grow with the flood: the peak
# resident memory of the issuer process may be at most this much above its value before the flood.
# The bound finds an issuer that keeps more than this much of the flood. So it means something only
# for a flood of at least twice the limit; below that it is not checked (review finding R1).
FLOOD_GROWTH_LIMIT_MIB = 256
FLOOD_FLOOR_MIB = 2 * FLOOD_GROWTH_LIMIT_MIB
ANSWER_SECONDS = 120


class Failed(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Failed(message)


def rel(path):
    return Path(path).resolve().relative_to(ROOT).as_posix()


def say(text=''):
    print(text, flush=True)


class Run:
    def __init__(self, work):
        self.work = work
        work.mkdir(parents=True)
        self.commands = []
        self.lock = threading.Lock()

    def execute(self, argv, name, **options):
        child = subprocess.run([str(part) for part in argv], cwd=ROOT, capture_output=True, **options)
        (self.work / (name + '.stdout')).write_bytes(child.stdout)
        (self.work / (name + '.stderr')).write_bytes(child.stderr)
        with self.lock:
            shown = [str(part).replace(str(ROOT), '<repository>').replace(str(Path.home()), '<home>') for part in argv]
            self.commands.append({'name': name, 'argv': shown, 'exit_code': child.returncode})
            (self.work / 'operations.json').write_bytes(canonical({'commands': self.commands, 'stage_exit': False}))
        return child


def compile_core(run, source, footer, name, record_path):
    """Compiles a checker core with the pinned Dafny. The module must be the one of the slice's evidence record."""
    out = run.work / name
    out.mkdir()
    built = run.execute([dafny.DAFNY, 'build', source, '--target', 'js', '--output', rel(out / 'model'), *dafny.OPTIONS],
                        'compile-' + name)
    require(built.returncode == 0, name + ': the pinned Dafny did not verify and compile the core (exit %d)' % built.returncode)
    module = out / 'model.cjs'
    module.write_bytes((out / 'model.js').read_bytes() + footer)
    recorded = read_json(ROOT / record_path)['compiled_core']['module_sha256']
    require(digest(module.read_bytes()) == recorded, name + ': CORE_MODULE: the compiled core is not the module of the evidence record')
    return module, recorded


# ---------------------------------------------------------------------------------------------------------
# Act 1

def act1(run):
    say('ACT 1  Spec Clearing (pinned Dafny through scripts/spec_clearing.py; 4 subjects, started together)')

    def clear(item):
        subject, _, _ = item
        work = run.work / ('act1-' + subject)
        started = time.monotonic()
        child = run.execute([sys.executable, CLEARING, subject, rel(work)], 'act1-' + subject)
        record = read_json(work / 'record.json') if (work / 'record.json').is_file() else None
        return child.returncode, record, time.monotonic() - started

    with ThreadPoolExecutor(max_workers=len(ACT1)) as pool:
        results = list(pool.map(clear, ACT1))
    rows = []
    for (subject, wanted, meaning), (code, record, seconds) in zip(ACT1, results):
        verdict = record['verdict'] if record else 'NO RECORD'
        say('  %-15s %-10s (required %s; tool exit %d; %.0f s)  %s' % (subject, verdict, wanted, code, seconds, meaning))
        require(code == 0 and record is not None and record['id'] == subject, 'act 1: the clearing tool gave no result for ' + subject)
        require(verdict == wanted, 'act 1: %s: required %s, observed %s' % (subject, wanted, verdict))
        examples = record.get('examples') or []
        if wanted in ('DIVERGES', 'CHOICE'):
            require(len(examples) >= 1, 'act 1: %s: the verdict has no verified example' % subject)
            say('      verified example: ' + json.dumps(examples[0], sort_keys=True)[:300])
        rows.append({'subject': subject, 'verdict': verdict, 'required': wanted, 'tool_exit': code, 'examples': examples})
    say('  The loose spec has the verdict CHOICE: it is not cleared for approval. The tool blocks nothing by itself;')
    say('  a person, or a rule that reads this verdict, does.')
    return {'subjects': rows}


# ---------------------------------------------------------------------------------------------------------
# Act 2

def canon(value):
    """The canonical JSON text of ts/refund-finality/encoding.ts for ASCII texts and booleans."""
    return json.dumps(value, sort_keys=True, separators=(',', ':'))


class Issuer:
    """The real Slice 1 token issuer as its own process. Raw bytes in, lines out."""

    def __init__(self, run, module):
        self.errors = open(run.work / 'issuer.stderr', 'wb')
        self.process = subprocess.Popen(['node', '--import', 'tsx', ISSUER, rel(module), SPEC_LOCK, 'off'], cwd=ROOT,
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.errors, bufsize=0)
        self.next, self.attempts = 0, 0
        self.ready = self.line()
        require(self.ready.get('ready') is True, 'act 2: the issuer gave no ready line')

    def line(self):
        """One answer line, with a time limit. The pipe is not buffered here, so select sees every byte."""
        data = b''
        while not data.endswith(b'\n'):
            ready, _, _ = select.select([self.process.stdout], [], [], ANSWER_SECONDS)
            require(ready, 'act 2: the issuer gave no answer in %d s' % ANSWER_SECONDS)
            piece = os.read(self.process.stdout.fileno(), 65536)
            require(piece != b'', 'act 2: THE ISSUER PROCESS ENDED')
            data += piece
        require(data.count(b'\n') == 1, 'act 2: the issuer wrote more than one line for one message')
        return json.loads(data)

    def ask(self, pre, transition):
        self.next += 1
        self.process.stdin.write(json.dumps({'id': self.next, 'pre': pre, 'transition': transition}).encode() + b'\n')
        self.process.stdin.flush()
        answer = self.line()
        require(answer.get('id') == self.next, 'act 2: the issuer answered another message')
        return answer

    def resident_mib(self):
        out = subprocess.run(['ps', '-o', 'rss=', '-p', str(self.process.pid)], capture_output=True, text=True).stdout.strip()
        require(out.isdigit(), 'act 2: the issuer process is gone')
        return int(out) / 1024

    def end(self):
        """Closes the input. Returns the exit code and the peak resident memory that the kernel recorded."""
        self.process.stdin.close()
        rest = self.process.stdout.read()
        require(rest in (b'', None), 'act 2: the issuer wrote lines that no message asked for')
        _, status, usage = os.wait4(self.process.pid, 0)
        self.process.returncode = os.waitstatus_to_exitcode(status)
        self.errors.close()
        return self.process.returncode, usage.ru_maxrss / (1024 * 1024)  # macOS reports bytes

    def kill(self):
        """For failure paths: no issuer process may stay behind."""
        if self.process.returncode is None:
            try:
                self.process.kill()
                self.process.wait()
            except OSError:
                pass
        self.errors.close()


def transition(pre, request_id, amount, reason='returned_item', post_remaining=None, intent_amount=None):
    remaining = int(pre['remaining']) - amount if post_remaining is None else post_remaining
    return {'request': {'requestId': request_id, 'amount': str(amount), 'reason': reason},
            'post': dict(pre, remaining=str(remaining)),
            'intent': {'chargeId': pre['chargeId'], 'requestId': request_id,
                       'amount': str(amount if intent_amount is None else intent_amount), 'reason': reason}}


def act2(run, flood_mib):
    say('ACT 2  Proof-Carrying Finality: attacks on the real Slice 1 issuer process and SQLite sink')
    module, module_sha = compile_core(run, REFUND_CORE, REFUND_FOOTER, 'refund-core', SLICE1_RECORD)
    say('  checker core compiled by the pinned Dafny; module %s... equal to the Slice 1 record' % module_sha[:12])
    work = run.work / 'act2'
    work.mkdir()
    issuer = Issuer(run, module)
    try:
        return act2_attacks(run, work, issuer, module_sha, flood_mib)
    finally:
        issuer.kill()


def act2_attacks(run, work, issuer, module_sha, flood_mib):
    config, database = work / 'sink-config.json', work / 'charge.sqlite'
    config.write_text(json.dumps({key: issuer.ready[key] for key in ('publicKeyPem', 'specLockSha256', 'checkerSha256')}))
    counter = [0]

    def node(script, *arguments):
        counter[0] += 1
        child = run.execute(['node', '--import', 'tsx', script, *arguments], 'act2-%03d-%s' % (counter[0], Path(script).stem))
        require(child.returncode == 0, 'act 2: %s ended with exit %d' % (script, child.returncode))
        return json.loads(child.stdout)

    def sink_report():
        return node(SINK_TOOL, 'report', rel(database), rel(config))

    def commit_together(texts, label):
        """One operating-system process per token text; all call commit at one common start time."""
        paths = []
        for index, text in enumerate(texts):
            path = work / ('%s-%02d.token' % (label, index))
            path.write_text(text)
            paths.append(path)
        start_at = str(int(time.time() * 1000) + 2500)
        with ThreadPoolExecutor(max_workers=len(paths)) as pool:
            answers = list(pool.map(lambda path: node(COMMIT, rel(database), rel(config), rel(path), start_at), paths))
        require(all(answer['onTime'] for answer in answers), 'act 2: a process of the %s group was late for the common start' % label)
        return answers

    pre = {'chargeId': 'ch_demo', 'original': '1000', 'remaining': '600', 'refundEnabled': True}
    first = node(SINK_TOOL, 'init', rel(database), rel(config), json.dumps(pre))
    require(first['state'] == pre and first['outbox'] == [] and first['audit'] == [], 'act 2: the sink did not store the first state')
    say('  stored charge: original 1000, remaining 600, refunds enabled')
    effects_expected = 0

    # 2a. Out-of-policy proposals to the issuer, then attempts at the sink with no valid token.
    proposals = [
        ('amount 601 of 600 remaining', transition(pre, 'rq_over', 601, post_remaining=0)),
        ('reason "goodwill" (not an approved reason)', transition(pre, 'rq_reason', 100, reason='goodwill')),
        ('amount 100, post-state keeps 600 remaining', transition(pre, 'rq_keep', 100, post_remaining=600)),
        ('amount 100, intent says 500', transition(pre, 'rq_intent', 100, intent_amount=500)),
    ]
    refused, attempts_without_commit = 0, 0
    for label, candidate in proposals:
        attempts_without_commit += 1
        answer = issuer.ask(pre, candidate)
        say('  2a issuer, %-45s -> %s' % (label, 'TOKEN' if answer['ok'] else 'no token (' + str(answer.get('reason')) + ')'))
        require(answer['ok'] is False and answer.get('reason') == 'core: Refuse', 'act 2a: an out-of-policy proposal was not refused by the core: ' + label)
        refused += 1
    forged_body = {'domain': DOMAIN, 'specLockSha256': issuer.ready['specLockSha256'], 'checkerSha256': issuer.ready['checkerSha256'],
                   'preStateSha256': hashlib.sha256(canon(pre).encode()).hexdigest(), 'requestId': 'rq_forged',
                   'post': dict(pre, remaining='0'),
                   'intent': {'chargeId': 'ch_demo', 'requestId': 'rq_forged', 'amount': '600', 'reason': 'returned_item'}}
    forged = canon({'body': forged_body, 'signature': base64.b64encode(bytes(64)).decode()})
    attempts = commit_together([forged, '{}', ''], 'forged')
    attempts_without_commit += len(attempts)
    for name, answer in zip(('forged token (right shape, right hashes, signature of zero bytes)', 'the text {}', 'an empty text'), attempts):
        say('  2a sink,   %-45s -> %s (%s)' % (name[:45], answer['status'], answer.get('reason')))
    require([a['status'] for a in attempts] == ['rejected'] * 3 and attempts[0].get('reason') == 'signature does not verify',
            'act 2a: the sink did not reject an attempt without a valid token')
    after = sink_report()
    require(after['state'] == pre and after['outbox'] == [] and after['settled'] == [], 'act 2a: AN ATTEMPT WITHOUT A TOKEN HAD AN EFFECT')

    # 2b. A race: several valid tokens for ONE pre-state. Each alone is inside the rule; two together are not.
    tokens = []
    for number in range(1, RACERS + 1):
        answer = issuer.ask(pre, transition(pre, 'rq_race_%d' % number, 400))
        require(answer['ok'] is True, 'act 2b: the issuer refused a valid proposal')
        tokens.append(canon(answer['token']))
    race = commit_together(tokens, 'race')
    committed = [index for index, answer in enumerate(race) if answer['status'] == 'committed']
    stale = sum(1 for answer in race if answer['status'] == 'rejected' and answer.get('reason') == STALE)
    say('  2b race: %d processes, one valid token each (400 of 600), one common start time -> committed %d, rejected as stale %d'
        % (RACERS, len(committed), stale))
    require(len(committed) == 1 and stale == RACERS - 1, 'act 2b: THE RACE DID NOT END WITH EXACTLY ONE COMMIT')
    effects_expected += 1
    attempts_without_commit += sum(1 for answer in race if answer['status'] != 'committed')
    winner = tokens[committed[0]]
    winner_id = json.loads(winner)['body']['requestId']
    state = dict(pre, remaining='200')
    after = sink_report()
    require(after['state'] == state and after['settled'] == [winner_id] and len(after['outbox']) == 1, 'act 2b: the stored state is not one refund of 400')
    say('     stored remaining: 200; outbox rows: 1 (request %s)' % winner_id)

    # 2c. Replays of the settled request id, the losing tokens again, and another token for the settled id.
    replays = commit_together([winner] * REPLAYS, 'replay')
    losers = commit_together([text for index, text in enumerate(tokens) if index != committed[0]], 'loser')
    other = issuer.ask(state, transition(state, winner_id, 100))
    require(other['ok'] is True, 'act 2c: the issuer refused a valid proposal')
    second = commit_together([canon(other['token'])], 'second')[0]
    attempts_without_commit += sum(1 for answer in replays + losers + [second] if answer['status'] != 'committed')
    say('  2c replay: the settled token %d times at once -> %s; the %d losing tokens again -> %s; another signed token for the settled request id -> %s (%s)'
        % (REPLAYS, sorted({a['status'] for a in replays}), RACERS - 1, sorted({a['status'] for a in losers}), second['status'], second.get('reason')))
    require(all(a['status'] == 'replayed' for a in replays) and all(a['status'] == 'rejected' and a.get('reason') == STALE for a in losers)
            and second['status'] == 'rejected' and second.get('reason') == 'request id is already settled with another token',
            'act 2c: a replay or a stale token was not answered as required')
    after = sink_report()
    require(after['state'] == state and after['settled'] == [winner_id] and len(after['outbox']) == 1, 'act 2c: A REPLAY HAD AN EFFECT')

    # 2d. The flood: raw bytes with no line end into the issuer's input, then one valid request.
    before_mib = issuer.resident_mib()
    chunk, peak, stop = b'A' * (1024 * 1024), [before_mib], threading.Event()

    def sample():
        while not stop.is_set():
            try:
                peak[0] = max(peak[0], issuer.resident_mib())
            except Failed:
                return
            stop.wait(0.05)

    sampler = threading.Thread(target=sample, daemon=True)
    sampler.start()
    try:
        started = time.monotonic()
        try:
            for _ in range(flood_mib):
                issuer.process.stdin.write(chunk)
            issuer.process.stdin.write(b'\n')
            issuer.process.stdin.flush()
        except BrokenPipeError:
            raise Failed('act 2d: THE ISSUER PROCESS ENDED DURING THE FLOOD')
        flood_seconds = time.monotonic() - started
        too_long = issuer.line()
        attempts_without_commit += 1
        sent = time.monotonic()
        valid = issuer.ask(state, transition(state, 'rq_after_flood', 150))
        latency_ms = (time.monotonic() - sent) * 1000
        peak[0] = max(peak[0], issuer.resident_mib())  # one sample after the flood was read to its end
    finally:
        stop.set()
        sampler.join()
    flood_bytes = flood_mib * len(chunk)
    say('  2d flood: %s bytes (%d MiB) with no line end in %.2f s -> one answer: %s' % (format(flood_bytes, ','), flood_mib, flood_seconds, too_long.get('reason')))
    bound_checked = flood_mib >= FLOOD_FLOOR_MIB
    say('     issuer resident memory: %.0f MiB before the flood, %.0f MiB largest sample during and after it' % (before_mib, peak[0]))
    say('     next valid request after the flood -> %s in %.1f ms' % ('token' if valid.get('ok') else 'NO TOKEN', latency_ms))
    require(too_long == {'id': None, 'ok': False, 'reason': 'message too long'}, 'act 2d: the flood was not answered once with "message too long"')
    require(not bound_checked or peak[0] - before_mib <= FLOOD_GROWTH_LIMIT_MIB, 'act 2d: THE MEMORY OF THE ISSUER GREW WITH THE FLOOD (%.0f MiB)' % (peak[0] - before_mib))
    require(valid.get('ok') is True, 'act 2d: the issuer did not sign a valid request after the flood')
    final = commit_together([canon(valid['token'])], 'after-flood')[0]
    require(final['status'] == 'committed', 'act 2d: the sink did not commit the valid refund after the flood')
    effects_expected += 1
    exit_code, kernel_peak = issuer.end()
    end = sink_report()
    say('     valid refund of 150 committed; issuer exit %d at the end of its input; peak resident memory by the kernel: %.0f MiB' % (exit_code, kernel_peak))
    require(exit_code == 0, 'act 2d: the issuer did not end with exit 0')
    require(not bound_checked or kernel_peak - before_mib <= FLOOD_GROWTH_LIMIT_MIB, 'act 2d: THE MEMORY OF THE ISSUER GREW WITH THE FLOOD (kernel peak %.0f MiB)' % kernel_peak)
    if bound_checked:
        say('     memory bound: growth at most %d MiB for a flood of %d MiB: held (it finds an issuer that keeps more than %d MiB of the flood)'
            % (FLOOD_GROWTH_LIMIT_MIB, flood_mib, FLOOD_GROWTH_LIMIT_MIB))
    else:
        say('     memory bound: NOT CHECKED. A flood of %d MiB is below %d MiB; the bound of %d MiB would mean nothing.' % (flood_mib, FLOOD_FLOOR_MIB, FLOOD_GROWTH_LIMIT_MIB))
    require(end['state'] == dict(pre, remaining='50') and end['settled'] == [winner_id, 'rq_after_flood'] and len(end['outbox']) == effects_expected
            and end['audit'] == [], 'act 2: THE STORE DOES NOT HOLD EXACTLY THE TWO AUTHORIZED REFUNDS')
    # Measured from the final store: rows in the outbox that are not one of the two authorized commits.
    effects_of_attempts = len(end['outbox']) - effects_expected + sum(1 for row in end['outbox'] if row['requestId'] not in (winner_id, 'rq_after_flood'))
    require(effects_of_attempts == 0, 'act 2: AN ATTACK ATTEMPT HAD AN EFFECT')
    say('  result: %d outbox rows, both for a commit of a token (400, then 150; remaining 50); %d attempts that did not commit, %d outbox rows from them;'
        % (len(end['outbox']), attempts_without_commit, effects_of_attempts))
    say('          the sink\'s own audit of the token chain: no problem found')
    return {'core_module_sha256': module_sha, 'issuer_refusals': refused, 'race': {'processes': RACERS, 'committed': len(committed), 'stale': stale},
            'replays': REPLAYS, 'attempts_that_did_not_commit': attempts_without_commit, 'outbox_rows_from_those_attempts': effects_of_attempts,
            'outbox_rows': len(end['outbox']), 'memory_bound_checked': bound_checked,
            'flood': {'mib': flood_mib, 'bytes': flood_bytes, 'seconds': round(flood_seconds, 2), 'answer': too_long.get('reason'),
                      'issuer_resident_mib_before': round(before_mib, 1), 'issuer_resident_mib_sampled_peak': round(peak[0], 1),
                      'issuer_resident_mib_kernel_peak': round(kernel_peak, 1), 'valid_request_latency_ms_after': round(latency_ms, 2)},
            'final_state': end['state'], 'audit_problems': end['audit']}


# ---------------------------------------------------------------------------------------------------------
# Act 3

def is_prover(line):
    """True for a process whose PROGRAM is Dafny, Boogie or Z3: the name of its first word is `dafny`, `boogie`
    or starts with `z3`, or it is `dotnet` with a Dafny or Boogie argument. A text match on the whole command
    line is not used: the first version did that, and a shell command of the author whose text held the word
    "Dafny" made one run fail (and system processes with random text in an argument matched "z3")."""
    words = line.split()
    name = Path(words[0]).name.lower() if words else ''
    return name in ('dafny', 'boogie') or name.startswith('z3') or (name == 'dotnet' and re.search(r'dafny|boogie', line.lower()) is not None)


def prover_lines():
    """The command lines of all Dafny, Boogie and Z3 processes on this machine (one sample)."""
    child = subprocess.run(['ps', '-axo', 'command='], capture_output=True, text=True)
    lines = child.stdout.splitlines()
    require(child.returncode == 0 and lines, 'act 3: the process list could not be read')
    return [line for line in lines if is_prover(line)]


class Watch:
    """Samples the process list ten times per second between start and end. Holds the largest count of
    prover processes, and the largest count of those whose command line holds `marker`."""

    def __init__(self, marker=None):
        self.seen, self.marked, self.samples, self.error, self.marker = 0, 0, 0, None, marker
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self.loop, daemon=True)
        self.thread.start()

    def loop(self):
        while not self.stop.is_set():
            try:
                lines = prover_lines()
            except Failed as error:
                self.error = error
                return
            self.seen = max(self.seen, len(lines))
            if self.marker is not None:
                self.marked = max(self.marked, sum(1 for line in lines if self.marker in line))
            self.samples += 1
            self.stop.wait(0.1)

    def end(self):
        self.stop.set()
        self.thread.join()
        if self.error is not None:
            raise self.error
        return self.seen


def act3(run):
    say('ACT 3  Runtime Certificates: three optimizers in three languages against ONE compiled checker core')
    require(Path('/usr/bin/sandbox-exec').is_file(), 'act 3: no sandbox tool on this platform; the optimizers are not started')
    # Positive control of the sampler: while Dafny compiles the core, the sampler must see it.
    # The control counts only processes whose command line holds the output path of THIS compile.
    control = Watch(marker=rel(run.work / 'booking-core' / 'model'))
    try:
        module, module_sha = compile_core(run, BOOKING_CORE, BOOKING_FOOTER, 'booking-core', SLICE3_RECORD)
    finally:
        control.end()
    seen_at_compile = control.marked
    say('  checker core compiled by the pinned Dafny; module %s... equal to the Slice 3 record' % module_sha[:12])
    require(seen_at_compile > 0, 'act 3: the process sampler did not see the Dafny of this run while it compiled the core; its 0 would mean nothing')
    rustc = shutil.which('rustc')
    require(rustc is not None, 'act 3: rustc is not installed; optimizer v2 cannot be built (this script installs nothing)')
    source = (ROOT / RUST_SOURCE).read_text()
    require('#![forbid(unsafe_code)]' in source, 'act 3: optimizer v2 does not forbid unsafe code')
    binary = run.work / 'v2_fast'
    built = run.execute([rustc, '-D', 'unsafe_code', '-D', 'warnings', '--edition', '2021', '-C', 'opt-level=2', '-C', 'debuginfo=0',
                         '--remap-path-prefix', str(ROOT) + '=.', '-o', binary, RUST_SOURCE], 'rustc-v2')
    require(built.returncode == 0 and binary.is_file(), 'act 3: rustc did not build optimizer v2')
    optimizers = [('v1', 'TypeScript', ['node', '--import', 'tsx', 'guests/booking/v1_baseline.ts']),
                  ('v2', 'safe Rust, #![forbid(unsafe_code)]', [rel(binary)])]
    optimizers += [('v3-' + mode, 'Python, adversary mode ' + mode, ['python3', 'guests/booking/v3_adversary.py', mode]) for mode in ADVERSARY_MODES]
    recorded = {entry['optimizer']: entry['counts'] for entry in read_json(ROOT / SLICE3_RECORD)['optimizer_swap']['runs']}
    first, rows = len(run.commands), []
    watcher = Watch()
    try:
        for name, language, command in optimizers:
            out = run.work / ('swap-' + name)
            child = run.execute(['node', '--import', 'tsx', SWAP, rel(out), rel(module), name, 'all', '20000', *command], 'swap-' + name)
            require(child.returncode == 0, 'act 3: the swap run of %s ended with exit %d' % (name, child.returncode))
            report = read_json(out / 'report.json')
            counts = report['counts']
            say('  %-22s %-36s batches %d: tokens %d, committed %d, no token %d, forged offers rejected %d of %d'
                % (name, language, counts['batches'], counts['tokens'], counts['committed'], counts['no_token'],
                   counts['forged_offers_rejected'], counts['forged_offers']))
            require(report['optimizer'] == name and report['ids']['core_module_sha256'] == module_sha and counts['failed'] == 0
                    and all(row['pass'] is True for row in report['rows']), 'act 3: a row of %s failed' % name)
            require(counts['effects_of_attempts_that_did_not_commit'] == 0 and counts['effects_of_replays'] == 0
                    and counts['forged_offers'] == counts['forged_offers_rejected'], 'act 3: AN ATTEMPT WITHOUT A COMMIT HAD AN EFFECT (%s)' % name)
            require(counts == recorded[name], 'act 3: the counts of %s differ from the Slice 3 record' % name)
            if name.startswith('v3-'):
                require(counts['tokens'] == 0 and counts['committed'] == 0, 'act 3: THE ADVERSARY GOT A TOKEN')
            else:
                require(counts['committed'] > 0, 'act 3: an honest optimizer committed nothing')
            rows.append({'optimizer': name, 'language': language, 'counts': counts})
    finally:
        seen = [watcher.end()]
    require(digest(module.read_bytes()) == module_sha, 'act 3: the compiled core changed during the exchange')
    require(len(run.commands) - first == len(optimizers), 'act 3: this script started another command between the optimizers')
    say('  between the first and the last optimizer: Dafny, Boogie or Z3 processes on this machine (by program name),')
    say('  seen by a sampler (%d samples; it saw %d such process(es) of this run while Dafny compiled the core): %d.' % (watcher.samples, seen_at_compile, seen[0]))
    say('  The sampler is the only check of this; a process shorter than a sample interval can be missed. The one compiled core kept its bytes.')
    require(seen[0] == 0, 'act 3: a Dafny, Boogie or Z3 process was seen during the exchange')
    committed = sum(row['counts']['committed'] for row in rows if not row['optimizer'].startswith('v3-'))
    say('  result: %d allocations committed, each for a token of the checker core; adversary: 0 tokens, 0 effects' % committed)
    return {'core_module_sha256': module_sha, 'optimizers': rows, 'sampler_samples_during_the_exchange': watcher.samples,
            'prover_processes_seen_by_the_sampler': seen[0], 'prover_processes_seen_while_dafny_compiled_the_core': seen_at_compile,
            'committed': committed}


def attempt_folder():
    base = ROOT / 'build/demo-gauntlet'
    base.mkdir(parents=True, exist_ok=True)
    number = 1 + max([int(p.name.split('-')[1]) for p in base.glob('attempt-*')] or [0])
    return base / ('attempt-%04d' % number)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--flood-mb', type=int, default=600)
    parser.add_argument('--acts', default='1,2,3')
    args = parser.parse_args()
    require(set(args.acts.split(',')) <= {'1', '2', '3'} and 1 <= args.flood_mb <= 1048576, 'usage: --acts from 1,2,3; --flood-mb from 1 to 1048576')
    acts = sorted(set(args.acts.split(',')))
    require((platform.system(), platform.machine()) == ('Darwin', 'arm64'), 'this demo runs on macOS arm64 only (sandbox tool, recorded toolchain)')
    from scripts.javascript_env import check as check_javascript
    check_javascript()
    run = Run(attempt_folder())
    started = time.monotonic()
    say('SKEPTIC GAUNTLET  real components, real processes; a finite demonstration, not a proof; end_to_end=false')
    say('work folder: ' + rel(run.work))
    record = {'record': 'forge-demo-gauntlet', 'end_to_end': False, 'kind': 'FINITE DEMONSTRATION', 'acts_run': acts, 'flood_mib': args.flood_mb}
    if '1' in acts:
        record['act1'] = act1(run)
    if '2' in acts:
        record['act2'] = act2(run, args.flood_mb)
    if '3' in acts:
        record['act3'] = act3(run)
    record['wall_seconds'] = round(time.monotonic() - started, 1)
    reduced = '2' in acts and not record['act2']['memory_bound_checked']
    record['complete'] = acts == ['1', '2', '3'] and not reduced
    (run.work / 'record.json').write_bytes(canonical(record))
    if record['complete']:
        say('GAUNTLET PASSED in %.0f s. Every required result was observed in this run. A demonstration, not a proof. end_to_end=false' % record['wall_seconds'])
        return 0
    why = ([] if acts == ['1', '2', '3'] else ['PARTIAL: acts ' + ','.join(acts) + ' only']) + (['REDUCED: memory bound of the flood not checked'] if reduced else [])
    say('GAUNTLET NOT COMPLETE (%s) in %.0f s. The checks that ran held. This is not a pass of the demo. Exit 3. end_to_end=false' % ('; '.join(why), record['wall_seconds']))
    return 3


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Failed as error:
        print('GAUNTLET FAILED: ' + str(error), file=sys.stderr)
        sys.exit(1)
    except Exception:  # a missing tool or a crash is not a result of the demonstration
        traceback.print_exc()
        sys.exit(2)
