#!/usr/bin/env python3
"""Direct tests of the two showcase MCP servers, WITHOUT the airlock proxy.

FINITE TEST. One line per case: PASS or FAIL. Exit 0 only when every case passes.
Run: python3 tests/mcp_proxy/test_servers.py
"""

import json
import os
from pathlib import Path
import sys
import tempfile
import traceback

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from mcp_client import McpClient  # noqa: E402

SERVERS = ROOT / 'examples' / 'archia_mcp_showcase' / 'servers'
FINTECH = SERVERS / 'fintech_server.py'
HEALTH = SERVERS / 'healthcare_server.py'
PY = sys.executable

RESULTS = []


def case(fn):
    name = fn.__name__[len('case_'):]
    try:
        fn()
        RESULTS.append((name, True, ''))
        print('PASS %s' % name, flush=True)
    except Exception as e:  # report and go on
        detail = '%s: %s' % (type(e).__name__, e)
        RESULTS.append((name, False, detail))
        print('FAIL %s -- %s' % (name, detail), flush=True)
        traceback.print_exc(file=sys.stderr)
    return fn


def check(cond, msg):
    if not cond:
        raise AssertionError(msg)


def tmpdir():
    return tempfile.mkdtemp(prefix='mcp-servers-', dir=os.environ.get('MCP_TEST_TMP'))


def read_lines(path):
    if not os.path.exists(path):
        return []
    with open(path, 'rb') as f:
        return f.read().split(b'\n')[:-1]


def audit(path):
    return [json.loads(x) for x in read_lines(path)]


def fintech(d, *extra):
    a, w = os.path.join(d, 'audit.jsonl'), os.path.join(d, 'wire.log')
    return McpClient([PY, str(FINTECH), '--audit', a, '--wire-log', w] + list(extra)), a, w


def health(d):
    a, w, s = (os.path.join(d, n) for n in ('audit.jsonl', 'wire.log', 'state.json'))
    return McpClient([PY, str(HEALTH), '--audit', a, '--wire-log', w, '--state', s]), a, w, s


def tool_result(r):
    check('result' in r, 'expected a result, got %r' % (r,))
    res = r['result']
    check(isinstance(res.get('content'), list) and res['content'][0]['type'] == 'text', 'content shape %r' % res)
    check(json.loads(res['content'][0]['text']) == res['structuredContent'], 'text != structuredContent')
    check(isinstance(res.get('isError'), bool), 'isError missing')
    return res


def lifecycle(client, tool_names):
    r = client.initialize()
    res = r['result']
    check(res['protocolVersion'] == '2025-06-18', 'protocolVersion %r' % res.get('protocolVersion'))
    check(res['capabilities'] == {'tools': {}}, 'capabilities %r' % res.get('capabilities'))
    check(isinstance(res['serverInfo'].get('name'), str) and res['serverInfo'].get('version'), 'serverInfo')
    p = client.request('ping')
    check(p.get('result') == {}, 'ping %r' % p)
    t = client.request('tools/list', {})
    tools = t['result']['tools']
    check(sorted(x['name'] for x in tools) == sorted(tool_names), 'tools %r' % [x['name'] for x in tools])
    for x in tools:
        s = x['inputSchema']
        check(s.get('type') == 'object' and isinstance(s.get('properties'), dict), 'inputSchema of %s' % x['name'])
    # notifications/initialized got no answer: exactly 3 answer lines for 3 requests.
    check(len(client.lines) == 3 and not client.other, 'unexpected extra lines %r' % client.lines)


@case
def case_fintech_lifecycle():
    d = tmpdir()
    c, a, w = fintech(d)
    lifecycle(c, ['issue_payout', 'get_balance', 'list_invoices'])
    check(c.close() == 0, 'exit code')
    check(len(read_lines(w)) == 4, 'wire log must hold 4 received lines (3 requests + 1 notification)')
    check(audit(a) == [], 'no tools/call -> empty audit')


@case
def case_healthcare_lifecycle():
    d = tmpdir()
    c, a, w, s = health(d)
    lifecycle(c, ['get_patient_chart', 'update_dosage'])
    check(c.close() == 0, 'exit code')
    check(len(read_lines(w)) == 4, 'wire log line count')
    check(os.path.exists(s), 'state file written at start')


