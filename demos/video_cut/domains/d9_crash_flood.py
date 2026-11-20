"""Domain 9, crash and flood. Policy: demos/video_cut/policies/crash-ledger.json (money airlock, parametric).

Mapping. Three failures of the caller or the machine, each against the real engine.
(a) Lease. `with_lease` opens a durable lease before the handler runs. A handler that raises a real
    TypeError leaves the lease open. `leases --sweep` after the deadline reports DROPPED_OBLIGATION. A
    handler that commits closes its lease; the same sweep does not report it.
(b) Flood. ctx.flood_mb MiB of bytes with no line end go into the stdin of a real `airlock-engine serve`
    process. A sampler reads the resident memory of that process with /bin/ps. After the LF the engine
    answers MALFORMED_REQUEST OVERSIZED; the next valid request on the same pipe must commit.
(c) SIGKILL. The kill-points build (a test-seam build of the same source, `--cfg kill_points`) stops at a
    named point of the WAL append; the scenario then sends a real SIGKILL (signal 9). The PRODUCTION engine
    opens the store next. Point b: half a record is in the WAL (torn). Point c: the record is written, the
    sync is not yet called. Point r: the sync returned, the ratchet entry is not yet written.

Labels: all NATIVE CHECK + FINITE TEST. Nothing here is proved. Every number is measured in this run, or is
read from a committed record that is named by path.

Gaps (also printed by ctx.gap): a SIGKILL is not a power loss (the page cache stays); F_FULLFSYNC, the
kernel and the drive are trusted; the kill build is a test-seam build; the memory bound of the flood is not
checked below 512 MiB; the 10 GiB record is of the Slice 1 token issuer, not of this engine; only handlers
that opened a lease are covered.
"""
import hashlib
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import threading
import time

try:
    from harness import TakeFailed
except ImportError:  # the folder is imported as a package
    from ..harness import TakeFailed

NUMBER, NAME, TITLE = 9, 'crash_flood', 'Crash and flood'
D = 'crash_flood'
ROOT = Path(__file__).resolve().parents[3]
RECORD_10GIB = ROOT / 'proposals/forge2-demo-gauntlet/records/run-10gib.json'
KILL_BUILD = ROOT / 'build' / 'silicon' / 'test' / 'airlock-engine-kill'  # the kill-points build of `bin/forge-airlock build`
LBL = 'NATIVE CHECK + FINITE TEST'
LBL_REPORT = 'NATIVE CHECK + FINITE TEST (a report of the engine, not a refusal)'
LBL_PY = 'PYTHON RUNTIME (the handler\'s own exception; not an engine answer)'
LBL_KILL = 'TEST-SEAM BUILD of the same source (kill points) + real SIGKILL; not a power loss'
LBL_RECOVER = 'NATIVE CHECK + FINITE TEST (production engine; recovery after a real SIGKILL)'
RULE_PAY = 'PAYOUT: amount <= 5000 COMMIT; amount >= 5001 REJECTED_POLICY'
RULE_LEASE = 'a lease closes only by a terminal verdict of its request id on its tenant and key; a sweep reports an open lease with now > deadline_ms'
RULE_LINE = 'a request line has at most 65,536 bytes before its LF; a longer line is skipped and answered MALFORMED_REQUEST OVERSIZED'
RULE_WAL = 'recovery: one incomplete record at the end of the WAL is cut; a whole record stays; a used request id is DUPLICATE_REQUEST_ID'
DEADLINE = 1700000000000          # a fixed deadline in the past; the sweep gets --now DEADLINE + 1
FLOOD_GROWTH_LIMIT_MIB = 256      # as scripts/demo_gauntlet.py: the bound means something only from twice this size
FLOOD_FLOOR_MIB = 2 * FLOOD_GROWTH_LIMIT_MIB
SAMPLE_S = 0.05
T, K = 'ledger', 'acct-1'


def read_line(proc, seconds=300):
    """One answer line of a serve process (its own bytes), or TakeFailed after `seconds`."""
    fd, buf, end = proc.stdout.fileno(), b'', time.monotonic() + seconds
    while not buf.endswith(b'\n'):
        if not select.select([fd], [], [], max(0.0, end - time.monotonic()))[0]:
            raise TakeFailed('no answer line in %d s: %r' % (seconds, buf[:200]))
        got = os.read(fd, 1)
        if not got:
            raise TakeFailed('the serve process closed its output: %r' % buf[:200])
        buf += got
    return buf.decode('ascii', 'replace').rstrip('\n')


