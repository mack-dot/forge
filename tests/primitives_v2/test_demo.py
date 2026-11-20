#!/usr/bin/env python3
"""FINITE TEST of examples/universal_self_repair/run_demo.py over the REAL primitives engine. It proves nothing.

Usage: python3 tests/primitives_v2/test_demo.py <engine> [--case NAME]... [--seed N]

Cases (one printed line each; a case that cannot run FAILS with NOT RUN):
  cli_exit       the CLI run exits 0 and prints the check table with every check PASS; a CLI canary run exits 1
  determinism    two runs: the results files are identical except the key `measured`; the measured parts differ
                 (fresh store, fresh random secrets and state hashes per run)
  alt_params     another scenario (other limits, other cooldown, a debit-side excess, another cycle edge, other taint
                 paths incl. JSON inside a string, another destination, another Farkas system): all checks pass and
                 each repaired proposal is the one the refusal's fields imply
  seeded_params  a scenario generated from --seed (random limits, amounts, chain, closing edge, nesting depth)
  canary:<name>  each positive control of run_demo.CANARIES: the run must fail (exit 1) and its named check must FAIL
  canary_coverage every check of the demo FAILED under at least one canary of this invocation
  missing_engine a missing engine, a non-executable file and /usr/bin/false: non-zero exit, a loud message, no check
                 table, no result
Exit 0: every selected case passed. 1: at least one failed. 2: the suite could not start.
Process note: most runs are in-process (this Python + the engine `serve` + a short `replay`).
"""

import argparse
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import random
import re
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
DEMO = ROOT / 'examples' / 'universal_self_repair' / 'run_demo.py'
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}


class Failed(Exception):
    pass


def require(cond, msg):
    if not cond:
        raise Failed(msg)


def load_demo():
    spec = importlib.util.spec_from_file_location('run_demo', DEMO)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run_in_process(demo, engine, scenario, canary=None, json_out=None):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        run, ok = demo.run_once(engine, scenario, canary=canary, quiet=True, json_out=json_out)
    return run, ok


def strip_measured(d):
    d = dict(d)
    d.pop('measured', None)
    return d


def turns_of(run, task):
    return [t for t in run.turns if t['task'] == task]


ALT = {
    'tenant': 'beta',
    'rate': {'key': 'api:beta', 'max_ops_per_window': 2, 'window_ms': 700, 'cooldown_after': 1, 'cooldown_ms': 900,
             'max_volume_per_window': 1000, 'volume': 3, 'burst': 4},
    'ledger': {'name': 'wallet', 'max_balance': 5000, 'open': {'w:alpha': 900, 'w:beta': 100, 'w:gamma': 40},
               'bad_post': {'w:alpha': -200, 'w:beta': -50, 'w:gamma': 230}},
    'graph': {'key': 'deps', 'base': [['root', 'ops'], ['ops', 'dev'], ['dev', 'intern'], ['ops', 'qa']],
              'batch': [['qa', 'intern'], ['intern', 'ops'], ['dev', 'qa2']]},
    'taint': {'destination': 'LLM_STDOUT',
              'fields': [{'path': 'dx', 'labels': ['PHI']}, {'path': '$.meta.token', 'labels': ['SECRET_KEY']}],
              'document': {'meta': {'token': '<SECRET:tok>', 'v': 2},
                           'visits': [{'date': '2026-01-02'}, {'notes': 'ok', 'dx': '<SECRET:dx>'}],
                           'blob': '{"inner":{"dx":"<SECRET:dx2>","keep":1}}'}},
    'farkas': {'job': 'job-alt-7',
               'false_claim': {'A': [[2, 1, 0], [0, 1, 1], [-1, -1, -1]], 'b': [4, 3, -6], 'y': [1, -1, 0]},
               'true_claim': {'A': [[1, 0], [0, 1], [-1, -1]], 'b': [3, 3, -5], 'y': [1, 1, 1]},
               'search_bound': 10},
}


