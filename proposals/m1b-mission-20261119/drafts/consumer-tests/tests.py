#!/usr/bin/env python3
"""Z5 consumer tests 7..14 and negative controls. NOT proved. A finite test of a THIN harness (consumer.py) that
is not product code. Usage: python3 tests.py [smoke|all]. Writes results/<part>.json.
Exit 0: every test of the harness under test ('correct') gave its expected result AND every negative-control
variant failed at least one test. Exit 1: otherwise."""
import sys
sys.dont_write_bytecode = True
import hashlib, json, os, signal, socket, subprocess, threading, time
from pathlib import Path

W = Path(__file__).resolve().parent
sys.path.insert(0, str(W))
import consumer as C          # noqa: E402
M, frame = C.M, C.frame

ROOT = C.ROOT
CORE = W / 'model.cjs'
CORE_SHA = 'e6d5f5e54405f2767de59e054c329b86fc5d769c873c055c08780e89fbd906ce'
CFG = W / 'cfg.json'
SOCK = 'issuer.sock'          # relative to W (the AF_UNIX path limit is 104 bytes)
S0 = {'chargeId': 'ch_z5', 'original': '1000', 'remaining': '1000', 'refundEnabled': True}


# ------------------------------------------------------------------------------------------- issuer relay
class Issuer:
    """Starts the REAL minter.ts as the demo and D6 do; one relay thread serves a Unix socket, one line each."""
    def __init__(self):
        assert hashlib.sha256(CORE.read_bytes()).hexdigest() == CORE_SHA, 'core module is not the recorded one'
        env = dict(C.ENV, NODE_PATH=str(ROOT / 'node_modules'))
        self.p = subprocess.Popen([C.NODE, '--import', 'tsx', 'ts/refund-finality/minter.ts', str(CORE), 'spec/refund/spec.lock', 'off'],
                                  cwd=ROOT, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=open(W / 'logs' / 'issuer.stderr', 'wb'))
        self.ready = json.loads(self.p.stdout.readline())
        assert self.ready.get('ready') is True
        CFG.write_text(json.dumps({k: self.ready[k] for k in ('publicKeyPem', 'specLockSha256', 'checkerSha256')}))
        self.n, self.lock, self.signed = 0, threading.Lock(), []
        os.chdir(W)
        try: os.unlink(SOCK)
        except FileNotFoundError: pass
        self.srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.srv.bind(SOCK); self.srv.listen(16)
        threading.Thread(target=self.serve, daemon=True).start()

    def serve(self):
        while True:
            conn, _ = self.srv.accept()
            data = b''
            while not data.endswith(b'\n'):
                piece = conn.recv(65536)
                if not piece: break
                data += piece
            msg = json.loads(data)
            with self.lock:
                self.n += 1
                self.p.stdin.write((json.dumps({'id': self.n, 'pre': msg['pre'], 'transition': msg['transition']}) + '\n').encode())
                self.p.stdin.flush()
                line = self.p.stdout.readline()
                ans = json.loads(line)
                assert ans['id'] == self.n
                if ans.get('ok'): self.signed.append(ans['token']['body']['requestId'])
            del ans['id']
            conn.sendall((json.dumps(ans) + '\n').encode()); conn.close()

    def close(self):
        self.p.stdin.close(); code = self.p.wait(timeout=30); return code


_k = [0]


def store(state=S0, name='s'):
    _k[0] += 1
    db = W / 'db' / ('%s-%04d.sqlite' % (name, _k[0]))
    for suf in ('', '-journal', '-wal', '-shm'):
        Path(str(db) + suf).unlink(missing_ok=True)
    C.sinkctl('init', db, CFG, json.dumps(state))
    return db


def inspect(db):
    return C.sinkctl('inspect', db, CFG)


def req(rid, amount='40', reason='returned_item'):
    return {'requestId': rid, 'amount': amount, 'reason': reason}


def run(request, db, **kw):
    return C.consume(request, db, CFG, SOCK, **kw)


def issuer_direct(rec):
    """Precondition evidence only: the issuer's answer on the record's message. The token is discarded."""
    a = C.ask_issuer(SOCK, C.to_issuer(rec))
    return {'ok': a.get('ok'), 'reason': a.get('reason')}


def consistent(db, original=1000):
    r = inspect(db)
    st = json.loads(r['state'])
    total = sum(int(s['amount']) for s in r['settled'])
    ok = r['audit'] == [] and int(st['remaining']) == original - total and len(r['settled']) == len(r['outbox'])
    return ok, r


