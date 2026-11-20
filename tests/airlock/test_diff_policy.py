#!/usr/bin/env python3
"""Suite of `diff-policy` (Goal 20, L2). FINITE TEST. Python stdlib only. It proves nothing.

  python3 tests/airlock/test_diff_policy.py [--engine PATH] [--case NAME]...

Cases:
  loader      every valid fixture loads; the strict loader refuses every bad-*.json fixture
  malformed   control (d): each bad-*.json stops the CLI with exit 2 and 0 Dafny processes
  no-engine   an engine path that does not exist: every row says `engine: NOT RUN`, exit 7
  engine      the engine path: table from `airlock-engine eval`, no mismatch (NOT RUN without the binary)
  mismatch    control: a STAND-IN engine that answers COMMIT to every scenario gives TABLE_MISMATCH, exit 6
  demo        the demo store pair: the expected changed rows, cross-check passed, both NO_CHOICE
  choice      control (a): an ambiguous policy gives CHOICE with a witness that Dafny verified, exit 4
  fault       control (b): a generator that drops one amount bound fails the boundary cross-check, exit 8
  refused     control (c): a bodiless lemma or the word `expect` in the generated Dafny never gives NO_CHOICE
  saga        transitions removed / added / kept and states added; no clearing
  identical   two runs of the demo pair give byte-identical output

One line per case with the actual exit codes. Dafny process counts and wall times are printed only.
Exit 0: every selected case passed. 1: a case failed or was NOT RUN. 2: bad arguments.
Without the engine binary every case except `engine` runs with --allow-no-engine and says so.
Environment: FORGE_DAFNY_LOCK is passed through to diff_policy.py (one Dafny process at a time).
"""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
TOOL = 'src/airlock/py/diff_policy.py'
POL = 'tests/airlock/policies/'
sys.path.insert(0, str(ROOT / 'src/airlock/py'))
import policy_model as pm  # noqa: E402

DEMO_CHANGED = {
    ('GOODWILL', 2001, 0, 'shipping_paid=1000'): ('REJECTED_POLICY NO_RULE', 'REQUIRE_HUMAN_COSIGN'),
    ('GOODWILL', 2002, 0, 'shipping_paid=1000'): ('REJECTED_POLICY NO_RULE', 'REQUIRE_HUMAN_COSIGN'),
    ('GOODWILL', 2011, 0, 'shipping_paid=1000'): ('REJECTED_POLICY NO_RULE', 'REQUIRE_HUMAN_COSIGN'),
    ('SHIPPING', 1001, 0, 'shipping_paid=1000'): ('COMMIT', 'REJECTED_POLICY REASON_CAP'),
    ('SHIPPING', 2011, 0, 'shipping_paid=1000'): ('COMMIT', 'REJECTED_POLICY REASON_CAP'),
    ('SHIPPING', 2, 999, 'shipping_paid=1000'): ('COMMIT', 'REJECTED_POLICY REASON_CAP'),
    ('SHIPPING', 1, 1000, 'shipping_paid=1000'): ('COMMIT', 'REJECTED_POLICY REASON_CAP'),
    ('SHIPPING', 1, 0, 'shipping_paid=0'): ('COMMIT', 'REJECTED_POLICY REASON_CAP'),
}


class Failed(Exception):
    pass


class NotRun(Exception):
    pass


class Suite:
    def __init__(self, engine):
        self.engine = engine
        self.dafny = 0
        self.codes = []

    def work(self, name):
        base = ROOT / 'build/airlock/test-diff-policy'
        number = 1
        while (base / ('%s-%d' % (name, number))).exists():
            number += 1
        return 'build/airlock/test-diff-policy/%s-%d' % (name, number)

    def cli(self, args, work_name=None, engine=True):
        argv = [sys.executable, TOOL] + list(args)
        if engine and self.engine:
            argv += ['--engine', self.engine]
        elif engine:
            argv += ['--allow-no-engine']
        work = None
        if work_name and '--no-clearing' not in args:
            work = self.work(work_name)
            argv += ['--work', work]
        child = subprocess.run(argv, cwd=ROOT, capture_output=True)
        err = child.stderr.decode()
        found = re.search(r'dafny_processes=(\d+)', err)
        self.dafny += int(found.group(1)) if found else 0
        self.codes.append(child.returncode)
        return child.returncode, child.stdout.decode(), err, work

    def json_cli(self, args, work_name=None, engine=True):
        code, out, err, work = self.cli(list(args) + ['--json'], work_name, engine)
        try:
            return code, json.loads(out), err, work
        except ValueError:
            raise Failed('output is not JSON (exit %d): %s' % (code, err.strip()[-200:]))


