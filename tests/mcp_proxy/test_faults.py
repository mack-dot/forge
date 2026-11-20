#!/usr/bin/env python3
"""Black-box fault tests of the MCP airlock proxy (Python 3 stdlib only).

FINITE TEST of a NATIVE CHECK (an unproved Rust proxy). Nothing here is a proof.

    python3 tests/mcp_proxy/test_faults.py [--binary PATH] [--rounds N] [--seed S]

One printed line per case:
  PASS         the check ran and held;
  FAIL         the check ran and did not hold (or the case crashed);
  NOT RUN      a prerequisite case failed, so this case did not run;
  KNOWN LIMIT  the check ran and the proxy did what PROTOCOL.md documents, but the documented behaviour lets
               data through (it is NOT a protection; it is printed so that nobody reads it as one).
Exit 0 only when no case is FAIL or NOT RUN. Exit 2 for a setup error before any case.

Without --binary the proxy is built with the PROTOCOL.md rustc command into a temporary folder. Temporary files
go under $MCP_TEST_TMP (default: the system temporary folder) and are removed at the end (kept on failure).

Upstream servers used:
  - the real showcase server `examples/archia_mcp_showcase/servers/fintech_server.py` (wire log, audit file);
  - HOSTILE UPSTREAM TEST DOUBLE: the small stdlib script `HOSTILE_UPSTREAM` below, written to a temporary file
    and started as a real child process of the proxy. It misbehaves ON PURPOSE (error objects, 1 MiB lines,
    non-JSON lines, id respellings, double answers, unasked answers, notifications with foreign-clinic data,
    delays, death). It is a test double of a hostile upstream server, not a mock of the proxy.
"""

import hashlib
import json
import os
from pathlib import Path
import random
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import traceback

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from mcp_client import McpClient, McpError  # noqa: E402

SHOW = ROOT / 'examples' / 'archia_mcp_showcase'
FINTECH = SHOW / 'servers' / 'fintech_server.py'
FIN_POLICY = SHOW / 'policies' / 'fintech.policy.json'
PY = sys.executable
RUSTC = os.environ.get('RUSTC') or shutil.which('rustc') or os.path.expanduser('~/.cargo/bin/rustc')
SSH_KEYGEN = '/usr/bin/ssh-keygen'
PRINCIPAL = 'forge-airlock'  # the default --identity of verify-evidence
OWN_CLINIC = 'Clinic_Alpha'

HOSTILE_UPSTREAM = r'''
# HOSTILE UPSTREAM TEST DOUBLE (tests/mcp_proxy/test_faults.py). It misbehaves on purpose. Python 3 stdlib only.
import json, os, sys, time
a = dict(zip(sys.argv[1::2], sys.argv[2::2]))
wire = open(a['--wire'], 'ab')
audit = open(a['--audit'], 'ab')
with open(a['--pidfile'], 'w') as f:
    f.write(str(os.getpid()))
out = sys.stdout.buffer
OWN = {"patient_id": "P-1001", "clinic_id": "Clinic_Alpha", "name": "own"}
def foreign(mark):
    return {"patient_id": "P-2001", "clinic_id": "Clinic_Beta", "name": mark}
def raw(b):
    out.write(b + b"\n"); out.flush()
def send(o):
    raw(json.dumps(o, separators=(",", ":")).encode())
def tr(rec):
    return {"content": [{"type": "text", "text": json.dumps(rec)}], "isError": False}
def log(f, b):
    f.write(b + b"\n"); f.flush(); os.fsync(f.fileno())
for line in sys.stdin.buffer:
    body = line[:-1] if line.endswith(b"\n") else line
    log(wire, body)
    try:
        m = json.loads(body)
    except Exception:
        continue
    if not isinstance(m, dict) or "method" not in m or "id" not in m:
        continue
    i, meth, p = m["id"], m["method"], (m.get("params") or {})
    if meth == "initialize":
        send({"jsonrpc": "2.0", "id": i, "result": {"protocolVersion": p.get("protocolVersion"), "capabilities": {"tools": {}},
              "serverInfo": {"name": "hostile-upstream-test-double", "version": "0"}}})
        continue
    if meth == "ping":
        send({"jsonrpc": "2.0", "id": i, "result": {}}); continue
    if meth != "tools/call":
        send({"jsonrpc": "2.0", "id": i, "error": {"code": -32601, "message": "Method not found"}}); continue
    name, args = p.get("name"), (p.get("arguments") or {})
    if name == "issue_payout":
        log(audit, json.dumps({"tool": name, "request_id": (p.get("_meta") or {}).get("forge-airlock/request_id"), "arguments": args}).encode())
        send({"jsonrpc": "2.0", "id": i, "result": {"content": [{"type": "text", "text": "paid"}], "isError": False}}); continue
    if name == "get_balance":
        if "die" in args:
            out.flush(); os._exit(int(args["die"]))
        send({"jsonrpc": "2.0", "id": i, "result": {"content": [{"type": "text", "text": "{}"}], "isError": False}}); continue
    if name != "get_patient_chart":
        send({"jsonrpc": "2.0", "id": i, "error": {"code": -32602, "message": "unknown tool"}}); continue
    mode, mark = args.get("mode", "own"), args.get("mark", "FOREIGN-MARK")
    I = json.dumps(i).encode()
    own_marked = dict(OWN, name=mark)
    if mode == "own":
        send({"jsonrpc": "2.0", "id": i, "result": tr(own_marked)})
    elif mode == "error":
        send({"jsonrpc": "2.0", "id": i, "error": {"code": -32000, "message": json.dumps(foreign(mark))}})
    elif mode == "huge":
        rec = foreign(mark); rec["pad"] = "x" * (1100 * 1024)
        send({"jsonrpc": "2.0", "id": i, "result": tr(rec)})
    elif mode == "notjson":
        raw(b"NOT JSON " + mark.encode() + b" Clinic_Beta P-2001")
    elif mode == "idspell_foreign":
        raw(b'{"jsonrpc":"2.0","id":' + I + b'.0,"result":' + json.dumps(tr(foreign(mark))).encode() + b"}")
    elif mode == "idspell_own":
        raw(b'{"jsonrpc":"2.0","id":' + I + b'e0,"result":' + json.dumps(tr(own_marked)).encode() + b"}")
    elif mode == "twice":
        send({"jsonrpc": "2.0", "id": i, "result": tr(OWN)})
        send({"jsonrpc": "2.0", "id": i, "result": tr(foreign(mark))})
    elif mode == "unasked":
        send({"jsonrpc": "2.0", "id": 987654321, "result": tr(foreign(mark))})
        send({"jsonrpc": "2.0", "id": i, "result": tr(OWN)})
    elif mode == "notify":
        send({"jsonrpc": "2.0", "method": "notifications/message", "params": {"level": "info", "data": foreign(mark)}})
        send({"jsonrpc": "2.0", "id": i, "result": tr(OWN)})
    elif mode == "with_method":
        send({"jsonrpc": "2.0", "id": i, "method": "x/leak", "result": tr(foreign(mark))})
        send({"jsonrpc": "2.0", "id": i, "result": tr(OWN)})
    elif mode == "delay":
        time.sleep(float(args.get("secs", 1.5)))
        send({"jsonrpc": "2.0", "id": i, "result": tr(own_marked)})
    elif mode == "hold":
        pass
'''

