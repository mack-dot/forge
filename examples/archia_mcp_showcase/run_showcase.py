#!/usr/bin/env python3
"""Archia MCP airlock: the live showcase (Phase 3). Python 3 stdlib only.

FINITE TEST of an unproved Rust proxy (NATIVE CHECK). Nothing here is a proof.
Every number on the screen is measured in this run. Every PASS comes from a check that can fail,
computed from witnesses outside the proxy: the upstream server's wire log, audit file and state file,
the bytes that the client received, `ps` samples, and the exit code and output of `verify-evidence`.

  python3 examples/archia_mcp_showcase/run_showcase.py [--binary PATH] [--work DIR] [--json FILE]
          [--flood-gib N] [--no-color] [--no-pause]

Exit code: 0 every check is true; 1 a check is false or a beat broke; 2 setup error.
Wire and limits of the proxy: src/mcp_proxy/PROTOCOL.md. Guide: examples/archia_mcp_showcase/README.md.
"""

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tests' / 'mcp_proxy'))
from mcp_client import McpClient, McpError  # noqa: E402

SERVERS = HERE / 'servers'
FINTECH = SERVERS / 'fintech_server.py'
HEALTH = SERVERS / 'healthcare_server.py'
FIN_POLICY = HERE / 'policies' / 'fintech.policy.json'
HC_POLICY = HERE / 'policies' / 'healthcare.policy.json'
HC_FACTS = HERE / 'policies' / 'healthcare.facts.json'
LAUNCHER = ROOT / 'bin' / 'forge-mcp-proxy'
PY = sys.executable
SSH_KEYGEN = '/usr/bin/ssh-keygen'
PRINCIPAL = 'forge-airlock'          # the default identity of verify-evidence
NAMESPACE = 'forge-airlock-evidence'
RSS_LIMIT_KIB = 5 * 1024             # owner-approved bound: peak RSS of the proxy < 5.0 MiB
MIB = 1 << 20
GIB = 1 << 30
VENDOR = 'Example Paper Supply (synthetic)'

# ------------------------------------------------------------------ terminal output
C = {}


def set_colors(on):
    codes = {'r': '1;97;41', 'g': '1;92', 'red': '1;91', 'y': '1;93', 'c': '1;96', 'm': '1;95', 'b': '1',
             'dim': '2', 'ban': '1;30;46', 'ok': '1;30;42', 'bad': '1;97;41'}
    for k, v in codes.items():
        C[k] = ('\033[%sm' % v) if on else ''
    C['0'] = '\033[0m' if on else ''


def col(key, text):
    return '%s%s%s' % (C[key], text, C['0'])


OUT_LOCK = threading.Lock()


def say(text=''):
    with OUT_LOCK:
        sys.stdout.write(text + '\n')
        sys.stdout.flush()


def banner(title, sub=''):
    say('')
    line = ' %s ' % title
    say(col('ban', line.ljust(78)))
    if sub:
        say(col('dim', '  ' + sub))


def event(tag, key, text):
    say('  %s %s' % (col(key, '%-10s' % tag), text))


# ------------------------------------------------------------------ result store
CHECKS = {}
CHECK_DETAIL = {}
METRICS = {}
BEATS = {}


def check(name, ok, detail=''):
    ok = bool(ok)
    CHECKS[name] = ok
    CHECK_DETAIL[name] = detail
    event('PASS' if ok else 'FAIL', 'g' if ok else 'red', '%s  %s' % (name, col('dim', detail)))
    return ok


class SetupError(Exception):
    pass


class BeatError(Exception):
    pass


# ------------------------------------------------------------------ process bookkeeping
CLIENTS = []
PROCS = []


def children_of(pid):
    try:
        p = subprocess.run(['/usr/bin/pgrep', '-P', str(pid)], capture_output=True, text=True, timeout=5)
        return [int(x) for x in p.stdout.split()]
    except (OSError, subprocess.SubprocessError, ValueError):
        return []


def reap_all():
    """Kill every child that is still alive (and the server children of a proxy). Never raises."""
    for c in CLIENTS:
        try:
            if c.proc.poll() is None:
                kids = children_of(c.proc.pid)
                c.proc.kill()
                c.proc.wait(10)
                for k in kids:
                    try:
                        os.kill(k, 9)
                    except OSError:
                        pass
        except Exception:
            pass
    for p in PROCS:
        try:
            if p.poll() is None:
                p.kill()
                p.wait(10)
        except Exception:
            pass


def client(argv, stderr_path):
    c = McpClient(argv, cwd=str(ROOT), stderr_path=str(stderr_path))
    CLIENTS.append(c)
    return c


def finish(c, what):
    code = c.close()
    if code != 0:
        raise BeatError('%s exited with code %d' % (what, code))
    return code


# ------------------------------------------------------------------ helpers
def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(MIB), b''):
            h.update(chunk)
    return h.hexdigest()


def read_lines(path):
    if not os.path.exists(path):
        return []
    with open(path, 'rb') as f:
        return f.read().split(b'\n')[:-1]


def parsed(lines):
    out = []
    for x in lines:
        try:
            out.append(json.loads(x.decode('utf-8')))
        except (UnicodeDecodeError, ValueError):
            out.append(None)
    return out


def wire_calls(path, tool):
    """Lines that the SERVER received (its wire log) that are tools/call of `tool`."""
    n = 0
    for m in parsed(read_lines(path)):
        if isinstance(m, dict) and m.get('method') == 'tools/call' and isinstance(m.get('params'), dict) \
                and m['params'].get('name') == tool:
            n += 1
    return n


def audit_records(path):
    return [m for m in parsed(read_lines(path)) if isinstance(m, dict)]