@case
def case_initialize_unknown_version_gets_latest():
    d = tmpdir()
    c, _, _ = fintech(d)
    r = c.request('initialize', {'protocolVersion': '1999-01-01', 'capabilities': {}, 'clientInfo': {'name': 't', 'version': '0'}})
    check(r['result']['protocolVersion'] == '2025-06-18', 'version %r' % r)
    r = c.request('initialize', {'protocolVersion': '2024-11-05', 'capabilities': {}, 'clientInfo': {'name': 't', 'version': '0'}})
    check(r['result']['protocolVersion'] == '2024-11-05', 'supported older version echoed')
    check(c.close() == 0, 'exit code')


@case
def case_jsonrpc_errors():
    d = tmpdir()
    c, a, w = fintech(d)
    c.initialize()
    r = c.request('resources/list', {})
    check(r['error']['code'] == -32601, 'unknown method %r' % r)
    c.send_raw(b'{"jsonrpc":"2.0","id":7,"method":\n')
    o = c.wait_other(1)
    check(o[0]['error']['code'] == -32700 and o[0]['id'] is None, 'parse error %r' % o)
    c.send_raw(b'{"jsonrpc":"2.0","id":8,"id":9,"method":"ping"}\n')
    o = c.wait_other(2)
    check(o[1]['error']['code'] == -32700, 'duplicate key -> parse error %r' % o)
    c.send_raw(b'[{"jsonrpc":"2.0","id":10,"method":"ping"}]\n')
    o = c.wait_other(3)
    check(o[2]['error']['code'] == -32600, 'batch array -> invalid request %r' % o)
    c.send_raw(b'\xff\xfe\n')
    o = c.wait_other(4)
    check(o[3]['error']['code'] == -32700, 'bad UTF-8 -> parse error')
    r = c.call_tool('no_such_tool', {})
    check(r['error']['code'] == -32602, 'unknown tool %r' % r)
    r = c.request('tools/call', {'name': 'get_balance', 'arguments': []})
    check(r['error']['code'] == -32602, 'arguments not an object')
    # the server keeps going after errors
    check(c.request('ping')['result'] == {}, 'ping after errors')
    check(c.close() == 0, 'exit code')
    wl = read_lines(w)
    check(b'{"jsonrpc":"2.0","id":7,"method":' in wl and b'\xff\xfe' in wl, 'wire log holds unparseable lines')
    check(len(wl) == 10, 'wire log: 10 received lines, got %d' % len(wl))
    check(audit(a) == [], 'no executed call')


@case
def case_fintech_bad_arguments():
    d = tmpdir()
    c, a, _ = fintech(d)
    c.initialize()
    bad = [
        {'amount': '10.00', 'invoice_id': 'INV-A-1001'},                                   # missing vendor
        {'amount': 'ten', 'invoice_id': 'INV-A-1001', 'vendor': 'V'},
        {'amount': '-5.00', 'invoice_id': 'INV-A-1001', 'vendor': 'V'},
        {'amount': '0.00', 'invoice_id': 'INV-A-1001', 'vendor': 'V'},
        {'amount': '1.005', 'invoice_id': 'INV-A-1001', 'vendor': 'V'},
        {'amount': True, 'invoice_id': 'INV-A-1001', 'vendor': 'V'},
        {'amount': '1e3', 'invoice_id': 'INV-A-1001', 'vendor': 'V'},
        {'amount': '10.00', 'invoice_id': '', 'vendor': 'V'},
        {'amount': '10.00', 'invoice_id': 'INV-A-1001', 'vendor': 'V', 'extra': 1},
    ]
    for args in bad:
        r = c.call_tool('issue_payout', args)
        check('error' in r and r['error']['code'] == -32602, 'expected -32602 for %r, got %r' % (args, r))
    # a 3-decimal JSON number is refused too (exact Decimal parse, no float rounding)
    c.send_raw(b'{"jsonrpc":"2.0","id":"n1","method":"tools/call","params":{"name":"issue_payout","arguments":{"amount":0.105,"invoice_id":"X","vendor":"V"}}}\n')
    check(c.wait('n1')['error']['code'] == -32602, '0.105 refused')
    b = tool_result(c.call_tool('get_balance', {}))
    check(b['structuredContent']['balance'] == '1000.00', 'balance unchanged %r' % b)
    check(c.close() == 0, 'exit code')
    check([x['tool'] for x in audit(a)] == ['get_balance'], 'bad calls are not executed: %r' % audit(a))


