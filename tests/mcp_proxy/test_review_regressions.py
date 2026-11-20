#!/usr/bin/env python3
"""Regression cases for the findings of REVIEW-A, REVIEW-B and the TESTS finding T1 (CONTRACT3, round 3).

FINITE TEST of a NATIVE CHECK (an unproved Rust proxy). Nothing here is a proof. Python 3 stdlib only.

    python3 tests/mcp_proxy/test_review_regressions.py [--binary PATH] [--old-binary PATH] [--expect-defective]
                                                       [--only NAME[,NAME...]]

One case per reproduced finding. Each case is self-contained: it generates what it needs (keys, stores, the
text-mode server wrapper, payloads, forged and crafted evidence files) under a temporary folder
($MCP_TEST_TMP, default: the system temporary folder). It uses the real showcase servers, or the HOSTILE UPSTREAM
TEST DOUBLE `hostile_upstream.py` (a real child process that misbehaves on purpose), and both verifiers: the
proxy's `verify-evidence` and the independent `verify_independent.py`.

One printed line per case: PASS, FAIL, or NOT RUN (the case could not run). Exit 0 only when every case is PASS.

--expect-defective: a CONTROL run against a binary built BEFORE the repairs (for example
`…/scratchpad/orch/mcp-proxy`). Every case here must FAIL on such a binary (a regression test that passes on the
defective binary tests nothing). Exit 0 only when EVERY case is FAIL; a PASS or a NOT RUN gives exit 1.
The comment `PRE-REPAIR:` above each case records its result on `…/scratchpad/orch/mcp-proxy`.

--old-binary: the pre-repair binary, used only by case R2_double_commit_wal_fails_verify to BUILD the reviewer's
double-commit evidence file (default: `…/scratchpad/orch/mcp-proxy`). When it is missing, that case is NOT RUN.

Without --binary the proxy is built with the PROTOCOL.md rustc command into the temporary folder.
"""

import hashlib
import itertools
import json
import os
from pathlib import Path
import re
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
HEALTH = SHOW / 'servers' / 'healthcare_server.py'
FIN_POLICY = SHOW / 'policies' / 'fintech.policy.json'
HC_POLICY = SHOW / 'policies' / 'healthcare.policy.json'
HC_FACTS = SHOW / 'policies' / 'healthcare.facts.json'
HOSTILE = HERE / 'hostile_upstream.py'
VIND = HERE / 'verify_independent.py'
PY = sys.executable
RUSTC = os.environ.get('RUSTC') or shutil.which('rustc') or os.path.expanduser('~/.cargo/bin/rustc')
SSH_KEYGEN = '/usr/bin/ssh-keygen'
PRINCIPAL = 'forge-airlock'
DEFAULT_OLD = '/private/tmp/claude-501/-Users-mackianni-forge/fb0fde47-8987-485d-a625-0e9fdb4facee/scratchpad/orch/mcp-proxy'
GENESIS = hashlib.sha256(b'forge-airlock-ledger-genesis-v1').digest()[:16]
BETA_MARKS = (b'BETA_PHI_MARK', b'Clinic_Beta', b'Beta-One')

# The policy for the hostile upstream: one passthrough tool, one sensitive read.
FAKE_POLICY = {'version': 1, 'tools': {
    'issue_payout': {'kind': 'mutating', 'rules': [{'arg': 'amount', 'max': '500.00'}]},
    'get_patient_chart': {'kind': 'sensitive_read', 'scope': ['clinic_id']},
    'get_balance': {'kind': 'passthrough'}}}

# Text-mode server wrapper (the reader pattern of REVIEW-A R1): the showcase server logic, unchanged, behind
# io.TextIOWrapper iteration with universal newlines, so a raw '\r' also ends a line.
TEXTMODE = r'''
import importlib.util, io, sys
kind, path = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location('srv', path)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
if kind == 'fintech':
    balance, audit, wire = m.parse_args(sys.argv[3:])
    app = m.Fintech(balance, m.AppendLog(audit))
else:
    audit, wire, state = m.parse_args(sys.argv[3:])
    app = m.Healthcare(m.AppendLog(audit), state)
w = m.AppendLog(wire)
out = sys.stdout.buffer
for line in io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8'):
    raw = line.rstrip('\n').encode('utf-8')
    w.line(raw)
    r = m.handle(app, raw)
    if r is not None:
        out.write(m.dumps(r) + b'\n')
        out.flush()
'''


def _j(o):
    return json.dumps(o)


def _txt(o):
    return {'content': [{'type': 'text', 'text': _j(o)}]}


_BETA = {'name': 'Synthetic Patient Beta-One', 'MARK': 'BETA_PHI_MARK'}
# REVIEW-B finding 2: the nine result shapes that leaked (class (b) of the reviewer's payload table), plus one
# own-clinic control that must pass. Each entry is the RAW `result` text that the hostile upstream sends.
B2_PAYLOADS = [
    ('control own label (must pass)', _j(_txt({'clinic_id': 'Clinic_Alpha', 'n': 'ok'}))),
    ("free text 'CLINIC-ID: Clinic_Beta'", _j(_txt({'clinic_id': 'Clinic_Alpha', 'note': 'CLINIC-ID: Clinic_Beta BETA_PHI_MARK'}))),
    ("free text 'clinicId: Clinic_Beta'", _j(_txt({'clinic_id': 'Clinic_Alpha', 'note': 'clinicId: Clinic_Beta BETA_PHI_MARK'}))),
    ('non-strict nested JSON, camelCase key (trailing comma)',
     _j(_txt({'clinic_id': 'Clinic_Alpha', 'note': '{"clinicId":"Clinic_Beta","name":"Synthetic Patient Beta-One","MARK":"BETA_PHI_MARK",}'}))),
    ('nested JSON with duplicate clinicId keys',
     _j(_txt({'clinic_id': 'Clinic_Alpha', 'note': '{"clinicId":"Clinic_Alpha","clinicId":"Clinic_Beta","MARK":"BETA_PHI_MARK"}'}))),
    ('nested JSON, \\u005f-escaped key, trailing text',
     _j(_txt({'clinic_id': 'Clinic_Alpha', 'note': '{"clinic\\u005fid":"Clinic_Beta","MARK":"BETA_PHI_MARK"} end'}))),
    ('nested JSON after a form feed', _j(_txt({'clinic_id': 'Clinic_Alpha', 'note': '\f{"clinicId":"Clinic_Beta","MARK":"BETA_PHI_MARK"}'}))),
    ('foreign record inside an OBJECT KEY, value = session',
     _j(_txt({'clinic_id': 'Clinic_Alpha', _j(dict({'clinic_id': 'Clinic_Beta'}, **_BETA)): 'Clinic_Alpha'}))),
    ("plain text in an OBJECT KEY 'clinic_id=Clinic_Beta'",
     _j(_txt({'clinic_id': 'Clinic_Alpha', 'x': {'clinic_id=Clinic_Beta BETA_PHI_MARK': 'Clinic_Alpha'}}))),
    ('depth 65+ nested JSON text with clinicId',
     _j(_txt({'clinic_id': 'Clinic_Alpha', 'note': '[' * 70 + '{"clinicId":"Clinic_Beta","MARK":"BETA_PHI_MARK"}' + ']' * 70}))),
]

