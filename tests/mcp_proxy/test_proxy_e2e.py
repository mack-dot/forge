#!/usr/bin/env python3
"""End-to-end tests: the stdlib MCP client -> mcp-proxy -> the real showcase MCP servers.

FINITE TEST of a NATIVE CHECK. Nothing here is a proof. One line per case: PASS, FAIL or
NOT RUN (a prerequisite case failed). Exit 0 only when every case passes.

The binary is built with the contract's rustc command into a temporary folder, unless
--binary PATH is given. Temporary files go under $MCP_TEST_TMP (default: the system temp dir).

Run: python3 tests/mcp_proxy/test_proxy_e2e.py [--binary build/airlock/mcp-proxy]

Evidence checks (REVIEW-B finding 7): every evidence.wal is verified by BOTH verifiers, the proxy's
`verify-evidence` and the independent stdlib `verify_independent.py` (with the ledger cross-check), and the
receipts are counted by verdict and compared with this file's own count of the actions it sent. A signature
from another key must fail. Other cases: a reopen of a store (epoch and chain continue; a record whose chain
value does not match refuses the start), hostile-upstream reads with the foreign record in a text item and in
plain text, and an async-mode session.
Not testable here: a missing fsync of the ledger (reviewer mutant m09). Only a machine crash or power loss can
show it; no black-box test of this file can, and none is claimed.
"""

import collections
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import traceback

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from mcp_client import McpClient  # noqa: E402

SHOW = ROOT / 'examples' / 'archia_mcp_showcase'
FINTECH = SHOW / 'servers' / 'fintech_server.py'
HEALTH = SHOW / 'servers' / 'healthcare_server.py'
FIN_POLICY = SHOW / 'policies' / 'fintech.policy.json'
HC_POLICY = SHOW / 'policies' / 'healthcare.policy.json'
HC_FACTS = SHOW / 'policies' / 'healthcare.facts.json'
HOSTILE = HERE / 'hostile_upstream.py'
VIND = HERE / 'verify_independent.py'
PY = sys.executable
RUSTC = os.environ.get('RUSTC', shutil.which('rustc') or '/Users/mackianni/.cargo/bin/rustc')
SSH_KEYGEN = '/usr/bin/ssh-keygen'
PRINCIPAL = 'forge-airlock-test'
ZERO = '0' * 32

RESULTS = []
FAILED_KEYS = set()


class NotRun(Exception):
    pass


def case(name, needs=()):
    """Decorator that runs the case now. `needs`: names of cases that must have passed."""
    def deco(fn):
        missing = [n for n in needs if n in FAILED_KEYS or n not in {r[0] for r in RESULTS}]
        if missing:
            FAILED_KEYS.add(name)
            RESULTS.append((name, 'NOT RUN', 'needs %s' % ', '.join(missing)))
            print('NOT RUN %s -- needs %s' % (name, ', '.join(missing)), flush=True)
            return fn
        try:
            fn()
            RESULTS.append((name, 'PASS', ''))
            print('PASS %s' % name, flush=True)
        except Exception as e:
            FAILED_KEYS.add(name)
            detail = '%s: %s' % (type(e).__name__, e)
            RESULTS.append((name, 'FAIL', detail))
            print('FAIL %s -- %s' % (name, detail), flush=True)
            traceback.print_exc(file=sys.stderr)
        return fn
    return deco


def check(cond, msg):
    if not cond:
        raise AssertionError(msg)


def read_lines(path):
    if not os.path.exists(path):
        return []
    with open(path, 'rb') as f:
        return f.read().split(b'\n')[:-1]


def audit(path):
    return [json.loads(x) for x in read_lines(path)]


def take_binary_arg():
    if '--binary' in sys.argv:
        i = sys.argv.index('--binary')
        return str(Path(sys.argv[i + 1]).resolve())
    return None


T = {}  # shared test state
# This file's own count of the receipts that each session must have produced: session -> Counter(verdict).
EXPECT = collections.defaultdict(collections.Counter)
# Verdicts whose count may be higher by at most N (a behaviour that CONTRACT3 leaves open): session -> {verdict: N}.
EXPECT_FLEX = collections.defaultdict(dict)
TMP = Path(tempfile.mkdtemp(prefix='mcp-e2e-', dir=os.environ.get('MCP_TEST_TMP')))