FAKE_POLICY = {'version': 1, 'tools': {
    'issue_payout': {'kind': 'mutating', 'rules': [{'arg': 'amount', 'max': '500.00'}]},
    'get_patient_chart': {'kind': 'sensitive_read', 'scope': ['clinic_id']},
    'get_balance': {'kind': 'passthrough'}}}

RESULTS = []
DONE_OK = set()


def case(name, needs=()):
    """Run the case now. `needs`: names of cases that must have passed (PASS or KNOWN LIMIT)."""
    def deco(fn):
        missing = [n for n in needs if n not in DONE_OK]
        if missing:
            RESULTS.append((name, 'NOT RUN'))
            print('NOT RUN %s -- needs %s' % (name, ', '.join(missing)), flush=True)
            return fn
        t0 = time.monotonic()
        try:
            note = fn()
            dt = time.monotonic() - t0
            if isinstance(note, str) and note.startswith('KNOWN LIMIT'):
                RESULTS.append((name, 'KNOWN LIMIT'))
                DONE_OK.add(name)
                print('KNOWN LIMIT %s -- %s (%.1f s)' % (name, note[len('KNOWN LIMIT'):].lstrip(': '), dt), flush=True)
            else:
                RESULTS.append((name, 'PASS'))
                DONE_OK.add(name)
                print('PASS %s%s (%.1f s)' % (name, ' -- ' + note if note else '', dt), flush=True)
        except Exception as e:
            RESULTS.append((name, 'FAIL'))
            print('FAIL %s -- %s: %s' % (name, type(e).__name__, e), flush=True)
            traceback.print_exc(file=sys.stderr)
        return fn
    return deco


def check(cond, msg):
    if not cond:
        raise AssertionError(msg)


def opt(name, default=None):
    if name in sys.argv:
        i = sys.argv.index(name)
        if i + 1 >= len(sys.argv):
            sys.stderr.write('test_faults.py: %s needs a value\n' % name)
            sys.exit(2)
        return sys.argv[i + 1]
    return default


T = {}
TMP = Path(tempfile.mkdtemp(prefix='mcp-faults-', dir=os.environ.get('MCP_TEST_TMP'))).resolve()
SEQ = [0]


# ---------------------------------------------------------------- helpers
def h16(b):
    return hashlib.sha256(b).digest()[:16]


def framed(parts):
    return b''.join(len(p).to_bytes(4, 'big') + p for p in parts)


GENESIS = h16(b'forge-airlock-ledger-genesis-v1')


def post_hash(pre, epoch, rid, tool, line):
    """Second, independent reading of the state hash documented at the top of ledger.rs."""
    return h16(framed([b'forge-airlock-ledger-v1', pre, epoch.to_bytes(8, 'big'),
                       hashlib.sha256(rid.encode()).digest(), tool.encode(), hashlib.sha256(line).digest()]))


def lines_of(path):
    try:
        with open(path, 'rb') as f:
            return f.read().split(b'\n')[:-1]
    except FileNotFoundError:
        return []


def paid(audit_path):
    n = 0
    for x in lines_of(audit_path):
        r = json.loads(x)
        if r.get('tool') == 'issue_payout' and r.get('outcome', 'paid') == 'paid':
            n += 1
    return n


def new_dir(name):
    SEQ[0] += 1
    d = TMP / ('%02d-%s' % (SEQ[0], name))
    d.mkdir()
    return d


def new_store(d):
    s = d / 'store'
    s.mkdir(mode=0o700)
    return s


def proxy_argv(store, policy, session, server, key=None):
    argv = [T['bin'], 'mcp', '--policy', str(policy), '--agent-id', 'faults', '--store', str(store), '--key', key or T['key']]
    for kv in session:
        argv += ['--session', kv]
    return argv + ['--'] + server


def fintech(d, tag='fin'):
    audit, wire = d / ('%s.audit' % tag), d / ('%s.wire' % tag)
    return [PY, str(FINTECH), '--balance', '1000000.00', '--audit', str(audit), '--wire-log', str(wire)], audit, wire


def hostile(d, tag='hostile'):
    audit, wire, pid = d / ('%s.audit' % tag), d / ('%s.wire' % tag), d / ('%s.pid' % tag)
    return [PY, T['hostile'], '--wire', str(wire), '--audit', str(audit), '--pidfile', str(pid)], audit, wire