RESULTS = []


class NotRun(Exception):
    pass


def check(cond, msg):
    if not cond:
        raise AssertionError(msg)


def opt(name, default=None):
    if name in sys.argv:
        i = sys.argv.index(name)
        if i + 1 >= len(sys.argv):
            sys.stderr.write('test_review_regressions.py: %s needs a value\n' % name)
            sys.exit(2)
        return sys.argv[i + 1]
    return default


ONLY = set(x for x in (opt('--only') or '').split(',') if x)
T = {}
TMP = Path(tempfile.mkdtemp(prefix='mcp-regress-', dir=os.environ.get('MCP_TEST_TMP'))).resolve()
SEQ = [0]


def case(name):
    def deco(fn):
        if ONLY and name not in ONLY:
            return fn
        t0 = time.monotonic()
        try:
            if 'bin' not in T:
                raise NotRun('setup failed: %s' % T.get('setup_error'))
            note = fn()
            RESULTS.append((name, 'PASS', note or ''))
            print('PASS %s%s (%.1f s)' % (name, ' -- ' + note if note else '', time.monotonic() - t0), flush=True)
        except NotRun as e:
            RESULTS.append((name, 'NOT RUN', str(e)))
            print('NOT RUN %s -- %s' % (name, e), flush=True)
        except Exception as e:
            RESULTS.append((name, 'FAIL', '%s: %s' % (type(e).__name__, e)))
            print('FAIL %s -- %s: %s (%.1f s)' % (name, type(e).__name__, e, time.monotonic() - t0), flush=True)
            traceback.print_exc(file=sys.stderr)
        return fn
    return deco


# ---------------------------------------------------------------- helpers
def new_dir(name):
    SEQ[0] += 1
    d = TMP / ('%02d-%s' % (SEQ[0], name))
    d.mkdir(mode=0o700)
    return d


def new_store(d, name='store'):
    s = d / name
    s.mkdir(mode=0o700)
    os.chmod(s, 0o700)
    return s


def lines_of(path):
    try:
        with open(path, 'rb') as f:
            return f.read().split(b'\n')[:-1]
    except FileNotFoundError:
        return []


def paid(audit):
    return sum(1 for x in lines_of(audit) if json.loads(x).get('tool') == 'issue_payout' and json.loads(x).get('outcome') == 'paid')


def enc(o):
    return json.dumps(o, separators=(',', ':')).encode()


def meta(rid, pre):
    return {'forge-airlock/request_id': rid, 'forge-airlock/pre_state_hash': pre}


def payout_msg(req_id, rid, pre, amount='100.00'):
    return {'jsonrpc': '2.0', 'id': req_id, 'method': 'tools/call',
            'params': {'name': 'issue_payout', 'arguments': {'amount': amount, 'invoice_id': 'INV-A-1001', 'vendor': 'V'},
                       '_meta': meta(rid, pre)}}


def dose_msg(req_id, rid, pre, pid, med, mg):
    return {'jsonrpc': '2.0', 'id': req_id, 'method': 'tools/call',
            'params': {'name': 'update_dosage', 'arguments': {'patient_id': pid, 'medication': med, 'mg': mg},
                       '_meta': meta(rid, pre)}}


def fintech_server(d, tag='fin', textmode=False):
    audit, wire = d / ('%s.audit' % tag), d / ('%s.wire' % tag)
    args = ['--balance', '100000.00', '--audit', str(audit), '--wire-log', str(wire)]
    if textmode:
        return [PY, '-I', T['textmode'], 'fintech', str(FINTECH)] + args, audit, wire
    return [PY, '-I', str(FINTECH)] + args, audit, wire


def health_server(d, tag='hc', textmode=False):
    audit, wire, state = d / ('%s.audit' % tag), d / ('%s.wire' % tag), d / ('%s.state' % tag)
    args = ['--audit', str(audit), '--wire-log', str(wire), '--state', str(state)]
    if textmode:
        return [PY, '-I', T['textmode'], 'health', str(HEALTH)] + args, audit, wire, state
    return [PY, '-I', str(HEALTH)] + args, audit, wire, state


def hostile_server(d, tag='hostile', payloads=None):
    audit, wire = d / ('%s.audit' % tag), d / ('%s.wire' % tag)
    argv = [PY, '-I', str(HOSTILE), '--wire', str(wire), '--audit', str(audit)]
    if payloads is not None:
        pf = d / ('%s.payloads.json' % tag)
        pf.write_text(json.dumps(payloads))
        argv += ['--payloads', str(pf)]
    return argv, audit, wire


def proxy_argv(store, policy, session, server, key=None, facts=None, sign_mode=None, binary=None):
    argv = [binary or T['bin'], 'mcp', '--policy', str(policy), '--agent-id', 'regress', '--store', str(store),
            '--key', str(key or T['key'])]
    if facts:
        argv += ['--facts', str(facts)]
    for kv in session:
        argv += ['--session', kv]
    if sign_mode:
        argv += ['--sign-mode', sign_mode]
    return argv + ['--'] + server


def start(d, argv, tag='p'):
    c = McpClient(argv, cwd=str(ROOT), stderr_path=str(d / ('%s.stderr' % tag)))
    # The client numbers its own requests from 1; the cases here pick small ids by hand. Move the client's own
    # numbers far away so that no two requests of one session share an id.
    c._ids = itertools.count(1000000)
    return c


def head(c):
    r = c.request('forge-airlock/state', {}, timeout=30)
    check('result' in r, 'forge-airlock/state answer %r' % (r,))
    return r['result']['epoch'], r['result']['state']


def state_cmd(store, binary=None):
    p = subprocess.run([binary or T['bin'], 'state', str(store)], capture_output=True, timeout=30)
    check(p.returncode == 0, 'state exit %d: %s' % (p.returncode, p.stderr.decode('utf-8', 'replace')))
    w = dict(x.split('=', 1) for x in p.stdout.decode().split())
    return int(w['epoch']), w['state']


def barrier(c, tag='barrier'):
    T['bid'] = T.get('bid', 0) + 1
    r = c.request('ping', {}, req_id='%s-%d' % (tag, T['bid']), timeout=60)
    check(r.get('result') == {}, 'barrier ping %r' % (r,))


def rust_verify(wal, signers=None, binary=None):
    p = subprocess.run([binary or T['bin'], 'verify-evidence', str(wal), '--allowed-signers', str(signers or T['signers'])],
                       capture_output=True, timeout=900)
    return p.returncode, (p.stdout + p.stderr).decode('utf-8', 'replace')


def py_verify(wal, signers=None, ledger=None):
    argv = [PY, '-I', str(VIND), str(wal), '--allowed-signers', str(signers or T['signers']), '--quiet']
    if ledger:
        argv += ['--ledger', str(ledger)]
    p = subprocess.run(argv, capture_output=True, timeout=900)
    return p.returncode, (p.stdout + p.stderr).decode('utf-8', 'replace')