@case('build')
def _build():
    given = take_binary_arg()
    if given:
        check(os.path.isfile(given), 'no binary at %s' % given)
        T['bin'] = given
        return
    out = TMP / 'mcp-proxy'
    argv = [RUSTC, '--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3', 'src/mcp_proxy/main.rs', '-o', str(out)]
    p = subprocess.run(argv, cwd=ROOT, capture_output=True, timeout=900)
    check(p.returncode == 0, 'rustc exit %d: %s' % (p.returncode, p.stderr.decode('utf-8', 'replace')[-2000:]))
    T['bin'] = str(out)


@case('keygen')
def _keygen():
    key = TMP / 'signing_key'
    p = subprocess.run([SSH_KEYGEN, '-q', '-t', 'ed25519', '-N', '', '-C', PRINCIPAL, '-f', str(key)], capture_output=True)
    check(p.returncode == 0, 'ssh-keygen exit %d' % p.returncode)
    os.chmod(key, 0o600)
    pub = (TMP / 'signing_key.pub').read_text().split()
    signers = TMP / 'allowed_signers'
    signers.write_text('%s namespaces="forge-airlock-evidence" %s %s\n' % (PRINCIPAL, pub[0], pub[1]))
    T['key'], T['signers'] = str(key), str(signers)


def start_proxy(name, policy, server_argv, session, facts=None, store=None, sign_mode=None):
    d = TMP / name
    d.mkdir(parents=True, exist_ok=store is not None)
    if store is None:
        store = d / 'store'
        store.mkdir(parents=True)
        os.chmod(store, 0o700)
    argv = [T['bin'], 'mcp', '--policy', str(policy), '--agent-id', 'agent-%s' % name[:20], '--store', str(store),
            '--key', T['key']]
    if facts:
        argv += ['--facts', str(facts)]
    if sign_mode:
        argv += ['--sign-mode', sign_mode]
    for kv in session:
        argv += ['--session', kv]
    argv += ['--'] + server_argv
    c = McpClient(argv, cwd=str(ROOT), stderr_path=str(d / 'proxy.stderr'))
    return c, d, store


def head(c):
    r = c.request('forge-airlock/state', {})
    check('result' in r and isinstance(r['result'].get('state'), str), 'forge-airlock/state answer %r' % (r,))
    return r['result']['epoch'], r['result']['state']


def meta(request_id, pre):
    return {'forge-airlock/request_id': request_id, 'forge-airlock/pre_state_hash': pre}


def payout(c, rid, pre, amount='100.00', req_id=None):
    return c.call_tool('issue_payout', {'amount': amount, 'invoice_id': 'INV-A-1001', 'vendor': 'Example Paper Supply (synthetic)'},
                       meta=meta(rid, pre), req_id=req_id)


def refusal(r, verdict):
    check('error' in r, 'expected a refusal, got %r' % (r,))
    e = r['error']
    check(e['code'] == -32001 and e['message'] == 'Airlock Invariant Breach', 'refusal shape %r' % e)
    check(e['data']['verdict'] == verdict, 'verdict %r, want %s' % (e['data'].get('verdict'), verdict))
    return e['data']


def barrier(c):
    """A ping through the proxy to the server: when its answer is back, the server has read every earlier line."""
    r = c.request('ping', {})
    check(r.get('result') == {}, 'ping %r' % (r,))


def verify(wal, signers=None):
    # The allowed-signers principal is PRINCIPAL; EVIDENCE's default identity is `forge-airlock`.
    return subprocess.run([T['bin'], 'verify-evidence', str(wal), '--allowed-signers', str(signers or T['signers']),
                           '--identity', PRINCIPAL],
                          capture_output=True, timeout=300)


def verify_py(wal, ledger=None, signers=None):
    argv = [PY, '-I', str(VIND), str(wal), '--allowed-signers', str(signers or T['signers']), '--identity', PRINCIPAL]
    if ledger:
        argv += ['--ledger', str(ledger)]
    p = subprocess.run(argv, capture_output=True, timeout=300)
    return p.returncode, p.stdout.decode('utf-8', 'replace') + p.stderr.decode('utf-8', 'replace')


def state_cmd(store):
    p = subprocess.run([T['bin'], 'state', str(store)], capture_output=True, timeout=30)
    check(p.returncode == 0, 'state exit %d: %s' % (p.returncode, p.stderr.decode('utf-8', 'replace')))
    w = dict(x.split('=', 1) for x in p.stdout.decode().split())
    return int(w['epoch']), w['state']