def start(d, store, server, policy=None, session=('org_id=Org_Alpha',), tag='p'):
    argv = proxy_argv(store, policy or FIN_POLICY, session, server)
    return McpClient(argv, cwd=str(ROOT), stderr_path=str(d / ('%s.stderr' % tag)))


def head(c):
    r = c.request('forge-airlock/state', {}, timeout=15)
    check('result' in r, 'forge-airlock/state answer %r' % (r,))
    return r['result']['epoch'], r['result']['state']


def state_cmd(store):
    p = subprocess.run([T['bin'], 'state', str(store)], capture_output=True, timeout=30)
    check(p.returncode == 0, 'state exit %d: %s' % (p.returncode, p.stderr.decode('utf-8', 'replace')))
    w = dict(x.split('=', 1) for x in p.stdout.decode().split())
    return int(w['epoch']), w['state']


def verify(wal):
    p = subprocess.run([T['bin'], 'verify-evidence', str(wal), '--allowed-signers', T['signers']], capture_output=True, timeout=600)
    return p.returncode, (p.stdout + p.stderr).decode('utf-8', 'replace')


def barrier(c):
    r = c.request('ping', {}, timeout=15)
    check(r.get('result') == {}, 'ping %r' % (r,))


def payout_msg(rid, pre, req_id, inv='INV-X-1', amount='1.00'):
    return {'jsonrpc': '2.0', 'id': req_id, 'method': 'tools/call',
            'params': {'name': 'issue_payout', 'arguments': {'amount': amount, 'invoice_id': inv, 'vendor': 'Example Vendor (synthetic)'},
                       '_meta': {'forge-airlock/request_id': rid, 'forge-airlock/pre_state_hash': pre}}}


def enc(msg):
    return json.dumps(msg, separators=(',', ':')).encode()


def refusal(r, verdict, detail=None):
    check('error' in r, 'expected a refusal, got %r' % (r,))
    e = r['error']
    check(e.get('code') == -32001 and e.get('message') == 'Airlock Invariant Breach', 'refusal shape %r' % (e,))
    check(e['data']['verdict'] == verdict, 'verdict %r, want %s' % (e['data'].get('verdict'), verdict))
    if detail:
        check(detail in e['data']['detail'], 'detail %r lacks %r' % (e['data']['detail'], detail))
    return e['data']


def children(pid):
    p = subprocess.run(['/usr/bin/pgrep', '-P', str(pid)], capture_output=True, text=True)
    return [int(x) for x in p.stdout.split()]


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def wait_gone(pids, timeout=30.0):
    end = time.monotonic() + timeout
    while any(alive(p) for p in pids):
        check(time.monotonic() < end, 'process(es) %r still alive after %.0f s' % ([p for p in pids if alive(p)], timeout))
        time.sleep(0.02)


def kill9(c):
    """SIGKILL the proxy, then wait until its child processes (the upstream server, a signer) have ended."""
    kids = children(c.proc.pid)
    os.kill(c.proc.pid, signal.SIGKILL)
    c.proc.wait()
    wait_gone(kids)
    c.close(timeout=5)


def startup_refusal(argv, d):
    """Run a proxy that must refuse to start. Returns (exit code, stdout bytes, stderr text)."""
    line = enc(payout_msg('startup-1', GENESIS.hex(), 1)) + b'\n'
    p = subprocess.run(argv, input=line, capture_output=True, timeout=60, cwd=str(ROOT))
    return p.returncode, p.stdout, p.stderr.decode('utf-8', 'replace')


# ---------------------------------------------------------------- setup
@case('setup_build_and_key')
def _setup():
    given = opt('--binary')
    if given:
        b = Path(given).resolve()
        check(b.is_file(), 'no binary at %s' % b)
        T['bin'] = str(b)
    else:
        out = TMP / 'mcp-proxy'
        argv = [RUSTC, '--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3', 'src/mcp_proxy/main.rs', '-o', str(out)]
        p = subprocess.run(argv, cwd=ROOT, capture_output=True, timeout=900)
        check(p.returncode == 0, 'rustc exit %d: %s' % (p.returncode, p.stderr.decode('utf-8', 'replace')[-2000:]))
        T['bin'] = str(out)
    kd = TMP / 'key'
    kd.mkdir(mode=0o700)
    key = kd / 'signing_key'
    p = subprocess.run([SSH_KEYGEN, '-q', '-t', 'ed25519', '-N', '', '-C', PRINCIPAL, '-f', str(key)], capture_output=True)
    check(p.returncode == 0, 'ssh-keygen exit %d' % p.returncode)
    os.chmod(key, 0o600)
    pub = (kd / 'signing_key.pub').read_text().split()
    signers = kd / 'allowed_signers'
    signers.write_text('%s namespaces="forge-airlock-evidence" %s %s\n' % (PRINCIPAL, pub[0], pub[1]))
    T['key'], T['signers'] = str(key), str(signers)
    hp = TMP / 'hostile_upstream_test_double.py'
    hp.write_text(HOSTILE_UPSTREAM)
    T['hostile'] = str(hp)
    fp = TMP / 'fault.policy.json'
    fp.write_text(json.dumps(FAKE_POLICY))
    T['fake_policy'] = str(fp)
    return 'binary %s' % T['bin']


S0 = ('setup_build_and_key',)