def both_verify(wal, signers=None):
    """Both verifiers. A disagreement is recorded in T['disagree'] (a finding)."""
    rr, ro = rust_verify(wal, signers)
    pr, po = py_verify(wal, signers)
    if (rr == 0) != (pr == 0):
        T.setdefault('disagree', []).append('%s: rust exit %d, python exit %d' % (wal, rr, pr))
    return rr, pr, ro, po


def startup(argv, timeout=60):
    """Run a proxy with one ping line on stdin. -> (exit code, stdout bytes, stderr text)."""
    p = subprocess.run(argv, input=b'{"jsonrpc":"2.0","id":"s1","method":"ping"}\n', capture_output=True,
                       timeout=timeout, cwd=str(ROOT), start_new_session=True)
    return p.returncode, p.stdout, p.stderr.decode('utf-8', 'replace')


def make_key(d, name, passphrase=''):
    k = d / name
    p = subprocess.run([SSH_KEYGEN, '-q', '-t', 'ed25519', '-N', passphrase, '-C', PRINCIPAL, '-f', str(k)], capture_output=True)
    check(p.returncode == 0, 'ssh-keygen exit %d' % p.returncode)
    os.chmod(k, 0o600)
    return k


def signers_for(pubs, path):
    with open(path, 'w') as f:
        for pub in pubs:
            t = Path(str(pub)).read_text().split()
            f.write('%s namespaces="forge-airlock-evidence" %s %s\n' % (PRINCIPAL, t[0], t[1]))
    return path


# ---- evidence.wal writer (from the format documented at the top of evidence.rs); used to forge and to craft
def ev_frame(t, payload):
    return (bytes([t]) + len(payload).to_bytes(4, 'big') + payload
            + hashlib.sha256(b'forge-airlock-evidence-frame-v1' + bytes([t]) + len(payload).to_bytes(4, 'big') + payload).digest()[:8])


def ev_record(epoch, ts, agent, tool, pre, post, verdict):
    return (epoch.to_bytes(8, 'big') + ts.to_bytes(8, 'big') + agent.encode().ljust(32, b'\0') + tool.encode().ljust(32, b'\0')
            + pre + post + bytes([verdict]))


def ev_frames(data):
    i, out = 30, []
    while i < len(data):
        t, n = data[i], int.from_bytes(data[i + 1:i + 5], 'big')
        out.append((t, data[i + 5:i + 5 + n]))
        i += 5 + n + 8
    return out


def ssh_sign(key, msg):
    p = subprocess.run([SSH_KEYGEN, '-Y', 'sign', '-f', str(key), '-n', 'forge-airlock-evidence'], input=msg,
                       capture_output=True, timeout=60, start_new_session=True)
    check(p.returncode == 0, 'ssh-keygen -Y sign exit %d: %s' % (p.returncode, p.stderr[-200:]))
    return p.stdout


def craft_wal(path, records, key):
    """Write a NEW evidence.wal: R1 S1 R2 S2 ..., each record signed with `key` (a valid signature)."""
    chain = hashlib.sha256(b'forge-airlock-evidence-genesis-v1').digest()
    out = bytearray(b'forge-airlock-evidence-wal-v1\n')
    for i, rec in enumerate(records, 1):
        chain = hashlib.sha256(b'forge-airlock-evidence-v1' + chain + rec).digest()
        out += ev_frame(1, i.to_bytes(8, 'big') + rec + chain)
        out += ev_frame(2, i.to_bytes(8, 'big') + ssh_sign(key, chain.hex().encode()))
    Path(path).write_bytes(bytes(out))


def forge_unsigned(path, n, verdict, pre, post, epoch):
    """REVIEW-B a4: append `n` RECORD frames with no key (the frame check and the chain have no key)."""
    data = Path(path).read_bytes()
    recs = [p for t, p in ev_frames(data) if t == 1]
    chain = recs[-1][8 + 113:] if recs else hashlib.sha256(b'forge-airlock-evidence-genesis-v1').digest()
    with open(path, 'ab') as f:
        for k in range(n):
            idx = len(recs) + 1 + k
            rec = ev_record(epoch, 1, 'attacker-not-the-proxy', 'issue_payout', pre, post, verdict)
            chain = hashlib.sha256(b'forge-airlock-evidence-v1' + chain + rec).digest()
            f.write(ev_frame(1, idx.to_bytes(8, 'big') + rec + chain))


def send_and_collect(c, line, rid=None, timeout=30):
    """Write raw bytes; wait for the answer to `rid` (if given), then a barrier. -> (answer or None, new raw lines
    without the barrier answer)."""
    n0 = len(c.lines)
    c.send_raw(line)
    ans = None
    if rid is not None:
        try:
            ans = c.wait(rid, timeout)
        except McpError:
            ans = None
    barrier(c)
    return ans, [x for x in c.lines[n0:] if b'barrier-' not in x]


def refusal_verdict(r):
    return (r or {}).get('error', {}).get('data', {}).get('verdict')


# ---------------------------------------------------------------- setup
def setup():
    given = opt('--binary')
    if given:
        b = Path(given).resolve()
        if not b.is_file():
            T['setup_error'] = 'no binary at %s' % b
            return
        T['bin'] = str(b)
    else:
        out = TMP / 'mcp-proxy'
        argv = [RUSTC, '--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3', 'src/mcp_proxy/main.rs', '-o', str(out)]
        p = subprocess.run(argv, cwd=ROOT, capture_output=True, timeout=900)
        if p.returncode != 0:
            T['setup_error'] = 'rustc exit %d: %s' % (p.returncode, p.stderr.decode('utf-8', 'replace')[-1500:])
            return
        T['bin'] = str(out)
    kd = TMP / 'key'
    kd.mkdir(mode=0o700)
    T['key'] = str(make_key(kd, 'signing_key'))
    T['signers'] = str(signers_for([kd / 'signing_key.pub'], kd / 'allowed_signers'))
    tm = TMP / 'textmode_server.py'
    tm.write_text(TEXTMODE)
    T['textmode'] = str(tm)
    fp = TMP / 'fault.policy.json'
    fp.write_text(json.dumps(FAKE_POLICY))
    T['fake_policy'] = str(fp)
    old = opt('--old-binary', DEFAULT_OLD)
    T['old'] = old if old and os.path.isfile(old) else None
    print('binary %s; old binary %s; temp %s' % (T['bin'], T['old'], TMP), flush=True)


setup()


