#!/usr/bin/env python3
"""FINITE TEST of src/primitives_v2/py/policy_to_dfy.py (the generator: a TRUSTED ASSUMPTION) and of the tie between
its Dafny models and the real engines. It proves nothing about the engines.

Usage: python3 tests/primitives_v2/test_policy_to_dfy.py --seams-engine PATH --airlock-engine PATH
           [--ledger-engine PATH] [--generator PATH] [--case NAME]... [--work DIR] [--policy FILE]...

Cases:
  determinism   `gen` in 16 fresh processes (PYTHONHASHSEED 0 to 15): byte-identical; equal to the file in
                domains/compiled_policies/ when the default generator runs.
  injectivity   for each example policy, every one-field change (a bound, a cap, a verdict, a reason, a fact, the
                name, a rate constant) gives a different module text and different policies never share a file name.
  refuse        malformed policies are refused (exit 2) and no text reaches the Dafny file except ids and decimals.
  verify        the pinned Dafny (one process at a time; waits while another Dafny process runs) verifies each
                generated module with the gate options (exit 0, 0 errors) and `dafny audit` equals the empty baseline.
                This is a Dafny run of the generated MODEL; the case only records it.
  differential  the generator's `vectors` RUNS the verified decision function (Dafny Python back end) on thousands of
                inputs derived from the policy (boundaries included); this case replays every vector against the real
                engine: `airlock-engine eval` (money), the primitives engine test build with its test clock
                (rate_window), and (transfer) the engine with primitive 7 when --ledger-engine is given.
A case that cannot run FAILS with NOT RUN. Exit 0: every selected case passed. 1: a case failed. 2: no start.
Timings are indicative (shared machine).
"""

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import select
import shutil
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
GENERATOR = ROOT / 'src/primitives_v2/py/policy_to_dfy.py'
POLICIES = ROOT / 'domains/compiled_policies/policies'
COMMITTED = ROOT / 'domains/compiled_policies'
# Pinned Dafny: FORGE_DAFNY, else <FORGE_TOOLCHAIN_ROOT or this repository>/.toolchain/dafny-4.11.0/dafny/dafny
# (src/primitives_v2/PROTOCOL.md, Tests). The toolchain root is the cwd of every Dafny run.
DAFNY_ROOT = os.environ.get('FORGE_TOOLCHAIN_ROOT') or str(ROOT)
DAFNY = os.environ.get('FORGE_DAFNY') or str(Path(DAFNY_ROOT) / '.toolchain/dafny-4.11.0/dafny/dafny')
OPTIONS = ['--solver-path', '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1', '--resource-limit', '1000000',
           '--verification-time-limit', '0', '--cores', '1', '--verify-included-files', '--track-print-effects']
BASELINE = Path(DAFNY_ROOT) / 'gate/expected-audit.md'
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}
ANSWER = re.compile(r'^([A-Z][A-Z0-9_]{1,47})((?: [A-Za-z0-9_.:@+-]+=[A-Za-z0-9._~:/@$\[\]+,%-]*)*)(?: -- ([ -~]*))?$')


class Failed(Exception):
    pass


def require(cond, msg):
    if not cond:
        raise Failed(msg)