ROWS = []


def row(test, case, variant, expected, actual, passed, **extra):
    d = dict(test=test, case=case, variant=variant, expected=expected, actual=actual, passed=bool(passed), **extra)
    ROWS.append(d)
    print('%-4s %-6s %-12s %-58s %s' % (test, 'PASS' if passed else 'FAIL', variant, case[:58], actual[:110]), flush=True)
    return d


def brief(log):
    return 'stop=%s; m1=%s; issuer_asked=%d; token=%s; commit=%s' % (
        log.get('stop'), (log.get('m1') or ['-'])[0], log['issuer_asked'], 'yes' if log['token'] else 'no',
        (log['commit'] or {}).get('status', '-') + ((' (' + log['commit'].get('reason', '') + ')') if log['commit'] and log['commit'].get('reason') else ''))


# ------------------------------------------------------------------------------------------- tests
def t7(variant):
    # 7a: stored remaining 300 (after a commit of 700); M1 is given a STALE remaining 1000 (a cached snapshot);
    #     the transition post is built from the same stale snapshot (1000 - 400); pre goes to Check from the store.
    db = store(name='t7a')
    first = run(req('rq_t7_first', '700'), db)
    assert first['commit'] == {'status': 'committed'}, first
    before = inspect(db)
    log = run(req('rq_t7_stale', '400'), db, variant=variant,
              m1_side=lambda r: (r['state'].update(remaining='1000'), r)[1],
              iss_msg_side=lambda m: (m['transition']['post'].update(remaining='600'), m)[1])
    after = inspect(db)
    committed = len(after['settled']) - len(before['settled'])
    row('7a', 'stale remaining 1000 to M1, store 300, amount 400', variant, 'no token, no commit',
        brief(log), log['token'] is None and committed == 0, log=log)
    # 7b: ONE source, but the store changes between the read (step 0) and the commit (TOCTOU).
    db = store(name='t7b')
    log = run(req('rq_t7b', '400'), db, variant=variant, after_read=lambda: run(req('rq_t7b_other', '100'), db))
    ok, r = consistent(db)
    ids = [s['request_id'] for s in r['settled']]
    row('7b', 'one source; another commit after the read (TOCTOU)', variant,
        'no commit of rq_t7b (a token MAY exist; the sink must refuse the stale pre-state)', brief(log),
        'rq_t7b' not in ids and ok, settled=ids, log=log)
    # 7c: the SAME values; M1 accepts, the issuer refuses (its shape check: text > 256 UTF-16 units; U+0000).
    for case, rid in (('request id of 257 ASCII characters', 'r' * 257), ('request id with U+0000', 'rq_\u0000x')):
        db = store(name='t7c')
        log = run(req(rid), db, variant=variant)
        n = len(inspect(db)['settled'])
        row('7c', case, variant, 'no token, no commit', brief(log), log['token'] is None and n == 0, log=log)