# ---------------------------------------------------------------- REVIEW-A R1
# PRE-REPAIR: FAIL (the text-mode fintech server executes the smuggled issue_payout, PAYOUT-0001, ledger epoch 0;
# the smuggled get_patient_chart answer for PT-B-001 reaches the client unfiltered).
@case('R1_cr_smuggle_payout_and_read_textmode')
def _r1():
    smuggled = 'CR-SMUGGLED-VENDOR'
    inner = enc({'jsonrpc': '2.0', 'id': 99, 'method': 'tools/call', 'params': {
        'name': 'issue_payout', 'arguments': {'amount': '500.00', 'invoice_id': 'INV-A-1001', 'vendor': smuggled}}})
    line = b'{"jsonrpc":"2.0","id":1,"method":"ping","params":{"x":\r' + inner + b'\r}}\n'
    json.loads(line)  # one valid JSON value for a strict parser
    d = new_dir('r1-fin')
    store = new_store(d)
    server, audit, wire = fintech_server(d, textmode=True)
    c = start(d, proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server))
    try:
        ans, new = send_and_collect(c, line)
        smug_ans = [x for x in new if b'"id":99' in x]
    finally:
        code = c.close()
    check(paid(audit) == 0, 'FAIL-OPEN: the upstream executed %d smuggled payout(s)' % paid(audit))
    check(not any(smuggled.encode() in x or b'issue_payout' in x for x in lines_of(wire)), 'the smuggled call reached the upstream wire')
    check(len(lines_of(wire)) == 1, 'upstream wire has %d line(s), want only the barrier ping' % len(lines_of(wire)))
    check(state_cmd(store)[0] == 0, 'ledger epoch %d' % state_cmd(store)[0])
    check(not smug_ans, 'the client received an answer for the smuggled id 99: %r' % smug_ans[:1])
    errs = [json.loads(x) for x in new if b'"error"' in x]
    check(len(new) == 1 and len(errs) == 1, 'the CR line got %r, want one refusal' % new[:2])
    # Second half: a smuggled sensitive read (its response id was never pending).
    d = new_dir('r1-hc')
    store = new_store(d)
    server, audit2, wire2, state = health_server(d, textmode=True)
    inner = enc({'jsonrpc': '2.0', 'id': 98, 'method': 'tools/call', 'params': {
        'name': 'get_patient_chart', 'arguments': {'patient_id': 'PT-B-001'}}})
    line = b'{"jsonrpc":"2.0","id":2,"method":"ping","params":{"x":\r' + inner + b'\r}}\n'
    c = start(d, proxy_argv(store, HC_POLICY, ('clinic_id=Clinic_Alpha',), server, facts=HC_FACTS))
    try:
        ans, new2 = send_and_collect(c, line)
        raw = bytes(c.raw)
    finally:
        c.close()
    leaked = [m for m in BETA_MARKS if m in raw]
    check(not leaked, 'smuggled read: foreign bytes %r reached the client' % leaked)
    check(not any(b'get_patient_chart' in x for x in lines_of(wire2)), 'the smuggled read reached the upstream wire')
    check(len(new2) == 1 and b'"error"' in new2[0], 'the smuggled read line got %r, want one refusal' % new2[:2])
    e = errs[0]['error']
    return 'CR line refused (%s %s); 0 payouts, epoch 0, wire = barrier only; smuggled read: refused, 0 foreign bytes; exit %d' % (
        e.get('code'), e.get('data', {}).get('detail'), code)


# ---------------------------------------------------------------- REVIEW-A R2
# PRE-REPAIR: FAIL (run 2 with ledger.wal removed starts, commits the same request id again and pays twice).
@case('R2_ledger_removed_evidence_kept_refuses_start')
def _r2():
    d = new_dir('r2')
    store = new_store(d)
    server, audit, wire = fintech_server(d)
    argv = proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server)
    c = start(d, argv, 'run1')
    try:
        r = c.request('tools/call', payout_msg(1, 'invoice-INV-A-1001-once', GENESIS.hex())['params'], req_id=1)
        check('result' in r, 'run 1 commit %r' % (r,))
    finally:
        c.close()
    check(paid(audit) == 1, 'run 1 payouts %d' % paid(audit))
    os.remove(store / 'ledger.wal')
    w0 = len(lines_of(wire))
    line = enc(payout_msg(1, 'invoice-INV-A-1001-once', GENESIS.hex())) + b'\n'
    p = subprocess.run(argv, input=line, capture_output=True, timeout=60, cwd=str(ROOT))
    check(paid(audit) == 1, 'FAIL-OPEN: %d payouts for ONE request id' % paid(audit))
    check(p.returncode != 0, 'the proxy started on a store whose ledger.wal was removed (exit %d)' % p.returncode)
    check(b'"result"' not in p.stdout, 'a result reached the client: %r' % p.stdout[:200])
    check(len(lines_of(wire)) == w0, 'the upstream received %d line(s)' % (len(lines_of(wire)) - w0))
    # The other half of R2: a shared store folder (mode 0777) with intact files is refused.
    d2 = new_dir('r2-mode')
    store2 = new_store(d2)
    s2, a2, w2 = fintech_server(d2)
    c = start(d2, proxy_argv(store2, FIN_POLICY, ('org_id=Org_Alpha',), s2), 'ok')
    c.request('ping', {})
    c.close()
    os.chmod(store2, 0o777)
    rc, out, err = startup(proxy_argv(store2, FIN_POLICY, ('org_id=Org_Alpha',), s2))
    os.chmod(store2, 0o700)
    check(rc != 0 and b'"result"' not in out, 'a 0777 store folder was accepted (exit %d)' % rc)
    return 'ledger removed: start exit %d (%s); 0777 store: exit %d; payouts 1' % (
        p.returncode, p.stderr.decode('utf-8', 'replace').strip().splitlines()[-1][:90] if p.stderr.strip() else '', rc)


# PRE-REPAIR: FAIL (the pre-repair verify-evidence prints VERIFIED records=2, exit 0, for two COMMITTED epoch 1).
@case('R2_double_commit_wal_fails_verify')
def _r2b():
    if not T['old']:
        raise NotRun('the pre-repair binary is missing (--old-binary); cannot build the double-commit file')
    d = new_dir('r2b')
    store = new_store(d)
    server, audit, wire = fintech_server(d)
    argv = proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server, binary=T['old'])
    for run in (1, 2):
        line = enc(payout_msg(1, 'invoice-INV-A-1001-once', GENESIS.hex())) + b'\n'
        p = subprocess.run(argv, input=line, capture_output=True, timeout=60, cwd=str(ROOT))
        if run == 1:
            os.remove(store / 'ledger.wal')
    if paid(audit) != 2:
        raise NotRun('the pre-repair binary did not reproduce the double commit (payouts %d)' % paid(audit))
    rr, pr, ro, po = both_verify(store / 'evidence.wal')
    check(rr == 1, 'verify-evidence exit %d on the double-commit file: %s' % (rr, ro.strip().splitlines()[-1:]))
    check(pr == 1, 'verify_independent.py exit %d on the double-commit file' % pr)
    return 'built with the pre-repair binary (2 payouts, 2 COMMITTED epoch 1); rust verify exit %d (%s); python exit %d' % (
        rr, [x for x in ro.splitlines() if x.startswith('FAILED')][:1], pr)


