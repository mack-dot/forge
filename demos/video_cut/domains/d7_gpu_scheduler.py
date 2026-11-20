"""Domain 7, GPU scheduler. Policy: demos/video_cut/policies/gpu-slots.json (inventory airlock, max_alpha_bps 0).

Mapping. The engine has no GPU rule. Its inventory airlock takes a 0/1 selection of requests under row
capacities, with an LP-duality certificate (PROTOCOL.md section 8). Here one key is one night of one GPU:
4 one-hour slots, capacity 1 each. A column is a job; it needs a run of slots and has a value. A solver
proposes which jobs run (x) and prices (y, z). `alpha_bps` 0 states: no feasible selection has more value.

Who decides. The engine's native Rust `Accepts` runs first (NATIVE CHECK). Then the engine runs the
Dafny-compiled `BookingDualCert` checker through Node. An overbooked batch stops at the native check, so
this module ALSO starts the Dafny-compiled checker itself (`node src/airlock/node/booking_check.cjs
build/airlock/checker/model.cjs`, the canonical JSON on stdin) and records its own line and exit code.
"Proved" applies only to the Dafny SOURCE of that checker (build-record.json). The Dafny JavaScript compiler,
Node, bignumber.js and the helper's conversion code are trusted, not proved.

Solvers. All three are the committed, untrusted guests of Slice 3, started as real processes:
guests/booking/v1_baseline.ts (TypeScript), guests/booking/v2_fast.rs (safe Rust, built here with rustc),
guests/booking/v3_adversary.py (Python, mode overbook). A sampler reads the process list during the swap
and counts Dafny, Boogie and Z3 processes. The count on screen is the observed one.

Gaps (also printed by ctx.gap): the committed records say TypeScript v1 -> Rust v2, with Python as the
adversary v3 (not "Python -> Rust"); the Slice 3 record is of another issuer, sink and checker core than
the engine of this take; the checker is proved against a candidate spec that is not approved intent; the
check is sound, not complete; nothing here is about real GPUs.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time

try:
    from harness import TakeFailed
except ImportError:  # the folder is imported as a package
    from ..harness import TakeFailed

NUMBER, NAME, TITLE = 7, 'gpu_scheduler', 'GPU scheduler with a runtime certificate'
D = 'gpu_scheduler'
ROOT = Path(__file__).resolve().parents[3]
HELPER = ROOT / 'src/airlock/node/booking_check.cjs'
V1_TS = ROOT / 'guests/booking/v1_baseline.ts'
V2_RS = ROOT / 'guests/booking/v2_fast.rs'
V3_PY = ROOT / 'guests/booking/v3_adversary.py'
SLICE3 = ROOT / 'proposals/forge2-slice3-runtime-certificates/records/evidence.json'
BUILD_RECORD = ROOT / 'proposals/forge2-pillar3-dual-certificate/benchmark/records/build-record.json'
LBL_INV = 'PROVED CORE source (Dafny-compiled checker; compiler and Node trusted) + NATIVE CHECK + FINITE TEST'
LBL_NATIVE = 'NATIVE CHECK + FINITE TEST (the native Accepts refused it before the checker ran)'
LBL_DIRECT = 'PROVED CORE source (Dafny-compiled checker started directly; compiler and Node trusted) + FINITE TEST'
RULE = 'BOOK: x is 0/1; A x <= c (slot capacity); A^T y + z >= w; y.c + sum z <= w.x (alpha_bps 0)'
RULE_CHECKER = 'compiled VerifyCertifiedBooking: ACCEPT only if Accepts(A, c, w, x, y, z, alpha_bps)'
SAMPLE_S = 0.05
# One GPU, four one-hour slots (rows). Five jobs (columns): the slots a job needs, and its value.
JOBS = [('train-llm', (0, 1), 8), ('eval-suite', (1, 2), 5), ('finetune', (2, 3), 7), ('notebook', (0,), 3), ('render', (3,), 2)]
SLOTS = 4
CAPACITY = ['1'] * SLOTS
NEEDS = [['1' if i in slots else '0' for _, slots, _ in JOBS] for i in range(SLOTS)]
VALUES = [str(v) for _, _, v in JOBS]
PROBLEM = json.dumps({'capacity': CAPACITY, 'needs': NEEDS, 'values': VALUES}, separators=(',', ':')) + '\n'


def sha256_of(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def is_prover(command):
    """True if the PROGRAM of a process is Dafny, Boogie or Z3 (the rule of scripts/demo_gauntlet.py)."""
    words = command.split()
    name = Path(words[0]).name.lower() if words else ''
    low = command.lower()
    return name in ('dafny', 'boogie') or name.startswith('z3') or (name == 'dotnet' and ('dafny' in low or 'boogie' in low))


class Watch:
    """Samples the process list until end(). Keeps every prover process it saw: all, and those that descend
    from this take's process."""

    def __init__(self):
        self.all, self.mine, self.samples, self.error = set(), set(), 0, None
        self.stop = threading.Event()
        self.started = time.perf_counter()
        self.thread = threading.Thread(target=self.loop, daemon=True)
        self.thread.start()

    def sample(self):
        p = subprocess.run(['/bin/ps', '-axo', 'pid=,ppid=,command='], capture_output=True, timeout=60)
        if p.returncode != 0 or not p.stdout:
            raise TakeFailed('the process list could not be read')
        parent, cmd = {}, {}
        for ln in p.stdout.decode('utf-8', 'replace').split('\n'):
            t = ln.split(None, 2)
            if len(t) == 3 and t[0].isdigit() and t[1].isdigit():
                parent[int(t[0])], cmd[int(t[0])] = int(t[1]), t[2]
        me = os.getpid()
        for pid, c in cmd.items():
            if not is_prover(c):
                continue
            self.all.add(pid)
            q, seen = pid, set()
            while q in parent and q not in seen and q > 1:
                if q == me:
                    self.mine.add(pid)
                    break
                seen.add(q)
                q = parent[q]
        self.samples += 1

    def loop(self):
        while not self.stop.is_set():
            try:
                self.sample()
            except Exception as e:  # noqa: BLE001  (kept and raised by end())
                self.error = e
                return
            self.stop.wait(SAMPLE_S)

    def end(self):
        """Stops after one more full sample. Returns the measured mean time between two samples in ms."""
        self.stop.set()
        self.thread.join()
        if self.error is None:
            try:
                self.sample()
            except Exception as e:  # noqa: BLE001
                self.error = e
        elapsed = time.perf_counter() - self.started
        if self.error is not None:
            raise TakeFailed('process sampler: %r' % (self.error,))
        return elapsed * 1000 / self.samples