def expect(condition, text):
    if not condition:
        raise Failed(text)


def clean(work):
    if work:
        shutil.rmtree(ROOT / work, ignore_errors=True)


def case_loader(s):
    good = ['demo-old.json', 'demo-new.json', 'ambiguous.json', 'reject-rule.json', 'saga-old.json', 'saga-new.json']
    for name in good:
        pm.load_policy((ROOT / POL / name).read_bytes())
    bad = sorted(p.name for p in (ROOT / POL).glob('bad-*.json'))
    expect(len(bad) >= 10, 'fewer than 10 bad fixtures')
    for name in bad:
        try:
            pm.load_policy((ROOT / POL / name).read_bytes())
        except pm.Malformed:
            continue
        raise Failed('loader accepted ' + name)
    return '%d valid loaded, %d bad refused' % (len(good), len(bad))


def case_malformed(s):
    bad = sorted(p.name for p in (ROOT / POL).glob('bad-*.json'))
    before = s.dafny
    engine_refused = 0
    for name in bad:
        code, out, err, _ = s.cli([POL + name, POL + 'demo-old.json'])
        expect(code == 2 and 'MALFORMED' in out, '%s: exit %d' % (name, code))
        code, out, err, _ = s.cli([POL + 'demo-old.json', POL + name])
        expect(code == 2, '%s as new: exit %d' % (name, code))
        expect('work folder' not in err, '%s: a work folder was made' % name)
        if s.engine:
            child = subprocess.run([s.engine, 'eval', POL + name], cwd=ROOT, input=b'', capture_output=True)
            engine_refused += child.returncode != 0
    expect(s.dafny == before, 'a Dafny process started for a malformed policy')
    expect(not s.engine or engine_refused == len(bad), 'the engine accepts a fixture that the loader refuses')
    extra = '; engine also refuses %d of %d' % (engine_refused, len(bad)) if s.engine else '; engine NOT RUN'
    return '%d bad fixtures refused before any Dafny start%s' % (len(bad), extra)


def case_no_engine(s):
    code, report, _, _ = s.json_cli([POL + 'demo-old.json', POL + 'demo-new.json', '--no-clearing',
                                     '--engine', 'build/airlock/no-such-engine'], engine=False)
    expect(code == 7, 'exit %d, not 7' % code)
    expect(report['engine'] == 'NOT RUN' and all(r['engine'] == 'NOT RUN' for r in report['rows']),
           'a row does not say engine NOT RUN')
    code, report, _, _ = s.json_cli([POL + 'demo-old.json', POL + 'demo-new.json', '--no-clearing',
                                     '--engine', 'build/airlock/no-such-engine', '--allow-no-engine'], engine=False)
    expect(code == 3, '--allow-no-engine --no-clearing: exit %d, not 3' % code)
    return 'NOT RUN marked on %d rows; exit 7, and 3 with --allow-no-engine --no-clearing' % len(report['rows'])


def case_engine(s):
    if not s.engine:
        raise NotRun('engine binary absent')
    code, report, err, _ = s.json_cli([POL + 'demo-old.json', POL + 'demo-new.json', '--no-clearing'])
    expect(report['engine'] == 'RAN', 'engine did not run: ' + err.strip()[-200:])
    expect(code == 3, 'exit %d, not 3 (%s)' % (code, report.get('result')))
    expect(not any(r['mismatch'] for r in report['rows']), 'engine and evaluator differ')
    rows = len(report['rows'])
    for pair in (('ambiguous.json', 'ambiguous.json'), ('demo-new.json', 'reject-rule.json')):
        code, report, err, _ = s.json_cli([POL + pair[0], POL + pair[1], '--no-clearing'])
        expect(code == 3, '%s: exit %d, not 3 (%s) %s' % (pair[1], code, report.get('result'), err.strip()[-200:]))
        rows += len(report['rows'])
    return 'engine answered %d scenario rows over 3 pairs; no mismatch with the evaluator' % rows