# ---------------------------------------------------------------- REVIEW-A R3
# PRE-REPAIR: FAIL (the ledger moves to epoch 1, a COMMITTED receipt is signed, the client gets no answer for id 1).
@case('R3_jsonrpc_1_0_mutating_call_consumes_no_epoch')
def _r3a():
    d = new_dir('r3a')
    store = new_store(d)
    server, audit, wire = fintech_server(d)
    c = start(d, proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server))
    try:
        line = enc(payout_msg(1, 'rid-1', GENESIS.hex())).replace(b'"jsonrpc":"2.0"', b'"jsonrpc":"1.0"') + b'\n'
        n0 = len(c.lines)
        c.send_raw(line)
        barrier(c)
        new = [x for x in c.lines[n0:] if b'barrier-' not in x]
        e, _ = head(c)
    finally:
        code = c.close()
    check(e == 0 and state_cmd(store)[0] == 0, 'epoch %d after a "jsonrpc":"1.0" call' % e)
    check(len(lines_of(wire)) == 1, 'the upstream received %d line(s), want only the barrier' % len(lines_of(wire)))
    check(paid(audit) == 0, 'payouts %d' % paid(audit))
    check(len(new) == 1 and b'"error"' in new[0], 'the client got %r, want one refusal' % new)
    rr, pr, _, _ = both_verify(store / 'evidence.wal')
    check(rr == 0 and pr == 0, 'verify exit rust %d python %d' % (rr, pr))
    return 'refused: %s; epoch 0; wire = barrier only; exit %d' % (new[0][:120].decode('utf-8', 'replace'), code)


# PRE-REPAIR: FAIL (every one of the 4,096 slots leaks; the valid ping and payout get TOO_MANY_IN_FLIGHT).
@case('R3_4096_jsonrpc_1_0_pings_do_not_exhaust_the_session')
def _r3b():
    d = new_dir('r3b')
    store = new_store(d)
    server, audit, wire = fintech_server(d)
    c = start(d, proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server))
    n = 4096
    try:
        t0 = time.monotonic()
        c.send_raw(b''.join(b'{"jsonrpc":"1.0","id":%d,"method":"ping"}\n' % (1000 + i) for i in range(n)))
        r = c.request('ping', {}, req_id='after', timeout=600)
        dt = time.monotonic() - t0
        check(r.get('result') == {}, 'a valid ping after %d "jsonrpc":"1.0" pings: %r' % (n, r))
        _, h = head(c)
        r2 = c.request('tools/call', payout_msg('after2', 'rid-after', h)['params'], req_id='after2', timeout=60)
        check('result' in r2 and r2['result'].get('isError') is False, 'a valid payout after the pings: %r' % (r2,))
    finally:
        code = c.close(timeout=600)
    check(paid(audit) == 1, 'payouts %d' % paid(audit))
    fwd = [x for x in lines_of(wire) if b'"jsonrpc":"1.0"' in x]
    check(not fwd, '%d "jsonrpc":"1.0" line(s) reached the upstream' % len(fwd))
    return '%d pings refused, 0 forwarded; valid ping and payout then work (%.1f s); exit %d' % (n, dt, code)


# PRE-REPAIR: FAIL (the 5,000-digit number is committed at epoch 1; the 65-byte number ping is forwarded).
@case('R3_long_number_refused_before_commit')
def _r3c():
    d = new_dir('r3c')
    store = new_store(d)
    server, audit, wire = fintech_server(d)
    c = start(d, proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server))
    try:
        msg = payout_msg(1, 'big', GENESIS.hex())
        line = enc(msg).replace(b'"forge-airlock/request_id"', b'"n":' + b'9' * 5000 + b',"forge-airlock/request_id"') + b'\n'
        n0 = len(c.lines)
        c.send_raw(line)
        barrier(c)
        new5000 = [x for x in c.lines[n0:] if b'barrier-' not in x]
        e, _ = head(c)
        w1 = len(lines_of(wire))
        # Boundary: 65 digits anywhere is refused, 64 digits passes (a ping is forwarded).
        n1 = len(c.lines)
        c.send_raw(b'{"jsonrpc":"2.0","id":2,"method":"ping","params":{"z":' + b'1' * 65 + b'}}\n')
        barrier(c)
        new65 = [x for x in c.lines[n1:] if b'barrier-' not in x]
        w2 = len(lines_of(wire))
        r64 = c.request('ping', {'z': int('1' * 64)}, req_id=3)
        w3 = len(lines_of(wire))
    finally:
        code = c.close()
    check(e == 0, 'epoch %d after the 5,000-digit line' % e)
    check(w1 == 1, 'the 5,000-digit line reached the upstream (wire %d lines, want the barrier only)' % w1)
    check(len(new5000) == 1 and b'"error"' in new5000[0], 'answer to the 5,000-digit line %r' % [x[:100] for x in new5000])
    check(w2 == w1 + 1, 'the 65-digit ping reached the upstream')
    check(len(new65) == 1 and b'"error"' in new65[0], 'answer to the 65-digit ping %r' % [x[:100] for x in new65])
    check(r64.get('result') == {} and w3 == w2 + 1, 'the 64-digit control ping was not forwarded: %r' % (r64,))
    check(paid(audit) == 0, 'payouts %d' % paid(audit))
    return '5,000 digits: refused, epoch 0, wire +0; 65 digits refused; 64 digits forwarded; exit %d' % code


# ---------------------------------------------------------------- REVIEW-A R4 and REVIEW-B 6
# PRE-REPAIR: FAIL (after the key mode is restored, a payout commits at epoch 2 and is forwarded; exit 0).
@case('R4_B6_key_stops_working_mid_run_sticky_fault')
def _r4():
    d = new_dir('r4')
    key = d / 'k'
    shutil.copy(T['key'], key)
    os.chmod(key, 0o600)
    store = new_store(d)
    server, audit, wire = fintech_server(d)
    c = start(d, proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server, key=key))
    later = []
    try:
        c.initialize()
        _, h = head(c)
        os.chmod(key, 0o640)
        r1 = c.request('tools/call', payout_msg(1, 'r1', h, amount='900.00')['params'], req_id=1)  # policy block, receipt fails
        r2 = c.request('tools/call', payout_msg(2, 'r2', h)['params'], req_id=2)
        later.append(('payout with the key broken', r2))
        os.chmod(key, 0o600)
        _, h2 = head(c)
        r3 = c.request('tools/call', payout_msg(3, 'r3', h2, amount='1.00')['params'], req_id=3)
        later.append(('payout after the key is restored', r3))
        r4 = c.call_tool('get_balance', {}, req_id=4)
        later.append(('passthrough tools/call after the fault', r4))
    finally:
        os.chmod(key, 0o600)
        code = c.close()
    bad = [(what, r) for what, r in later if refusal_verdict(r) != 'EVIDENCE_FAULT']
    check(not bad, 'not refused with EVIDENCE_FAULT: %r' % [(w, json.dumps(r)[:160]) for w, r in bad])
    calls = [x for x in lines_of(wire) if b'tools/call' in x]
    check(not calls, '%d tools/call line(s) reached the upstream after the fault' % len(calls))
    check(paid(audit) == 0, 'payouts %d' % paid(audit))
    check(code == 1, 'proxy exit %r, want 1 after a failed receipt' % code)
    return 'first call: %s; later calls EVIDENCE_FAULT; 0 tools/call upstream; exit %d' % (
        refusal_verdict(r1) or json.dumps(r1)[:80], code)