def sampler_control(ctx):
    """Positive control: a `sleep` process that this take starts under the name `z3-video-cut-control`.
    The sampler must see it, or its count during the swap would mean nothing. Returns the samples it took."""
    child = subprocess.Popen(['z3-video-cut-control', '30'], executable='/bin/sleep', env=ctx.env)
    watch = Watch()
    try:
        deadline = time.perf_counter() + 20
        while child.pid not in watch.mine and watch.error is None and time.perf_counter() < deadline:
            time.sleep(0.01)
    finally:
        child.kill()
        child.wait()
        watch.end()
    if child.pid not in watch.mine:
        raise TakeFailed('the process sampler did not see its control process; its count would mean nothing')
    return watch.samples


def solve(ctx, argv, what):
    """Starts one untrusted solver process, gives it the problem line, returns (certificate, ms)."""
    t = time.perf_counter()
    p = subprocess.run([str(a) for a in argv], input=PROBLEM.encode(), capture_output=True, timeout=120, cwd=str(ROOT), env=ctx.env)
    ms = (time.perf_counter() - t) * 1000
    if p.returncode != 0:
        raise TakeFailed('%s: exit %d %r' % (what, p.returncode, p.stderr[-300:]))
    a = json.loads(p.stdout.decode('ascii').split('\n')[0])
    if sorted(a) != ['allocation', 'alphaBps', 'requestPrices', 'slotPrices']:
        raise TakeFailed('%s: not a proposal: %r' % (what, sorted(a)))
    # The certificate of the engine, built from the problem of THIS take and the solver's own answer.
    return {'A': NEEDS, 'c': CAPACITY, 'w': VALUES, 'x': a['allocation'], 'y': a['slotPrices'], 'z': a['requestPrices'],
            'alpha_bps': a['alphaBps']}, ms