# ---------------------------------------------------------------- 1. upstream death
@case('upstream_dies_mid_session', needs=S0)
def _death():
    d = new_dir('death')
    store = new_store(d)
    server, audit, wire = hostile(d)
    c = start(d, store, server, T['fake_policy'], ('clinic_id=%s' % OWN_CLINIC,))
    try:
        c.initialize()
        e0, h0 = head(c)
        # A sensitive read that the upstream never answers, then a passthrough call that makes it exit with code 7.
        c.send(c.make_request('tools/call', {'name': 'get_patient_chart', 'arguments': {'mode': 'hold'}}, req_id=10))
        c.send(c.make_request('tools/call', {'name': 'get_balance', 'arguments': {'die': 7}}, req_id=11))
        r10, r11 = c.wait(10, 15), c.wait(11, 15)
        check(r10.get('result', {}).get('_meta', {}).get('forge-airlock/reason') == 'UPSTREAM_EOF', 'pending read: %r' % (r10,))
        refusal(r11, 'UPSTREAM_GONE')
        w0 = len(lines_of(wire))
        r12 = c.request('tools/call', payout_msg('after-death-1', h0, 12)['params'], req_id=12, timeout=15)
        refusal(r12, 'UPSTREAM_GONE')
        r13 = c.request('tools/call', payout_msg('after-death-2', h0, 13)['params'], req_id=13, timeout=15)
        refusal(r13, 'UPSTREAM_GONE')
        r14 = c.request('ping', {}, req_id=14, timeout=15)
        refusal(r14, 'UPSTREAM_GONE')
        e1, h1 = head(c)
        check((e1, h1) == (e0, h0), 'head moved after death: %r -> %r' % ((e0, h0), (e1, h1)))
        check(state_cmd(store) == (e0, h0), 'state DIR moved: %r' % (state_cmd(store),))
        check(len(lines_of(wire)) == w0 and paid(audit) == 0, 'upstream saw a call after death')
    finally:
        code = c.close()
    check(code == 7, 'proxy exit %r, upstream exit 7' % code)
    rc, out = verify(store / 'evidence.wal')
    check(rc == 0, 'verify-evidence exit %d: %s' % (rc, out[-500:]))
    return 'in-flight read UPSTREAM_EOF, in-flight call UPSTREAM_GONE, 2 payouts refused, epoch stays %d, exit 7' % e0


# ---------------------------------------------------------------- 2. hostile answers to a sensitive read
def read(c, mode, mark, extra=None, wait=True):
    """Send one get_patient_chart with `mode`; wait for its answer and a barrier. Returns the client-side view."""
    T['hid'] += 1
    rid = T['hid']
    n0 = len(c.lines)
    args = {'mode': mode, 'mark': mark}
    args.update(extra or {})
    c.send(c.make_request('tools/call', {'name': 'get_patient_chart', 'arguments': args}, req_id=rid))
    msg = None
    if wait:
        try:
            msg = c.wait(rid, 20)
        except McpError:
            pass
    barrier(c)
    new = c.lines[n0:]
    return {'id': rid, 'msg': msg, 'raw': b'\n'.join(new).decode('utf-8', 'replace'), 'lines': new}


def dropped(r, reason):
    m = r['msg']
    check(m is not None, 'no answer for the read')
    res = m.get('result', {})
    check(res.get('content') == [] and res.get('isError') is True, 'not the dropped-read shape: %r' % (m,))
    got = res.get('_meta', {}).get('forge-airlock/reason')
    check(got == reason, 'reason %r, want %r' % (got, reason))


@case('hostile_session_start', needs=S0)
def _hstart():
    d = new_dir('hostile-reads')
    store = new_store(d)
    server, audit, wire = hostile(d)
    c = start(d, store, server, T['fake_policy'], ('clinic_id=%s' % OWN_CLINIC,))
    c.initialize()
    T['hc'], T['hwire'], T['hstore'] = c, wire, store
    T['hid'] = 100
    r = read(c, 'own', 'OWN-CONTROL-MARK')
    check('OWN-CONTROL-MARK' in r['raw'] and r['msg'] and 'content' in r['msg'].get('result', {}), 'own read did not pass: %r' % (r,))
    return 'control: an own-clinic read passes'


H = ('hostile_session_start',)


@case('read_answered_with_error_object', needs=H)
def _rerr():
    r = read(T['hc'], 'error', 'MARK-ERR-7f3a')
    dropped(r, 'NO_RESULT')
    check('MARK-ERR-7f3a' not in r['raw'] and 'Clinic_Beta' not in r['raw'], 'foreign bytes reached the client')


@case('read_answered_with_result_over_1MiB', needs=H)
def _rhuge():
    r = read(T['hc'], 'huge', 'MARK-HUGE-1c2d')
    dropped(r, 'UPSTREAM_LINE_TOO_LONG')
    check('MARK-HUGE-1c2d' not in r['raw'] and len(''.join(r['raw'])) < 10000, 'bytes of the huge line reached the client')


@case('read_answered_with_non_json_line', needs=H)
def _rnotjson():
    r = read(T['hc'], 'notjson', 'MARK-NJ-88aa')
    dropped(r, 'UPSTREAM_LINE_NOT_A_JSON_OBJECT')
    check('MARK-NJ-88aa' not in r['raw'], 'the non-JSON line reached the client')


@case('read_answered_with_respelled_id_foreign', needs=H)
def _rspell():
    r = read(T['hc'], 'idspell_foreign', 'MARK-SP-0b0b')  # id N answered as N.0 with foreign data
    dropped(r, 'SCOPE')
    check('MARK-SP-0b0b' not in r['raw'], 'foreign bytes reached the client')


@case('read_answered_with_respelled_id_own_passes', needs=H)
def _rspell_own():
    c = T['hc']
    r = read(c, 'idspell_own', 'MARK-SPOWN-4e4e', wait=False)  # the barrier orders it; the client map keys 106e0 apart  # id N answered as Ne0 with own data: matched and filtered
    want = '"id":%de0' % r['id']
    check(any(want.encode() in x and b'MARK-SPOWN-4e4e' in x for x in r['lines']), 'the original own-clinic bytes did not pass: %r' % (r['raw'][:300],))
    return 'U2: original bytes with id %s' % want[5:]