# PRE-REPAIR: FAIL (both keys start the proxy; every receipt fails; exit 0).
@case('R4_B6_key_that_cannot_sign_refuses_start')
def _r4b():
    d = new_dir('r4b')
    pp = make_key(d, 'passphrase_key', passphrase='secret-passphrase')
    pub = d / 'pub_as_key'
    shutil.copy(T['key'] + '.pub', pub)
    os.chmod(pub, 0o600)
    out = []
    for label, key in (('passphrase key', pp), ('public key as --key', pub)):
        sd = new_dir('r4b-%s' % label.split()[0])
        store = new_store(sd)
        server, audit, wire = fintech_server(sd)
        try:
            rc, so, err = startup(proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server, key=key), timeout=60)
        except subprocess.TimeoutExpired:
            raise AssertionError('%s: the proxy hung for 60 s' % label)
        check(rc != 0, '%s: the proxy started (exit %d)' % (label, rc))
        check(not wire.exists() or not lines_of(wire), '%s: a line reached the upstream' % label)
        check(b'"result"' not in so, '%s: a result reached the client' % label)
        out.append('%s: exit %d' % (label, rc))
    return '; '.join(out)


# ---------------------------------------------------------------- REVIEW-A R7
# PRE-REPAIR: FAIL (the client gets UPSTREAM_GONE "...closed its output before this response", which is false).
@case('R7_over_cap_upstream_line_true_error_text')
def _r7():
    d = new_dir('r7')
    store = new_store(d)
    server, audit, wire = hostile_server(d)
    c = start(d, proxy_argv(store, T['fake_policy'], ('clinic_id=Clinic_Alpha',), server))
    try:
        c.initialize()
        c.send(c.make_request('tools/call', {'name': 'get_balance', 'arguments': {'huge': True}}, req_id=5))
        barrier(c)
        early = c._answers.get(json.dumps(5))
    finally:
        code = c.close()
    ans = c._answers.get(json.dumps(5))
    check(ans is not None, 'no answer for the request whose response was over the cap')
    text = json.dumps(ans)
    check('error' in ans, 'answer %r' % text[:200])
    check('closed its output before this response' not in text, 'false text: %s' % text[:300])
    check(re.search(r'(?i)discard|too.?long|over.{0,20}(cap|limit)|1 ?MiB|1048576', text), 'the text does not say the line was discarded: %s' % text[:300])
    return 'answer %s (%s the upstream closed); exit %d' % (text[:200], 'before' if early else 'after', code)


# ---------------------------------------------------------------- REVIEW-B 1
# PRE-REPAIR: FAIL (the Clinic_Alpha session sets Clinic_Beta warfarin 5 -> 10; updates_applied 1; the client gets
# previous_mg 5 and max_safe_mg 10 of the Beta patient).
@case('B1_alpha_session_cannot_change_beta_dose')
def _b1():
    d = new_dir('b1')
    store = new_store(d)
    server, audit, wire, state = health_server(d)
    c = start(d, proxy_argv(store, HC_POLICY, ('clinic_id=Clinic_Alpha',), server, facts=HC_FACTS))
    try:
        c.initialize()
        e0, h = head(c)
        st0 = state.read_bytes()
        n0 = len(c.raw)
        r = c.request('tools/call', dose_msg(1, 'b1-x', h, 'PT-B-001', 'warfarin', 10)['params'], req_id=1)
        got = bytes(c.raw[n0:])
        barrier(c)
        st1 = state.read_bytes()
        e1, h1 = head(c)
        # Control: an Alpha dose still works.
        r2 = c.request('tools/call', dose_msg(2, 'b1-own', h1, 'PT-A-001', 'metoprolol', 40)['params'], req_id=2)
        e2, _ = head(c)
    finally:
        code = c.close()
    check(st1 == st0, 'FAIL-OPEN: the server state changed (cross-clinic write)')
    check(not any(b'update_dosage' in x and b'PT-B-001' in x for x in lines_of(wire)), 'the Beta update reached the upstream')
    ups = [x for x in lines_of(wire) if b'update_dosage' in x]
    check(len(ups) == 1 and b'PT-A-001' in ups[0], 'update_dosage lines on the wire: %r' % [u[:80] for u in ups])
    check('error' in r and 'SCOPE_BIND' in json.dumps(r['error']), 'not refused with SCOPE_BIND: %r' % json.dumps(r)[:200])
    leaked = [m for m in BETA_MARKS + (b'previous_mg', b'warfarin') if m in got]
    check(not leaked, 'Beta data in the refusal: %r' % leaked)
    check(e1 == e0, 'epoch moved on the refusal')
    st = json.loads(state.read_text())
    meds = {m['medication']: m['mg'] for m in st['patients']['PT-A-001']['medications']}
    check(meds.get('metoprolol') == 40 and st['updates_applied'] == 1 and e2 == e0 + 1, 'Alpha control dose: %r, epoch %d' % (meds, e2))
    check('result' in r2, 'Alpha control answer is a refusal: %r' % json.dumps(r2)[:200])
    return 'Beta dose refused %s; state unchanged; 0 Beta update_dosage lines; Alpha dose applied (answer %s); exit %d' % (
        r['error'].get('data', {}).get('detail'), 'dropped shape' if r2['result'].get('content') == [] else 'passed', code)


# ---------------------------------------------------------------- REVIEW-B 2
# PRE-REPAIR: FAIL (all 9 shapes PASS the filter and the Beta marker reaches the client).
@case('B2_nine_leaking_result_shapes_zero_marker_bytes')
def _b2():
    d = new_dir('b2')
    store = new_store(d)
    server, audit, wire = hostile_server(d, payloads=[p for _, p in B2_PAYLOADS])
    c = start(d, proxy_argv(store, HC_POLICY, ('clinic_id=Clinic_Alpha',), server, facts=HC_FACTS))
    leaks, ctrl = [], None
    try:
        c.initialize()
        for i, (label, _) in enumerate(B2_PAYLOADS):
            n0 = len(c.raw)
            r = c.call_tool('get_patient_chart', {'payload': i}, req_id='b2-%d' % i)
            barrier(c)
            got = bytes(c.raw[n0:])
            if i == 0:
                ctrl = r
                continue
            found = [m.decode() for m in BETA_MARKS if m in got]
            if found:
                leaks.append('%d %s: %s' % (i, label, found))
    finally:
        code = c.close()
    check(ctrl and ctrl.get('result', {}).get('content') and '_meta' not in ctrl['result'], 'the own-clinic control did not pass: %r' % (ctrl,))
    check(not leaks, '%d of 9 shapes leaked: %s' % (len(leaks), '; '.join(leaks)))
    return '9 of 9 shapes: 0 marker bytes at the client; own control passes; exit %d' % code