def canonical(cert):
    """The input form of the helper: the keys in the order A, c, w, x, y, z, alpha_bps, no spaces."""
    return json.dumps({k: cert[k] for k in ('A', 'c', 'w', 'x', 'y', 'z', 'alpha_bps')}, separators=(',', ':'))


def checker(ctx, model, cert, headline, want):
    """Starts the Dafny-compiled checker directly. The observed text is its own stdout line and its exit code."""
    t = time.perf_counter()
    p = subprocess.run([ctx.node, str(HELPER), str(model)], input=canonical(cert).encode(), capture_output=True, timeout=120, env=ctx.env)
    ms = (time.perf_counter() - t) * 1000
    observed = '%s exit=%d' % (p.stdout.decode('ascii', 'replace').strip() or 'NO-OUTPUT', p.returncode)
    if p.stderr:
        observed += ' stderr=%r' % p.stderr.decode('utf-8', 'replace').strip()[:160]
    ctx.record(D, headline, RULE_CHECKER, 'node booking_check.cjs model.cjs < {"A":<4x5>,"c":[%s],"w":..,"x":[%s],..}' % (
        ','.join(cert['c']), ','.join(cert['x'])), want, observed, ms, LBL_DIRECT, klass='EVENT')


def book_text(key, rid, cert):
    return 'BOOK lab-a %s %s <hash> {"A":<4x5>,"c":[%s],"w":[%s],"x":[%s],"y":[%s],"z":[%s],"alpha_bps":"%s"}' % (
        key, rid, ','.join(cert['c']), ','.join(cert['w']), ','.join(cert['x']), ','.join(cert['y']), ','.join(cert['z']), cert['alpha_bps'])


def cite_slice3(ctx):
    """What the committed Slice 3 record says. Every value is read from the file now."""
    src = str(SLICE3.relative_to(ROOT))
    rec = json.loads(SLICE3.read_text())
    swap = rec['optimizer_swap']
    ctx.note(D, 'Slice 3 record file SHA-256 (computed now)', sha256_of(SLICE3), src)
    for r in swap['runs'][:2]:
        ctx.note(D, 'Slice 3 record: optimizer %s' % r['optimizer'],
                 'language=%r argv=%r batches=%d committed=%d committed_at_gap_0=%d exit_code=%d' % (
                     r['language'], r['argv'], r['batches'], r['counts']['committed'], r['counts']['committed_at_gap_0'], r['exit_code']),
                 src + ' optimizer_swap.runs[]')
    adv = [r for r in swap['runs'] if r['optimizer'].startswith('v3')]
    ctx.note(D, 'Slice 3 record: optimizer v3 runs',
             '%d runs, languages %r, committed in total %d' % (len(adv), sorted({r['language'] for r in adv}), sum(r['counts']['committed'] for r in adv)),
             src + ' optimizer_swap.runs[]')
    ctx.note(D, 'Slice 3 record: commands between the first and the last optimizer', swap['commands_of_this_script_between_first_and_last_optimizer'],
             src + ' optimizer_swap.commands_of_this_script_between_first_and_last_optimizer')
    ctx.note(D, 'Slice 3 record: of them Dafny or Z3', swap['of_them_dafny_or_z3'], src + ' optimizer_swap.of_them_dafny_or_z3')
    ctx.note(D, 'Slice 3 record: compiled core SHA-256 before and after the swap', swap['compiled_core_sha256_before_and_after'],
             src + ' optimizer_swap.compiled_core_sha256_before_and_after')
    ctx.note(D, 'Slice 3 record: gate_accepted / end_to_end', '%r / %r' % (rec['gate_accepted'], rec['end_to_end']), src)
    return swap


