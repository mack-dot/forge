"""Domain 6, multi-tenant SaaS. Policy: demos/video_cut/policies/saas-credits.json (money airlock, parametric;
it gives the race key a rule). The read airlock needs no policy.

Mapping.
  * Scoped read. `read_scoped('org-a', rows)` sends the rows to the engine (verb READ). The engine answers
    `OK <n>` only if every row has the top-level member tenant_id equal to the tenant. The org id of this
    scenario is that tenant_id member.
  * Unscoped read. A result set of a query with no `WHERE org_id` holds rows of two orgs. The engine answers
    TENANT_ISOLATION_BREACH and the SDK releases 0 rows. The module prints len(result.rows) as measured.
  * Race. 50 SDK clients, each with its own `forge-airlock serve` process, send one REFUND (reason
    USE_CREDITS) on ONE key with ONE pre_state_hash. A threading.Barrier starts them together (the method of
    examples/unbreakable_store/run_demo.py d1_race). The module counts the answers and then counts the effect
    records of the key in the WAL through the engine's replay. Required: 1 COMMITTED, 49 STALE_STATE_HASH,
    0 other, 1 WAL record. The printed numbers come from the counters. The racer count is always 50.

Heavy run. The race takes the shared lock /private/tmp/claude-501/forge-locks/heavy.lock (atomic mkdir) unless
the environment variable VIDEO_CUT_LOCK_HELD is '1' (the runner holds it then). If the lock's parent folder
does not exist (another machine, CI), the race runs without the lock.

Labels. Every shot is NATIVE CHECK + FINITE TEST (Rust engine, not proved). end_to_end=false.

Gaps (also printed by ctx.gap). The engine checks only the top-level tenant_id of the rows passed to it. It
does not see the SQL, and no database runs here: the rows are a scripted table. The race is one race at one
start time, not all schedules. The latencies include the SDK and the pipe, and the machine load of this run.
"""
import os
import statistics
import threading
import time

from harness import heavy_lock, observed_of

NUMBER, NAME, TITLE = 6, 'saas', 'Multi-tenant SaaS'
D = 'saas'
RACERS = 50  # always 50, also with ctx.fast
LOCK_OWNER = 'VIDEO9'
LOCK_POLL_S = 15
RULE_READ = 'READ: every row has top-level tenant_id == tenant, else TENANT_ISOLATION_BREACH and 0 rows'
RULE_CAS = 'compare-and-swap: a write must name the present state hash of the key, else STALE_STATE_HASH'
TABLE = [  # the scripted `invoices` table; tenant_id is the org id
    {'tenant_id': 'org-a', 'invoice': 'a-1', 'total_cents': 1250},
    {'tenant_id': 'org-a', 'invoice': 'a-2', 'total_cents': 9900},
    {'tenant_id': 'org-b', 'invoice': 'b-1', 'total_cents': 4400},
    {'tenant_id': 'org-b', 'invoice': 'b-2', 'total_cents': 700},
]


def _heavy_lock():
    """The shared heavy lock for the race (harness.heavy_lock: atomic mkdir, removes only its own lock), or
    None when the runner already holds it for the whole take (VIDEO_CUT_LOCK_HELD=1)."""
    if os.environ.get('VIDEO_CUT_LOCK_HELD') == '1':
        return None
    return heavy_lock('demos/video_cut/domains/d6_saas.py race of %d serve processes (pid %d)' % (RACERS, os.getpid()), owner=LOCK_OWNER, poll_s=LOCK_POLL_S)


def _reads(ctx, st):
    scoped = [r for r in TABLE if r['tenant_id'] == 'org-a']  # SELECT * FROM invoices WHERE org_id = 'org-a'
    _, res = ctx.shot(D, 'Scoped read, own org', RULE_READ, "READ org-a %d  (rows of: SELECT ... WHERE org_id = 'org-a')" % len(scoped),
                      'OK %d' % len(scoped), lambda: st.read_scoped('org-a', scoped))
    ctx.note(D, 'rows released by the scoped read', len(getattr(res, 'rows', [])), 'measured live')
    unscoped = list(TABLE)  # SELECT * FROM invoices   -- the WHERE org_id is missing
    _, res = ctx.shot(D, 'Query without WHERE org_id', RULE_READ, 'READ org-a %d  (rows of: SELECT ... with no WHERE org_id)' % len(unscoped),
                      'TENANT_ISOLATION_BREACH', lambda: st.read_scoped('org-a', unscoped))
    ctx.note(D, 'rows sent by the unscoped read', len(unscoped), 'measured live')
    released = len(getattr(res, 'rows', []))
    ctx.record(D, 'Rows released: counted', RULE_READ, 'len(result.rows) of the unscoped read', '0 rows released',
               '%d rows released of %d sent' % (released, len(unscoped)), 0.0, 'FINITE TEST (count of the rows that the SDK returned)')
    ctx.note(D, 'rows released by the unscoped read', released, 'measured live')