# ---------------------------------------------------------------- REVIEW-B 3
# PRE-REPAIR: FAIL (the texts differ: "above the fact" vs "fact ... missing"; mg 1 for PT-B-001/warfarin commits).
@case('B3_foreign_refusal_identical_for_any_fact_and_dose')
def _b3():
    d = new_dir('b3')
    store = new_store(d)
    server, audit, wire, state = health_server(d)
    c = start(d, proxy_argv(store, HC_POLICY, ('clinic_id=Clinic_Alpha',), server, facts=HC_FACTS))
    probes = [('PT-B-001', 'warfarin', 99999), ('PT-B-001', 'warfarin', 11), ('PT-B-001', 'insulin', 1),
              ('PT-B-001', 'insulin', 99999), ('PT-B-001', 'sertraline', 5), ('PT-Z-999', 'warfarin', 1),
              ('PT-B-001', 'metoprolol', 50), ('PT-B-001', 'warfarin', 10), ('PT-B-001', 'warfarin', 1)]
    seen = {}
    try:
        c.initialize()
        st0 = state.read_bytes()
        for k, (pid, med, mg) in enumerate(probes):
            _, h = head(c)
            rid = 'b3-%d' % k
            ans, new = send_and_collect(c, enc(dose_msg(rid, 'b3-probe', h, pid, med, mg)) + b'\n', rid=rid)
            mine = [x for x in new if b'"id":"%s"' % rid.encode() in x]
            check(len(mine) == 1, '%s/%s/%s: %d answer line(s)' % (pid, med, mg, len(mine)))
            norm = mine[0].replace(b'"id":"%s"' % rid.encode(), b'"id":<ID>')
            seen.setdefault(norm, []).append('%s/%s/%s' % (pid, med, mg))
    finally:
        code = c.close()
    check(len(seen) == 1, '%d different refusals: %s' % (len(seen), ' || '.join('%s <- %s' % (k[:160].decode('utf-8', 'replace'), v) for k, v in seen.items())))
    only = next(iter(seen))
    check(b'"error"' in only, 'the common answer is not a refusal: %r' % only[:200])
    check(state.read_bytes() == st0, 'the server state changed')
    check(not any(b'update_dosage' in x for x in lines_of(wire)), 'an update_dosage line reached the upstream')
    return '%d probes, 1 byte-identical refusal: %s; exit %d' % (len(probes), only[:160].decode('utf-8', 'replace'), code)


# ---------------------------------------------------------------- REVIEW-B 4
# PRE-REPAIR: FAIL (the next start signs the 3 forged records; verify-evidence then prints VERIFIED records=4).
@case('B4_unsigned_forged_records_not_signed_by_next_start')
def _b4():
    out = []
    for mode in ('sync', 'async'):
        d = new_dir('b4-%s' % mode)
        store = new_store(d)
        server, audit, wire = fintech_server(d)
        argv = proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server, sign_mode=mode)
        p = subprocess.run(argv, input=b'{bad\n', capture_output=True, timeout=60, cwd=str(ROOT))
        check(p.returncode == 0, 'run 1 exit %d' % p.returncode)
        rr, pr, _, _ = both_verify(store / 'evidence.wal')
        check(rr == 0 and pr == 0, 'run 1 evidence does not verify: rust %d python %d' % (rr, pr))
        forge_unsigned(store / 'evidence.wal', 3, 1, b'\xaa' * 16, b'\xbb' * 16, 0)  # 3 unsigned COMMITTED records
        forged = (store / 'evidence.wal').read_bytes()
        rc, so, err = startup(argv)
        after = (store / 'evidence.wal').read_bytes()
        rr, pr, ro, _ = both_verify(store / 'evidence.wal')
        check(rc != 0, '%s: the proxy started on a WAL with 3 unsigned forged COMMITTED records (exit %d)' % (mode, rc))
        check(after == forged, '%s: the refused start changed evidence.wal (%d -> %d bytes)' % (mode, len(forged), len(after)))
        check(rr != 0 and pr != 0, '%s: the forged WAL verifies (rust %d, python %d)' % (mode, rr, pr))
        check(not lines_of(wire), '%s: %d line(s) reached the upstream' % (mode, len(lines_of(wire))))
        out.append('%s: start exit %d, file unchanged, verify rust %d python %d' % (mode, rc, rr, pr))
    return '; '.join(out)


# ---------------------------------------------------------------- REVIEW-B 5
# PRE-REPAIR: FAIL (async: the payout is forwarded and PAID; its signature never reaches the disk).
@case('B5_async_no_paid_payout_without_durable_signature')
def _b5():
    d = new_dir('b5')
    key = d / 'k'
    shutil.copy(T['key'], key)
    os.chmod(key, 0o600)
    store = new_store(d)
    server, audit, wire = fintech_server(d)
    c = start(d, proxy_argv(store, FIN_POLICY, ('org_id=Org_Alpha',), server, key=key, sign_mode='async'))
    try:
        c.initialize()
        _, h = head(c)
        os.chmod(key, 0o644)
        r = c.request('tools/call', payout_msg(1, 'p1', h)['params'], req_id=1)
    finally:
        os.chmod(key, 0o600)
        code = c.close()
    check(paid(audit) == 0, 'FAIL-OPEN: %d payout(s) PAID while the signature could not be made' % paid(audit))
    check('error' in r, 'the client got success: %r' % json.dumps(r)[:200])
    check(code == 1, 'proxy exit %r, want 1' % code)
    # Positive side: with a working key, kill -9 right after the success answer; the COMMITTED record must have its
    # signature on disk already.
    d2 = new_dir('b5-kill')
    store2 = new_store(d2)
    s2, a2, w2 = fintech_server(d2)
    c = start(d2, proxy_argv(store2, FIN_POLICY, ('org_id=Org_Alpha',), s2, sign_mode='async'))
    c.initialize()
    _, h = head(c)
    r = c.request('tools/call', payout_msg(1, 'p2', h)['params'], req_id=1)
    os.kill(c.proc.pid, signal.SIGKILL)
    c.proc.wait()
    c.close(timeout=10)
    check('result' in r and paid(a2) == 1, 'async control payout %r' % json.dumps(r)[:200])
    pr, po = py_verify(store2 / 'evidence.wal')
    check(pr == 0, 'after kill -9 right after a paid async commit, the WAL does not verify: %s' % po.strip().splitlines()[-1:])
    return 'key broken: %s, 0 paid, exit %d; kill -9 after a paid async commit: signature on disk (python verify 0)' % (
        refusal_verdict(r) if 'error' in r else 'refused', code)


