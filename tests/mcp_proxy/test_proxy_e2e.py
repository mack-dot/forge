#!/usr/bin/env python3
"""End-to-end tests: the stdlib MCP client -> mcp-proxy -> the real showcase MCP servers.

FINITE TEST of a NATIVE CHECK. Nothing here is a proof. One line per case: PASS, FAIL or
NOT RUN (a prerequisite case failed). Exit 0 only when every case passes.

The binary is built with the contract's rustc command into a temporary folder, unless
--binary PATH is given. Temporary files go under $MCP_TEST_TMP (default: the system temp dir).

Run: python3 tests/mcp_proxy/test_proxy_e2e.py [--binary build/airlock/mcp-proxy]
"""

import json
import os
from pathlib import Path
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


def start_proxy(name, policy, server_argv, session, facts=None):
    d = TMP / name
    store = d / 'store'
    store.mkdir(parents=True)
    os.chmod(store, 0o700)
    argv = [T['bin'], 'mcp', '--policy', str(policy), '--agent-id', 'agent-%s' % name, '--store', str(store),
            '--key', T['key']]
    if facts:
        argv += ['--facts', str(facts)]
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
    barrier(c)
    check(len(read_lines(T['fin_wire'])) == before + 1, 'rule refusal reached the server')
    check(head(c) == T['fin_head1'], 'a refusal must not move the head')


@case('fintech_duplicate_request_id', needs=('fintech_one_committed_payout',))
def _fin_dup():
    c = T['fin']
    before = len(read_lines(T['fin_wire']))
    # Same forge request id, CURRENT pre-state (so only the idempotency check can refuse it), new JSON-RPC id.
    refusal(payout(c, 'pay-1', T['fin_head1'][1], amount='100.00'), 'BLOCKED_DUPLICATE')
    barrier(c)
    check(len(read_lines(T['fin_wire'])) == before + 1, 'duplicate reached the server')
    check(len(audit(T['fin_audit'])) == 1, 'audit grew')


@case('fintech_cross_tenant_invoice_read_dropped', needs=('fintech_one_committed_payout',))
def _fin_read():
    c = T['fin']
    raw0 = len(c.raw)
    r = c.call_tool('list_invoices', {})
    check(r['result']['isError'] is True and r['result']['content'] == [], 'dropped read %r' % (r,))
    got = bytes(c.raw[raw0:])
    for foreign in (b'Org_Beta', b'INV-B-', b'Legal Services'):
        check(foreign not in got, 'foreign bytes %r reached the client' % foreign)
    r = c.call_tool('list_invoices', {'org_id': 'Org_Alpha'})
    check(r['result']['isError'] is False and len(r['result']['structuredContent']['invoices']) == 2, 'own read %r' % r)


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
        winner = ok[0]['params']['_meta']['forge-airlock/request_id']
        _, cur = head(c)
        retries = [c.make_request('tools/call', {'name': 'issue_payout', 'arguments': {
            'amount': '500.00', 'invoice_id': 'INV-A-1001', 'vendor': 'V'}}, meta=meta(winner, cur)) for _ in range(5)]
        rans = [c.wait(i) for i in c.send_many(retries)]
        check(all(r.get('error', {}).get('data', {}).get('verdict') == 'BLOCKED_DUPLICATE' for r in rans), 'retries %r' % rans)
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


@case('health_cross_clinic_chart_zero_foreign_bytes', needs=('health_start',))
def _hc_cross():
    c = T['hc']
    raw0 = len(c.raw)
    r = c.call_tool('get_patient_chart', {'patient_id': 'PT-B-001'})
    check(r['result']['isError'] is True and r['result']['content'] == [], 'dropped %r' % (r,))
    check('structuredContent' not in r['result'], 'structuredContent leaked')
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
    check('result' in r and r['result']['isError'] is False, 'within-cap answer %r' % (r,))
    st = json.loads(Path(T['hc_state']).read_text())
    meds = {m['medication']: m['mg'] for m in st['patients']['PT-A-001']['medications']}
    check(meds['metoprolol'] == 50 and st['updates_applied'] == 1, 'state %r' % meds)


@case('health_close_exit_0', needs=('health_start',))
def _hc_close():
    code = T['hc'].close()
    check(code == 0, 'proxy exit %d' % code)


# ---------------------------------------------------------------- evidence
def verify(wal):
    # The allowed-signers principal is PRINCIPAL; EVIDENCE's default identity is `forge-airlock`.
    return subprocess.run([T['bin'], 'verify-evidence', str(wal), '--allowed-signers', T['signers'],
                           '--identity', PRINCIPAL],
                          capture_output=True, timeout=300)


for _name, _store_key, _close in (('fintech', 'fin_store', 'fintech_close_exit_0'),
                                  ('race', 'race_store', 'race_20_calls_one_executed_payout'),
                                  ('health', 'hc_store', 'health_close_exit_0')):
    def _v(store_key=_store_key):
        wal = T[store_key] / 'evidence.wal'
        check(wal.is_file() and wal.stat().st_size > 0, 'no evidence.wal')
        p = verify(wal)
        check(p.returncode == 0, 'verify-evidence exit %d: %s' % (p.returncode, (p.stdout + p.stderr).decode('utf-8', 'replace')[-1500:]))
    case('verify_evidence_%s_exit_0' % _name, needs=(_close,))(_v)


@case('verify_evidence_detects_one_flipped_byte', needs=('verify_evidence_fintech_exit_0',))
def _tamper():
    wal = T['fin_store'] / 'evidence.wal'
    data = bytearray(wal.read_bytes())
    bad = TMP / 'tampered.wal'
    data[len(data) // 2] ^= 0x01
    bad.write_bytes(bytes(data))
    p = verify(bad)
    check(p.returncode != 0, 'a flipped byte still verified')


def main():
    bad = [r for r in RESULTS if r[1] != 'PASS']
    print('%d case(s): %d PASS, %d FAIL, %d NOT RUN; temp %s' % (
        len(RESULTS), sum(r[1] == 'PASS' for r in RESULTS), sum(r[1] == 'FAIL' for r in RESULTS),
        sum(r[1] == 'NOT RUN' for r in RESULTS), TMP))
    return 0 if not bad else 1


if __name__ == '__main__':
    sys.exit(main())