def _race(ctx, st):
    ctx.shot(D, 'Open the credit balance', 'trusted opener sets the balance', 'OPEN_MONEY org-a credits-1 open-credits-1 saas-credits 10000',
             'COMMITTED', lambda: st.open_money('org-a', 'credits-1', 'open-credits-1', 'saas-credits', 10000))
    h = st.get('org-a', 'credits-1').state_hash  # ONE pre_state_hash for all racers
    res, lat = [None] * RACERS, [None] * RACERS
    clients = []
    lock = _heavy_lock()
    mine = False
    try:
        if lock:
            lock.__enter__()
            mine = lock.held
        for _ in range(RACERS):
            clients.append(ctx.client('saas'))  # each client is its own serve process; it is up before the race
        barrier = threading.Barrier(RACERS)

        def racer(i):
            barrier.wait()
            t = time.perf_counter()
            try:
                res[i] = clients[i].refund('org-a', 'credits-1', 'race-%d' % i, h, 'USE_CREDITS', 100)
            except Exception as e:  # noqa: BLE001  (counted as "other"; the summary then fails the take)
                res[i] = e
            lat[i] = (time.perf_counter() - t) * 1000
        threads = [threading.Thread(target=racer, args=(i,)) for i in range(RACERS)]
        t0 = time.perf_counter()
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        wall_ms = (time.perf_counter() - t0) * 1000
    finally:
        for c in clients:
            try:
                c.close()
            except Exception:  # noqa: BLE001  (closing; the counts are already taken)
                pass
        if lock:
            lock.__exit__(None, None, None)
    codes = [getattr(r, 'code', 'RAISED') for r in res]
    nc, ns = codes.count('COMMITTED'), codes.count('STALE_STATE_HASH')
    other = len(codes) - nc - ns
    wal = [e for e in ctx.replay('saas') if e[0] == 'REFUND' and e[2] == 'credits-1']
    req = 'REFUND org-a credits-1 race-<i> <one hash> USE_CREDITS 100'
    label = 'NATIVE CHECK + FINITE TEST (%d engine serve processes, %d SDK clients in threads, one start)' % (RACERS, RACERS)
    if nc:
        i = codes.index('COMMITTED')
        ctx.record(D, 'The one winner', RULE_CAS, req.replace('<i>', str(i)), 'COMMITTED', observed_of(res[i]), lat[i], label)
    if ns:
        i = codes.index('STALE_STATE_HASH')
        ctx.record(D, 'A stale racer', RULE_CAS, req.replace('<i>', str(i)), 'STALE_STATE_HASH', observed_of(res[i]), lat[i], label)
    want = '%d racers: 1 COMMITTED, %d STALE_STATE_HASH, 0 other; WAL effect records of the key: 1' % (RACERS, RACERS - 1)
    observed = '%d racers: %d COMMITTED, %d STALE_STATE_HASH, %d other; WAL effect records of the key: %d' % (len(codes), nc, ns, other, len(wal))
    ctx.record(D, 'Race of 50 counted', RULE_CAS, '%d x %s (barrier start)' % (RACERS, req), want, observed, wall_ms, label)
    done = sorted(x for x in lat if x is not None)
    ctx.note(D, 'race: serve processes', len(clients), 'measured live')
    ctx.note(D, 'race: COMMITTED', nc, 'measured live')
    ctx.note(D, 'race: STALE_STATE_HASH', ns, 'measured live')
    ctx.note(D, 'race: other answers', other, 'measured live')
    ctx.note(D, 'race: WAL effect records of the key', len(wal), 'measured live (engine replay)')
    if done:
        ctx.note(D, 'race: request latency p50 (ms)', round(statistics.median(done), 3), 'measured live')
        ctx.note(D, 'race: request latency max (ms)', round(done[-1], 3), 'measured live')
    ctx.note(D, 'race: wall time, barrier to last answer (ms)', round(wall_ms, 3), 'measured live')
    ctx.note(D, 'race: heavy lock', 'taken by this module' if mine else 'not taken here (held by the runner, or no lock folder)', 'measured live')


def run(ctx):
    st = ctx.store('saas', ['saas-credits.json'])
    _reads(ctx, st)
    _race(ctx, st)
    ctx.gap(D, 'the engine checks only the top-level tenant_id of the rows passed to it; a nested object of another org passes')
    ctx.gap(D, 'the engine does not see the SQL; no database runs here, the rows are a scripted table')
    ctx.gap(D, 'one race of 50 processes at one start time, not all schedules')