def ev_frames(data):
    """Frames of an evidence.wal (format at the top of evidence.rs): list of [type, payload]."""
    i, out = 30, []
    while i < len(data):
        t, n = data[i], int.from_bytes(data[i + 1:i + 5], 'big')
        out.append([t, bytes(data[i + 5:i + 5 + n])])
        i += 5 + n + 8
    return out


def ev_build(frames):
    out = bytearray(b'forge-airlock-evidence-wal-v1\n')
    for t, p in frames:
        ln = len(p).to_bytes(4, 'big')
        out += bytes([t]) + ln + p + hashlib.sha256(b'forge-airlock-evidence-frame-v1' + bytes([t]) + ln + p).digest()[:8]
    return bytes(out)


# ---------------------------------------------------------------- fintech
@case('fintech_start_and_lifecycle_passthrough', needs=('build', 'keygen'))
def _fin_start():
    d = TMP / 'fin'
    d.mkdir()
    T['fin_audit'], T['fin_wire'] = str(d / 'audit.jsonl'), str(d / 'wire.log')
    server = [PY, str(FINTECH), '--balance', '500.00', '--audit', T['fin_audit'], '--wire-log', T['fin_wire']]
    c, _, store = start_proxy('fin-proxy', FIN_POLICY, server, ['org_id=Org_Alpha'])
    T['fin'], T['fin_store'] = c, store
    r = c.initialize()
    check(r['result']['serverInfo']['name'] == 'archia-fintech-demo', 'initialize passthrough %r' % r)
    check(r['result']['protocolVersion'] == '2025-06-18', 'protocolVersion')
    t = c.request('tools/list', {})
    check(sorted(x['name'] for x in t['result']['tools']) == ['get_balance', 'issue_payout', 'list_invoices'], 'tools/list')
    barrier(c)
    wl = read_lines(T['fin_wire'])
    check(len(wl) == 4, 'server saw initialize, initialized, tools/list, ping: %d lines' % len(wl))


@case('fintech_stale_pre_state_refused_wire_unchanged', needs=('fintech_start_and_lifecycle_passthrough',))
def _fin_stale():
    c = T['fin']
    epoch, state = head(c)
    T['fin_head0'] = (epoch, state)
    stale = ZERO if state != ZERO else 'f' * 32
    before = read_lines(T['fin_wire'])
    data = refusal(payout(c, 'stale-1', stale), 'BLOCKED_CAS')
    EXPECT['fintech']['BLOCKED_CAS'] += 1
    check(data['state'] == state and data['epoch'] == epoch, 'refusal names the head %r' % data)
    barrier(c)
    after = read_lines(T['fin_wire'])
    check(len(after) == len(before) + 1, 'only the barrier ping reached the server')
    check(not any(b'stale-1' in x for x in after), 'the stale call reached the server')
    check(audit(T['fin_audit']) == [], 'nothing executed')


@case('fintech_one_committed_payout', needs=('fintech_stale_pre_state_refused_wire_unchanged',))
def _fin_commit():
    c = T['fin']
    epoch, state = T['fin_head0']
    r = payout(c, 'pay-1', state, amount='100.00')
    check('result' in r and r['result']['isError'] is False, 'committed call answer %r' % (r,))
    EXPECT['fintech']['COMMITTED'] += 1
    check(r['result']['structuredContent']['balance'] == '400.00', 'server balance %r' % r['result'])
    e2, s2 = head(c)
    check(e2 == epoch + 1 and s2 != state, 'head advanced: %r -> %r' % ((epoch, state), (e2, s2)))
    T['fin_head1'] = (e2, s2)
    au = audit(T['fin_audit'])
    check(len(au) == 1 and au[0]['outcome'] == 'paid', 'audit %r' % au)


@case('fintech_policy_rule_refused', needs=('fintech_one_committed_payout',))
def _fin_rule():
    c = T['fin']
    before = len(read_lines(T['fin_wire']))
    refusal(payout(c, 'big-1', T['fin_head1'][1], amount='500.01'), 'BLOCKED_POLICY')
    EXPECT['fintech']['BLOCKED_POLICY'] += 1
    barrier(c)
    check(len(read_lines(T['fin_wire'])) == before + 1, 'rule refusal reached the server')
    check(head(c) == T['fin_head1'], 'a refusal must not move the head')