def ask(proc, line):
    t = time.perf_counter()
    proc.stdin.write(line.encode('ascii') + b'\n')
    proc.stdin.flush()
    answer = read_line(proc)
    return answer, (time.perf_counter() - t) * 1000


# ------------------------------------------------------------------------------------------------ (a) lease

def lease_part(ctx, st):
    h = st.get(T, K).state_hash

    def good(lease):
        return lease.commit('refund', pre_state_hash=h, reason='PAYOUT', amount=1200)
    ctx.shot(D, 'Handler commits its payout', RULE_PAY + '; ' + RULE_LEASE,
             'OPEN_LEASE wh-ok %d %s %s; REFUND %s %s wh-ok <hash> PAYOUT 1200' % (DEADLINE, T, K, T, K),
             'COMMITTED', lambda: st.with_lease('wh-ok', DEADLINE, T, K, good), LBL)

    def crashing(lease):
        event = json.loads('{"type": "payout.requested", "amount": null}')
        cents = event['amount'] + 1  # the bug: None + 1, a real TypeError, after the lease is open and before any commit
        return lease.commit('refund', pre_state_hash=st.get(T, K).state_hash, reason='PAYOUT', amount=cents)

    def run_crashing():
        try:
            st.with_lease('wh-crash', DEADLINE, T, K, crashing)
        except TypeError as e:  # the SDK lets the handler's exception through
            return '%s %s' % (type(e).__name__, e)
        raise TakeFailed('the handler did not raise')
    ctx.shot(D, 'Handler crashes mid-way', 'Python: None + 1 raises TypeError; the SDK never closes a lease',
             'OPEN_LEASE wh-crash %d %s %s; handler computes None + 1' % (DEADLINE, T, K), 'TypeError', run_crashing, LBL_PY, klass='EVENT')

    now = DEADLINE + 1
    ctx.shot(D, 'Sweep finds dropped obligation', RULE_LEASE, 'leases <store> --sweep --now %d' % now,
             'SWEEP 1 1', lambda: st.sweep(now_ms=now).detail, LBL_REPORT, klass='EVENT')  # .detail: the engine's own first line
    t = time.perf_counter()
    code, out, _ = ctx.cli(['leases', ctx.store_dir('crash'), '--sweep', '--now', now])
    ms = (time.perf_counter() - t) * 1000
    lines = [ln for ln in out.split('\n') if ln]
    ctx.record(D, 'Engine names the lease', RULE_LEASE, 'leases <store> --sweep --now %d (second output line)' % now,
               'DROPPED_OBLIGATION wh-crash %d %s %s' % (DEADLINE, T, K), lines[1] if len(lines) > 1 else 'NO-LINE', ms, LBL_REPORT, klass='EVENT')
    ctx.note(D, 'sweep: first output line and exit code of the engine', '%s ; exit %d' % (lines[0] if lines else '', code), 'measured live')
    code, out, _ = ctx.cli(['leases', ctx.store_dir('crash'), '--all'])
    ctx.note(D, 'leases --all: the engine\'s lines (the committed handler\'s lease is CLOSED, the crashed one is OPEN)',
             ' | '.join(ln for ln in out.split('\n') if ln), 'measured live')


# ------------------------------------------------------------------------------------------------ (b) flood