def planted(kind):
    def tr(fields, real):
        exp = M.expected_accept(fields)
        other = frame.render_fields(True, fields['amount'], fields['reason'], fields['charge'], fields['request'] + b'x', 1)
        P = M.ProcessResult
        return {'status0-empty': P(0, None, False, b'', b'', False),
                'status0-cut-last-byte': P(0, None, False, exp[:-1], b'', False),
                'status0-half': P(0, None, False, exp[:len(exp) // 2], b'', False),
                'status0-stderr-line': P(0, None, False, exp, b'Resource limit reached\n', False),
                'status1-full-frame': P(1, None, False, exp, b'', False),
                'signal9-full-frame': P(None, 9, False, exp, b'', False),
                'status0-other-request-frame': P(0, None, False, other, b'', False),
                'status0-frame-twice': P(0, None, False, exp + exp, b'', False),
                'real-run-cut-last-byte': real._replace(stdout=real.stdout[:-1]),
                'real-run-cut-half': real._replace(stdout=real.stdout[:len(real.stdout) // 2]),
                }[kind]
    return tr


PLANTED = ['status0-empty', 'status0-cut-last-byte', 'status0-half', 'status0-stderr-line', 'status1-full-frame',
           'signal9-full-frame', 'status0-other-request-frame', 'status0-frame-twice', 'real-run-cut-last-byte', 'real-run-cut-half']


def t8(variant):
    for kind in PLANTED:
        db = store(name='t8')
        rq = req('rq_t8')
        pre_ok = issuer_direct({'state': S0, 'request': rq, 'opened': True, 'candidate': True})
        log = run(rq, db, variant=variant, m1_runner=C.composed_runner(planted(kind)))
        n = len(inspect(db)['settled'])
        row('8', kind + ' (Check alone: ok=%s)' % pre_ok['ok'], variant, 'no token, no commit', brief(log),
            pre_ok['ok'] and log['token'] is None and n == 0, log=log)


def t9(variant):
    db = store(name='t9')
    log = run(req('rq_t9'), db, variant=variant)
    replay = C.sinkctl('commit', db, CFG, _tokfile(log['token'])) if log['token'] else None
    ok, r = consistent(db)
    passed = (log['token'] is not None and log['commit'] == {'status': 'committed'} and replay == {'status': 'replayed'}
              and len(r['settled']) == 1 and len(r['outbox']) == 1 and json.loads(r['state'])['remaining'] == '960' and ok)
    row('9', 'both accept; then a replay of the same token', variant, 'one token; committed once; replay = replayed',
        brief(log) + '; replay=%s; settled=%d; remaining=%s; audit=%s' % (
            (replay or {}).get('status'), len(r['settled']), json.loads(r['state'])['remaining'], r['audit']), passed, log=log)
    again = run(req('rq_t9'), db, variant=variant)
    ok2, r2 = consistent(db)
    row('9b', 'the same request again after its commit (new pre-state)', variant,
        'no second commit (record what happens)', brief(again) + '; settled=%d' % len(r2['settled']),
        len(r2['settled']) == 1 and ok2, log=again)


def _tokfile(text):
    f = W / 'tmp' / ('replay-%d-%d.txt' % (os.getpid(), time.time_ns()))
    f.write_bytes(text.encode('utf-8'))
    return f


T10 = [('charge', lambda r: r['state'].update(chargeId='ch_z5x')),
       ('request', lambda r: r['request'].update(requestId='rq_t10x')),
       ('reason', lambda r: r['request'].update(reason='duplicate_charge')),
       ('original', lambda r: r['state'].update(original='2000')),
       ('remaining', lambda r: r['state'].update(remaining='999')),
       ('amount', lambda r: r['request'].update(amount='39')),
       ('enabled', lambda r: r['state'].update(refundEnabled=False)),
       ('opened', lambda r: r.update(opened=False)),
       ('candidate', lambda r: r.update(candidate=False))]


def t10(variant):
    for name, change in T10:
        db = store(name='t10')
        log = run(req('rq_t10'), db, variant=variant, m1_side=lambda r, c=change: (c(r), r)[1])
        n = len(inspect(db)['settled'])
        row('10', 'M1 value differs in field %s' % name, variant, 'no token, no commit', brief(log),
            log['token'] is None and n == 0, log=log)


def t11():
    """SIGKILL of the consumer process at three points; then a restart with the same request."""
    for point in ('after-m1', 'after-sign', 'after-commit'):
        db = store(name='t11')
        rq = json.dumps(req('rq_t11'))
        p = subprocess.Popen([sys.executable, '-I', str(W / 'consumer.py'), 'run', str(db), str(CFG), SOCK, rq, point],
                             cwd=W, env=C.ENV, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        line = p.stdout.readline().decode().strip()
        os.kill(p.pid, signal.SIGKILL); p.wait()
        killed = p.returncode
        ok1, r1 = consistent(db)
        n1 = len(r1['settled'])
        q = subprocess.run([sys.executable, '-I', str(W / 'consumer.py'), 'run', str(db), str(CFG), SOCK, rq, 'none'],
                           cwd=W, env=C.ENV, capture_output=True, timeout=180)
        log2 = json.loads(q.stdout.decode().strip().splitlines()[-1])
        ok2, r2 = consistent(db)
        replay = C.sinkctl('commit', db, CFG, _tokfile(log2['token'])) if log2['token'] else None
        want1 = 1 if point == 'after-commit' else 0
        # After a commit, the restart reads the NEW state, gets a NEW token (other pre-state hash): the sink must
        # refuse it as 'request id is already settled with another token'; no second commit.
        want2 = 'rejected' if point == 'after-commit' else 'committed'
        want_replay = 'rejected' if point == 'after-commit' else 'replayed'
        passed = (line == 'PAUSED ' + point and killed == -9 and n1 == want1 and ok1 and
                  (log2['commit'] or {}).get('status') == want2 and len(r2['settled']) == 1 and ok2
                  and (replay or {}).get('status') == want_replay)
        row('11', 'SIGKILL %s, then restart' % point, 'correct',
            'after kill: %d commit(s), store consistent; restart: %s; replay of restart token: %s; one settled row' % (want1, want2, want_replay),
            'paused=%r kill_rc=%s settled_after_kill=%d consistent=%s | restart: %s exit=%d | settled=%d consistent=%s replay=%s' % (
                line, killed, n1, ok1, brief(log2), q.returncode, len(r2['settled']), ok2, (replay or {}).get('status')),
            passed, log=log2)


def t12():
    db = store(name='t12')
    a = run(req('rq_zero_1', '0'), db)
    b = run(req('rq_zero_2', '0'), db)
    rep = C.sinkctl('commit', db, CFG, _tokfile(a['token'])) if a['token'] else None
    c = run(req('rq_t12_after', '40'), db)
    ok, r = consistent(db)
    row('12', 'two zero-amount requests, a replay, then amount 40', 'correct',
        'RECORD (no fixed expectation); store consistent',
        'zero_1: %s | zero_2: %s | replay zero_1: %s | amount 40: %s | outbox amounts=%s remaining=%s audit=%s' % (
            brief(a), brief(b), (rep or {}).get('status'), brief(c), [s['amount'] for s in r['settled']],
            json.loads(r['state'])['remaining'], r['audit']), ok, logs=[a, b, c])


def t13():
    # (a) the request carries non-canonical integer text; the harness's strict parser refuses before M1.
    for amt in ('040', '+40', ' 40', '40.0', '4e1'):
        db = store(name='t13')
        log = run(req('rq_t13', amt), db)
        row('13a', 'amount text %r, correct harness' % amt, 'correct', 'refused at step 0; no M1 run; no token',
            brief(log), log['token'] is None and 'm1' not in log and log.get('stop', '').startswith('S0'), log=log)
    # (b) a careless reader (Python int) and no guards: M1 receives 40; the issuer receives '040'.
    db = store(name='t13')
    log = run(req('rq_t13b', '040'), db, variant='lenient-int-noguard')
    row('13b', "amount '040' read by int(), guards off", 'lenient-int-noguard','no token (issuer shape check refuses 040)',
        brief(log), log['token'] is None, log=log)
    # (c) the executable itself on a hand-built non-canonical wire (NOT a harness path).
    fields = C.to_m1({'state': S0, 'request': req('rq_t13c'), 'opened': True, 'candidate': True})
    canonical = M.wire(fields)
    out = {}
    for label, wire in (('canonical', canonical), ('amount 040', canonical.replace(b' 40 returned_item', b' 040 returned_item')),
                        ('amount +40', canonical.replace(b' 40 returned_item', b' +40 returned_item')),
                        ('remaining 01000', canonical.replace(b' 1000 1000 ', b' 1000 01000 '))):
        res = M.run_process(str(C.EXE), wire, M.output_bound(fields))
        dec = M.decide_from_result(fields, res)
        out[label] = {'wire': wire.decode(), 'exit': res.exit_code, 'stdout': res.stdout.decode('latin-1'), 'decide': list(dec)}
        row('13c', 'executable on hand-built wire: %s' % label, 'direct', 'RECORD', 'exit=%s stdout=%r decide=%s' % (
            res.exit_code, res.stdout.decode('latin-1')[:70], dec[0]), True, run=out[label])
    # (d) the only wire builder in the harness: count the call sites in consumer.py.
    src = (W / 'consumer.py').read_text()
    sites = {'M.wire(': src.count('M.wire('), 'M.decide(': src.count('M.decide('), 'render_request': src.count('render_request'),
             'run_process(': src.count('run_process(')}
    row('13d', 'wire builders in consumer.py (source count)', 'correct', 'only M.wire (frame.render_request) via decide/composed',
        json.dumps(sites), sites['render_request'] == 0 and sites['M.wire('] == 1, sites=sites)


T14 = [('request rq_é (U+00E9)', 'ch_z5', 'rq_é'),
       ('request rq_€ (U+20AC)', 'ch_z5', 'rq_€'),
       ('request rq_\U0001F600 (astral)', 'ch_z5', 'rq_\U0001F600'),
       ('charge ch_日本, request rq_ü', 'ch_日本', 'rq_ü'),
       ('request with space, quote, backslash', 'ch_z5', 'rq "x" y\\z'),
       ('request with tab, newline, CR', 'ch_z5', 'rq\tx\ny\rz'),
       ('request with U+0085 and U+2028', 'ch_z5', 'rq\u0085 '),
       ('request = 128 astral (256 UTF-16 units, 512 bytes)', 'ch_z5', '\U0001F600' * 128),
       ('request = 129 astral (258 UTF-16 units)', 'ch_z5', '\U0001F600' * 129),
       ('request = 256 x U+00E9 (256 units, 512 bytes)', 'ch_z5', 'é' * 256),
       ('request with a lone surrogate U+D800', 'ch_z5', 'rq_\ud800')]


def t14():
    for case, ch, rid in T14:
        st = dict(S0, chargeId=ch)
        try:
            db = store(st, name='t14')
        except RuntimeError as e:
            row('14', case, 'correct', 'RECORD', 'sink init refused: %s' % str(e)[:80], True); continue
        log = run(req(rid), db)
        n = len(inspect(db)['settled'])
        fields = log.get('m1_fields')
        # M1 alone, on the same fields: is the result AUTHORIZED, i.e. did stdout equal D11's expected frame?
        row('14', case, 'correct', 'RECORD; if M1 AUTHORIZED then its stdout == D11 expected frame; token iff both accept',
            brief(log) + '; settled=%d' % n, (log['token'] is None) == (n == 0), log=log)
    # bytes >= 0x80 that are not UTF-8: a Latin-1 encoder for M1 (the issuer gets the Unicode text).
    for g in (True, False):
        db = store(name='t14')
        log = run(req('rq_é'), db, variant='latin1' if g else 'latin1-noguard')
        row('14L', 'M1 gets Latin-1 byte E9, issuer gets U+00E9; guards=%s' % g, 'latin1' if g else 'latin1-noguard',
            'no token (M1 checked other bytes than the token binds)', brief(log), log['token'] is None, log=log)
    # M1 directly on non-UTF-8 byte ids (no issuer side exists for them).
    for b in (b'rq_\xe9', b'\xff\xfe', b'\x80', b'rq_\xc3'):
        f = C.to_m1({'state': S0, 'request': req('x'), 'opened': True, 'candidate': True})
        f['request'] = b
        d = M.decide(f, str(C.EXE))
        row('14B', 'M1 alone, request bytes %r' % b, 'direct', 'RECORD (D11: AUTHORIZED only if stdout == expected frame)',
            str(d), True, decide=list(d))


VARIANTS_CTRL = ['m1-alone', 'exit0-alone', 'two-source', 'latin1-noguard']
INFO_CTRL = ['lenient-int-noguard']   # a careless control that is NOT required to fail (reported as it is)


def main():
    part = sys.argv[1] if len(sys.argv) > 1 else 'all'
    t0 = time.monotonic()
    iss = Issuer()
    try:
        if part == 'smoke':
            t9('correct')
        else:
            for v in ['correct'] + VARIANTS_CTRL:
                t7(v); t8(v); t9(v); t10(v)
            t11(); t12(); t13(); t14()
    finally:
        code = iss.close()
    under = [r for r in ROWS if r['variant'] not in VARIANTS_CTRL + INFO_CTRL]
    ctrl = {v: [r['test'] + ':' + r['case'] for r in ROWS if r['variant'] == v and not r['passed']] for v in VARIANTS_CTRL}
    summary = {'part': part, 'seconds': round(time.monotonic() - t0, 1), 'issuer_exit': code, 'issuer_signed': len(iss.signed),
               'rows': len(ROWS), 'under_test_rows': len(under), 'under_test_failed': [r['test'] + ':' + r['case'] for r in under if not r['passed']],
               'controls_failed_tests': {v: len(x) for v, x in ctrl.items()}, 'controls_failed_list': ctrl}
    (W / 'results' / ('%s.json' % part)).write_text(json.dumps({'summary': summary, 'rows': ROWS}, indent=1, default=repr))
    print(json.dumps(summary, indent=1)[:5000])
    ok = not summary['under_test_failed'] and (part == 'smoke' or all(summary['controls_failed_tests'][v] > 0 for v in VARIANTS_CTRL))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