def case_mismatch(s):
    """Control for TABLE_MISMATCH: a STAND-IN engine (a test double of `airlock-engine eval`) that answers COMMIT to
    every scenario. The table must flag the rows where the evaluator says otherwise, and the exit code is 6."""
    folder = ROOT / s.work('standin-engine')
    folder.mkdir(parents=True)
    engine = folder / 'airlock-engine'
    engine.write_text('#!/bin/sh\n# STAND-IN ENGINE: COMMIT for every line\nwhile IFS= read -r line; do echo COMMIT; done\n')
    engine.chmod(0o700)
    try:
        code, report, err, _ = s.json_cli([POL + 'demo-old.json', POL + 'demo-new.json', '--no-clearing', '--engine', str(engine)], engine=False)
        flagged = sum(1 for r in report['rows'] if r['mismatch'])
        expect(report['engine'] == 'RAN', 'the stand-in engine did not run: ' + err.strip()[-200:])
        expect(flagged > 0 and report['result'] == 'TABLE_MISMATCH' and code == 6,
               'an engine that differs from the evaluator: %d rows flagged, result %s, exit %d (expected TABLE_MISMATCH, 6)' % (flagged, report['result'], code))
    finally:
        shutil.rmtree(folder, ignore_errors=True)
    return 'STAND-IN engine (COMMIT for all): %d of %d rows flagged, exit 6' % (flagged, len(report['rows']))


def case_demo(s):
    code, report, err, work = s.json_cli([POL + 'demo-old.json', POL + 'demo-new.json'], 'demo')
    changed = {(r['reason'], r['amount'], r['reason_total'], r['facts']): (r['before'], r['after'])
               for r in report['rows'] if r['changed']}
    expect(changed == DEMO_CHANGED, 'changed rows differ: %s' % sorted(set(changed) ^ set(DEMO_CHANGED)))
    for side in ('old', 'new'):
        expect(report['crosscheck'][side]['passed'], side + ' cross-check failed')
        expect(report['clearing'][side]['verdict'] == 'NO_CHOICE',
               side + ' verdict ' + report['clearing'][side]['verdict'])
    expect(code == 0, 'exit %d, not 0 (%s)' % (code, report['result']))
    clean(work)
    return '%d rows, %d changed as expected; old NO_CHOICE, new NO_CHOICE' % (len(report['rows']), len(changed))


def case_choice(s):
    code, report, err, work = s.json_cli([POL + 'ambiguous.json', POL + 'ambiguous.json'], 'choice')
    result = report['clearing']['old']
    expect(result['verdict'] == 'CHOICE', 'verdict ' + result['verdict'])
    witness = result['witness'] or {}
    expect(witness.get('input', '').startswith('reason=GOODWILL amount=2001 '), 'witness input ' + str(witness))
    expect({witness.get('verdict_one'), witness.get('verdict_two')} == {'COMMIT', 'REQUIRE_HUMAN_COSIGN'},
           'witness verdicts')
    expect(report['crosscheck']['old']['passed'], 'cross-check failed')
    expect(code == 4, 'exit %d, not 4' % code)
    clean(work)
    return 'CHOICE at %s: %s / %s' % (witness['input'], witness['verdict_one'], witness['verdict_two'])


def case_fault(s):
    parts = []
    for rule in (2, 3):     # rule 2 loses its max_amount, rule 3 its min_amount
        code, report, err, work = s.json_cli([POL + 'demo-new.json', POL + 'demo-new.json',
                                              '--test-fault', 'drop-bound:%d' % rule], 'fault')
        check = report['crosscheck']['old']
        expect(not check['passed'] and check['failed'], 'rule %d: the cross-check did not fail' % rule)
        expect(report['result'] == 'CROSSCHECK_FAILED' and code == 8, 'rule %d: exit %d, not 8' % (rule, code))
        parts.append('drop-bound:%d -> cross-check FAILED on %s; clearing said %s' % (
            rule, ','.join(check['failed']), report['clearing']['old']['verdict']))
        clean(work)
    return '; '.join(parts)