@case('read_answered_twice_second_not_passed', needs=H)
def _rtwice():
    # Requirement (worker contract): the second answer must not reach the client as a second answer to the read.
    # PROTOCOL.md: after the first (allowed) answer the id leaves the in-flight set; U9 then passes "any other
    # response" unchanged. This case checks the requirement, so it FAILS when U9 passes the second answer.
    r = read(T['hc'], 'twice', 'MARK-TWICE-5d5d')
    answers = [x for x in r['lines'] if (b'"id":%d,' % r['id']) in x or (b'"id":%d}' % r['id']) in x]
    check(len(answers) == 1, '%d answers with the read id reached the client; the second one carries foreign-clinic data'
          ' (MARK-TWICE-5d5d present: %s). PROTOCOL.md U9 passes it unfiltered' % (len(answers), 'MARK-TWICE-5d5d' in r['raw']))
    check('MARK-TWICE-5d5d' not in r['raw'], 'foreign bytes reached the client')


@case('read_with_unasked_response_id', needs=H)
def _runasked():
    r = read(T['hc'], 'unasked', 'MARK-UNASKED-6e6e')
    check(r['msg'] and 'content' in r['msg'].get('result', {}) and r['msg']['result']['content'], 'own read was not answered: %r' % (r['msg'],))
    leaked = 'MARK-UNASKED-6e6e' in r['raw']
    check(leaked, 'PROTOCOL.md U9 says pass unchanged, but the unasked response did not reach the client')
    return 'KNOWN LIMIT: a response with an id the client never used (987654321) passes UNFILTERED (U9) with foreign-clinic data'


@case('server_notification_with_foreign_data', needs=H)
def _rnotify():
    r = read(T['hc'], 'notify', 'MARK-NOTE-7f7f')
    check(r['msg'] and r['msg'].get('result', {}).get('content'), 'own read was not answered')
    check('MARK-NOTE-7f7f' in r['raw'], 'PROTOCOL.md U1 says pass unchanged, but the notification did not reach the client')
    return 'KNOWN LIMIT: server notifications are not filtered (PROTOCOL.md U1 and section 8); foreign-clinic data reached the client'


@case('response_with_method_key_and_foreign_result', needs=H)
def _rmethod():
    # A line with the read's id, a `method` AND a `result` is routed as a server request (U1) and passes.
    r = read(T['hc'], 'with_method', 'MARK-METH-9a9a')
    check(r['msg'] and r['msg'].get('result', {}).get('content'), 'own read was not answered')
    check('MARK-METH-9a9a' in r['raw'], 'expected U1 pass-through did not happen')
    return ('KNOWN LIMIT: {"id":<read id>,"method":..,"result":<foreign>} passes unfiltered (U1: it has a method); '
            'a client that reads id+result first would take it as the read answer')


@case('request_id_reused_while_in_flight', needs=H)
def _reuse():
    c = T['hc']
    wire = T['hwire']
    barrier(c)
    w0 = len(lines_of(wire))
    T['hid'] += 1
    rid = T['hid']
    c.send(c.make_request('tools/call', {'name': 'get_patient_chart', 'arguments': {'mode': 'delay', 'secs': 1.5, 'mark': 'MARK-DELAY-1111'}}, req_id=rid))
    n0 = len(c.lines)
    c.send(c.make_request('ping', {}, req_id=rid))           # same id, number
    c.send(c.make_request('ping', {}, req_id=str(rid)))      # same key as a string, on purpose (PROTOCOL 3.1)
    first = c.wait(rid, 20)
    barrier(c)
    msgs = [json.loads(x) for x in c.lines[n0:]]
    refs = [m for m in msgs if 'error' in m]
    check(len(refs) == 2 and all(m['error']['data']['verdict'] == 'BLOCKED_MALFORMED' and m['error']['data']['detail'] == 'ID_IN_FLIGHT' for m in refs),
          'refusals %r' % (refs,))
    check(any('result' in m and m.get('id') == rid for m in msgs), 'the delayed read did not arrive')
    check(len(lines_of(wire)) == w0 + 2, 'wire grew by %d, want 2 (the read and the barrier)' % (len(lines_of(wire)) - w0))
    # After the answer the id is free again (read the raw lines: the client map already holds an answer for rid).
    n1 = len(c.lines)
    c.send(c.make_request('ping', {}, req_id=rid))
    barrier(c)
    again = [json.loads(x) for x in c.lines[n1:-1]]
    check(again == [{'jsonrpc': '2.0', 'id': rid, 'result': {}}], 'id not free after its answer: %r' % (again,))
    return '2 reuses (number and string spelling) refused ID_IN_FLIGHT, 0 bytes upstream; id free after the answer'


@case('hostile_session_close_and_verify', needs=H)
def _hclose():
    code = T['hc'].close()
    check(code == 0, 'proxy exit %d' % code)
    rc, out = verify(T['hstore'] / 'evidence.wal')
    check(rc == 0, 'verify-evidence exit %d: %s' % (rc, out[-500:]))


# ---------------------------------------------------------------- 3. crash safety (kill -9)
@case('kill9_after_committed_call_then_restart', needs=S0)
def _kill_one():
    d = new_dir('kill-one')
    store = new_store(d)
    server, audit, wire = fintech(d)
    c = start(d, store, server, tag='p1')
    c.initialize()
    e0, h0 = head(c)
    check((e0, h0) == (0, GENESIS.hex()), 'genesis %r' % ((e0, h0),))
    msg = payout_msg('crash-1', h0, 50, inv='INV-K-1')
    r = c.request('tools/call', msg['params'], req_id=50, timeout=20)
    check('result' in r and r['result'].get('isError') is False, 'commit answer %r' % (r,))
    kill9(c)
    want = post_hash(GENESIS, 1, 'crash-1', 'issue_payout', enc(msg))
    check(state_cmd(store) == (1, want.hex()), 'head after kill %r, want epoch 1 %s' % (state_cmd(store), want.hex()))
    rc, out = verify(store / 'evidence.wal')
    check(rc == 0, 'verify-evidence right after kill: exit %d: %s' % (rc, out[-400:]))
    c2 = start(d, store, server, tag='p2')
    try:
        c2.initialize()
        check(head(c2) == (1, want.hex()), 'restart head %r' % (head(c2),))
        r = c2.request('tools/call', payout_msg('crash-1', want.hex(), 51, inv='INV-K-1')['params'], req_id=51, timeout=20)
        refusal(r, 'BLOCKED_DUPLICATE')
    finally:
        code = c2.close()
    check(code == 0, 'restart exit %d' % code)
    check(paid(audit) == 1, 'payouts %d, want 1' % paid(audit))
    rc, out = verify(store / 'evidence.wal')
    check(rc == 0, 'verify-evidence after restart: exit %d: %s' % (rc, out[-400:]))
    T['crash_store'] = store