def flood_part(ctx):
    engine = Path(ctx.engine_dir) / 'airlock-engine'
    mib = int(ctx.flood_mb)
    proc = subprocess.Popen([str(engine), 'serve', str(ctx.store_dir('crash')), '--node', ctx.node],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=ctx.env)
    try:
        first, _ = ask(proc, 'STATE')  # the process is up and has answered once before the memory is read
        if not first.startswith('STATE '):
            raise TakeFailed('serve did not answer STATE: %r' % first)
        before = ctx.rss_kib(proc.pid)
        if before is None:
            raise TakeFailed('the memory of the serve process could not be read')
        samples, stop = [before], threading.Event()

        def sample():
            while not stop.is_set():
                v = ctx.rss_kib(proc.pid)
                if v is not None:
                    samples.append(v)
                stop.wait(SAMPLE_S)
        th = threading.Thread(target=sample, daemon=True)
        th.start()
        chunk, sent = b'A' * (1024 * 1024), 0
        started = time.perf_counter()
        try:
            for _ in range(mib):
                proc.stdin.write(chunk)
                sent += len(chunk)
            proc.stdin.write(b'\n')
            proc.stdin.flush()
            answer = read_line(proc)
            seconds = time.perf_counter() - started
            got, get_ms = ask(proc, 'GET %s %s' % (T, K))
            if not got.startswith('OK '):
                raise TakeFailed('GET after the flood: %r' % got)
            h = got.split(' ')[1]
            valid, valid_ms = ask(proc, 'REFUND %s %s after-flood %s PAYOUT 100' % (T, K, h))
            after = ctx.rss_kib(proc.pid)  # one sample after the flood was read to its end
            if after is not None:
                samples.append(after)
        except BrokenPipeError:
            raise TakeFailed('THE SERVE PROCESS ENDED DURING THE FLOOD')
        finally:
            stop.set()
            th.join()
        proc.stdin.close()
        exit_code = proc.wait(timeout=60)
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
    peak = max(samples)
    ctx.record(D, 'Flood with no line end', RULE_LINE, '%d MiB of bytes with no LF on stdin of `airlock-engine serve`, then LF' % mib,
               'MALFORMED_REQUEST OVERSIZED', answer, seconds * 1000, LBL)
    ctx.record(D, 'Valid request after flood', RULE_PAY, 'REFUND %s %s after-flood <hash> PAYOUT 100 (same pipe, same process)' % (T, K),
               'COMMITTED', valid, valid_ms, LBL)
    ctx.note(D, 'flood: bytes sent with no line end', sent, 'measured live')
    ctx.note(D, 'flood: seconds from the first byte to the answer line', round(seconds, 3), 'measured live')
    ctx.note(D, 'flood: resident memory of the serve process before, KiB', before, 'measured live')
    ctx.note(D, 'flood: largest resident memory sample during and after, KiB', peak, 'measured live')
    ctx.note(D, 'flood: growth of resident memory (largest sample minus before), KiB', peak - before, 'measured live')
    ctx.note(D, 'flood: memory samples taken (/bin/ps, one per %d ms plus the time of ps)' % int(SAMPLE_S * 1000), len(samples), 'measured live')
    ctx.note(D, 'flood: exit code of the serve process at the end of its input', exit_code, 'measured live')
    if mib >= FLOOD_FLOOR_MIB:
        if peak - before > FLOOD_GROWTH_LIMIT_MIB * 1024:
            raise TakeFailed('THE MEMORY OF THE SERVE PROCESS GREW WITH THE FLOOD (%d KiB)' % (peak - before))
        ctx.note(D, 'flood: memory bound', 'growth at most %d MiB for a flood of %d MiB: held' % (FLOOD_GROWTH_LIMIT_MIB, mib), 'measured live')
    else:
        ctx.note(D, 'flood: memory bound', 'memory bound NOT CHECKED at this size (%d MiB is below %d MiB; a bound of %d MiB would mean nothing)' % (
            mib, FLOOD_FLOOR_MIB, FLOOD_GROWTH_LIMIT_MIB), 'measured live')
        ctx.gap(D, 'flood: memory bound NOT CHECKED at this size (%d MiB). The growth on screen is a measurement, not a bound.' % mib)

    # The 10 GiB record: read now, cited by path. It is of another component.
    src = str(RECORD_10GIB.relative_to(ROOT))
    raw = RECORD_10GIB.read_bytes()
    f = json.loads(raw)['act2']['flood']
    ctx.note(D, '10 GiB record file SHA-256 (computed now)', hashlib.sha256(raw).hexdigest(), src)
    ctx.note(D, '10 GiB record (Slice 1 token ISSUER, not this engine): bytes', f['bytes'], src + ' act2.flood.bytes')
    ctx.note(D, '10 GiB record (Slice 1 token ISSUER, not this engine): seconds', f['seconds'], src + ' act2.flood.seconds')
    ctx.note(D, '10 GiB record (Slice 1 token ISSUER, not this engine): issuer resident MiB before / sampled peak / kernel peak',
             '%s / %s / %s' % (f['issuer_resident_mib_before'], f['issuer_resident_mib_sampled_peak'], f['issuer_resident_mib_kernel_peak']),
             src + ' act2.flood.issuer_resident_mib_*')
    ctx.note(D, '10 GiB record (Slice 1 token ISSUER, not this engine): answer', f['answer'], src + ' act2.flood.answer')
    ctx.gap(D, 'the 10 GiB flood is a committed record of the Slice 1 token ISSUER (a Node process), a different component. '
            'This engine was flooded with %d MiB in this take. No 10 GiB flood of this engine is on record here.' % mib)