def seeded(seed):
    rnd = random.Random(seed)
    m = rnd.randint(2, 4)
    accts = {'s:%s' % n: rnd.randint(200, 900) for n in ('a', 'b', 'c', 'd')}
    keys = sorted(accts)
    debit = rnd.randint(10, 150)
    split = rnd.randint(1, debit - 1)
    extra = rnd.randint(1, 9)
    bad = {keys[0]: -debit, keys[1]: split, keys[2]: debit - split + extra}  # credit side too large by `extra`
    n = rnd.randint(4, 8)
    chain = ['n%d' % i for i in range(n)]
    base = [[chain[i], chain[i + 1]] for i in range(n - 1)]
    j = rnd.randint(1, n - 1)
    i = rnd.randint(0, j - 1)
    closing = [chain[j], chain[i]]  # path i ~> j exists: j -> i closes a cycle of length j - i + 1
    depth = rnd.randint(1, 5)
    doc = '<SECRET:deep>'
    for d in range(depth):
        doc = {'lvl%d' % d: doc, 'pad%d' % d: d}
    doc = {'items': [{'x': 1}, doc]}
    return {
        'tenant': 'seed%d' % (seed % 1000),
        'rate': {'key': 'api:s', 'max_ops_per_window': m, 'window_ms': rnd.randint(500, 900), 'cooldown_after': rnd.choice([0, 2, 3]),
                 'cooldown_ms': 800, 'max_volume_per_window': 1000, 'volume': rnd.randint(1, 5), 'burst': m + 1},
        'ledger': {'name': 'sl', 'max_balance': 100000, 'open': accts, 'bad_post': bad},
        'graph': {'key': 'g:s', 'base': base, 'batch': [['side', chain[0]], closing]},
        'taint': {'destination': 'PUBLIC_HTTP', 'fields': [{'path': 'lvl0', 'labels': ['PII']}], 'document': doc},
        'farkas': dict(ALT['farkas']),
    }, {'extra': extra, 'closing': '%s->%s' % tuple(closing), 'cycle_len': str(j - i + 1), 'depth': depth}


# ---- cases --------------------------------------------------------------------------------------------------------
def case_cli_exit(ctx):
    with tempfile.TemporaryDirectory() as d:
        out = Path(d) / 'r.json'
        p = subprocess.run([sys.executable, str(DEMO), '--engine', ctx['engine'], '--json', str(out)], capture_output=True, text=True,
                           env=ENV, timeout=600)
        require(p.returncode == 0, 'exit %d: %s' % (p.returncode, (p.stdout + p.stderr)[-600:]))
        require('RESULT: ALL' in p.stdout and ' FAIL ' not in p.stdout, 'check table not all PASS')
        require('SCRIPTED AGENT, NO MODEL' in p.stdout, 'the screen does not say "scripted agent, no model"')
        doc = json.loads(out.read_text())
        require(doc['all_checks_pass'] and all(doc['checks'].values()), 'results file: %r' % doc['checks'])
        p = subprocess.run([sys.executable, str(DEMO), '--engine', ctx['engine'], '--canary', 'secret_in_sink', '--json', str(out)],
                           capture_output=True, text=True, env=ENV, timeout=600)
        bad = json.loads(out.read_text())
        require(p.returncode == 1 and bad['checks']['zero_secret_bytes_in_sink'] is False and not bad['all_checks_pass'],
                'a canary run via the CLI: exit %d, checks %r' % (p.returncode, bad['checks']))
    return 'exit 0; %d checks PASS on screen and in the results file; CLI canary run exit 1' % len(doc['checks'])


def case_determinism(ctx):
    demo = ctx['demo']
    with tempfile.TemporaryDirectory() as d:
        docs = []
        for k in (1, 2):
            out = Path(d) / ('r%d.json' % k)
            _, ok = run_in_process(demo, ctx['engine'], demo.DEFAULT_SCENARIO, json_out=out)
            require(ok, 'run %d: not every check passed' % k)
            docs.append(json.loads(out.read_text()))
    a, b = strip_measured(docs[0]), strip_measured(docs[1])
    if a != b:
        diff = [k for k in sorted(set(a) | set(b)) if a.get(k) != b.get(k)]
        raise Failed('deterministic parts differ in keys %s' % diff)
    ma, mb = docs[0]['measured'], docs[1]['measured']
    require(ma['commit_answers'] != mb['commit_answers'], 'measured state hashes identical across two fresh stores (unexpected)')
    return 'two runs; results identical except `measured` (%d records, %d turns); state hashes differ' % (len(a['records']), len(a['turns']))