def burst_lines(pre_hex, epoch0, tag, n, id0):
    out, pre = [], bytes.fromhex(pre_hex)
    for i in range(n):
        rid = 'burst-%s-%d' % (tag, i)
        b = enc(payout_msg(rid, pre.hex(), id0 + i, inv='INV-%s-%d' % (tag, i)))
        pre = post_hash(pre, epoch0 + i + 1, rid, 'issue_payout', b)
        out.append(b)
    return out, pre.hex()


@case('burst_200_commits_no_kill_control', needs=S0)
def _burst_control():
    d = new_dir('burst')
    store = new_store(d)
    server, audit, wire = fintech(d)
    c = start(d, store, server, tag='warm')
    try:
        c.initialize()
        e0, h0 = head(c)
        lines, final = burst_lines(h0, e0, 'w', 200, 1000)
        t0 = time.monotonic()
        c.send_raw(b''.join(x + b'\n' for x in lines))
        last = c.wait(1199, 120)
        dt = time.monotonic() - t0
        check('result' in last, 'last burst answer %r' % (last,))
        check(head(c) == (e0 + 200, final), 'head %r, want %r' % (head(c), (e0 + 200, final)))
    finally:
        code = c.close()
    check(code == 0, 'exit %d' % code)
    check(paid(audit) == 200, 'payouts %d' % paid(audit))
    T['burst'] = (d, store, server, audit, dt)
    return '200 pipelined commits in %.2f s (independent Python state hash matches the head)' % dt


@case('kill9_during_burst_rounds', needs=('burst_200_commits_no_kill_control',))
def _burst_kill():
    d, store, server, audit, dt = T['burst']
    rounds = int(opt('--rounds', '10'))
    seed = int(opt('--seed', str(int(time.time()))))
    rng = random.Random(seed)
    report = []
    for r in range(rounds):
        c = start(d, store, server, tag='r%d' % r)
        c.initialize()
        e0, h0 = head(c)
        lines, _ = burst_lines(h0, e0, 'r%d' % r, 200, 10000 * (r + 1))
        delay = rng.uniform(0.0, dt)
        c.send_raw(b''.join(x + b'\n' for x in lines))
        time.sleep(delay)
        kill9(c)
        # Restart on the same store: the ledger opens, the store works, the evidence verifies.
        c2 = start(d, store, server, tag='r%d-restart' % r)
        try:
            c2.initialize()
            e1, h1 = head(c2)
            check(state_cmd(store) == (e1, h1), 'state DIR differs from the proxy head')
            nxt = c2.request('tools/call', payout_msg('after-r%d' % r, h1, 7, inv='INV-after-%d' % r)['params'], req_id=7, timeout=30)
            check('result' in nxt, 'commit after restart: %r' % (nxt,))
            e2, _ = head(c2)
            check(e2 == e1 + 1, 'epoch after restart commit %d, want %d' % (e2, e1 + 1))
        finally:
            code = c2.close()
        check(code == 0, 'round %d restart exit %d' % (r, code))
        rc, out = verify(store / 'evidence.wal')
        check(rc == 0, 'round %d verify-evidence exit %d: %s' % (r, rc, out[-400:]))
        n_paid = paid(audit)
        invs = [json.loads(x)['arguments']['invoice_id'] for x in lines_of(audit) if json.loads(x).get('outcome') == 'paid']
        check(len(invs) == len(set(invs)), 'round %d: an invoice was paid twice' % r)
        check(n_paid <= e2, 'round %d: payouts %d > ledger epoch %d (AT MOST ONCE BROKEN)' % (r, n_paid, e2))
        report.append('r%d kill@%.2fs epoch+%d' % (r, delay, e1 - e0))
    return 'seed %d; %s; final payouts %d <= epoch %d' % (seed, ', '.join(report), paid(audit), state_cmd(store)[0])


# ---------------------------------------------------------------- 4. a second proxy on the same store
@case('second_proxy_same_store_refused', needs=S0)
def _second():
    d = new_dir('second')
    store = new_store(d)
    server, audit, wire = fintech(d, 'a')
    c = start(d, store, server, tag='a')
    try:
        c.initialize()
        e0, h0 = head(c)
        server_b, audit_b, wire_b = fintech(d, 'b')
        rc, out, err = startup_refusal(proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server_b), d)
        check(rc != 0, 'second proxy exit %d' % rc)
        check(out == b'', 'second proxy wrote to stdout: %r' % out[:200])
        check(not wire_b.exists(), 'the second proxy started its upstream server')
        check('lock' in err, 'stderr does not name the lock: %r' % err[-300:])
        r = c.request('tools/call', payout_msg('second-1', h0, 60)['params'], req_id=60, timeout=20)
        check('result' in r and head(c)[0] == e0 + 1, 'first proxy stopped working: %r' % (r,))
    finally:
        code = c.close()
    check(code == 0, 'first proxy exit %d' % code)
    return 'second proxy exit %d: %s' % (rc, err.strip().splitlines()[-1][:120])


# ---------------------------------------------------------------- 5. damaged files at start
def damaged_store(name, which, pos_fn):
    src = T['crash_store']
    d = new_dir(name)
    store = new_store(d)
    for f in ('ledger.wal', 'evidence.wal'):
        shutil.copy2(src / f, store / f)
    p = store / which
    b = bytearray(p.read_bytes())
    pos = pos_fn(len(b))
    b[pos] ^= 0x01
    p.write_bytes(bytes(b))
    return d, store, pos