@case('fintech_duplicate_request_id', needs=('fintech_one_committed_payout',))
def _fin_dup():
    c = T['fin']
    before = len(read_lines(T['fin_wire']))
    # Same forge request id, CURRENT pre-state (so only the idempotency check can refuse it), new JSON-RPC id.
    refusal(payout(c, 'pay-1', T['fin_head1'][1], amount='100.00'), 'BLOCKED_DUPLICATE')
    EXPECT['fintech']['BLOCKED_DUPLICATE'] += 1
    barrier(c)
    check(len(read_lines(T['fin_wire'])) == before + 1, 'duplicate reached the server')
    check(len(audit(T['fin_audit'])) == 1, 'audit grew')


@case('fintech_cross_tenant_invoice_read_dropped', needs=('fintech_one_committed_payout',))
def _fin_read():
    c = T['fin']
    raw0 = len(c.raw)
    r = c.call_tool('list_invoices', {})
    check(r['result']['isError'] is True and r['result']['content'] == [], 'dropped read %r' % (r,))
    EXPECT['fintech']['READ_DROPPED'] += 1
    got = bytes(c.raw[raw0:])
    for foreign in (b'Org_Beta', b'INV-B-', b'Legal Services'):
        check(foreign not in got, 'foreign bytes %r reached the client' % foreign)
    r = c.call_tool('list_invoices', {'org_id': 'Org_Alpha'})
    check(r['result']['isError'] is False and len(r['result']['structuredContent']['invoices']) == 2, 'own read %r' % r)
    EXPECT['fintech']['READ_ALLOWED'] += 1


@case('fintech_close_exit_0', needs=('fintech_start_and_lifecycle_passthrough',))
def _fin_close():
    code = T['fin'].close()
    check(code == 0, 'proxy exit %d' % code)


# ---------------------------------------------------------------- race (Beat 1 shape)
@case('race_20_calls_one_executed_payout', needs=('build', 'keygen'))
def _race():
    d = TMP / 'race'
    d.mkdir()
    a, w = str(d / 'audit.jsonl'), str(d / 'wire.log')
    server = [PY, str(FINTECH), '--balance', '500.00', '--audit', a, '--wire-log', w]
    c, _, store = start_proxy('race-proxy', FIN_POLICY, server, ['org_id=Org_Alpha'])
    T['race_store'] = store
    try:
        c.initialize()
        _, pre = head(c)
        msgs = [c.make_request('tools/call', {'name': 'issue_payout', 'arguments': {
            'amount': '500.00', 'invoice_id': 'INV-A-1001', 'vendor': 'V'}}, meta=meta('race-%02d' % i, pre))
            for i in range(20)]
        ids = c.send_many(msgs)
        answers = [c.wait(i) for i in ids]
        ok = [m for m, r in zip(msgs, answers) if 'result' in r and r['result'].get('isError') is False]
        cas = [r for r in answers if 'error' in r and r['error'].get('data', {}).get('verdict') == 'BLOCKED_CAS']
        check(len(ok) == 1 and len(cas) == 19, 'committed %d, BLOCKED_CAS %d, answers %r' % (len(ok), len(cas), answers[:3]))
        EXPECT['race'].update({'COMMITTED': 1, 'BLOCKED_CAS': 19})
        winner = ok[0]['params']['_meta']['forge-airlock/request_id']
        _, cur = head(c)
        retries = [c.make_request('tools/call', {'name': 'issue_payout', 'arguments': {
            'amount': '500.00', 'invoice_id': 'INV-A-1001', 'vendor': 'V'}}, meta=meta(winner, cur)) for _ in range(5)]
        rans = [c.wait(i) for i in c.send_many(retries)]
        check(all(r.get('error', {}).get('data', {}).get('verdict') == 'BLOCKED_DUPLICATE' for r in rans), 'retries %r' % rans)
        EXPECT['race']['BLOCKED_DUPLICATE'] += 5
        b = c.call_tool('get_balance', {})
        check(b['result']['structuredContent']['balance'] == '0.00', 'balance %r' % b)
    finally:
        code = c.close()
    check(code == 0, 'proxy exit %d' % code)
    au = audit(a)
    pays = [x for x in au if x['tool'] == 'issue_payout']
    check(len(pays) == 1 and pays[0]['outcome'] == 'paid', 'audit payouts %r' % pays)
    wire_calls = [x for x in read_lines(w) if b'issue_payout' in x]
    check(len(wire_calls) == 1, 'server received %d payout lines' % len(wire_calls))