def load_generator(path):
    spec = importlib.util.spec_from_file_location('policy_to_dfy_under_test', str(path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def slot_busy():
    """A process whose command line names the pinned Dafny, Holmake, hol or z3-4.12.1 holds the slot; a shell, pgrep,
    grep, ps, tail or sleep that merely NAMES the text does not (`pgrep -f 'dafny/dafny'` matched such shells)."""
    p = subprocess.run(['ps', '-ax', '-o', 'pid=,command='], capture_output=True, text=True)
    for line in p.stdout.splitlines():
        pid, _, cmd = line.strip().partition(' ')
        first = os.path.basename(cmd.split(' ', 1)[0]).lstrip('-')
        if not pid.isdigit() or int(pid) == os.getpid() or first in ('sh', 'bash', 'zsh', 'pgrep', 'grep', 'ps', 'tail', 'sleep'):
            continue
        if re.search(r'dafny/dafny|Holmake|/hol |z3-4\.12\.1', cmd):
            return True
    return False


def wait_slot(limit=3600):
    waited = 0
    while slot_busy():
        if waited >= limit:
            return False
        time.sleep(30)
        waited += 30
    return True


def dafny(args, log):
    require(Path(DAFNY).is_file(), 'NOT RUN: the pinned Dafny is missing at %s: set FORGE_TOOLCHAIN_ROOT to the checkout '
            'that holds .toolchain/dafny-4.11.0, or FORGE_DAFNY to the dafny binary' % DAFNY)
    require(wait_slot(), 'NOT RUN: the Dafny slot was not free in 60 min')
    p = subprocess.run([DAFNY] + args, cwd=DAFNY_ROOT, capture_output=True, text=True)
    log.append('%s -> exit %d: %s' % (' '.join(['dafny'] + args[:2]), p.returncode, (p.stdout.strip().splitlines() or [''])[-1]))
    return p


def policies(s):
    return [Path(p) for p in s.args.policy] if s.args.policy else sorted(POLICIES.glob('*.json'))


def generate(s, folder, policy, seed='0'):
    """Runs `gen` of the generator under test in a fresh process (PYTHONHASHSEED=seed); returns (file, text)."""
    env = dict(os.environ, PYTHONHASHSEED=seed)
    p = subprocess.run([sys.executable, str(s.generator), 'gen', str(policy), '--out', str(folder)], capture_output=True, text=True, env=env)
    require(p.returncode == 0 and p.stdout.startswith('GENERATED '), '%s: gen exit %d %r %r' % (policy.name, p.returncode, p.stdout[-200:], p.stderr[-300:]))
    name = p.stdout.split()[1]
    return folder / name, (folder / name).read_text()


# ---- cases ---------------------------------------------------------------------------------------------------------
DET_SEEDS = [str(k) for k in range(16)]   # seeds 1 and 2 alone gave one set order for money-refunds (G11 survived)


def case_determinism(s):
    n = 0
    for policy in policies(s):
        a, ta = generate(s, s.fresh('det-a'), policy, DET_SEEDS[0])
        for seed in DET_SEEDS[1:]:
            b, tb = generate(s, s.fresh('det-b'), policy, seed)
            require(a.name == b.name and ta.encode() == tb.encode(),
                    '%s: two runs differ (not byte-identical; PYTHONHASHSEED %s and %s)' % (policy.name, DET_SEEDS[0], seed))
        if s.generator == GENERATOR and not s.args.policy:
            require((COMMITTED / a.name).read_text() == ta, '%s: differs from domains/compiled_policies/%s' % (policy.name, a.name))
        n += 1
    return '%d policies: byte-identical in %d processes (hash seeds %s to %s)%s' % (
        n, len(DET_SEEDS), DET_SEEDS[0], DET_SEEDS[-1], '; equal to the committed files' if s.generator == GENERATOR and not s.args.policy else '')


def variants(kind, obj):
    """One-field changes of a policy object (JSON level)."""
    out = []
    if kind == 'money':
        for k, rule in enumerate(obj['rules']):
            for field in ('min_amount', 'max_amount'):
                if field in rule:
                    for delta in (-1, 1):
                        v = json.loads(json.dumps(obj))
                        v['rules'][k][field] = str(int(rule[field]) + delta)
                        out.append(v)
                    v = json.loads(json.dumps(obj))
                    del v['rules'][k][field]
                    out.append(v)
            for verdict in ('COMMIT', 'REQUIRE_HUMAN_COSIGN', 'REJECTED_POLICY'):
                if verdict != rule['verdict']:
                    v = json.loads(json.dumps(obj))
                    v['rules'][k]['verdict'] = verdict
                    out.append(v)
            v = json.loads(json.dumps(obj))
            v['rules'][k]['reason'] = rule['reason'] + 'X'
            out.append(v)
            v = json.loads(json.dumps(obj))
            if 'max_reason_total_fact' in rule:
                v['rules'][k]['max_reason_total_fact'] = rule['max_reason_total_fact'] + 'x'
            else:
                v['rules'][k]['max_reason_total_fact'] = 'f'
            out.append(v)
        v = json.loads(json.dumps(obj))
        v['rules'] = v['rules'][:-1]
        out.append(v)
        v = json.loads(json.dumps(obj))
        v['rules'] = v['rules'][1:] + v['rules'][:1]
        out.append(v)
    else:
        for field, value in obj.items():
            if isinstance(value, str) and value.isdigit():
                for delta in (-1, 1):
                    v = dict(obj)
                    v[field] = str(int(value) + delta)
                    out.append(v)
    v = json.loads(json.dumps(obj))
    v['name'] = obj['name'] + 'b'
    out.append(v)
    return out


def case_injectivity(s):
    G = load_generator(s.generator)
    total = 0
    names = {}
    for policy in policies(s):
        data = policy.read_bytes()
        name, text, kind, _ = G.generate(data)
        texts = {text: 'original'}
        for k, v in enumerate(variants(kind, json.loads(data))):
            raw = json.dumps(v).encode()
            try:
                vname, vtext, vkind, vpol = G.generate(raw)
            except Exception:
                continue       # a change that the loader refuses (out of range) makes no module
            require(vtext not in texts, '%s: variant %d gives the same module as %s' % (policy.name, k, texts.get(vtext)))
            texts[vtext] = 'variant %d' % k
            key = vname
            require(names.get(key, vpol['name']) == vpol['name'] or vkind != kind, 'two policy names give the file name %s' % key)
            names[key] = vpol['name']
            total += 1
    return '%d one-field variants: every module differs from the original and from every other variant; file names follow the policy name' % total


def case_refuse(s):
    bad = [b'{', b'[]', b'{"airlock": "money", "version": 1, "name": "x", "profile": "parametric", "rules": []}',
           b'{"airlock": "money", "version": 1, "name": "x y", "profile": "parametric", "rules": [{"reason": "A", "verdict": "COMMIT"}]}',
           b'{"airlock": "money", "version": 1, "name": "x", "profile": "parametric", "rules": [{"reason": "A\\"} lemma X() ensures false {", "verdict": "COMMIT"}]}',
           b'{"airlock": "money", "version": 1, "name": "x", "profile": "parametric", "rules": [{"reason": "A", "max_amount": 5, "verdict": "COMMIT"}]}',
           b'{"primitive": "rate_window", "version": 1, "name": "r", "max_ops_per_window": "0", "max_volume_per_window": "1", "window_ms": "1", "cooldown_after": "0", "cooldown_ms": "0"}',
           b'{"primitive": "rate_window", "version": 1, "name": "r", "max_ops_per_window": "1", "max_volume_per_window": "1", "window_ms": "0", "cooldown_after": "0", "cooldown_ms": "0"}',
           b'{"primitive": "rate_window", "version": 1, "name": "r", "max_ops_per_window": "1", "max_volume_per_window": "1", "window_ms": "1", "cooldown_after": "2", "cooldown_ms": "0"}',
           b'{"primitive": "rate_window", "version": 1, "name": "r", "max_ops_per_window": "1", "max_volume_per_window": "1", "window_ms": "1", "cooldown_after": "0", "cooldown_ms": "0", "x": "1"}',
           b'{"primitive": "rate_window", "version": 1.0, "name": "r", "max_ops_per_window": "1", "max_volume_per_window": "1", "window_ms": "1", "cooldown_after": "0", "cooldown_ms": "0"}',
           b'{"primitive": "rate_window", "version": 1, "name": "r", "max_ops_per_window": "01", "max_volume_per_window": "1", "window_ms": "1", "cooldown_after": "0", "cooldown_ms": "0"}',
           b'{"primitive": "ledger_graph", "version": 1, "name": "l", "kind": "ledger", "issuance": "free", "max_balance": "10", "max_legs": "2"}',
           b'{"primitive": "ledger_graph", "version": 1, "name": "l", "kind": "graph", "max_nodes": "2", "max_edges": "1"}',
           b'{"primitive": "taint_egress", "version": 1, "name": "t"}']
    folder = s.fresh('refuse')
    for k, data in enumerate(bad):
        f = folder / ('bad%d.json' % k)
        f.write_bytes(data)
        p = subprocess.run([sys.executable, str(s.generator), 'gen', str(f), '--out', str(folder / 'out')], capture_output=True, text=True)
        require(p.returncode == 2 and p.stdout.startswith('MALFORMED'), 'bad policy %d was not refused: exit %d %r' % (k, p.returncode, p.stdout[:200]))
        require(not (folder / 'out').exists() or not any((folder / 'out').iterdir()), 'bad policy %d wrote a file' % k)
    return '%d malformed policies refused before any file is written' % len(bad)


def case_verify(s):
    log = []
    counts = []
    for policy in policies(s):
        dfy, _ = generate(s, s.fresh('verify'), policy)
        p = dafny(['verify', str(dfy)] + OPTIONS, log)
        m = re.search(r'finished with (\d+) verified, (\d+) errors?', p.stdout)
        require(p.returncode == 0 and m and m.group(2) == '0',
                '%s: dafny verify exit %d (%s); first error: %s' % (dfy.name, p.returncode, m.group(0) if m else 'no summary',
                                                                    next((l for l in p.stdout.splitlines() if 'Error' in l), '')[-200:]))
        report = dfy.parent / 'audit.md'
        shutil.copyfile(BASELINE, report)
        a = dafny(['audit', str(dfy), '--report-format', 'md', '--report-file', str(report), '--compare-report'], log)
        require(a.returncode == 0 and report.read_bytes() == BASELINE.read_bytes(), '%s: dafny audit exit %d, report differs from the empty baseline' % (dfy.name, a.returncode))
        counts.append('%s %s verified 0 errors, audit empty' % (dfy.name, m.group(1)))
    return '; '.join(counts)


# ---- engines --------------------------------------------------------------------------------------------------------
class Answer:
    def __init__(self, line):
        m = ANSWER.match(line)
        require(m is not None, 'answer breaks the wire grammar: %r' % line)
        self.line, self.code = line, m.group(1)
        self.f = dict(tok.split('=', 1) for tok in m.group(2).split())


class Session:
    def __init__(self, engine, store, env):
        self.p = subprocess.Popen([engine, 'serve', str(store)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, bufsize=0)

    def ask(self, line):
        self.p.stdin.write(line.encode() + b'\n')
        buf = b''
        end = time.monotonic() + 120
        while not buf.endswith(b'\n'):
            r, _, _ = select.select([self.p.stdout], [], [], max(end - time.monotonic(), 0))
            require(r, 'no answer to %r' % line)
            c = self.p.stdout.read(1)
            require(c, 'serve ended at %r' % line)
            buf += c
        return Answer(buf[:-1].decode())

    def close(self):
        self.p.stdin.close()
        return self.p.wait(timeout=600)


def replay_money(s, policy, record):
    require(s.args.airlock_engine and os.access(s.args.airlock_engine, os.X_OK), 'NOT RUN: no --airlock-engine')
    lines = []
    for v in record['vectors']:
        i = v['input']
        lines.append(' '.join(['EVAL', i['reason'], str(i['amount']), str(i['remaining']), str(i['reason_total'])] + ['%s=%d' % tuple(f) for f in i['facts']]))
    p = subprocess.run([s.args.airlock_engine, 'eval', str(policy)], input=''.join(l + '\n' for l in lines).encode(), capture_output=True, env=ENV, timeout=600)
    out = p.stdout.decode().split('\n')[:-1]
    require(p.returncode == 0 and len(out) == len(lines), 'airlock-engine eval exit %d, %d lines for %d' % (p.returncode, len(out), len(lines)))
    for line, v, got in zip(lines, record['vectors'], out):
        require(got == v['decision'], 'money vector %r: Dafny model %r, engine %r' % (line, v['decision'], got))
    kinds = {}
    for v in record['vectors']:
        kinds[v['decision']] = kinds.get(v['decision'], 0) + 1
    return len(lines), kinds


def replay_rate(s, policy, record, name):
    require(s.args.seams_engine and os.access(s.args.seams_engine, os.X_OK), 'NOT RUN: no --seams-engine')
    steps, kinds = 0, {}
    for n, trace in enumerate(record['vectors']):
        d = s.fresh('rate')
        clock = d / 'clock'
        clock.write_text('%d 0\n' % trace[0][0])
        env = dict(ENV, PRIMITIVES_TEST_CLOCK=str(clock))
        st = d / 'st'
        p = subprocess.run([s.args.seams_engine, 'init', str(st), '--policy', str(policy)], capture_output=True, env=env)
        require(p.returncode == 0, 'init with the policy: exit %d %r' % (p.returncode, p.stdout))
        ses = Session(s.args.seams_engine, st, env)
        try:
            for k, (t, vol, want) in enumerate(trace):
                tmp = d / 'clock.tmp'
                tmp.write_text('%d 0\n' % t)
                os.replace(tmp, clock)
                a = ses.ask('DO rate_window acquire r%d t1 1 key * %s %d' % (k, name, vol))
                require(a.f.get('now_ms') == str(t), 'trace %d step %d: engine time %r, expected %d' % (n, k, a.f.get('now_ms'), t))
                got = [a.code] + ([int(a.f['retry_after_ms'])] if 'retry_after_ms' in a.f else [])
                require(got == want, 'trace %d step %d (t=%d v=%d): Dafny model %r, engine %r' % (n, k, t, vol, want, a.line[:200]))
                kinds[want[0]] = kinds.get(want[0], 0) + 1
                steps += 1
        finally:
            ses.close()
        shutil.rmtree(d, ignore_errors=True)
    return steps, kinds


def case_differential(s):
    G = load_generator(s.generator)
    out = []
    for policy in policies(s):
        data = policy.read_bytes()
        name, text, kind, pol = G.generate(data)
        gen = s.fresh('vec-gen')
        (gen / name).write_text(text)
        work = s.fresh('vec-work')
        code = G.vectors(data, str(gen), str(work))
        require(code == 0, 'NOT RUN: vectors for %s exit %d (Dafny build failed or slot not free)' % (policy.name, code))
        record = json.loads((gen / (name[:-4] + '.vectors.json')).read_text())
        require(record['model_sha256'] == hashlib.sha256(text.encode()).hexdigest(), 'the vectors are not those of this model')
        if s.generator == GENERATOR and not s.args.policy:
            committed = COMMITTED / (name[:-4] + '.vectors.json')
            fresh = (gen / (name[:-4] + '.vectors.json')).read_bytes()
            require(committed.is_file() and committed.read_bytes() == fresh,
                    '%s: the committed vector file differs from a fresh computation (whole file, byte for byte)' % committed.name)
        if kind == 'money':
            n, kinds = replay_money(s, policy, record)
        elif kind == 'rate_window':
            n, kinds = replay_rate(s, policy, record, pol['name'])
        else:
            require(s.args.ledger_engine, 'NOT RUN: transfer vectors need --ledger-engine (an engine build with primitive 7)')
            n, kinds = replay_transfer(s, policy, record, pol)
        out.append('%s: %d vectors agree %s' % (name, n, sorted(kinds.items())))
    return '; '.join(out)


TRANSFER_CODE = {'SelfTransfer': 'SELF_TRANSFER', 'ZeroAmount': 'ZERO_AMOUNT', 'InsufficientFunds': 'INSUFFICIENT_FUNDS',
                 'BalanceLimit': 'BALANCE_LIMIT'}


def replay_transfer(s, policy, record, pol):
    """Each vector: a new tenant opens two accounts with the vector's balances, then one `transfer`; a commit is
    checked with GET of both balances. A fresh store every 250 vectors (each request replays the whole WAL)."""
    require(os.access(s.args.ledger_engine, os.X_OK), 'NOT RUN: no --ledger-engine')
    eng, n, kinds = s.args.ledger_engine, 0, {}
    vecs = record['vectors']
    for start in range(0, len(vecs), 250):
        d = s.fresh('transfer')
        st = d / 'st'
        p = subprocess.run([eng, 'init', str(st), '--policy', str(policy)], capture_output=True, env=ENV)
        require(p.returncode == 0, 'init with the ledger policy: exit %d %r' % (p.returncode, p.stdout))
        genesis = Answer(subprocess.run([eng, 'get', str(st), 't0', 'a0'], capture_output=True, env=ENV).stdout.decode().strip()).f['hash']
        ses = Session(eng, st, ENV)
        try:
            for k, v in enumerate(vecs[start:start + 250], start):
                same, fb, tb, amount = v['input']
                want = v['decision']
                ten, a, b = 't%d' % k, 'a%d' % k, 'b%d' % k
                o = ses.ask('DO ledger_graph open o%d %s 2 %s %s %s %s %s %d %d' % (k, ten, a, genesis, b, genesis, pol['name'], fb, tb))
                require(o.code == 'COMMITTED', 'vector %d: open refused: %r' % (k, o.line[:200]))
                h = o.f['hash.' + a]
                to = a if same else b
                r = ses.ask('DO ledger_graph transfer x%d %s 2 %s %s %s %s %s %s %s %d' % (k, ten, a, h, b, h, pol['name'], a, to, amount))
                if want[0] == 'COMMITTED':
                    require(r.code == 'COMMITTED', 'vector %d %r: Dafny model %r, engine %r' % (k, v['input'], want, r.line[:200]))
                    ga, gb = ses.ask('GET %s %s' % (ten, a)), ses.ask('GET %s %s' % (ten, b))
                    got = ['COMMITTED', int(ga.f.get('balance', -1)), int(gb.f.get('balance', -1))]
                    require(got == want, 'vector %d %r: Dafny model %r, engine balances %r' % (k, v['input'], want, got))
                else:
                    require(r.code == TRANSFER_CODE[want[0]], 'vector %d %r: Dafny model %r, engine %r' % (k, v['input'], want, r.line[:200]))
                kinds[want[0]] = kinds.get(want[0], 0) + 1
                n += 1
        finally:
            ses.close()
        shutil.rmtree(d, ignore_errors=True)
    return n, kinds


CASES = [('determinism', case_determinism), ('injectivity', case_injectivity), ('refuse', case_refuse),
         ('verify', case_verify), ('differential', case_differential)]


class Suite:
    def fresh(self, label):
        self.n += 1
        d = self.work / ('%s-%d' % (label, self.n))
        d.mkdir(mode=0o700, parents=True)
        return d


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--seams-engine')
    ap.add_argument('--airlock-engine')
    ap.add_argument('--ledger-engine')
    ap.add_argument('--generator', default=str(GENERATOR))
    ap.add_argument('--case', action='append')
    ap.add_argument('--policy', action='append')
    ap.add_argument('--work')
    args = ap.parse_args()
    s = Suite()
    s.args, s.n = args, 0
    s.generator = Path(args.generator).resolve()
    if not s.generator.is_file():
        print('suite error: no generator at %s' % s.generator)
        return 2
    s.work = Path(tempfile.mkdtemp(prefix='p9-policy-', dir=args.work))
    os.chmod(s.work, 0o700)
    failed = 0
    for name, fn in CASES:
        if args.case and name not in args.case:
            continue
        t = time.time()
        try:
            msg = fn(s)
            print('PASS %-13s %7.1fs %s' % (name, time.time() - t, msg), flush=True)
        except Failed as e:
            failed += 1
            print('FAIL %-13s %7.1fs %s' % (name, time.time() - t, e), flush=True)
        except Exception as e:
            failed += 1
            print('FAIL %-13s %7.1fs suite error: %s: %s' % (name, time.time() - t, type(e).__name__, e), flush=True)
    shutil.rmtree(s.work, ignore_errors=True)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
