#!/usr/bin/env python3
"""Y6 crash-recovery and race harness for the Slice 1 finality sink (graph links U7 and U3).
NOT a proof. A finite test of process kills (SIGKILL) and races on this machine. Power loss is NOT tested.
The repository's sink.ts is used unchanged (bundled by esbuild into build/sink-real.cjs; types stripped only).
Usage: python3 -I harness.py <part> [...]   parts: kill-points kill-external kill-self race zero negative crosscheck
Every part writes results/<part>.json. Exit 0: every check of the part held; 1: a violation was found
(for `negative`: exit 0 means the harness DETECTED every broken copy)."""
import json, os, random, signal, subprocess, sys, time
from pathlib import Path

W = Path(__file__).resolve().parent
ROOT = Path('<HOME>/forge')
NODE = '/opt/homebrew/bin/node'
ENV = dict(os.environ, PATH='/opt/homebrew/bin:' + os.environ['PATH'], NODE_NO_WARNINGS='1')
B = W / 'build'
CFG = W / 'cfg.json'
TOK = json.loads((W / 'tokens.json').read_text())
S0 = TOK['S0']
CHAIN = TOK['chain']
CHAIN_IDS = [json.loads(t)['body']['requestId'] for t in CHAIN]
STALE = "stored state is not the token's pre-state"
SINKS = {v: str(B / ('sink-%s.cjs' % v)) for v in ('real', 'twotx', 'nocheck', 'toctou')}
SINKS['tsx-source'] = str(ROOT / 'ts/refund-finality/sink.ts')
POINTS = ['before-call', 'before-begin', 'after-begin', 'after-select-settled', 'after-select-state', 'after-update-state',
          'after-insert-settled', 'after-insert-outbox', 'before-commit', 'after-commit', 'after-return']
COMMITTED_POINTS = {'after-commit', 'after-return'}
rng = random.Random(int(os.environ.get('Y6_SEED', '20261119')))
for d in ('db', 'tmp', 'results', 'logs'):
    (W / d).mkdir(exist_ok=True)


def node_argv(script, *args, tsx=False):
    return [NODE, *(['--import', 'tsx'] if tsx else []), str(script), *map(str, args)]


def run(argv, timeout=120):
    c = subprocess.run(argv, cwd=ROOT, env=ENV, capture_output=True, timeout=timeout)
    return c.returncode, c.stdout.decode(), c.stderr.decode()


_n = [0]


def new_store(name):
    _n[0] += 1
    db = W / 'db' / ('%s-%04d.sqlite' % (name, _n[0]))
    for suffix in ('', '-journal', '-wal', '-shm'):
        Path(str(db) + suffix).unlink(missing_ok=True)
    code, out, err = run(node_argv(B / 'init.cjs', SINKS['real'], db, CFG, json.dumps(S0)))
    assert code == 0 and json.loads(out) == S0, (code, out, err)
    return db


def check(db, max_replays=6):
    hot = os.path.exists(str(db) + '-journal'), os.path.exists(str(db) + '-wal')
    code, out, err = run(node_argv(B / 'checker.cjs', SINKS['real'], db, CFG, max_replays))
    if code != 0:
        return {'checker_exit': code, 'stderr': err[-2000:]}, ['checker exit %d' % code]
    r = json.loads(out)
    r['hot_journal_before_reopen'], r['wal_before_reopen'] = hot
    r['journal_after_reopen'] = os.path.exists(str(db) + '-journal')
    v = []
    if r['integrity'] != ['ok']: v.append('integrity_check: %s' % r['integrity'])
    if r['audit']: v.append('audit: %s' % r['audit'])
    st = r['state']
    total = sum(int(s['amount']) for s in r['settled'])
    if st is None: v.append('no stored state')
    else:
        if st['original'] != S0['original']: v.append('original changed')
        if int(st['remaining']) != int(S0['original']) - total:
            v.append('remaining %s != original %s - sum of committed %d' % (st['remaining'], S0['original'], total))
    ids = [s['request_id'] for s in r['settled']]
    if len(set(ids)) != len(ids): v.append('a request id is settled twice')
    if len(r['settled']) != len(r['outbox']): v.append('partial: %d settled rows, %d outbox rows' % (len(r['settled']), len(r['outbox'])))
    for s, o in zip(r['settled'], r['outbox']):
        if s['request_id'] != o['request_id'] or s['amount'] != o['amount']: v.append('outbox row %s does not match settled row' % o['seq'])
    for rp in r['replays']:
        if rp['status'] != 'replayed' or not rp['unchanged']: v.append('replay of %s: %s %s unchanged=%s' % (rp['request_id'], rp['status'], rp['reason'], rp['unchanged']))
    return r, v