# ---------------------------------------------------------------- healthcare
@case('health_start', needs=('build', 'keygen'))
def _hc_start():
    d = TMP / 'hc'
    d.mkdir()
    T['hc_audit'], T['hc_wire'], T['hc_state'] = (str(d / n) for n in ('audit.jsonl', 'wire.log', 'state.json'))
    server = [PY, str(HEALTH), '--audit', T['hc_audit'], '--wire-log', T['hc_wire'], '--state', T['hc_state']]
    c, _, store = start_proxy('hc-proxy', HC_POLICY, server, ['clinic_id=Clinic_Alpha'], facts=HC_FACTS)
    T['hc'], T['hc_store'] = c, store
    r = c.initialize()
    check(r['result']['serverInfo']['name'] == 'archia-healthcare-demo', 'initialize %r' % r)


@case('health_own_clinic_chart_passes', needs=('health_start',))
def _hc_own():
    r = T['hc'].call_tool('get_patient_chart', {'patient_id': 'PT-A-001'})
    check(r['result']['isError'] is False and r['result']['structuredContent']['clinic_id'] == 'Clinic_Alpha', 'own chart %r' % r)
    EXPECT['health']['READ_ALLOWED'] += 1


@case('health_cross_clinic_chart_zero_foreign_bytes', needs=('health_start',))
def _hc_cross():
    c = T['hc']
    raw0 = len(c.raw)
    r = c.call_tool('get_patient_chart', {'patient_id': 'PT-B-001'})
    check(r['result']['isError'] is True and r['result']['content'] == [], 'dropped %r' % (r,))
    check('structuredContent' not in r['result'], 'structuredContent leaked')
    EXPECT['health']['READ_DROPPED'] += 1
    got = bytes(c.raw[raw0:])
    for foreign in (b'Clinic_Beta', b'Beta-One', b'warfarin', b'1962'):
        check(foreign not in got, 'foreign bytes %r reached the client' % foreign)
    # The server did execute the read (reads are forwarded); the proxy dropped the answer.
    check(any(x['arguments'] == {'patient_id': 'PT-B-001'} for x in audit(T['hc_audit'])), 'server did not run the read')


@case('health_over_cap_dosage_no_state_change', needs=('health_start',))
def _hc_overcap():
    c = T['hc']
    _, pre = head(c)
    state0 = Path(T['hc_state']).read_bytes()
    wire0 = len(read_lines(T['hc_wire']))
    r = c.call_tool('update_dosage', {'patient_id': 'PT-A-001', 'medication': 'metoprolol', 'mg': 500},
                    meta=meta('dose-500', pre))
    refusal(r, 'BLOCKED_SUBCAP')
    EXPECT['health']['BLOCKED_SUBCAP'] += 1
    barrier(c)
    check(len(read_lines(T['hc_wire'])) == wire0 + 1, 'the over-cap call reached the server')
    check(Path(T['hc_state']).read_bytes() == state0, 'server state changed')
    check(head(c)[1] == pre, 'head moved')


@case('health_within_cap_dosage_applied', needs=('health_over_cap_dosage_no_state_change',))
def _hc_ok():
    c = T['hc']
    _, pre = head(c)
    r = c.call_tool('update_dosage', {'patient_id': 'PT-A-001', 'medication': 'metoprolol', 'mg': 50},
                    meta=meta('dose-50', pre))
    # CONTRACT3: the result of `update_dosage` now goes through the scoped-result filter. The showcase server's
    # result carries no `clinic_id`, so the proxy may replace it by the documented dropped shape with the word
    # RESULT_DROPPED (the dose was applied upstream: the state checks below hold either way).
    check('result' in r, 'within-cap answer is not a result: %r' % (r,))
    if r['result'].get('content') == [] and r['result'].get('isError') is True:
        check('RESULT_DROPPED' in json.dumps(r), 'dropped result without RESULT_DROPPED: %r' % (r,))
        check(b'previous_mg' not in bytes(c.raw), 'bytes of the dropped result reached the client')
        EXPECT['health']['READ_DROPPED'] += 1
        T['dose_note'] = 'result dropped (RESULT_DROPPED)'
    else:
        check(r['result']['isError'] is False, 'within-cap answer %r' % (r,))
        EXPECT_FLEX['health']['READ_ALLOWED'] = 1  # CONTRACT3 does not say whether an allowed result gets a receipt
        T['dose_note'] = 'result passed'
    EXPECT['health']['COMMITTED'] += 1
    st = json.loads(Path(T['hc_state']).read_text())
    meds = {m['medication']: m['mg'] for m in st['patients']['PT-A-001']['medications']}
    check(meds['metoprolol'] == 50 and st['updates_applied'] == 1, 'state %r' % meds)
    return T['dose_note']