def case_alt_params(ctx):
    demo = ctx['demo']
    sc = demo.merge_scenario(demo.DEFAULT_SCENARIO, ALT)
    run, ok = run_in_process(demo, ctx['engine'], sc)
    bad = [c['check'] for c in run.results if not c['ok']]
    require(ok, 'checks failed: %s' % bad)
    post = turns_of(run, 'unbalanced posting')
    require(post[0]['answer'] == 'CONSERVATION_BREACH' and post[0]['fields'] == {'credit_total': '230', 'debit_total': '250'}, 'post refusal %r' % post[0])
    require(post[-1]['proposal'] == 'post legs w:alpha:-200 w:beta:-30 w:gamma:+230', 'post repair: %r' % post[-1]['proposal'])
    cyc = turns_of(run, 'edge batch that closes a cycle')
    require(cyc[0]['fields'].get('edge') == 'intern->ops' and cyc[0]['fields'].get('cycle_len') == '3', 'cycle refusal %r' % cyc[0])
    require(cyc[-1]['proposal'] == 'add edges qa->intern dev->qa2', 'cycle repair %r' % cyc[-1]['proposal'])
    tn = turns_of(run, 'outbound document with a nested tainted field')
    paths = [t['fields'].get('json_path') for t in tn if t['answer'] == 'TAINT_EGRESS_BLOCKED']
    require(len(paths) == 3 and any('@' in p for p in paths) and tn[-1]['answer'] == 'ALLOW', 'taint paths %r final %s' % (paths, tn[-1]['answer']))
    got = json.loads(run.allowed_docs[-1])
    want = {'meta': {'v': 2}, 'visits': [{'date': '2026-01-02'}, {'notes': 'ok'}], 'blob': '{"inner":{"keep":1}}'}
    require(got == want, 'taint repair did not remove exactly the named paths: %r' % got)
    fk = turns_of(run, 'false "no schedule exists" claim')
    require(fk[0]['fields'].get('reason') == 'Y_NEGATIVE' and fk[-1]['answer'] == 'COMMITTED', 'farkas %r' % fk)
    rt = turns_of(run, 'rate burst')
    codes = [t['answer'] for t in rt]
    require(codes[0] == 'RATE_LIMIT_EXCEEDED' and codes[-1] == 'COMMITTED', 'rate turns %r' % codes)
    return 'all checks pass; repairs: debit cut 20, drop intern->ops (cycle_len 3), 3 taint paths removed (%s), Y_NEGATIVE -> schedule; rate %s' % (
        ', '.join(paths), '/'.join(codes))


def case_seeded_params(ctx):
    demo = ctx['demo']
    over, want = seeded(ctx['seed'])
    sc = demo.merge_scenario(demo.DEFAULT_SCENARIO, over)
    run, ok = run_in_process(demo, ctx['engine'], sc)
    require(ok, 'seed %d: checks failed: %s' % (ctx['seed'], [c['check'] for c in run.results if not c['ok']]))
    post = turns_of(run, 'unbalanced posting')
    f = post[0]['fields']
    require(int(f['credit_total']) - int(f['debit_total']) == want['extra'], 'seed %d: refusal fields %r' % (ctx['seed'], f))
    cyc = turns_of(run, 'edge batch that closes a cycle')
    require(cyc[0]['fields'].get('edge') == want['closing'] and cyc[0]['fields'].get('cycle_len') == want['cycle_len'], 'seed %d: %r' % (ctx['seed'], cyc[0]))
    tn = turns_of(run, 'outbound document with a nested tainted field')
    require(tn[-1]['answer'] == 'ALLOW', 'seed %d: taint %r' % (ctx['seed'], tn[-1]))
    return 'seed %d: all checks pass; excess %d, closing %s (cycle_len %s), taint depth %d' % (
        ctx['seed'], want['extra'], want['closing'], want['cycle_len'], want['depth'])