def meta(request_id, pre):
    return {'forge-airlock/request_id': request_id, 'forge-airlock/pre_state_hash': pre}


def head(c):
    r = c.request('forge-airlock/state', {})
    res = r.get('result')
    if not isinstance(res, dict) or not isinstance(res.get('state'), str):
        raise BeatError('forge-airlock/state gave %r' % (r,))
    return res['epoch'], res['state']


def barrier(c):
    """A ping through to the server: when it is answered, the server has logged every earlier line."""
    r = c.request('ping', {})
    if r.get('result') != {}:
        raise BeatError('ping gave %r' % (r,))


def verdict_of(answer):
    if 'error' in answer:
        d = answer['error'].get('data') or {}
        return d.get('verdict') or ('JSONRPC_%s' % answer['error'].get('code')), d
    res = answer.get('result') or {}
    m = res.get('_meta') or {}
    if m.get('forge-airlock/verdict'):
        return m['forge-airlock/verdict'], m
    sc = res.get('structuredContent') or {}
    return ('SERVER_ERROR' if res.get('isError') else 'SERVER_OK'), sc


def pct(values, p):
    s = sorted(values)
    k = max(1, math.ceil(p / 100.0 * len(s)))
    return s[k - 1]


def money_cents(text):
    a, _, b = text.partition('.')
    return int(a) * 100 + int((b + '00')[:2])