K = ('kill9_after_committed_call_then_restart',)


@case('ledger_one_flipped_byte_refuses_start', needs=K)
def _flip_ledger():
    out = []
    for label, fn in (('middle', lambda n: n // 2), ('first', lambda n: 0), ('last', lambda n: n - 1)):
        d, store, pos = damaged_store('ledger-flip-%s' % label, 'ledger.wal', fn)
        server, audit, wire = fintech(d)
        rc, so, err = startup_refusal(proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server), d)
        check(rc == 1 and so == b'' and not wire.exists(), '%s byte %d: exit %d, stdout %r, server started %s' % (label, pos, rc, so[:100], wire.exists()))
        sp = subprocess.run([T['bin'], 'state', str(store)], capture_output=True)
        check(sp.returncode != 0, 'state DIR accepted the damaged ledger')
        out.append('%s@%d exit %d' % (label, pos, rc))
    return ', '.join(out)


@case('evidence_one_flipped_byte_at_start', needs=K)
def _flip_evidence():
    # Documented (evidence.rs "Opening an existing file"): every frame check is checked at open; a COMPLETE frame with
    # a bad check refuses the open (start-up fault, exit 1). Only an INCOMPLETE last frame is cut.
    out = []
    for label, fn in (('middle', lambda n: n // 2), ('magic', lambda n: 3), ('last', lambda n: n - 1)):
        d, store, pos = damaged_store('evidence-flip-%s' % label, 'evidence.wal', fn)
        server, audit, wire = fintech(d)
        before = (store / 'evidence.wal').read_bytes()
        rc, so, err = startup_refusal(proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server), d)
        check(rc == 1 and so == b'' and not wire.exists(), '%s byte %d: exit %d, server started %s' % (label, pos, rc, wire.exists()))
        check((store / 'evidence.wal').read_bytes() == before, 'the refused evidence file was changed')
        vr, _ = verify(store / 'evidence.wal')
        check(vr == 1, 'verify-evidence exit %d on the damaged file' % vr)
        out.append('%s@%d start exit %d, verify exit %d, file unchanged' % (label, pos, rc, vr))
    return '; '.join(out)


# ---------------------------------------------------------------- 6. bad key files
@case('bad_key_files_refuse_start', needs=S0)
def _keys():
    out = []
    d = new_dir('keys')
    k644 = d / 'k644'
    shutil.copy(T['key'], k644)
    os.chmod(k644, 0o644)
    link = d / 'klink'
    os.symlink(T['key'], link)
    for label, key in (('mode 0644', k644), ('symlink to a good key', link), ('missing', d / 'nope')):
        sd = new_dir('key-%s' % label.split()[0])
        store = new_store(sd)
        server, audit, wire = fintech(sd)
        argv = proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server, key=str(key))
        rc, so, err = startup_refusal(argv, sd)
        check(rc == 1, '%s: exit %d' % (label, rc))
        check(so == b'' and not wire.exists() and paid(audit) == 0, '%s: something was forwarded' % label)
        check(not (store / 'evidence.wal').exists() or (store / 'evidence.wal').stat().st_size == 0, '%s: evidence written' % label)
        out.append('%s: exit %d' % (label, rc))
    # Control: the same setup with the good key starts.
    sd = new_dir('key-good')
    store = new_store(sd)
    server, audit, wire = fintech(sd)
    c = McpClient(proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server), cwd=str(ROOT), stderr_path=str(sd / 'p.stderr'))
    try:
        c.initialize()
    finally:
        code = c.close()
    check(code == 0 and wire.exists(), 'control with the good key: exit %d' % code)
    return '; '.join(out) + '; control good key: exit 0'


# ---------------------------------------------------------------- 7. spellings of a mutating call
@case('spelling_session_start', needs=S0)
def _sp_start():
    d = new_dir('spell')
    store = new_store(d)
    server, audit, wire = fintech(d)
    c = start(d, store, server)
    c.initialize()
    T['sp'] = (c, audit, wire, store)


SP = ('spelling_session_start',)
SPID = [500]


def probe(make):
    """Send the bytes `make(pre, id)`, then a barrier. Returns the answers and the deltas. A FAIL-OPEN check runs on
    every probe: the server must never execute more payouts than the ledger committed."""
    c, audit, wire = T['sp'][:3]
    barrier(c)
    e0, h0 = head(c)
    w0, a0 = len(lines_of(wire)), paid(audit)
    n0 = len(c.lines)
    SPID[0] += 1
    c.send_raw(make(h0, SPID[0]))
    barrier(c)
    msgs = [json.loads(x) for x in c.lines[n0:-1]]
    e1, _ = head(c)
    res = {'answers': msgs, 'dwire': len(lines_of(wire)) - w0 - 1, 'depoch': e1 - e0, 'dpaid': paid(audit) - a0}
    check(res['dpaid'] <= res['depoch'], 'FAIL-OPEN: %d payout(s) executed with %d ledger commit(s)' % (res['dpaid'], res['depoch']))
    return res


def refused(res, code, detail):
    check(res['dwire'] == 0, 'the server wire log shows %d new line(s)' % res['dwire'])
    check(res['depoch'] == 0, 'epoch moved by %d' % res['depoch'])
    check(len(res['answers']) == 1, 'answers %r' % (res['answers'],))
    e = res['answers'][0].get('error', {})
    check(e.get('code') == code, 'code %r, want %d: %r' % (e.get('code'), code, res['answers']))
    check(detail in e.get('data', {}).get('detail', ''), 'detail %r, want %r' % (e.get('data', {}).get('detail'), detail))
    return 'refused %d %s, wire +0, epoch +0' % (code, e.get('data', {}).get('detail'))