@case('health_close_exit_0', needs=('health_start',))
def _hc_close():
    code = T['hc'].close()
    check(code == 0, 'proxy exit %d' % code)


# ---------------------------------------------------------------- reopen (REVIEW-B finding 7, mutant m12)
@case('reopen_store_continues_epoch_and_chain', needs=('fintech_close_exit_0',))
def _reopen():
    store = T['fin_store']
    e0, h0 = state_cmd(store)
    check((e0, h0) == T['fin_head1'], 'state DIR %r, want the head of the first session %r' % ((e0, h0), T['fin_head1']))
    d = TMP / 'fin-reopen'
    d.mkdir()
    a, w = str(d / 'audit.jsonl'), str(d / 'wire.log')
    server = [PY, str(FINTECH), '--balance', '500.00', '--audit', a, '--wire-log', w]
    c, _, _ = start_proxy('fin-reopen-proxy', FIN_POLICY, server, ['org_id=Org_Alpha'], store=store)
    try:
        c.initialize()
        check(head(c) == (e0, h0), 'the reopened proxy starts at %r, want %r' % (head(c), (e0, h0)))
        refusal(payout(c, 'reopen-stale', ZERO), 'BLOCKED_CAS')
        EXPECT['fintech']['BLOCKED_CAS'] += 1
        r = payout(c, 'reopen-pay', h0, amount='10.00')
        check('result' in r and r['result']['isError'] is False, 'commit after reopen %r' % (r,))
        EXPECT['fintech']['COMMITTED'] += 1
        e1, h1 = head(c)
        check(e1 == e0 + 1 and h1 != h0, 'epoch after reopen commit %d, want %d' % (e1, e0 + 1))
    finally:
        code = c.close()
    check(code == 0, 'reopen proxy exit %d' % code)
    check(state_cmd(store) == (e1, h1), 'state DIR after reopen %r' % (state_cmd(store),))
    return 'epoch %d -> %d on the same store' % (e0, e1)


@case('reopen_refused_when_a_chain_value_does_not_match', needs=('reopen_store_continues_epoch_and_chain',))
def _reopen_chain():
    # Change the timestamp of record 1 and recompute ONLY its frame check (the check has no key). The stored chain
    # value no longer matches; evidence.rs says that `open` checks every chain link again and refuses.
    d = TMP / 'chain-tamper'
    store = d / 'store'
    store.mkdir(parents=True)
    os.chmod(store, 0o700)
    for f in ('ledger.wal', 'evidence.wal'):
        shutil.copy2(T['fin_store'] / f, store / f)
        os.chmod(store / f, 0o600)
    fr = ev_frames((store / 'evidence.wal').read_bytes())
    k = next(i for i, x in enumerate(fr) if x[0] == 1)
    p = bytearray(fr[k][1])
    p[8 + 15] ^= 0x01  # last byte of the record's timestamp
    fr[k][1] = bytes(p)
    (store / 'evidence.wal').write_bytes(ev_build(fr))
    before = (store / 'evidence.wal').read_bytes()
    a, w = d / 'audit.jsonl', d / 'wire.log'
    argv = [T['bin'], 'mcp', '--policy', str(FIN_POLICY), '--agent-id', 'tamper', '--store', str(store), '--key', T['key'],
            '--session', 'org_id=Org_Alpha', '--', PY, str(FINTECH), '--audit', str(a), '--wire-log', str(w)]
    pr = subprocess.run(argv, input=b'{"jsonrpc":"2.0","id":1,"method":"ping"}\n', capture_output=True, timeout=60, cwd=str(ROOT))
    check(pr.returncode != 0, 'the proxy started on an evidence.wal whose chain value does not match (exit %d)' % pr.returncode)
    check(b'"result"' not in pr.stdout, 'a result reached the client')
    check((store / 'evidence.wal').read_bytes() == before, 'the refused start changed evidence.wal')
    rr = verify(store / 'evidence.wal').returncode
    pv = verify_py(store / 'evidence.wal')[0]
    check(rr == 1 and pv == 1, 'verifiers on the tampered file: rust %d, python %d' % (rr, pv))
    return 'start exit %d; verify rust %d python %d' % (pr.returncode, rr, pv)