def fmt_cents(c):
    return '$%s.%02d' % ('{:,}'.format(c // 100), c % 100)


# ------------------------------------------------------------------ setup
class Env:
    pass


def setup(args):
    e = Env()
    if args.work:
        e.work = Path(args.work).resolve()
        if e.work.exists() and any(e.work.iterdir()):
            raise SetupError('--work %s is not empty (a fresh folder is needed)' % e.work)
        e.work.mkdir(parents=True, exist_ok=True)
    else:
        e.work = Path(tempfile.mkdtemp(prefix='archia-showcase-'))
    os.chmod(e.work, 0o700)
    for f in (FINTECH, HEALTH, FIN_POLICY, HC_POLICY, HC_FACTS, LAUNCHER):
        if not f.is_file():
            raise SetupError('missing file %s' % f)
    if not os.path.isfile(SSH_KEYGEN):
        raise SetupError('missing %s' % SSH_KEYGEN)
    if args.binary:
        e.binary = str(Path(args.binary).resolve())
        if not os.path.isfile(e.binary):
            raise SetupError('no proxy binary at %s' % e.binary)
    else:
        rustc = shutil.which('rustc') or '/Users/mackianni/.cargo/bin/rustc'
        e.binary = str(e.work / 'mcp-proxy')
        argv = [rustc, '--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3', 'src/mcp_proxy/main.rs',
                '-o', e.binary]
        say(col('dim', '  building the proxy: %s' % ' '.join(argv)))
        try:
            p = subprocess.run(argv, cwd=str(ROOT), capture_output=True, timeout=900)
        except (OSError, subprocess.SubprocessError) as x:
            raise SetupError('cannot run rustc: %s' % x)
        if p.returncode != 0:
            raise SetupError('rustc exit %d: %s' % (p.returncode, p.stderr.decode('utf-8', 'replace')[-1500:]))
    keys = e.work / 'keys'
    keys.mkdir(mode=0o700)
    e.key = str(keys / 'signing_key')
    p = subprocess.run([SSH_KEYGEN, '-q', '-t', 'ed25519', '-N', '', '-C', PRINCIPAL, '-f', e.key],
                       capture_output=True)
    if p.returncode != 0:
        raise SetupError('ssh-keygen exit %d' % p.returncode)
    os.chmod(e.key, 0o600)
    pub = Path(e.key + '.pub').read_text().split()
    e.signers = str(keys / 'allowed_signers')
    Path(e.signers).write_text('%s namespaces="%s" %s %s\n' % (PRINCIPAL, NAMESPACE, pub[0], pub[1]))
    METRICS['work_dir'] = str(e.work)
    METRICS['binary'] = e.binary
    METRICS['binary_sha256'] = sha256_file(e.binary)
    return e


def start_proxy(e, name, policy, server_argv, session, facts=None):
    d = e.work / name
    store = d / 'store'
    store.mkdir(parents=True)
    os.chmod(store, 0o700)
    argv = [e.binary, 'mcp', '--policy', str(policy), '--agent-id', 'archia-%s' % name, '--store', str(store),
            '--key', e.key, '--sign-mode', 'sync']
    if facts:
        argv += ['--facts', str(facts)]
    for kv in session:
        argv += ['--session', kv]
    argv += ['--'] + server_argv
    c = client(argv, d / 'proxy.stderr')
    c.initialize()
    return c, store


# ------------------------------------------------------------------ layer 01: configuration
def layer_config(e):
    banner('LAYER 01  CONFIGURATION', 'the policy files that the proxy loads, their SHA-256, and the bounds it enforces')
    for p in (FIN_POLICY, HC_POLICY, HC_FACTS):
        say('  %s  %s' % (col('c', '%-34s' % p.relative_to(ROOT)), col('dim', 'sha256 ' + sha256_file(p))))
        METRICS['sha256_' + p.name] = sha256_file(p)
    fin = json.loads(FIN_POLICY.read_text())
    hc = json.loads(HC_POLICY.read_text())
    bounds = []
    for pol in (fin, hc):
        for tool, spec in sorted(pol['tools'].items()):
            kind = spec['kind']
            if kind == 'mutating':
                for r in spec.get('rules', []):
                    bounds.append('%s: %s <= %s (rule; CAS + fresh request id)' % (tool, r['arg'], r['max']))
                for s in spec.get('subcaps', []):
                    bounds.append('%s: %s <= fact %s (sub-cap; facts file; CAS + fresh request id)'
                                  % (tool, s['arg'], s['max_fact']))
                if not spec.get('rules') and not spec.get('subcaps'):
                    bounds.append('%s: CAS + fresh request id' % tool)
            elif kind == 'sensitive_read':
                bounds.append('%s: every returned record must carry %s == session value (scoped read)'
                              % (tool, ', '.join(spec['scope'])))
            else:
                bounds.append('%s: passthrough (no check)' % tool)
    for b in bounds:
        say('  %s %s' % (col('y', 'BOUND'), b))
    has_clearing = 'clearing' in fin or 'clearing' in hc
    say('')
    say('  %s these policies are %s. No clearing check ran in this run.' % (col('y', 'STATUS'),
                                                                          col('red', 'NOT spec-cleared')))
    say('         The bounds above are a %s by an unproved Rust proxy (src/mcp_proxy/policy.rs).'
        % col('b', 'NATIVE CHECK'))
    say(col('dim', '         Why: scripts/spec_clearing.py and src/airlock/py/diff_policy.py clear Goal 20 MONEY'))
    say(col('dim', '         policies with the pinned Dafny; no generator maps this MCP policy format to a Dafny'))
    say(col('dim', '         model, and this run starts no Dafny. A real NO_CHOICE clearing would need that generator,'))
    say(col('dim', '         a clearing subject, and a Dafny verify + audit run of the generated model.'))
    BEATS['config'] = {'policies': [FIN_POLICY.name, HC_POLICY.name], 'facts': HC_FACTS.name,
                       'bounds': bounds, 'clearing': 'NOT_RUN', 'policy_has_clearing_block': has_clearing}


# ------------------------------------------------------------------ beat 1
def race(c, label, calls, pre):
    """20 threads, one call each, all at once. Prints each answer as it arrives. -> list of (rid, verdict, data)."""
    go = threading.Event()
    results = [None] * len(calls)

    def one(i, rid):
        go.wait()
        t0 = time.perf_counter()
        try:
            a = c.call_tool('issue_payout', {'amount': '500.00', 'invoice_id': 'INV-A-1001', 'vendor': VENDOR},
                            meta=meta(rid, pre))
        except McpError as x:
            results[i] = (rid, 'NO_ANSWER', {'detail': str(x)})
            event('ERROR', 'red', '%s %s no answer: %s' % (label, rid, x))
            return
        ms = (time.perf_counter() - t0) * 1000
        v, d = verdict_of(a)
        results[i] = (rid, v, d)
        if v == 'SERVER_OK':
            event('COMMITTED', 'g', '%s %s  pre-state matched -> ledger synced -> FORWARDED -> server: %s %s, '
                  'balance %s  %s' % (label, rid, d.get('status'), d.get('amount'), d.get('balance'),
                                      col('dim', '%.1f ms' % ms)))
        elif v == 'SERVER_ERROR':
            event('SERVER', 'y', '%s %s  forwarded; server refused: %s' % (label, rid, d.get('reason')))
        else:
            event('BLOCKED', 'red', '%s %s  %s at proxy (0 bytes forwarded)  %s'
                  % (label, rid, v, col('dim', '%.1f ms' % ms)))

    ths = [threading.Thread(target=one, args=(i, rid)) for i, rid in enumerate(calls)]
    for t in ths:
        t.start()
    go.set()
    for t in ths:
        t.join(60)
    return results


def control_run(e, name, balance):
    d = e.work / name
    d.mkdir()
    audit, wire = str(d / 'audit.jsonl'), str(d / 'wire.log')
    c = client([PY, str(FINTECH), '--balance', balance, '--audit', audit, '--wire-log', wire], d / 'server.stderr')
    c.initialize()
    calls = ['payout-race-%02d' % i for i in range(1, 21)]
    lock = threading.Lock()
    tally = {'paid': 0, 'refused': 0, 'other': 0}

    def one(rid):
        a = c.call_tool('issue_payout', {'amount': '500.00', 'invoice_id': 'INV-A-1001', 'vendor': VENDOR},
                        meta=meta(rid, '0' * 32))
        v, dd = verdict_of(a)
        with lock:
            if v == 'SERVER_OK' and dd.get('status') == 'paid':
                tally['paid'] += 1
            elif v == 'SERVER_ERROR':
                tally['refused'] += 1
            else:
                tally['other'] += 1

    ths = [threading.Thread(target=one, args=(rid,)) for rid in calls]
    for t in ths:
        t.start()
    for t in ths:
        t.join(60)
    bal = c.call_tool('get_balance', {})['result']['structuredContent']['balance']
    finish(c, 'control server (%s)' % name)
    recs = audit_records(audit)
    paid = [r for r in recs if r.get('tool') == 'issue_payout' and r.get('outcome') == 'paid']
    received = wire_calls(wire, 'issue_payout')
    out = {'start_balance': balance, 'calls_received': received, 'payouts_executed': len(paid),
           'paid_total': fmt_cents(sum(money_cents(r['arguments']['amount']) for r in paid)),
           'refused_by_server': tally['refused'], 'end_balance': bal}
    event('CONTROL', 'm', 'NO proxy, balance $%s: server received %d of 20 calls, EXECUTED %d payouts (%s), '
          'refused %d, end balance $%s' % (balance, received, len(paid), out['paid_total'], tally['refused'], bal))
    return out


def beat1(e):
    banner('BEAT 1  LAYER 02 ENFORCEMENT: THE FINTECH RACE AND RETRY STORM',
           '20 concurrent issue_payout of $500.00 against a $500.00 balance, then 5 retries of the winner')
    d = e.work / 'fintech'
    d.mkdir()
    audit, wire = str(d / 'audit.jsonl'), str(d / 'wire.log')
    server = [PY, str(FINTECH), '--balance', '500.00', '--audit', audit, '--wire-log', wire]
    c, store = start_proxy(e, 'fintech-proxy', FIN_POLICY, server, ['org_id=Org_Alpha'])
    epoch0, pre = head(c)
    say('  pre-state read before the race: epoch %d  %s  (all 20 calls carry it)' % (epoch0, col('c', pre)))
    calls = ['payout-race-%02d' % i for i in range(1, 21)]
    t0 = time.perf_counter()
    res = race(c, 'call', calls, pre)
    METRICS['beat1_race_ms'] = round((time.perf_counter() - t0) * 1000, 1)
    winners = [r for r in res if r and r[1] == 'SERVER_OK']
    cas = [r for r in res if r and r[1] == 'BLOCKED_CAS']
    winner = winners[0][0] if winners else calls[0]
    METRICS['beat1_winner_request_id'] = winner
    epoch1, now = head(c)
    METRICS['beat1_state_after_commit'] = now
    say('  retry storm: 5 retries with the winner\'s request id %s and the CURRENT pre-state %s'
        % (col('c', winner), col('c', now)))
    dups = []
    for i in range(1, 6):
        a = c.call_tool('issue_payout', {'amount': '500.00', 'invoice_id': 'INV-A-1001', 'vendor': VENDOR},
                        meta=meta(winner, now))
        v, dd = verdict_of(a)
        dups.append(v)
        event('BLOCKED' if v.startswith('BLOCKED') else v, 'red' if v.startswith('BLOCKED') else 'y',
              'retry %d %s  %s at proxy (0 bytes forwarded)' % (i, winner, v))
    bal = c.call_tool('get_balance', {})
    balance = bal['result']['structuredContent']['balance']
    barrier(c)
    finish(c, 'fintech proxy')
    say('')
    say(col('b', '  Witnesses on the SERVER side (its own files, not the proxy\'s word):'))
    received = wire_calls(wire, 'issue_payout')
    recs = audit_records(audit)
    paid = [r for r in recs if r.get('tool') == 'issue_payout' and r.get('outcome') == 'paid']
    lost = 50000 - money_cents(balance) - sum(money_cents(r['arguments']['amount']) for r in paid)
    check('beat1_one_commit_through_proxy', len(winners) == 1, '%d of 20 answers were a server payout' % len(winners))
    check('beat1_19_blocked_cas', len(cas) == 19, '%d BLOCKED_CAS answers' % len(cas))
    check('beat1_5_retries_blocked_duplicate', dups == ['BLOCKED_DUPLICATE'] * 5, ','.join(dups))
    check('beat1_server_wire_log_1_payout_call', received == 1, 'wire log: %d issue_payout line(s) received' % received)
    check('beat1_server_audit_1_payout', len(paid) == 1, 'audit file: %d payout(s) executed' % len(paid))
    check('beat1_server_balance_0', balance == '0.00', 'get_balance: $%s' % balance)
    check('beat1_zero_lost', lost == 0, '$500.00 - balance - booked payouts = %s' % fmt_cents(lost))
    say('')
    say(col('b', '  CONTROL (same 20 calls, same server program, NO proxy in front):'))
    ctl500 = control_run(e, 'control-500', '500.00')
    ctl10k = control_run(e, 'control-10000', '10000.00')
    check('beat1_control_500_server_alone_pays_once', ctl500['payouts_executed'] == 1 and ctl500['calls_received'] == 20,
          'the server\'s own balance check stops 19 of 20 (all 20 reached it)')
    check('beat1_control_10000_naive_server_pays_20', ctl10k['payouts_executed'] == 20,
          'without the airlock: %d payouts, %s' % (ctl10k['payouts_executed'], ctl10k['paid_total']))
    BEATS['beat1'] = {
        'proxy': {'calls': 20, 'committed': len(winners), 'blocked_cas': len(cas), 'retries': 5,
                  'retries_blocked_duplicate': dups.count('BLOCKED_DUPLICATE'),
                  'server_wire_issue_payout_lines': received, 'server_audit_payouts': len(paid),
                  'server_balance': balance, 'lost': fmt_cents(lost)},
        'control_no_proxy_500': ctl500, 'control_no_proxy_10000': ctl10k,
    }
    e.stores.append(('beat1', store))


# ------------------------------------------------------------------ beat 2
def beat2(e):
    banner('BEAT 2  LAYER 02 ENFORCEMENT: PHI LEAK AND OVERDOSE ATTACK',
           'session clinic_id=Clinic_Alpha; the agent asks for a Clinic_Beta chart, then a 500 mg dose')
    # Ground truth: the Beta chart taken from the server with NO proxy.
    d0 = e.work / 'direct-ehr'
    d0.mkdir()
    dc = client([PY, str(HEALTH)], d0 / 'server.stderr')
    dc.initialize()
    beta = dc.call_tool('get_patient_chart', {'patient_id': 'PT-B-001'})['result']['structuredContent']
    finish(dc, 'direct healthcare server')
    needles = [beta['name'], str(beta['birth_year']), beta['clinic_id']] + [m['medication'] for m in beta['medications']]
    say('  ground truth (direct call, no proxy): PT-B-001 = %s, born %s, %s, meds %s'
        % (beta['name'], beta['birth_year'], beta['clinic_id'], ', '.join(m['medication'] for m in beta['medications'])))

    d = e.work / 'healthcare'
    d.mkdir()
    audit, wire, state = str(d / 'audit.jsonl'), str(d / 'wire.log'), str(d / 'ehr_state.json')
    server = [PY, str(HEALTH), '--audit', audit, '--wire-log', wire, '--state', state]
    c, store = start_proxy(e, 'healthcare-proxy', HC_POLICY, server, ['clinic_id=Clinic_Alpha'], facts=HC_FACTS)

    # (a) scoped read
    say(col('b', '  (a) cross-clinic read'))
    mark = len(c.raw)
    a = c.call_tool('get_patient_chart', {'patient_id': 'PT-B-001'})
    v, dd = verdict_of(a)
    event('DROPPED' if v == 'READ_DROPPED' else v, 'red' if v == 'READ_DROPPED' else 'y',
          'get_patient_chart PT-B-001 -> %s reason %s; the client got content=%s'
          % (v, dd.get('forge-airlock/reason'), json.dumps(a.get('result', {}).get('content'))))
    ok = c.call_tool('get_patient_chart', {'patient_id': 'PT-A-002'})
    v2, sc2 = verdict_of(ok)
    event('ALLOWED' if v2 == 'SERVER_OK' else v2, 'g' if v2 == 'SERVER_OK' else 'red',
          'get_patient_chart PT-A-002 -> %s, %s, %s' % (sc2.get('clinic_id'), sc2.get('name'),
                                                       'passed unchanged' if v2 == 'SERVER_OK' else v2))
    barrier(c)
    beat_bytes = bytes(c.raw[mark:])
    hits = {n: beat_bytes.count(n.encode('utf-8')) for n in needles}
    phi = sum(hits.values())
    seen = [m for m in parsed(read_lines(wire)) if isinstance(m, dict) and m.get('method') == 'tools/call'
            and (m.get('params') or {}).get('name') == 'get_patient_chart'
            and (m['params'].get('arguments') or {}).get('patient_id') == 'PT-B-001']
    served = [r for r in audit_records(audit) if r.get('tool') == 'get_patient_chart'
              and r.get('arguments', {}).get('patient_id') == 'PT-B-001' and r.get('outcome') == 'ok']
    say('  client bytes in (a): %d; searched for %d Beta values: %s'
        % (len(beat_bytes), len(needles), ', '.join('%s=%d' % (k, n) for k, n in hits.items())))
    check('beat2a_beta_read_dropped', v == 'READ_DROPPED' and dd.get('forge-airlock/reason') == 'SCOPE',
          'verdict %s reason %s' % (v, dd.get('forge-airlock/reason')))
    check('beat2a_zero_phi_bytes_to_client', phi == 0, '%d occurrences of Beta chart values in client bytes' % phi)
    check('beat2a_server_did_answer', len(seen) == 1 and len(served) == 1,
          'wire log: %d request(s) received; audit: %d chart(s) served with clinic %s'
          % (len(seen), len(served), served[0].get('clinic_id') if served else '-'))
    check('beat2a_alpha_read_passes', v2 == 'SERVER_OK' and sc2.get('clinic_id') == 'Clinic_Alpha',
          'PT-A-002 chart reached the client')

    # (b) sub-cap
    say(col('b', '  (b) overdose attack (cap from the airlock\'s facts file %s, NOT from the server)'
            % HC_FACTS.relative_to(ROOT)))
    facts = json.loads(HC_FACTS.read_text())
    fact_key = 'max_mg/PT-A-003/metoprolol'
    say('  fact %s = %s mg' % (col('c', fact_key), facts.get(fact_key)))
    before_state = sha256_file(state)
    _, pre = head(c)
    a = c.call_tool('update_dosage', {'patient_id': 'PT-A-003', 'medication': 'metoprolol', 'mg': 500},
                    meta=meta('dose-overdose-1', pre))
    v3, d3 = verdict_of(a)
    event('BLOCKED' if v3.startswith('BLOCKED') else v3, 'red', 'update_dosage PT-A-003 metoprolol 500 mg -> %s  %s'
          % (v3, col('dim', d3.get('detail', ''))))
    barrier(c)
    upd_after_block = wire_calls(wire, 'update_dosage')
    state_same = sha256_file(state) == before_state
    _, pre = head(c)
    a = c.call_tool('update_dosage', {'patient_id': 'PT-A-003', 'medication': 'metoprolol', 'mg': 25},
                    meta=meta('dose-safe-1', pre))
    v4, d4 = verdict_of(a)
    event('COMMITTED' if v4 == 'SERVER_OK' else v4, 'g' if v4 == 'SERVER_OK' else 'red',
          'update_dosage PT-A-003 metoprolol 25 mg -> server: %s, %s -> %s mg'
          % (d4.get('status'), d4.get('previous_mg'), d4.get('mg')))
    barrier(c)
    finish(c, 'healthcare proxy')
    st = json.loads(Path(state).read_text())
    mg_now = {m['medication']: m['mg'] for m in st['patients']['PT-A-003']['medications']}['metoprolol']
    upd_total = wire_calls(wire, 'update_dosage')
    check('beat2b_500mg_blocked_subcap', v3 == 'BLOCKED_SUBCAP', v3)
    check('beat2b_server_saw_0_update_lines', upd_after_block == 0, 'wire log: %d update_dosage line(s)' % upd_after_block)
    check('beat2b_server_state_unchanged', state_same, 'state file SHA-256 equal before and after the blocked call')
    check('beat2b_25mg_commits', v4 == 'SERVER_OK' and d4.get('status') == 'applied' and mg_now == 25
          and upd_total == 1 and st.get('updates_applied') == 1,
          'state file: metoprolol %s mg, %d update(s) applied' % (mg_now, st.get('updates_applied')))
    BEATS['beat2'] = {
        'a': {'beta_read_verdict': v, 'reason': dd.get('forge-airlock/reason'), 'phi_values_searched': len(needles),
              'phi_occurrences': phi, 'client_bytes': len(beat_bytes), 'server_received_beta_request': len(seen),
              'server_served_beta_chart': len(served), 'alpha_read': v2},
        'b': {'fact': fact_key, 'fact_mg': facts.get(fact_key), 'overdose_verdict': v3,
              'server_update_lines_after_block': upd_after_block, 'state_unchanged': state_same,
              'safe_update': d4.get('status'), 'metoprolol_mg_after': mg_now, 'server_update_lines_total': upd_total},
    }
    e.stores.append(('beat2', store))


# ------------------------------------------------------------------ beat 3
class RssSampler(threading.Thread):
    def __init__(self, pid, period=0.02):
        super().__init__(daemon=True)
        self.pid, self.period = pid, period
        self.samples = []      # RSS in KiB, as `ps -o rss=` prints it
        self.times = []        # perf_counter() when the sample came back
        self.stop = threading.Event()

    def run(self):
        while not self.stop.is_set():
            try:
                p = subprocess.run(['/bin/ps', '-o', 'rss=', '-p', str(self.pid)], capture_output=True, text=True,
                                   timeout=5)
                if p.returncode == 0 and p.stdout.strip():
                    v = int(p.stdout.strip())
                    self.times.append(time.perf_counter())
                    self.samples.append(v)
            except (OSError, subprocess.SubprocessError, ValueError):
                pass
            self.stop.wait(self.period)


def beat3(e, gib):
    banner('BEAT 3  SYSTEMS PARANOIA: %d GiB STREAM FLOOD, THEN THE NEXT COMMIT' % gib,
           'one line of %d GiB with no newline, written in 1 MiB chunks (never held in memory, never on disk)' % gib)
    d = e.work / 'flood'
    d.mkdir()
    audit, wire = str(d / 'audit.jsonl'), str(d / 'wire.log')
    server = [PY, str(FINTECH), '--balance', '1000.00', '--audit', audit, '--wire-log', wire]
    c, store = start_proxy(e, 'flood-proxy', FIN_POLICY, server, ['org_id=Org_Alpha'])
    pid = c.proc.pid
    prefix = b'{"jsonrpc":"2.0","id":"flood","method":"tools/call","params":{"name":"issue_payout","x":"'
    total = gib * GIB
    chunk = memoryview(b'A' * MIB)
    sampler = RssSampler(pid)
    sampler.start()
    time.sleep(0.2)
    others0 = len(c.other)
    tty = sys.stdout.isatty()
    t0 = time.perf_counter()
    sent = 0
    last = t0
    next_gib = GIB
    out = c.proc.stdin
    with c._write_lock:
        out.write(prefix)
        sent = len(prefix)
        while sent < total:
            n = min(MIB, total - sent)
            out.write(chunk[:n])
            sent += n
            now = time.perf_counter()
            if tty and now - last > 0.2:
                last = now
                rate = sent / MIB / (now - t0)
                sys.stdout.write('\r  %s %6.2f / %d GiB  %8.1f MiB/s  rss %s KiB   '
                                 % (col('c', 'FLOOD'), sent / GIB, gib, rate,
                                    sampler.samples[-1] if sampler.samples else '?'))
                sys.stdout.flush()
            elif not tty and sent >= next_gib:
                next_gib += GIB
                say('  %s %d / %d GiB  %.1f MiB/s' % (col('c', 'FLOOD'), sent // GIB, gib, sent / MIB / (now - t0)))
        out.write(b'"}}\n')
        out.flush()
    sent += 4
    if tty:
        sys.stdout.write('\n')
    c.wait_other(others0 + 1, timeout=300)
    t_drain = time.perf_counter() - t0
    sampler.stop.set()
    sampler.join(10)
    flood_answer = c.other[others0]
    fv = (flood_answer.get('error') or {}).get('data', {}).get('verdict') if isinstance(flood_answer, dict) else None
    fdetail = (flood_answer.get('error') or {}).get('data', {}).get('detail') if isinstance(flood_answer, dict) else None
    fcode = (flood_answer.get('error') or {}).get('code') if isinstance(flood_answer, dict) else None
    peak = max(sampler.samples) if sampler.samples else None
    during = sum(1 for t in sampler.times if t0 <= t <= t0 + t_drain)
    say('  proxy answer to the flood line: code %s verdict %s detail %s' % (fcode, fv, fdetail))
    say('  drain %.2f s, %.1f MiB/s, %d bytes; peak RSS of the proxy %s KiB (%.2f MiB) over %d ps samples'
        % (t_drain, sent / MIB / t_drain, sent, peak, (peak or 0) / 1024.0, len(sampler.samples)))
    say('  %d of those samples fell inside the flood window (one sample about every %.0f ms)'
        % (during, 1000.0 * (sampler.times[-1] - sampler.times[0]) / max(1, len(sampler.times) - 1)
           if len(sampler.times) > 1 else 0))
    # the very next valid call
    _, pre = head(c)
    t1 = time.perf_counter()
    a = c.call_tool('issue_payout', {'amount': '1.00', 'invoice_id': 'INV-A-1001', 'vendor': VENDOR},
                    meta=meta('after-flood-1', pre))
    first_ms = (time.perf_counter() - t1) * 1000
    v, dd = verdict_of(a)
    event('COMMITTED' if v == 'SERVER_OK' else v, 'g' if v == 'SERVER_OK' else 'red',
          'first tools/call after the flood: %s %s, round trip %.2f ms' % (dd.get('status'), dd.get('amount'), first_ms))
    lat = []
    oks = 0
    for i in range(2, 32):
        _, pre = head(c)
        t1 = time.perf_counter()
        a = c.call_tool('issue_payout', {'amount': '1.00', 'invoice_id': 'INV-A-1001', 'vendor': VENDOR},
                        meta=meta('after-flood-%d' % i, pre))
        lat.append((time.perf_counter() - t1) * 1000)
        if verdict_of(a)[0] == 'SERVER_OK':
            oks += 1
    say('  30 further commits (round trip, ms): min %.2f  p50 %.2f  p99 %.2f  max %.2f  %s'
        % (min(lat), pct(lat, 50), pct(lat, 99), max(lat), col('dim', '(measured; no bound asserted)')))
    barrier(c)
    finish(c, 'flood proxy')
    flood_lines = sum(1 for x in read_lines(wire) if x.startswith(prefix[:40]) or len(x) > 65536)
    paid = [r for r in audit_records(audit) if r.get('tool') == 'issue_payout' and r.get('outcome') == 'paid']
    check('beat3_flood_refused_line_too_long', fcode == -32700 and fv == 'BLOCKED_MALFORMED'
          and (fdetail or '').startswith('LINE_TOO_LONG'), 'code %s %s %s' % (fcode, fv, fdetail))
    check('beat3_rss_sampled_during_flood', during >= 2, '%d ps sample(s) inside the flood window' % during)
    check('beat3_peak_rss_below_5_MiB', peak is not None and peak < RSS_LIMIT_KIB, 'peak %s KiB < %d KiB' % (peak, RSS_LIMIT_KIB))
    check('beat3_0_flood_bytes_to_server', flood_lines == 0, 'wire log: %d flood line(s)' % flood_lines)
    check('beat3_next_call_commits', v == 'SERVER_OK' and dd.get('status') == 'paid', 'status %s' % dd.get('status'))
    check('beat3_30_further_commits', oks == 30 and len(paid) == 31, '%d of 30 ok; audit %d payouts' % (oks, len(paid)))
    METRICS.update({'flood_bytes': sent, 'flood_drain_s': round(t_drain, 3),
                    'flood_mib_per_s': round(sent / MIB / t_drain, 1), 'flood_peak_rss_kib': peak,
                    'flood_rss_samples': len(sampler.samples), 'flood_rss_samples_in_window': during, 'next_call_ms': round(first_ms, 2),
                    'commits30_ms': {'min': round(min(lat), 2), 'p50': round(pct(lat, 50), 2),
                                     'p99': round(pct(lat, 99), 2), 'max': round(max(lat), 2)}})
    BEATS['beat3'] = {'flood_gib': gib, 'flood_bytes': sent, 'flood_verdict': fv, 'flood_code': fcode,
                      'rss_limit_kib': RSS_LIMIT_KIB, 'flood_lines_at_server': flood_lines,
                      'next_call': dd.get('status'), 'further_commits_ok': oks, 'server_payouts': len(paid)}
    e.stores.append(('beat3', store))


# ------------------------------------------------------------------ layer 03: evidence
def verify(e, wal):
    env = dict(os.environ, FORGE_MCP_PROXY=e.binary)
    p = subprocess.run([PY, str(LAUNCHER), 'verify-evidence', str(wal), '--allowed-signers', e.signers],
                       capture_output=True, text=True, timeout=600, env=env)
    return p.returncode, p.stdout, p.stderr


def layer_evidence(e):
    banner('LAYER 03  EVIDENCE: OFFLINE VERIFICATION OF EVERY evidence.wal OF THIS RUN',
           'bin/forge-mcp-proxy verify-evidence (ssh-keygen -Y verify of each Ed25519 signature, hash chain)')
    found = sorted(e.work.rglob('evidence.wal'))
    wals = [s / 'evidence.wal' for _, s in e.stores if (s / 'evidence.wal') in found]
    wals += [w for w in found if w not in wals]
    want = {'beat1': 25, 'beat2': 4, 'beat3': 32}
    names = {str(s / 'evidence.wal'): b for b, s in e.stores}
    BEATS['evidence'] = {}
    for w in wals:
        beat = names.get(str(w), w.parent.parent.name)
        code, out, err = verify(e, w)
        last = [x for x in out.splitlines() if x.startswith('VERIFIED') or x.startswith('FAILED')]
        fin = [x.split('=', 1)[1] for x in out.splitlines() if x.startswith('final_chain=')]
        recs = [x for x in out.splitlines() if x.startswith('#')]
        verdicts = {}
        for x in recs:
            for part in x.split():
                if part.startswith('verdict='):
                    verdicts[part[8:]] = verdicts.get(part[8:], 0) + 1
        sig_ok = sum(1 for x in recs if x.endswith(' OK'))
        line = last[-1] if last else (err.strip().splitlines() or ['no output'])[-1]
        event('VERIFY', 'g' if code == 0 else 'red', '%s %s  exit %d  %s' % (beat, w.relative_to(e.work), code, line))
        if fin:
            say('             final chain %s' % col('c', fin[0]))
        say('             verdicts %s' % ', '.join('%s=%d' % kv for kv in sorted(verdicts.items())))
        n = sum(verdicts.values())
        check('evidence_%s_verified' % beat, code == 0 and bool(last) and last[-1].startswith('VERIFIED')
              and ('records=%d signatures=%d chain=OK' % (n, n)) in last[-1] and sig_ok == n and n == want.get(beat),
              'exit %d, %d records, %d signatures OK, expected %s records' % (code, n, sig_ok, want.get(beat)))
        METRICS['final_chain_' + beat] = fin[0] if fin else None
        BEATS['evidence'][beat] = {'exit': code, 'records': n, 'verdicts': verdicts}
    check('evidence_every_beat_has_a_wal', sorted(names.values()) == sorted(BEATS['evidence']) and len(wals) == 3,
          '%d evidence.wal file(s) found' % len(wals))
    # tamper control
    if wals:
        src = wals[0]
        bad = e.work / 'tamper' / 'evidence.tampered.wal'
        bad.parent.mkdir()
        data = bytearray(src.read_bytes())
        off = 30 + 5 + 8 + 16 + 32 + 4   # inside the tool field of record 1 (layout in evidence.rs)
        data[off] ^= 0x01
        bad.write_bytes(bytes(data))
        os.chmod(bad, 0o600)
        code, out, err = verify(e, bad)
        line = ([x for x in out.splitlines() if x.startswith('FAILED')] or [err.strip() or 'no output'])[-1]
        event('TAMPER', 'red' if code == 1 else 'y', 'copy of %s with byte %d flipped -> exit %d  %s'
              % (src.relative_to(e.work), off, code, line))
        check('evidence_tamper_control_fails', code == 1 and line.startswith('FAILED'), 'exit %d' % code)
        BEATS['evidence']['tamper'] = {'offset': off, 'exit': code}


# ------------------------------------------------------------------ summary
NOT_SHOWN = [
    'The proxy is unproved Rust (NATIVE CHECK, FINITE TEST). No proof of any property is claimed.',
    'The policies are NOT spec-cleared; no clearing check ran.',
    'The scoped-read filter trusts the clinic_id / org_id labels that the server puts in its answer.',
    'The CAS runs on the airlock\'s own ledger, not on the bank\'s or the EHR\'s state.',
    'One machine, one run. No hardware claim, no compliance claim.',
    'Removal of trailing evidence records is not detected without an outside anchor of the last chain value.',
]


def summary(t_start):
    banner('SUMMARY')
    w = max(len(k) for k in CHECKS) if CHECKS else 10
    for k, ok in CHECKS.items():
        say('  %s  %s  %s' % (col('ok', ' PASS ') if ok else col('bad', ' FAIL '), k.ljust(w), col('dim', CHECK_DETAIL[k])))
    METRICS['wall_s'] = round(time.perf_counter() - t_start, 1)
    say('')
    for k in ('flood_drain_s', 'flood_mib_per_s', 'flood_peak_rss_kib', 'next_call_ms', 'commits30_ms', 'wall_s'):
        if k in METRICS:
            say('  %s %s' % (col('c', k.ljust(20)), METRICS[k]))
    say('')
    say(col('y', '  What this does NOT show:'))
    for x in NOT_SHOWN:
        say('   - ' + x)
    n_ok = sum(CHECKS.values())
    say('')
    say(col('ok' if n_ok == len(CHECKS) else 'bad', ' %d of %d checks PASS ' % (n_ok, len(CHECKS))))


def main():
    ap = argparse.ArgumentParser(description='Archia MCP airlock live showcase (finite test of an unproved proxy)')
    ap.add_argument('--binary')
    ap.add_argument('--work')
    ap.add_argument('--json')
    ap.add_argument('--flood-gib', type=int, default=10)
    ap.add_argument('--no-color', action='store_true')
    ap.add_argument('--no-pause', action='store_true')
    args = ap.parse_args()
    set_colors(not args.no_color and not os.environ.get('NO_COLOR'))
    if args.flood_gib < 1:
        say('run_showcase: --flood-gib must be >= 1')
        return 2
    t_start = time.perf_counter()
    say(col('b', 'ARCHIA MCP AIRLOCK  live showcase  (FINITE TEST of an unproved Rust proxy; NATIVE CHECK)'))
    code = 0
    try:
        try:
            e = setup(args)
        except (SetupError, OSError, subprocess.SubprocessError) as x:
            say(col('red', 'SETUP ERROR: %s' % x))
            return 2
        e.stores = []
        say(col('dim', '  work folder %s' % e.work))
        layer_config(e)
        for n, fn in ((1, lambda: beat1(e)), (2, lambda: beat2(e)), (3, lambda: beat3(e, args.flood_gib))):
            if not args.no_pause:
                time.sleep(1.0)
            try:
                fn()
                CHECKS['beat%d_ran' % n] = True
                CHECK_DETAIL['beat%d_ran' % n] = ''
            except Exception as x:  # a broken beat: one clear line, exit 1, children reaped
                say(col('bad', ' BEAT %d BROKE: %s: %s ' % (n, type(x).__name__, x)))
                CHECKS['beat%d_ran' % n] = False
                CHECK_DETAIL['beat%d_ran' % n] = '%s: %s' % (type(x).__name__, x)
                reap_all()
        try:
            layer_evidence(e)
            CHECKS['evidence_ran'] = True
            CHECK_DETAIL['evidence_ran'] = ''
        except Exception as x:
            say(col('bad', ' EVIDENCE STEP BROKE: %s: %s ' % (type(x).__name__, x)))
            CHECKS['evidence_ran'] = False
            CHECK_DETAIL['evidence_ran'] = str(x)
        summary(t_start)
        code = 0 if CHECKS and all(CHECKS.values()) else 1
        if args.json:
            with open(args.json, 'w') as f:
                json.dump({'checks': CHECKS, 'metrics': METRICS, 'beats': BEATS}, f, indent=2, sort_keys=True)
                f.write('\n')
        return code
    except KeyboardInterrupt:
        say(col('red', 'interrupted'))
        return 1
    finally:
        reap_all()


if __name__ == '__main__':
    sys.exit(main())