def case_refused(s):
    parts = []
    for fault in ('bodiless-lemma', 'expect'):
        code, report, err, work = s.json_cli([POL + 'ambiguous.json', POL + 'ambiguous.json',
                                              '--test-fault', fault], 'refused-' + fault)
        verdict = report['clearing']['old']['verdict']
        expect(verdict == 'LINK_BROKEN', '%s: verdict %s, not LINK_BROKEN' % (fault, verdict))
        expect(code == 5, '%s: exit %d, not 5' % (fault, code))
        parts.append('%s -> %s (exit %d)' % (fault, verdict, code))
        clean(work)
    # The same with the demo policy, which is NO_CHOICE without a fault.
    code, report, err, work = s.json_cli([POL + 'demo-new.json', POL + 'demo-new.json',
                                          '--test-fault', 'bodiless-lemma'], 'refused-demo')
    verdict = report['clearing']['old']['verdict']
    expect(verdict == 'LINK_BROKEN', 'demo bodiless: verdict ' + verdict)
    parts.append('demo bodiless-lemma -> %s (exit %d)' % (verdict, code))
    clean(work)
    return '; '.join(parts)


def case_saga(s):
    code, report, err, _ = s.json_cli([POL + 'saga-old.json', POL + 'saga-new.json'])
    expect(code == 0, 'exit %d' % code)
    expect(report['transitions_removed'] == [['CONFIRMED_REJECTED', 'IN_FLIGHT']], 'removed')
    expect(report['transitions_added'] == [['SETTLED', 'REFUNDED']], 'added')
    expect(len(report['transitions_kept']) == 3 and report['states_added'] == ['REFUNDED'], 'kept or states')
    expect(report['clearing'] == 'NOT APPLICABLE', 'clearing')
    code, out, err, _ = s.cli([POL + 'saga-old.json', POL + 'demo-old.json'])
    expect(code == 2, 'mixed kinds: exit %d' % code)
    return '1 removed, 1 added, 3 kept, 1 state added; mixed kinds exit 2'


def case_identical(s):
    outputs = []
    for run in (1, 2):
        code, out, err, work = s.cli([POL + 'demo-old.json', POL + 'demo-new.json'], 'identical')
        outputs.append((code, out))
        clean(work)
    expect(outputs[0] == outputs[1], 'the two outputs differ')
    expect(re.search(r'(^|[\s(])/(Users|private|tmp|home)/', outputs[0][1]) is None, 'an absolute path in output')
    return 'two runs byte-identical (%d bytes, exit %d)' % (len(outputs[0][1]), outputs[0][0])


CASES = [('loader', case_loader), ('malformed', case_malformed), ('no-engine', case_no_engine),
         ('engine', case_engine), ('mismatch', case_mismatch), ('demo', case_demo), ('choice', case_choice), ('fault', case_fault),
         ('refused', case_refused), ('saga', case_saga), ('identical', case_identical)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', default=None)
    parser.add_argument('--case', action='append', default=[])
    args = parser.parse_args()
    names = [name for name, _ in CASES]
    if any(c not in names for c in args.case):
        print('unknown case; cases: ' + ', '.join(names), file=sys.stderr)
        return 2
    engine = args.engine
    if engine is None and (ROOT / 'build/airlock/airlock-engine').is_file():
        engine = 'build/airlock/airlock-engine'
    print('engine: %s' % ('RAN path given' if engine else 'NOT RUN (binary absent; cases use --allow-no-engine)'))
    s = Suite(engine)
    bad = 0
    for name, function in CASES:
        if args.case and name not in args.case:
            continue
        s.codes, start, dafny_before = [], time.monotonic(), s.dafny
        try:
            detail = function(s)
            state = 'PASS'
        except NotRun as reason:
            state, detail = 'NOT RUN', str(reason)
            bad += 1
        except Failed as reason:
            state, detail = 'FAIL', str(reason)
            bad += 1
        codes = ','.join(str(c) for c in s.codes) or '-'
        print('%-9s %-7s exits=[%s] dafny_processes=%d wall=%.1fs | %s' % (
            name, state, codes if len(codes) < 60 else codes[:57] + '...', s.dafny - dafny_before,
            time.monotonic() - start, detail))
    print('RESULT: %s' % ('PASS' if bad == 0 else 'FAIL or NOT RUN (%d)' % bad))
    return 0 if bad == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