# ---------------------------------------------------------------- hostile upstream reads (mutants m14, m15)
@case('health_hostile_upstream_text_items_dropped', needs=('build', 'keygen'))
def _hostile_items():
    d = TMP / 'hostile-items'
    d.mkdir()
    server = [PY, str(HOSTILE), '--wire', str(d / 'wire.log'), '--audit', str(d / 'audit.jsonl')]
    c, _, store = start_proxy('hostile-items-proxy', HC_POLICY, server, ['clinic_id=Clinic_Alpha'], facts=HC_FACTS)
    T['hostile_store'] = store
    out = []
    try:
        c.initialize()
        r = c.call_tool('get_patient_chart', {'mode': 'own', 'mark': 'OWN-CONTROL-1a1a'})
        check(r['result'].get('content') and b'OWN-CONTROL-1a1a' in bytes(c.raw), 'own-clinic control did not pass: %r' % (r,))
        EXPECT['hostile']['READ_ALLOWED'] += 1
        for mode in ('foreign_text_first', 'foreign_text_second', 'plain_text_first', 'plain_text_second', 'plain_text_in_own'):
            mark = 'MARK-%s' % mode.upper()
            raw0 = len(c.raw)
            r = c.call_tool('get_patient_chart', {'mode': mode, 'mark': mark})
            barrier(c)
            got = bytes(c.raw[raw0:])
            check(r['result'].get('content') == [] and r['result'].get('isError') is True, '%s: not dropped: %r' % (mode, r))
            for foreign in (mark.encode(), b'Clinic_Beta', b'P-2001'):
                check(foreign not in got, '%s: foreign bytes %r reached the client' % (mode, foreign))
            EXPECT['hostile']['READ_DROPPED'] += 1
            out.append('%s %s' % (mode, r['result'].get('_meta', {}).get('forge-airlock/reason')))
    finally:
        code = c.close()
    check(code == 0, 'proxy exit %d' % code)
    return '; '.join(out)


# ---------------------------------------------------------------- async sign mode
@case('async_mode_session', needs=('build', 'keygen'))
def _async():
    d = TMP / 'async'
    d.mkdir()
    a, w = str(d / 'audit.jsonl'), str(d / 'wire.log')
    server = [PY, str(FINTECH), '--balance', '500.00', '--audit', a, '--wire-log', w]
    c, _, store = start_proxy('async-proxy', FIN_POLICY, server, ['org_id=Org_Alpha'], sign_mode='async')
    T['async_store'] = store
    try:
        c.initialize()
        for i in range(3):
            _, h = head(c)
            r = payout(c, 'async-%d' % i, h, amount='10.00')
            check('result' in r and r['result']['isError'] is False, 'async commit %d: %r' % (i, r))
            EXPECT['async']['COMMITTED'] += 1
        refusal(payout(c, 'async-stale', ZERO), 'BLOCKED_CAS')
        EXPECT['async']['BLOCKED_CAS'] += 1
        _, h = head(c)
        refusal(payout(c, 'async-big', h, amount='600.00'), 'BLOCKED_POLICY')
        EXPECT['async']['BLOCKED_POLICY'] += 1
        check(head(c)[0] == 3, 'epoch %d' % head(c)[0])
    finally:
        code = c.close()
    check(code == 0, 'proxy exit %d' % code)
    check(len([x for x in audit(a) if x.get('outcome') == 'paid']) == 3, 'payouts')


# ---------------------------------------------------------------- evidence: both verifiers, receipt counts
def evidence_check(session, store):
    wal = store / 'evidence.wal'
    check(wal.is_file() and wal.stat().st_size > 0, 'no evidence.wal')
    p = verify(wal)
    rout = (p.stdout + p.stderr).decode('utf-8', 'replace')
    rc, pout = verify_py(wal, ledger=store / 'ledger.wal')
    check(p.returncode == 0 and rc == 0, 'verify-evidence exit %d, verify_independent.py exit %d: %s || %s' % (
        p.returncode, rc, rout[-600:], pout[-600:]))
    got = collections.Counter(json.loads([x for x in pout.splitlines() if x.startswith('counts=')][-1][len('counts='):]))
    rust = collections.Counter(re.findall(r'^#\d+ .*verdict=([A-Z_]+)', rout, re.M))
    if rust:
        check(rust == got, 'VERIFIERS DISAGREE on the receipt counts: rust %r, python %r' % (dict(rust), dict(got)))
    want, flex = EXPECT[session], EXPECT_FLEX[session]
    for v in set(want) | set(got):
        check(0 <= got[v] - want[v] <= flex.get(v, 0), 'receipts %s: %d, this test sent actions for %d (all: got %r, want %r)' % (
            v, got[v], want[v], dict(got), dict(want)))
    return 'both verifiers exit 0; receipts %s' % json.dumps(dict(sorted(got.items())))