@case
def case_fintech_payout_and_logs():
    d = tmpdir()
    c, a, w = fintech(d)
    c.initialize()
    # a JSON number amount is read as an exact decimal
    c.send_raw(b'{"jsonrpc":"2.0","id":"p1","method":"tools/call","params":{"name":"issue_payout","arguments":{"amount":250.10,"invoice_id":"INV-A-1001","vendor":"Example Paper Supply (synthetic)"}}}\n')
    r = tool_result(c.wait('p1'))
    check(r['isError'] is False and r['structuredContent']['status'] == 'paid', 'paid %r' % r)
    check(r['structuredContent']['balance'] == '749.90', 'balance after %r' % r['structuredContent'])
    r = tool_result(c.call_tool('issue_payout', {'amount': '0.01', 'invoice_id': 'INV-A-1002', 'vendor': 'V'}))
    check(r['structuredContent']['balance'] == '749.89', 'cent-exact %r' % r['structuredContent'])
    check(c.close() == 0, 'exit code')
    au = audit(a)
    check(len(au) == 2 and all(x['outcome'] == 'paid' for x in au), 'audit %r' % au)
    check(au[0]['arguments']['amount'] == '250.10' and au[0]['balance_after'] == '749.90', 'audit fields %r' % au[0])
    wl = read_lines(w)
    check(len(wl) == 4 and b'"id":"p1"' in wl[2], 'wire log holds the raw request line')


@case
def case_fintech_balance_exhaustion_default():
    d = tmpdir()
    c, a, _ = fintech(d)
    c.initialize()
    msgs = [c.make_request('tools/call', {'name': 'issue_payout', 'arguments': {
        'amount': '100.00', 'invoice_id': 'INV-%02d' % i, 'vendor': 'V'}}) for i in range(20)]
    ids = c.send_many(msgs)
    res = [tool_result(c.wait(i)) for i in ids]
    paid = [r for r in res if not r['isError']]
    refused = [r for r in res if r['isError']]
    check(len(paid) == 10 and len(refused) == 10, 'paid %d refused %d' % (len(paid), len(refused)))
    check(all(r['structuredContent']['reason'] == 'insufficient_funds' for r in refused), 'refusal reason')
    check(tool_result(c.call_tool('get_balance', {}))['structuredContent']['balance'] == '0.00', 'balance 0.00')
    check(c.close() == 0, 'exit code')
    au = audit(a)
    check(sum(1 for x in au if x['outcome'] == 'paid') == 10, 'audit paid count')


@case
def case_fintech_race_without_proxy_500():
    """No proxy: 20 pipelined $500 payouts against $500.00 -> the server alone pays exactly one."""
    d = tmpdir()
    c, a, w = fintech(d, '--balance', '500.00')
    c.initialize()
    msgs = [c.make_request('tools/call', {'name': 'issue_payout', 'arguments': {
        'amount': '500.00', 'invoice_id': 'INV-A-1001', 'vendor': 'V'}}) for _ in range(20)]
    ids = c.send_many(msgs)
    res = [tool_result(c.wait(i)) for i in ids]
    check(sum(1 for r in res if not r['isError']) == 1, 'exactly one paid')
    check(c.close() == 0, 'exit code')
    au = audit(a)
    check(len(au) == 20, 'all 20 reached and were executed by the server (no airlock): %d' % len(au))
    check(sum(1 for x in au if x['outcome'] == 'paid') == 1, 'one paid in audit')
    check(len(read_lines(w)) == 22, 'wire log: 2 lifecycle + 20 calls')


@case
def case_fintech_bad_balance_option():
    import subprocess
    p = subprocess.run([PY, str(FINTECH), '--balance', '1.234'], input=b'', capture_output=True)
    check(p.returncode == 2, 'bad --balance exit %d' % p.returncode)


@case
def case_fintech_list_invoices_cross_tenant():
    d = tmpdir()
    c, a, _ = fintech(d)
    c.initialize()
    r = tool_result(c.call_tool('list_invoices', {}))
    orgs = {x['org_id'] for x in r['structuredContent']['invoices']}
    check(orgs == {'Org_Alpha', 'Org_Beta'}, 'naive server returns both organisations: %r' % orgs)
    r = tool_result(c.call_tool('list_invoices', {'org_id': 'Org_Alpha'}))
    orgs = {x['org_id'] for x in r['structuredContent']['invoices']}
    check(orgs == {'Org_Alpha'}, 'filtered %r' % orgs)
    check(c.close() == 0, 'exit code')
    check(len(audit(a)) == 2, 'two executed reads')