def make_canary(name):
    def case(ctx):
        demo = ctx['demo']
        check = demo.CANARIES[name][0]
        run, ok = run_in_process(demo, ctx['engine'], demo.DEFAULT_SCENARIO, canary=name)
        require(run.canary_applied, 'NOT RUN: the canary was not applied (%r)' % run.canary_applied)
        res = {c['check']: c['ok'] for c in run.results}
        require(res[check] is False, 'the control did not bite: %s PASSED with canary %s' % (check, name))
        require(not ok, 'the run reported success with a broken variant')
        others = sorted(k for k, v in res.items() if not v and k != check)
        ctx.setdefault('bitten', set()).update(k for k, v in res.items() if not v)
        ctx['all_checks'] = set(res)
        return '%s FAILS as it must (also failing: %s)' % (check, ', '.join(others) or 'none')
    return case


def case_canary_coverage(ctx):
    if 'all_checks' not in ctx:
        raise Failed('NOT RUN: no canary case ran in this invocation')
    missing = sorted(ctx['all_checks'] - ctx['bitten'])
    require(not missing, 'checks that no canary made FAIL: %s' % missing)
    return 'each of the %d checks FAILED under at least one canary' % len(ctx['all_checks'])


def case_missing_engine(ctx):
    rows = []
    with tempfile.TemporaryDirectory() as d:
        noexec = Path(d) / 'not-exec'
        noexec.write_text('#!/bin/sh\necho INITIALIZED\n')
        os.chmod(noexec, 0o600)
        for label, eng in (('missing', str(Path(d) / 'no-such-engine')), ('not executable', str(noexec)), ('/usr/bin/false', '/usr/bin/false')):
            p = subprocess.run([sys.executable, str(DEMO), '--engine', eng, '--json', str(Path(d) / 'r.json')], capture_output=True,
                               text=True, env=ENV, timeout=120)
            out = p.stdout + p.stderr
            require(p.returncode == 2, '%s: exit %d (want 2): %s' % (label, p.returncode, out[-300:]))
            require('FATAL' in out and ('ENGINE MISSING' in out or 'ENGINE INIT FAILED' in out), '%s: no loud message: %s' % (label, out[-300:]))
            require('PASS' not in out and 'RESULT' not in out and not re.search(r'^CHECK +RESULT', out, re.M), '%s: a check table or result was printed' % label)
            require(not (Path(d) / 'r.json').exists(), '%s: a results file was written' % label)
            rows.append('%s exit 2' % label)
    return '; '.join(rows) + '; no check table, no results file'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('engine')
    ap.add_argument('--case', action='append')
    ap.add_argument('--seed', type=int, default=20261120)
    args = ap.parse_args()
    if not DEMO.is_file():
        print('cannot start: %s is missing' % DEMO)
        return 2
    demo = load_demo()
    engine = str(Path(args.engine).absolute())
    cases = [('cli_exit', case_cli_exit), ('determinism', case_determinism), ('alt_params', case_alt_params),
             ('seeded_params', case_seeded_params)]
    cases += [('canary:' + n, make_canary(n)) for n in sorted(demo.CANARIES)]
    cases += [('canary_coverage', case_canary_coverage), ('missing_engine', case_missing_engine)]
    ctx = {'engine': engine, 'demo': demo, 'seed': args.seed}
    engine_ok = os.path.isfile(engine) and os.access(engine, os.X_OK)
    failed = 0
    for name, fn in cases:
        if args.case and name not in args.case:
            continue
        t = time.time()
        if not engine_ok and name != 'missing_engine':
            failed += 1
            print('FAIL %-26s %6.1fs NOT RUN: engine %s is missing' % (name, 0.0, engine), flush=True)
            continue
        try:
            detail = fn(ctx)
            print('PASS %-26s %6.1fs %s' % (name, time.time() - t, detail), flush=True)
        except Failed as e:
            failed += 1
            print('FAIL %-26s %6.1fs %s' % (name, time.time() - t, str(e).replace('\n', ' ')[:600]), flush=True)
        except Exception as e:  # noqa: BLE001
            failed += 1
            print('FAIL %-26s %6.1fs suite error %s: %s' % (name, time.time() - t, type(e).__name__, str(e)[:400]), flush=True)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