for _name, _store_key, _close in (('fintech', 'fin_store', 'reopen_store_continues_epoch_and_chain'),
                                  ('race', 'race_store', 'race_20_calls_one_executed_payout'),
                                  ('health', 'hc_store', 'health_close_exit_0'),
                                  ('hostile', 'hostile_store', 'health_hostile_upstream_text_items_dropped'),
                                  ('async', 'async_store', 'async_mode_session')):
    def _v(store_key=_store_key, name=_name):
        return evidence_check(name, T[store_key])
    case('evidence_%s_both_verifiers_and_receipt_counts' % _name, needs=(_close,))(_v)


@case('verify_evidence_detects_one_flipped_byte', needs=('evidence_fintech_both_verifiers_and_receipt_counts',))
def _tamper():
    wal = T['fin_store'] / 'evidence.wal'
    data = bytearray(wal.read_bytes())
    bad = TMP / 'tampered.wal'
    data[len(data) // 2] ^= 0x01
    bad.write_bytes(bytes(data))
    p = verify(bad)
    check(p.returncode != 0, 'a flipped byte still verified')
    check(verify_py(bad)[0] != 0, 'verify_independent.py: a flipped byte still verified')


@case('verify_evidence_rejects_a_signature_of_another_key', needs=('evidence_fintech_both_verifiers_and_receipt_counts',))
def _other_key():
    # Mutant m06 (the verifier skips `ssh-keygen -Y verify`) passes every case above. These two must fail.
    d = TMP / 'other-key'
    d.mkdir()
    k = d / 'other'
    p = subprocess.run([SSH_KEYGEN, '-q', '-t', 'ed25519', '-N', '', '-C', PRINCIPAL, '-f', str(k)], capture_output=True)
    check(p.returncode == 0, 'ssh-keygen exit %d' % p.returncode)
    pub = (d / 'other.pub').read_text().split()
    other_signers = d / 'allowed_signers'
    other_signers.write_text('%s namespaces="forge-airlock-evidence" %s %s\n' % (PRINCIPAL, pub[0], pub[1]))
    wal = T['fin_store'] / 'evidence.wal'
    r1, p1 = verify(wal, other_signers).returncode, verify_py(wal, signers=other_signers)[0]
    check(r1 == 1 and p1 == 1, 'a WAL checked against the allowed signers of ANOTHER key: rust %d, python %d' % (r1, p1))
    # A copy whose signature of record 1 is replaced by a valid signature of another key (frame check recomputed).
    fr = ev_frames(wal.read_bytes())
    rec1 = next(x for x in fr if x[0] == 1 and int.from_bytes(x[1][:8], 'big') == 1)
    chain_hex = rec1[1][8 + 113:].hex().encode()
    sp = subprocess.run([SSH_KEYGEN, '-Y', 'sign', '-f', str(k), '-n', 'forge-airlock-evidence'], input=chain_hex, capture_output=True)
    check(sp.returncode == 0, 'ssh-keygen -Y sign exit %d' % sp.returncode)
    sig = next(x for x in fr if x[0] == 2 and int.from_bytes(x[1][:8], 'big') == 1)
    sig[1] = sig[1][:8] + sp.stdout
    bad = d / 'resigned.wal'
    bad.write_bytes(ev_build(fr))
    r2, p2 = verify(bad).returncode, verify_py(bad)[0]
    check(r2 == 1 and p2 == 1, 'a WAL with a signature of another key: rust %d, python %d' % (r2, p2))
    return 'other allowed signers: rust %d python %d; re-signed record 1: rust %d python %d' % (r1, p1, r2, p2)


def main():
    bad = [r for r in RESULTS if r[1] != 'PASS']
    print('%d case(s): %d PASS, %d FAIL, %d NOT RUN; temp %s' % (
        len(RESULTS), sum(r[1] == 'PASS' for r in RESULTS), sum(r[1] == 'FAIL' for r in RESULTS),
        sum(r[1] == 'NOT RUN' for r in RESULTS), TMP))
    return 0 if not bad else 1


if __name__ == '__main__':
    sys.exit(main())