@case
def case_healthcare_chart_any_clinic():
    d = tmpdir()
    c, a, _, _ = health(d)
    c.initialize()
    ra = tool_result(c.call_tool('get_patient_chart', {'patient_id': 'PT-A-001'}))
    rb = tool_result(c.call_tool('get_patient_chart', {'patient_id': 'PT-B-001'}))
    check(ra['structuredContent']['clinic_id'] == 'Clinic_Alpha', 'alpha chart')
    check(rb['structuredContent']['clinic_id'] == 'Clinic_Beta', 'naive server returns the Beta chart')
    meds = {m['medication']: m for m in ra['structuredContent']['medications']}
    check(meds['metoprolol'] == {'medication': 'metoprolol', 'mg': 25, 'max_safe_mg': 50}, 'meds %r' % meds)
    ru = tool_result(c.call_tool('get_patient_chart', {'patient_id': 'PT-X-999'}))
    check(ru['isError'] is True, 'unknown patient isError')
    r = c.call_tool('get_patient_chart', {})
    check(r['error']['code'] == -32602, 'missing patient_id -32602')
    check(c.close() == 0, 'exit code')
    check([x['outcome'] for x in audit(a)] == ['ok', 'ok', 'unknown_patient'], 'audit %r' % audit(a))


@case
def case_healthcare_update_dosage_naive():
    d = tmpdir()
    c, a, w, s = health(d)
    c.initialize()
    r = tool_result(c.call_tool('update_dosage', {'patient_id': 'PT-A-001', 'medication': 'metoprolol', 'mg': 500}))
    check(r['isError'] is False and r['structuredContent']['mg'] == 500, 'naive server applies 500 mg %r' % r)
    r = tool_result(c.call_tool('update_dosage', {'patient_id': 'PT-A-003', 'medication': 'metoprolol', 'mg': '37.5'}))
    check(r['structuredContent']['mg'] == '37.5' and r['structuredContent']['previous_mg'] == '12.5', 'decimal dose %r' % r)
    r = tool_result(c.call_tool('update_dosage', {'patient_id': 'PT-A-001', 'medication': 'aspirin', 'mg': 5}))
    check(r['isError'] is True, 'unknown medication isError')
    for bad in ({'patient_id': 'PT-A-001', 'medication': 'metoprolol', 'mg': -1},
                {'patient_id': 'PT-A-001', 'medication': 'metoprolol', 'mg': 0},
                {'patient_id': 'PT-A-001', 'medication': 'metoprolol', 'mg': '1.234'},
                {'patient_id': 'PT-A-001', 'medication': 'metoprolol'},
                {'patient_id': 'PT-A-001', 'medication': 'metoprolol', 'mg': None}):
        r = c.call_tool('update_dosage', bad)
        check(r['error']['code'] == -32602, 'bad dose %r -> %r' % (bad, r))
    check(c.close() == 0, 'exit code')
    st = json.loads(Path(s).read_text())
    check(st['updates_applied'] == 2, 'state updates %r' % st['updates_applied'])
    meds = {m['medication']: m for m in st['patients']['PT-A-001']['medications']}
    check(meds['metoprolol']['mg'] == 500, 'state shows applied dose')
    check([x['outcome'] for x in audit(a)] == ['applied', 'applied', 'unknown_medication'], 'audit')
    check(len(read_lines(w)) == 2 + 3 + 5, 'wire log count')


@case
def case_facts_agree_with_server():
    facts = json.loads((ROOT / 'examples/archia_mcp_showcase/policies/healthcare.facts.json').read_text())
    d = tmpdir()
    c, _, _, s = health(d)
    check(c.close() == 0, 'exit code')
    st = json.loads(Path(s).read_text())
    want = {}
    for pid, chart in st['patients'].items():
        for m in chart['medications']:
            want['max_mg/%s/%s' % (pid, m['medication'])] = str(m['max_safe_mg'])
    got = {k: str(v) for k, v in facts.items()}
    check(got == want, 'facts %r != server %r' % (got, want))


@case
def case_eof_exit_zero_both():
    import subprocess
    for srv in (FINTECH, HEALTH):
        p = subprocess.run([PY, str(srv)], input=b'{"jsonrpc":"2.0","id":1,"method":"ping"}\n', capture_output=True, timeout=30)
        check(p.returncode == 0, '%s exit %d' % (srv.name, p.returncode))
        check(p.stdout == b'{"id":1,"jsonrpc":"2.0","result":{}}\n', 'stdout %r' % p.stdout)


def main():
    failed = [r for r in RESULTS if not r[1]]
    print('%d case(s), %d passed, %d failed' % (len(RESULTS), len(RESULTS) - len(failed), len(failed)))
    return 0 if not failed else 1


if __name__ == '__main__':
    sys.exit(main())