# ---------------------------------------------------------------- REVIEW-B 8
# PRE-REPAIR: FAIL (the pre-repair verifier accepts all six crafted files: exit 0).
@case('B8_verifier_commit_continuity')
def _b8():
    d = new_dir('b8')
    key = T['key']
    X1 = hashlib.sha256(b'x1').digest()[:16]
    X2 = hashlib.sha256(b'x2').digest()[:16]
    Y = hashlib.sha256(b'y').digest()[:16]
    G = GENESIS

    def R(epoch, pre, post, v, ts=1):
        return ev_record(epoch, ts, 'regress', 'issue_payout', pre, post, v)
    files = {
        'control_continuous': [R(0, G, G, 8), R(1, G, X1, 1), R(1, X1, X1, 2), R(2, X1, X2, 1), R(2, X2, X2, 7)],
        'two_commits_epoch_1': [R(1, G, X1, 1), R(1, G, X2, 1)],
        'epoch_gap_1_to_3': [R(1, G, X1, 1), R(3, X1, X2, 1)],
        'pre_not_previous_post': [R(1, G, X1, 1), R(2, Y, X2, 1)],
        'first_pre_not_genesis': [R(1, Y, X1, 1)],
        'blocked_not_at_head': [R(1, G, X1, 1), R(1, Y, Y, 2)],
        'blocked_wrong_epoch': [R(1, G, X1, 1), R(5, X1, X1, 8)],
    }
    bad = []
    note = []
    for name, recs in files.items():
        p = d / ('%s.wal' % name)
        craft_wal(p, recs, key)
        rr, pr, ro, po = both_verify(p)
        want = 0 if name.startswith('control') else 1
        if rr != want or pr != want:
            bad.append('%s: rust %d python %d (want %d)' % (name, rr, pr, want))
        note.append('%s r%d/p%d' % (name, rr, pr))
    # Trust note: two key lines in the allowed signers file are reported, not failed.
    k2 = make_key(d, 'other')
    two = signers_for([T['key'] + '.pub', str(k2) + '.pub'], d / 'two_signers')
    rr1, o1 = rust_verify(d / 'control_continuous.wal')
    rr2, o2 = rust_verify(d / 'control_continuous.wal', signers=two)
    extra = [x for x in o2.splitlines() if x not in o1.splitlines() and re.search(r'(?i)key', x)]
    if rr2 != 0 or not extra:
        bad.append('two-key allowed signers: rust exit %d, trust note %r' % (rr2, extra[:1]))
    check(not bad, '; '.join(bad))
    return '; '.join(note) + '; two-key note: %s' % extra[0][:80]


# ---------------------------------------------------------------- TESTS T1 and REVIEW-A D1
def hostile_session(name):
    d = new_dir(name)
    store = new_store(d)
    server, audit, wire = hostile_server(d)
    c = start(d, proxy_argv(store, T['fake_policy'], ('clinic_id=Clinic_Alpha',), server))
    c.initialize()
    return c, d, store


def hostile_read(c, rid, mode, mark):
    n0 = len(c.lines)
    c.send(c.make_request('tools/call', {'name': 'get_patient_chart', 'arguments': {'mode': mode, 'mark': mark}}, req_id=rid))
    try:
        c.wait(rid, 20)
    except McpError:
        pass
    barrier(c)
    return [x for x in c.lines[n0:] if b'barrier-' not in x]


# PRE-REPAIR: FAIL (two answers with the read id reach the client; the second carries foreign-clinic data).
@case('T1_second_answer_to_a_read_discarded')
def _t1():
    c, d, store = hostile_session('t1')
    try:
        rid = 41
        new = hostile_read(c, rid, 'twice', 'MARK-TWICE-5d5d')
    finally:
        code = c.close()
    answers = [x for x in new if json.loads(x).get('id') == rid]
    check(len(answers) == 1, '%d answers with the read id reached the client' % len(answers))
    check(not any(b'MARK-TWICE-5d5d' in x or b'Clinic_Beta' in x for x in new), 'foreign bytes reached the client')
    return 'one answer; 0 foreign bytes; exit %d' % code


# PRE-REPAIR: FAIL (the method+result line and the extra top-level member both pass with foreign data).
@case('D1_method_plus_result_and_extra_member_not_passed')
def _d1():
    c, d, store = hostile_session('d1')
    try:
        a = hostile_read(c, 51, 'with_method', 'MARK-METH-9a9a')
        b = hostile_read(c, 52, 'extra_member', 'MARK-EXTRA-3c3c')
    finally:
        code = c.close()
    check(not any(b'MARK-METH-9a9a' in x for x in a), 'the line with method AND result reached the client')
    # Read 51 must get exactly ONE answer (a result, no method). This case does not fix WHICH one: the own answer, or
    # the dropped-read shape (PROTOCOL.md U5 drops pending reads when a line with their id is discarded).
    a51 = [json.loads(x) for x in a if json.loads(x).get('id') == 51]
    check(len(a51) == 1 and 'result' in a51[0] and 'method' not in a51[0], 'read 51 got %r, want exactly one answer' % (a51,))
    r51 = a51[0]['result']
    check(not any(b'MARK-EXTRA-3c3c' in x or b'Clinic_Beta' in x for x in b), 'the response with an extra top-level member reached the client')
    b52 = [json.loads(x) for x in b if json.loads(x).get('id') == 52]
    check(len(b52) == 1 and b52[0].get('result', {}).get('content') == [] and b52[0]['result'].get('isError') is True,
          'read 52 did not get the dropped-read answer: %r' % (b52,))
    return 'method+result: discarded, read 51 got %s; extra member: dropped (%s); exit %d' % (
        'the own answer' if r51.get('content') else 'the dropped-read shape (%s)' % r51.get('_meta', {}).get('forge-airlock/reason'),
        b52[0]['result'].get('_meta', {}).get('forge-airlock/reason'), code)


# ---------------------------------------------------------------- summary
def main():
    counts = {}
    for _, st, _ in RESULTS:
        counts[st] = counts.get(st, 0) + 1
    if T.get('disagree'):
        if '--expect-defective' in sys.argv:
            print('NOTE (expected: a pre-repair verifier has no commit-continuity rule): the Rust and the Python verifier '
                  'disagree on %d file(s)' % len(T['disagree']), flush=True)
        else:
            print('FINDING: the Rust and the Python verifier DISAGREE on: %s' % '; '.join(T['disagree']), flush=True)
    print('%d case(s): %d PASS, %d FAIL, %d NOT RUN; temp %s' % (
        len(RESULTS), counts.get('PASS', 0), counts.get('FAIL', 0), counts.get('NOT RUN', 0), TMP))
    if not RESULTS:
        print('no case ran: %s' % T.get('setup_error'))
        return 2
    if '--expect-defective' in sys.argv:
        ok = all(st == 'FAIL' for _, st, _ in RESULTS)
        print('EXPECT-DEFECTIVE CONTROL: %d of %d case(s) FAIL on this binary; %s' % (
            counts.get('FAIL', 0), len(RESULTS), 'every case fails as it must' if ok else 'NOT every case fails'))
        return 0 if ok else 1
    return 0 if counts.get('PASS', 0) == len(RESULTS) else 1


if __name__ == '__main__':
    sys.exit(main())