def committed(res):
    check(res['depoch'] == 1 and res['dpaid'] == 1 and res['dwire'] == 1, 'deltas %r' % ({k: v for k, v in res.items() if k != 'answers'},))
    check(len(res['answers']) == 1 and 'result' in res['answers'][0], 'answers %r' % (res['answers'],))
    return 'committed (epoch +1) and then forwarded; server executed it once'


def valid(pre, i, rid=None):
    return payout_msg(rid or 'sp-%d' % i, pre, i, inv='INV-SP-%d' % i)


def no_meta(pre, i):
    m = valid(pre, i)
    del m['params']['_meta']
    return m


def spell(name, make, judge):
    case('spelling_' + name, needs=SP)(lambda: judge(probe(make)))


spell('batch_array', lambda pre, i: b'[' + enc(valid(pre, i)) + b']\n', lambda r: refused(r, -32600, 'BATCH_NOT_SUPPORTED'))
spell('duplicate_method_ping_then_call',
      lambda pre, i: b'{"jsonrpc":"2.0","id":%d,"method":"ping","method":"tools/call",' % i + enc(valid(pre, i))[enc(valid(pre, i)).index(b'"params"'):] + b'\n',
      lambda r: refused(r, -32700, ''))
spell('duplicate_method_call_then_ping',
      lambda pre, i: enc(valid(pre, i))[:-1] + b',"method":"ping"}\n', lambda r: refused(r, -32700, ''))
spell('duplicate_method_escaped_key',
      lambda pre, i: enc(valid(pre, i))[:-1] + b',"meth\\u006fd":"ping"}\n', lambda r: refused(r, -32700, ''))
spell('duplicate_params_key',
      lambda pre, i: enc(valid(pre, i))[:-1] + b',"params":{"name":"get_balance","arguments":{}}}\n', lambda r: refused(r, -32700, ''))
spell('escaped_slash_method_without_meta',
      lambda pre, i: enc(no_meta(pre, i)).replace(b'"tools/call"', b'"tools\\/call"') + b'\n', lambda r: refused(r, -32001, 'META_MISSING'))
spell('escaped_slash_method_valid_meta',
      lambda pre, i: enc(valid(pre, i)).replace(b'"tools/call"', b'"tools\\u002fcall"') + b'\n', committed)
spell('escaped_tool_name_without_meta',
      lambda pre, i: enc(no_meta(pre, i)).replace(b'"issue_payout"', b'"issue\\u005fpayout"') + b'\n', lambda r: refused(r, -32001, 'META_MISSING'))
spell('leading_spaces_without_meta', lambda pre, i: b'   \t' + enc(no_meta(pre, i)) + b'\n', lambda r: refused(r, -32001, 'META_MISSING'))
spell('leading_spaces_valid_meta', lambda pre, i: b'   \t' + enc(valid(pre, i)) + b'\n', committed)
spell('utf8_bom_valid_meta', lambda pre, i: b'\xef\xbb\xbf' + enc(valid(pre, i)) + b'\n', lambda r: refused(r, -32700, ''))
spell('cr_before_lf_without_meta', lambda pre, i: enc(no_meta(pre, i)) + b'\r\n', lambda r: refused(r, -32001, 'META_MISSING'))
spell('cr_before_lf_valid_meta', lambda pre, i: enc(valid(pre, i)) + b'\r\n', committed)
spell('tools_call_notification_no_id',
      lambda pre, i: enc({k: v for k, v in valid(pre, i).items() if k != 'id'}) + b'\n', lambda r: refused(r, -32600, 'TOOLS_CALL_WITHOUT_ID'))
spell('id_null', lambda pre, i: enc(dict(valid(pre, i), id=None)) + b'\n', lambda r: refused(r, -32600, 'BAD_ID'))
spell('id_float_text', lambda pre, i: enc(valid(pre, i)).replace(b'"id":%d' % i, b'"id":%d.0' % i) + b'\n', lambda r: refused(r, -32600, 'BAD_ID'))


def _case_variant(r):
    # PROTOCOL.md C13: a method other than `tools/call` is forwarded unchanged. The real server must not execute it.
    check(r['depoch'] == 0 and r['dpaid'] == 0 and r['dwire'] == 1, 'deltas %r' % ({k: v for k, v in r.items() if k != 'answers'},))
    check(r['answers'] and r['answers'][0].get('error', {}).get('code') == -32601, 'server answer %r' % (r['answers'],))
    return 'forwarded unchanged (C13); fintech_server answered -32601 and executed nothing'


spell('method_case_variant_forwarded_not_executed',
      lambda pre, i: enc(valid(pre, i)).replace(b'"tools/call"', b'"Tools/Call"') + b'\n', _case_variant)


@case('spelling_session_close_and_verify', needs=SP)
def _sp_close():
    c, audit, wire, store = T['sp']
    code = c.close()
    check(code == 0, 'exit %d' % code)
    rc, out = verify(store / 'evidence.wal')
    check(rc == 0, 'verify-evidence exit %d: %s' % (rc, out[-400:]))
    e, _ = state_cmd(store)
    check(paid(audit) <= e, 'payouts %d > epoch %d' % (paid(audit), e))
    return 'payouts %d, epoch %d' % (paid(audit), e)


def main():
    counts = {}
    for _, st in RESULTS:
        counts[st] = counts.get(st, 0) + 1
    bad = counts.get('FAIL', 0) + counts.get('NOT RUN', 0)
    print('%d case(s): %d PASS, %d KNOWN LIMIT, %d FAIL, %d NOT RUN; temp %s' % (
        len(RESULTS), counts.get('PASS', 0), counts.get('KNOWN LIMIT', 0), counts.get('FAIL', 0), counts.get('NOT RUN', 0),
        TMP if bad else '(removed)'))
    for c in ('hc', 'sp'):
        x = T.get(c)
        cl = x[0] if isinstance(x, tuple) else x
        if cl is not None and cl.proc.poll() is None:
            cl.kill()
    if not bad:
        shutil.rmtree(TMP, ignore_errors=True)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