# ------------------------------------------------------------------------------------------------ (c) SIGKILL

def production(ctx, args):
    """One command of the PRODUCTION engine, started directly. Returns (exit code, stdout text, ms)."""
    t = time.perf_counter()
    p = subprocess.run([str(Path(ctx.engine_dir) / 'airlock-engine')] + [str(a) for a in args], capture_output=True, timeout=120, env=ctx.env)
    return p.returncode, p.stdout.decode('ascii', 'replace'), (time.perf_counter() - t) * 1000


def kill_once(ctx, st, kill_engine, point, split, rid, amount, present, what):
    """One real SIGKILL of the kill-points build at `point`, then recovery by the production engine."""
    store = ctx.store_dir('kill')
    wal = store / 'airlock.wal'
    before = ctx.replay('kill')
    state = st.get(T, K)
    h, remaining = state.state_hash, int(state.fields['remaining'])
    size0 = wal.stat().st_size
    env = dict(ctx.env, AIRLOCK_KILL_AT=point)
    if split is not None:
        env['AIRLOCK_KILL_SPLIT'] = str(split)
    line = 'REFUND %s %s %s %s PAYOUT %d' % (T, K, rid, h, amount)
    proc = subprocess.Popen([str(kill_engine), 'serve', str(store)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    t = time.perf_counter()
    proc.stdin.write(line.encode() + b'\n')
    proc.stdin.flush()
    if not select.select([proc.stderr], [], [], 120)[0]:  # the kill build prints `AT <point>` and parks
        proc.kill()
        proc.wait()
        raise TakeFailed('kill at %s: the kill-points build printed nothing in 120 s' % point)
    at = proc.stderr.readline().decode('ascii', 'replace').strip()
    proc.send_signal(signal.SIGKILL)
    answered = proc.stdout.read()
    status = proc.wait()
    ms = (time.perf_counter() - t) * 1000
    for pipe in (proc.stdin, proc.stdout, proc.stderr):
        pipe.close()
    size1 = wal.stat().st_size
    tag = 'kill at %s%s' % (point, '' if split is None else ' (split %s)' % split)
    ctx.record(D, what, 'kill-points build: stop at point %s of the WAL append; then signal 9' % point,
               'AIRLOCK_KILL_AT=%s%s airlock-engine-kill serve <store> < REFUND %s %s %s <hash> PAYOUT %d' % (
                   point, '' if split is None else ' AIRLOCK_KILL_SPLIT=%s' % split, T, K, rid, amount),
               'AT ' + point, at or 'NO-LINE', ms, LBL_KILL, klass='EVENT')
    if status != -signal.SIGKILL:
        raise TakeFailed('%s: wait status %r, not -9' % (tag, status))
    if answered:
        raise TakeFailed('%s: an answer left the process before the kill: %r' % (tag, answered[:80]))
    ctx.note(D, tag + ': wait status of the killed process (-9 = SIGKILL) / answer bytes before the kill', '%d / %d' % (status, len(answered)), 'measured live')

    # The PRODUCTION engine opens the store: lock, fold, recovery, then GET.
    code, out, first_ms = production(ctx, ['get', store, T, K])
    size2 = wal.stat().st_size
    _, _, again_ms = production(ctx, ['get', store, T, K])
    ctx.record(D, 'Production engine recovers', RULE_WAL, 'airlock-engine get <store> %s %s (first open after the kill)' % (T, K),
               'OK', out.strip() or 'NO-OUTPUT exit=%d' % code, first_ms, LBL_RECOVER, klass='EVENT')  # a read of the state, not an action
    fields = dict(x.split('=', 1) for x in out.strip().split(' ')[3:] if '=' in x)
    want_remaining = remaining - (amount if present else 0)
    if code != 0 or fields.get('remaining') != str(want_remaining):
        raise TakeFailed('%s: after recovery remaining=%r, required %d' % (tag, fields.get('remaining'), want_remaining))
    after = ctx.replay('kill')
    if after[:len(before)] != before or len(after) != len(before) + (1 if present else 0):
        raise TakeFailed('%s: the effect records after recovery are not the earlier ones%s' % (tag, ' plus one' if present else ''))
    ctx.note(D, tag + ': WAL bytes before the request / after the kill / after recovery', '%d / %d / %d' % (size0, size1, size2), 'measured live')
    ctx.note(D, tag + ': WAL bytes cut by recovery', size1 - size2, 'measured live')
    ctx.note(D, tag + ': effect records by the engine\'s replay, before the kill / after recovery (the earlier ones all present, same order)',
             '%d / %d' % (len(before), len(after)), 'measured live')
    ctx.note(D, tag + ': first production-engine command after the kill (process start + lock + fold + recovery), ms / the same command again, ms',
             '%.1f / %.1f' % (first_ms, again_ms), 'measured live')
    ctx.shot(D, 'Same request id again', RULE_WAL, 'REFUND %s %s %s <hash before the kill> PAYOUT %d' % (T, K, rid, amount),
             'DUPLICATE_REQUEST_ID' if present else 'COMMITTED', lambda: st.refund(T, K, rid, h, 'PAYOUT', amount), LBL_RECOVER)


def kill_part(ctx):
    # `bin/forge-airlock build` puts the test-seam build in build/silicon/test/, never beside the production engine
    # (src/airlock/PROTOCOL.md section 1). An --engine-dir folder may still hold its own airlock-engine-kill.
    kill_engine = Path(ctx.engine_dir) / 'airlock-engine-kill'
    if not kill_engine.is_file() and Path(ctx.engine_dir).resolve() == (ROOT / 'build' / 'airlock').resolve():
        kill_engine = KILL_BUILD
    if not kill_engine.is_file():
        ctx.skip(D, 'SIGKILL at a kill point: NOT IN TAKE (%s is not built)' % kill_engine.name)
        return
    st = ctx.store('kill', ['crash-ledger.json'])
    ctx.shot(D, 'Open the crash ledger', 'trusted opener sets the total', 'OPEN_MONEY %s %s open-kill crash-ledger 100000' % (T, K),
             'COMMITTED', lambda: st.open_money(T, K, 'open-kill', 'crash-ledger', 100000), LBL)
    for i in (1, 2, 3):  # earlier committed records; recovery must keep each of them
        h = st.get(T, K).state_hash
        res = st.refund(T, K, 'pay-%d' % i, h, 'PAYOUT', 100 * i)
        if not res.committed:
            raise TakeFailed('setup payout %d: %r' % (i, res))
    ctx.note(D, 'SIGKILL: the killed process is %s' % (kill_engine.relative_to(ROOT) if kill_engine.is_relative_to(ROOT) else kill_engine), 'the test-seam build of the same source (--cfg kill_points); '
             'the production build ignores AIRLOCK_KILL_AT. Recovery and every later answer are of the production engine.', 'src/airlock/PROTOCOL.md section 1')
    kill_once(ctx, st, kill_engine, 'b', 40, 'pay-torn', 700, False, 'SIGKILL: record half written')
    kill_once(ctx, st, kill_engine, 'c', None, 'pay-unsynced', 800, True, 'SIGKILL: written, not synced')
    kill_once(ctx, st, kill_engine, 'r', None, 'pay-synced', 900, True, 'SIGKILL: after the sync')
    h = st.get(T, K).state_hash
    ctx.shot(D, 'New payout after recovery', RULE_PAY, 'REFUND %s %s pay-after <hash> PAYOUT 250' % (T, K),
             'COMMITTED', lambda: st.refund(T, K, 'pay-after', h, 'PAYOUT', 250), LBL)
    ctx.gap(D, 'a SIGKILL is not a power loss: the page cache stays. The record of kill point c stays because the kernel keeps the '
            'written bytes, not because it was synced. No take can show what a drive keeps after a power cut.')
    ctx.gap(D, 'F_FULLFSYNC, the macOS kernel and the drive are trusted, not checked')
    ctx.gap(D, 'the killed process is the kill-points build: a test-seam build of the same source, not the production binary')


def run(ctx):
    st = ctx.store('crash', ['crash-ledger.json'])
    ctx.shot(D, 'Open the payout ledger', 'trusted opener sets the total', 'OPEN_MONEY %s %s open-acct-1 crash-ledger 100000' % (T, K),
             'COMMITTED', lambda: st.open_money(T, K, 'open-acct-1', 'crash-ledger', 100000), LBL)
    lease_part(ctx, st)
    flood_part(ctx)
    kill_part(ctx)
    ctx.gap(D, 'leases: the engine sees only handlers that opened a lease; a sweep reports, it repairs nothing')