def run(ctx):
    model = Path(ctx.engine_dir) / 'checker' / 'model.cjs'
    if not model.is_file():
        raise TakeFailed('%s is missing: run `python3 bin/forge-airlock build --checker`' % model)
    build = json.loads(BUILD_RECORD.read_text())
    model_sha = sha256_of(model)
    if model_sha != build['module_sha256']:
        raise TakeFailed('the checker model %s is not the module of %s' % (model_sha, BUILD_RECORD))
    brc = str(BUILD_RECORD.relative_to(ROOT))
    ctx.note(D, 'checker model SHA-256 (computed now; equal to module_sha256 of the record)', model_sha, 'measured live')
    ctx.note(D, 'proof record of the checker SOURCE', 'source=%s verify_exit=%d verify_last_line=%r' % (
        build['source'], build['verify_exit'], build['verify_last_line']), brc)

    st = ctx.store('gpu', ['gpu-slots.json'])
    caps = ','.join(CAPACITY)
    ctx.shot(D, 'Open GPU night one', 'trusted opener sets the slot capacities', 'OPEN_INVENTORY lab-a gpu-night-1 open-night-1 gpu-slots ' + caps,
             'COMMITTED', lambda: st.open_inventory('lab-a', 'gpu-night-1', 'open-night-1', 'gpu-slots', [int(c) for c in CAPACITY]))
    h1 = st.get('lab-a', 'gpu-night-1').state_hash

    # The buggy batch: the committed adversary (Python, mode overbook) books every job.
    bad, bad_ms = solve(ctx, [sys.executable, '-B', V3_PY, 'overbook'], 'solver v3 (Python adversary, overbook)')
    ctx.note(D, 'solver v3 (Python adversary, mode overbook) run time ms', round(bad_ms, 1), 'measured live')
    ctx.shot(D, 'Buggy solver overbooks GPU', RULE, book_text('gpu-night-1', 'bk-overbook', bad),
             'REJECTED_POLICY OVERBOOKED', lambda: st.book('lab-a', 'gpu-night-1', 'bk-overbook', h1, bad), LBL_NATIVE)
    checker(ctx, model, bad, 'Dafny checker, same overbook', 'REJECT exit=1')

    control_samples = sampler_control(ctx)
    ctx.note(D, 'sampler control: a sleep process named z3-video-cut-control was seen', 'yes, within %d samples' % control_samples, 'measured live')

    rustc = shutil.which('rustc')
    v2_bin, why_not = ctx.tmp / 'v2_fast', None
    if rustc is None:
        why_not = 'rustc is not installed'
    else:
        t = time.perf_counter()
        b = subprocess.run([rustc, '-D', 'unsafe_code', '-D', 'warnings', '--edition', '2021', '-C', 'opt-level=2', '-o', str(v2_bin), str(V2_RS)],
                           capture_output=True, timeout=600, cwd=str(ROOT))
        if b.returncode != 0 or not v2_bin.is_file():
            why_not = 'rustc exit %d' % b.returncode
        else:
            ver = subprocess.run([rustc, '--version'], capture_output=True, text=True, timeout=60).stdout.strip()
            ctx.note(D, 'solver v2 built from guests/booking/v2_fast.rs (not pinned, untrusted)', '%s in %.0f ms; source SHA-256 %s' % (
                ver, (time.perf_counter() - t) * 1000, sha256_of(V2_RS)), 'measured live')

    # The swap: v1 (TypeScript), then v2 (safe Rust), through the SAME engine process and the SAME checker model.
    watch = Watch()
    try:
        good1, ms1 = solve(ctx, [ctx.node, '--import', 'tsx', V1_TS], 'solver v1 (TypeScript)')
        ctx.shot(D, 'Solver v1 TypeScript books', RULE, book_text('gpu-night-1', 'bk-v1-ts', good1),
                 'COMMITTED', lambda: st.book('lab-a', 'gpu-night-1', 'bk-v1-ts', h1, good1), LBL_INV)
        checker(ctx, model, good1, 'Dafny checker, v1 batch', 'ACCEPT exit=0')
        ctx.note(D, 'solver v1 (TypeScript, guests/booking/v1_baseline.ts) run time ms', round(ms1, 1), 'measured live')
        if why_not is None:
            ctx.shot(D, 'Open GPU night two', 'trusted opener sets the slot capacities', 'OPEN_INVENTORY lab-a gpu-night-2 open-night-2 gpu-slots ' + caps,
                     'COMMITTED', lambda: st.open_inventory('lab-a', 'gpu-night-2', 'open-night-2', 'gpu-slots', [int(c) for c in CAPACITY]))
            h2 = st.get('lab-a', 'gpu-night-2').state_hash
            good2, ms2 = solve(ctx, [v2_bin], 'solver v2 (safe Rust)')
            ctx.shot(D, 'Solver v2 Rust books', RULE, book_text('gpu-night-2', 'bk-v2-rust', good2),
                     'COMMITTED', lambda: st.book('lab-a', 'gpu-night-2', 'bk-v2-rust', h2, good2), LBL_INV)
            checker(ctx, model, good2, 'Dafny checker, v2 batch', 'ACCEPT exit=0')
            ctx.note(D, 'solver v2 (safe Rust, guests/booking/v2_fast.rs) run time ms', round(ms2, 1), 'measured live')
            ctx.note(D, 'v1 and v2 answers for the same problem', 'x v1=%s v2=%s; prices y v1=%s v2=%s' % (
                ''.join(good1['x']), ''.join(good2['x']), ','.join(good1['y']), ','.join(good2['y'])), 'measured live')
    finally:
        every_ms = watch.end()
    if watch.mine:
        raise TakeFailed('a Dafny, Boogie or Z3 process of this take was seen during the swap: %r' % sorted(watch.mine))
    ctx.note(D, 'Dafny processes seen during the swap', 'Dafny processes seen during the swap: %d, sampled every %.0f ms (%d samples; '
             'Dafny, Boogie or Z3 by program name, among the processes that descend from this take)' % (len(watch.mine), every_ms, watch.samples), 'measured live')
    ctx.note(D, 'Dafny, Boogie or Z3 processes of OTHER programs on the machine in the same samples', len(watch.all - watch.mine), 'measured live')
    ctx.note(D, 'remaining slot capacity after the bookings', '; '.join('%s=%s' % (k, st.get('lab-a', k).fields.get('remaining'))
             for k in (['gpu-night-1'] + (['gpu-night-2'] if why_not is None else []))), 'measured live')

    swap = cite_slice3(ctx)
    if why_not is not None:
        ctx.skip(D, 'live solver swap to Rust: NOT IN TAKE (%s). The committed Slice 3 record is cited in its place.' % why_not)
    langs = [r['language'] for r in swap['runs'][:2]]
    ctx.gap(D, 'the directive says "Python -> Rust". The committed records say: v1 is %s, v2 is %s, and Python is only the adversary v3. '
            'The take shows TypeScript v1 -> Rust v2; the Python process is the adversary.' % (langs[0], langs[1]))
    ctx.gap(D, 'the Slice 3 record is of the Slice 3 token issuer and SQLite sink with checker core %s... (impl/BookingCertificate.dfy), under the '
            'macOS sandbox tool. The take runs the forge-airlock engine with checker model %s... (BookingDualCert.dfy) and no sandbox. '
            'Same guests, another component.' % (swap['compiled_core_sha256_before_and_after'][:12], model_sha[:12]))
    ctx.gap(D, '"no Dafny during the swap" means: none seen by a sampler. A process shorter than one sample interval can be missed.')
    ctx.gap(D, 'an overbooked batch never reaches the checker inside the engine: the native Accepts refuses it first. The direct checker '
            'call shows what the Dafny-compiled checker answers to the same certificate.')
    ctx.gap(D, 'PROVED applies to the Dafny source of the checker only, against its own Accepts predicate: a candidate spec that is not approved intent. '
            'The Dafny compiler, Node, bignumber.js, the helper and the engine are not proved.')
    ctx.gap(D, 'the check is sound, not complete: it can refuse a good schedule that comes with weak prices. It shows nothing about a solver.')
    ctx.gap(D, 'a GPU scheduler is modeled as 0/1 job selection under slot capacities (one GPU, 4 slots, 5 jobs). Nothing here is about real GPUs.')