def chain_prefix(r):
    ids = [s['request_id'] for s in r['settled']]
    return ids == CHAIN_IDS[:len(ids)], len(ids)


def read_line(p, timeout):
    """One line from the child's stdout within timeout seconds, or None."""
    import select
    data = b''
    end = time.monotonic() + timeout
    while not data.endswith(b'\n'):
        left = end - time.monotonic()
        if left <= 0: return None
        ready, _, _ = select.select([p.stdout], [], [], left)
        if not ready: return None
        piece = os.read(p.stdout.fileno(), 4096)
        if piece == b'': return data.decode() or None
        data += piece
    return data.decode().strip()


def popen(argv):
    return subprocess.Popen(argv, cwd=ROOT, env=ENV, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def kill9(p):
    os.kill(p.pid, signal.SIGKILL)
    p.wait()
    return p.returncode


def token_file(text):
    _n[0] += 1
    f = W / 'tmp' / ('tok-%06d.txt' % _n[0])
    f.write_text(text)
    return f


def save(name, obj):
    (W / 'results' / (name + '.json')).write_text(json.dumps(obj, indent=1))


# ----------------------------------------------------------------------------------------------------------
def kill_points(variant='real', points=POINTS, reps=20, label='kill-points', expect=None, tsx=False, fresh=False):
    """SIGKILL at controlled points. The child patches node:sqlite in its own process and blocks at the point."""
    rows, violations, kills = [], [], 0
    child = SINKS['tsx-source'] if tsx else SINKS[variant]
    script = W / 'src/child.ts' if tsx else B / 'child.cjs'
    for point in points:
        db = new_store('%s-%s-%s' % (label, variant, point.replace('#', '_')))
        k = 0
        for rep in range(reps):
            if k >= len(CHAIN) or (fresh and rep > 0):
                db, k = new_store('%s-%s-%s' % (label, variant, point.replace('#', '_'))), 0
            p = popen(node_argv(script, 'pause', child, db, CFG, token_file(CHAIN[k]), point, tsx=tsx))
            line = read_line(p, 60)
            journal_at_kill = os.path.exists(str(db) + '-journal')
            if line != 'PAUSED ' + point:
                kill9(p)
                violations.append({'point': point, 'rep': rep, 'problem': 'point not reached', 'line': line, 'stderr': p.stderr.read().decode()[-800:]})
                continue
            contender = None
            if rep % 2 == 1 and point not in COMMITTED_POINTS:
                # A second process tries the same token while the first one holds the point; then the first one is killed.
                contender = popen(node_argv(script, 'race', child, db, CFG, token_file(CHAIN[k]), 0, tsx=tsx))
                time.sleep(0.3)
            rc = kill9(p); kills += 1
            committed_expected = (expect or (lambda pt: pt in COMMITTED_POINTS))(point)
            contender_result = None
            if contender is not None:
                out, err = contender.communicate(timeout=90)
                contender_result = json.loads(out.decode().strip().splitlines()[-1]) if out.strip() else {'stderr': err.decode()[-500:]}
            r, v = check(db)
            ok_prefix, n = chain_prefix(r) if 'settled' in r else (False, -1)
            want = k + (1 if committed_expected else 0) + (1 if contender_result and contender_result.get('status') == 'committed' else 0)
            if not ok_prefix: v.append('settled rows are not a prefix of the chain')
            if n != want: v.append('settled count %d, expected %d (kill at %s)' % (n, want, point))
            if contender is not None and contender_result.get('status') != 'committed':
                v.append('contender after kill: %s' % contender_result)
            row = {'point': point, 'rep': rep, 'k': k, 'kill_rc': rc, 'journal_at_kill': journal_at_kill,
                   'hot_journal_before_reopen': r.get('hot_journal_before_reopen'), 'settled_after': n,
                   'contender': contender_result, 'violations': v}
            rows.append(row)
            if v: violations.append(row)
            k = n
            if rep % 2 == 0 and n == k and not committed_expected:
                pass
    res = {'variant': variant, 'tsx_source': tsx, 'kills': kills, 'runs': len(rows), 'violations': violations,
           'journal_present_at_kill': sum(1 for r in rows if r['journal_at_kill']),
           'hot_journal_recovered': sum(1 for r in rows if r['hot_journal_before_reopen']),
           'contender_runs': sum(1 for r in rows if r['contender'] is not None), 'rows': rows}
    return res


def kill_random(mode, variant='real', runs=150, label='kill-random', fresh=False):
    """SIGKILL at random times while a child commits a run of chain tokens (with a few settled ones first).
    mode 'external': the harness sends SIGKILL after a random delay. mode 'self': a worker thread in the child
    sends SIGKILL a random number of microseconds after the first commit call starts."""
    # Calibration: time of one uninterrupted child that commits 40 tokens.
    db = new_store('%s-calib-%s' % (label, variant))
    log = W / 'tmp' / ('calib-%s-%s.log' % (mode, variant))
    log.unlink(missing_ok=True); tf = W / 'tmp' / 'calib-tokens.json'; tf.write_text(json.dumps(CHAIN[:40]))
    t0 = time.monotonic(); p = popen(node_argv(B / 'child.cjs', 'chain', SINKS[variant], db, CFG, tf, log, -1))
    assert read_line(p, 60) == 'READY'; t1 = time.monotonic(); p.communicate(timeout=120)
    calib = [json.loads(x) for x in log.read_text().splitlines()]
    assert len(calib) == 40 and all(x['status'] == 'committed' for x in calib), calib[:3]
    span = calib[-1]['ms'] / 1000  # duration of the commit loop of 40 tokens
    rows, violations = [], []
    db, k = new_store('%s-%s-%s' % (label, mode, variant)), 0
    for i in range(runs):
        if k > len(CHAIN) - 45 or (fresh and i > 0):
            db, k = new_store('%s-%s-%s' % (label, mode, variant)), 0
        start = max(0, k - 3)
        toks = CHAIN[start:k + 40]
        tf = W / 'tmp' / ('toks-%s-%s-%04d.json' % (mode, variant, i)); tf.write_text(json.dumps(toks))
        log = W / 'tmp' / ('log-%s-%s-%04d.log' % (mode, variant, i)); log.unlink(missing_ok=True)
        delay = rng.uniform(0, span)
        micros = int(delay * 1e6) if mode == 'self' else -1
        p = popen(node_argv(B / 'child.cjs', 'chain', SINKS[variant], db, CFG, tf, log, micros))
        ready = read_line(p, 60)
        if mode == 'external':
            time.sleep(delay)
            try: os.kill(p.pid, signal.SIGKILL)
            except ProcessLookupError: pass
        p.wait(timeout=120)
        rc = p.returncode
        lines = [json.loads(x) for x in log.read_text().splitlines()] if log.exists() else []
        reported_new = [start + x['i'] for x in lines if x['status'] == 'committed']
        reported_replay_ok = all(x['status'] == 'replayed' for x in lines if start + x['i'] < k)
        r, v = check(db)
        ok_prefix, n = chain_prefix(r) if 'settled' in r else (False, -1)
        if not ok_prefix: v.append('settled rows are not a prefix of the chain')
        if reported_new and max(reported_new) + 1 > n: v.append('LOST: the child reported a commit that is not in the store')
        if n - (k + len(reported_new)) not in (0, 1): v.append('settled %d; before %d; reported new %d' % (n, k, len(reported_new)))
        if not reported_replay_ok: v.append('a settled token was not answered replayed')
        unreported = n - (k + len(reported_new))
        row = {'new_in_list': len(toks) - (k - start), 'i': i, 'k': k, 'delay_s': round(delay, 6), 'ready': ready, 'rc': rc, 'reported_new': len(reported_new),
               'settled_after': n, 'committed_but_unreported': unreported, 'killed': rc == -9,
               'hot_journal_before_reopen': r.get('hot_journal_before_reopen'), 'violations': v}
        rows.append(row)
        if v: violations.append(row)
        k = n
    killed = [r for r in rows if r['killed']]
    return {'mode': mode, 'variant': variant, 'runs': runs, 'kills': len(killed), 'calibration_span_s': span,
            'killed_before_first_new_commit_reported': sum(1 for r in killed if r['reported_new'] == 0),
            'killed_after_all_reported': sum(1 for r in killed if r['reported_new'] == r['new_in_list']),
            'hot_journal_recovered': sum(1 for r in rows if r['hot_journal_before_reopen']),
            'committed_but_unreported': sum(1 for r in rows if r['committed_but_unreported'] == 1),
            'violations': violations, 'rows': rows}


# ----------------------------------------------------------------------------------------------------------
def free_mib():
    out = subprocess.run(['vm_stat'], capture_output=True, text=True).stdout
    pages = {l.split(':')[0]: int(l.split(':')[1].strip().rstrip('.')) for l in out.splitlines()[1:] if ':' in l}
    return (pages.get('Pages free', 0) + pages.get('Pages inactive', 0) + pages.get('Pages speculative', 0)) * 16384 / 2**20


def race_once(db, texts, variant='real', tsx=False):
    margin = 1.5 + 0.06 * len(texts)
    start_at = int((time.time() + margin) * 1000)
    script = W / 'src/child.ts' if tsx else B / 'child.cjs'
    child = SINKS['tsx-source'] if tsx else SINKS[variant]
    procs = [popen(node_argv(script, 'race', child, db, CFG, token_file(t), start_at, tsx=tsx)) for t in texts]
    answers = []
    for p in procs:
        out, err = p.communicate(timeout=300)
        answers.append(json.loads(out.decode().strip()) if p.returncode == 0 and out.strip() else {'status': 'CRASH', 'rc': p.returncode, 'stderr': err.decode()[-300:]})
    return answers


def race(ks=(2, 5, 10, 25, 50, 100), rounds=None, variant='real', tsx=False):
    rounds = rounds or {2: 5, 5: 5, 10: 5, 25: 3, 50: 2, 100: 2}
    rows, violations = [], []
    for K in ks:
        for rd in range(rounds[K]):
            mem = free_mib()
            if mem < K * 45 + 1024:
                rows.append({'K': K, 'round': rd, 'skipped': 'free+inactive memory %.0f MiB' % mem}); continue
            db = new_store('race-%s-K%d' % (variant, K))
            ans = race_once(db, TOK['race'][:K], variant, tsx)
            committed = [i for i, a in enumerate(ans) if a['status'] == 'committed']
            stale = sum(1 for a in ans if a['status'] == 'rejected' and a.get('reason') == STALE)
            late = sum(1 for a in ans if not a.get('onTime', False))
            r, v = check(db)
            if len(committed) != 1: v.append('%d commits for one pre-state' % len(committed))
            if stale != K - len(committed): v.append('other results: %s' % sorted({(a['status'], a.get('reason')) for a in ans}))
            row = {'K': K, 'round': rd, 'committed': len(committed), 'stale': stale, 'late': late, 'mem_mib_before': round(mem),
                   'violations': v}
            if variant == 'real' and len(committed) == 1 and K >= 10 and rd == 0:
                before = check(db, 0)[0]
                reps = race_once(db, [TOK['race'][committed[0]]] * 50, variant, tsx)
                after, v2 = check(db, 0)
                row['replays50'] = {'statuses': sorted({a['status'] for a in reps}), 'late': sum(1 for a in reps if not a.get('onTime')),
                                    'store_unchanged': {k: before[k] for k in ('state', 'settled', 'outbox')} == {k: after[k] for k in ('state', 'settled', 'outbox')}}
                if row['replays50']['statuses'] != ['replayed'] or not row['replays50']['store_unchanged'] or v2:
                    v.append('replays50: %s %s' % (row['replays50'], v2))
            rows.append(row)
            if v: violations.append(row)
    return {'variant': variant, 'tsx_source': tsx, 'rows': rows, 'violations': violations,
            'races': sum(1 for r in rows if 'skipped' not in r), 'skipped': [r for r in rows if 'skipped' in r]}


# ----------------------------------------------------------------------------------------------------------
def commit_one(db, text):
    code, out, err = run(node_argv(B / 'child.cjs', 'race', SINKS['real'], db, CFG, token_file(text), 0))
    return json.loads(out.strip()) if code == 0 else {'status': 'CRASH', 'stderr': err[-300:]}


def zero():
    z = TOK['zero']
    steps = []
    db = new_store('zero-seq')
    def step(label, text):
        a = commit_one(db, text); r, v = check(db, 0)
        steps.append({'step': label, 'result': a, 'settled': len(r['settled']), 'outbox_amounts': [o['amount'] for o in r['outbox']],
                      'remaining': r['state']['remaining'], 'audit': r['audit'], 'violations': v})
    for i, t in enumerate(z['zero']): step('zero token rq_zero_%d (amount 0, pre = S0)' % (i + 1), t)
    step('rq_zero_1 asked again from the issuer (same text: %s)' % (z['zero_same_again'] == z['zero'][0]), z['zero_same_again'])
    step('rq_zero_1, amount 0, other reason duplicate_charge', z['zero_same_id_other_reason'])
    step('chain[0]: amount 2 on S0', CHAIN[0])
    step('rq_zero_2 again after the state changed', z['zero'][1])
    step('zero token minted for the state after chain[0]', z['zero_on_after1'])
    step('chain[0] again', CHAIN[0])
    step('chain[1]: amount 2 on the state after chain[0]', CHAIN[1])
    db2 = new_store('zero-race')
    ans = race_once(db2, z['zero'])
    r2, v2 = check(db2, 0)
    race_row = {'K': 5, 'statuses': [a['status'] for a in ans], 'settled': len(r2['settled']), 'outbox_amounts': [o['amount'] for o in r2['outbox']],
                'remaining': r2['state']['remaining'], 'audit': r2['audit'], 'violations': v2}
    return {'sequence': steps, 'race_of_5_zero_tokens': race_row}


# ----------------------------------------------------------------------------------------------------------
def negative():
    out = {}
    # N1: two transactions. Kill between them (after the first COMMIT).
    out['twotx_point'] = kill_points('twotx', ['after-commit#1'], reps=10, label='neg', expect=lambda pt: False, fresh=True)
    out['twotx_external'] = kill_random('external', 'twotx', runs=60, label='neg', fresh=True)
    # N2: no pre-state check; N3: pre-state checked before the transaction.
    out['nocheck_race'] = race(ks=(10,), rounds={10: 3}, variant='nocheck')
    out['toctou_race'] = race(ks=(10, 25), rounds={10: 3, 25: 3}, variant='toctou')
    det = {k: len(v['violations']) for k, v in out.items()}
    out['detected'] = det
    return out


def main():
    part = sys.argv[1]
    t0 = time.monotonic()
    if part == 'kill-points': res = kill_points()
    elif part == 'kill-external': res = kill_random('external')
    elif part == 'kill-self': res = kill_random('self')
    elif part == 'race': res = race()
    elif part == 'zero': res = zero()
    elif part == 'negative': res = negative()
    elif part == 'crosscheck':
        # The same checks with the repository sink.ts loaded by tsx from its source (no bundle).
        res = {'kill_points_tsx': kill_points(points=['after-update-state', 'before-commit', 'after-commit'], reps=4, label='xc', tsx=True),
               'race_tsx': race(ks=(10,), rounds={10: 2}, tsx=True)}
    else: raise SystemExit('unknown part')
    res['seconds'] = round(time.monotonic() - t0, 1)
    save(part, res)
    if part == 'negative':
        summary = res['detected']; code = 0 if all(summary.values()) else 1
    elif part == 'zero':
        summary = {'sequence': [(s['step'], s['result'].get('status'), s.get('result').get('reason'), s['settled'], s['remaining']) for s in res['sequence']],
                   'race': {k: res['race_of_5_zero_tokens'][k] for k in ('statuses', 'settled', 'remaining', 'audit', 'violations')}}
        code = 0 if not any(s['violations'] for s in res['sequence']) and not res['race_of_5_zero_tokens']['violations'] else 1
    elif part == 'crosscheck':
        summary = {k: {'violations': len(v['violations'])} for k, v in res.items() if isinstance(v, dict)}
        code = 0 if all(x['violations'] == 0 for x in summary.values()) else 1
    else:
        summary = {k: v for k, v in res.items() if k not in ('rows',)}
        summary['violations'] = summary['violations'][:5]
        code = 0 if not res['violations'] else 1
    print(json.dumps(summary, indent=1)[:6000])
    return code


if __name__ == '__main__':
    sys.exit(main())
