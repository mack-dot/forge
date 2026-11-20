#!/usr/bin/env python3
"""Suite of `intent_clearing.py check-intent` (Goal 21, Gate F1). FINITE TEST. Python stdlib only. It proves nothing.

  python3 tests/intent/test_intent_clearing.py [--case NAME]...

Cases:
  loader        both formats load; bad inputs are refused in process, and by the CLI with exit 2 and 0 Dafny processes
  ast           the canonical AST of each fixture is stable (two `ast` runs, and equal to the loader) and format A maps
                min_amount/max_amount/max_reason_total_fact as designed
  clean         each clean fixture with its queries: exit 0, every query NO, the seal PROVED, no undecided cell
  planted       each planted fixture with its queries: exit 4, the named query is a WARNING with a Dafny-verified witness
                that the evaluator confirms; the row at the changed boundary differs from the clean twin
  ambiguous     tests/airlock/policies/ambiguous.json: an AMBIGUOUS row and exit 4
  dead-rule     tests/intent/specs/t-dead-rule.json: a DEAD RULE warning and exit 4
  faults        drop-bound and flip-op give UNDECIDED (5); bodiless-lemma and expect give LINK_BROKEN (6); never CLEAN
  undecided     scramble-candidate: no row comes from the (changed) solver values; scramble-all: no row at all, exit 5
  pm-crosscheck every format A row agrees with policy_model.allowed (an independent second transcription)
  identical     two runs give byte-identical stdout, for text and for --json; no absolute path, no work folder
  too-large     tests/intent/specs/t-too-large.json: exit 9 and 0 Dafny processes
  restater      bullets present, the trust line, and the --request text after them in its own section

One line per case with the actual exit codes. Exit 0: every selected case passed. 1: a case failed or was NOT RUN.
2: bad arguments. Work folders are new folders under build/intent/test/ and are removed after each run.
"""

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
TOOL = 'scripts/intent_clearing.py'
SPECS, QUERIES = 'tests/intent/specs/', 'tests/intent/queries/'
sys.path.insert(0, str(ROOT / 'scripts'))
import intent_clearing as ic  # noqa: E402
pm = ic.pm

PAIRS = [  # (clean, planted, queries, named query, (clean cell, planted cell) at the changed boundary)
    ('boundary-clean', 'boundary-planted-inclusive', 'boundary', 'EDGE-1', ('amount=5000', 'amount=5000')),
    ('vip-clean', 'vip-planted-swapped-flag', 'vip', 'VIP-1', ('amount=5001, vip=0', 'amount=5001, vip=0')),
    ('shipping-clean', 'shipping-planted-coarse-cap', 'shipping', 'SHIP-1',
     ('amount=10000, shipping_paid missing', 'amount=10000')),
]
GOOD = ['boundary-clean', 'boundary-planted-inclusive', 'vip-clean', 'vip-planted-swapped-flag', 'shipping-clean',
        'shipping-planted-coarse-cap', 't-dead-rule', 't-too-large']
EXTRA_A = ['examples/unbreakable_store/policies/refunds-v2.json', 'tests/airlock/policies/ambiguous.json']
MONEY = '{"airlock": "money", "version": 1, "name": "x", "profile": "parametric", "rules": [%s]}'
SPEC_B = '{"intent_spec": 1, "name": "x", "rules": [%s]}'
RULE_B = '{"reason": "G", "verdict": "COMMIT"%s}'
BAD = {
    'unknown-key': SPEC_B % RULE_B % ', "colour": "red"',
    'duplicate-key': SPEC_B % RULE_B % ', "verdict": "COMMIT"',
    'float': SPEC_B % RULE_B % ', "amount": [["<=", 5.5]]',
    'number-not-string': SPEC_B % RULE_B % ', "amount": [["<=", 55]]',
    'bad-op': SPEC_B % RULE_B % ', "amount": [["=<", "5"]]',
    'non-canonical-decimal': SPEC_B % RULE_B % ', "amount": [["<=", "0050"]]',
    'too-big-decimal': SPEC_B % RULE_B % ', "amount": [["<=", "9223372036854775808"]]',
    '65-rules': SPEC_B % ', '.join([RULE_B % ''] * 65),
    'no-rules': SPEC_B % '',
    'description-key': '{"intent_spec": 1, "name": "x", "description": "refund up to 50", "rules": [%s]}' % (RULE_B % ''),
    'bad-id': SPEC_B % '{"reason": "G!", "verdict": "COMMIT"}',
    'bad-verdict': SPEC_B % '{"reason": "G", "verdict": "ALLOW"}',
    '9-amount-atoms': SPEC_B % RULE_B % (', "amount": [%s]' % ', '.join(['["<=", "5"]'] * 9)),
    'version-2': '{"intent_spec": 2, "name": "x", "rules": [%s]}' % (RULE_B % ''),
    'money-min-above-max': MONEY % '{"reason": "G", "min_amount": "9", "max_amount": "5", "verdict": "COMMIT"}',
    'money-description': MONEY % '{"reason": "G", "verdict": "COMMIT", "description": "x"}',
    'not-json': '{"intent_spec": 1,',
}
BAD_FILES = {'saga-policy': 'tests/airlock/policies/saga-old.json'}
BAD_QUERIES = {
    'query-unknown-key': '{"intent_queries": 1, "queries": [{"id": "Q", "question": "q?", "where": [["amount", ">", "1"]], "note": "x"}]}',
    'query-bad-term': '{"intent_queries": 1, "queries": [{"id": "Q", "question": "q?", "where": [["payout", ">", "1"]]}]}',
    'query-duplicate-id': '{"intent_queries": 1, "queries": [{"id": "Q", "question": "q?", "where": [["amount", ">", "1"]]}, '
                          '{"id": "Q", "question": "q?", "where": [["amount", ">", "1"]]}]}',
}


class Failed(Exception):
    pass


class NotRun(Exception):
    pass


def expect(condition, text):
    if not condition:
        raise Failed(text)


class Suite:
    def __init__(self):
        self.dafny, self.codes, self.cache, self.number = 0, [], {}, 0
        self.scratch = ROOT / 'build/intent/test'

    def cli(self, args, cache=True):
        key = tuple(args)
        if cache and key in self.cache:
            self.codes.append(self.cache[key][0])
            return self.cache[key]
        argv = [sys.executable, '-B', TOOL] + list(args)
        work = None
        if args[0] == 'check-intent':
            self.number += 1
            work = 'build/intent/test/run-%d' % self.number
            while (ROOT / work).exists():
                self.number += 1
                work = 'build/intent/test/run-%d' % self.number
            argv += ['--work', work]
        child = subprocess.run(argv, cwd=ROOT, capture_output=True)
        err = child.stderr.decode()
        found = re.search(r'dafny_processes=(\d+)', err)
        self.dafny += int(found.group(1)) if found else 0
        self.codes.append(child.returncode)
        if work:
            shutil.rmtree(ROOT / work, ignore_errors=True)
        out = (child.returncode, child.stdout.decode(), err)
        if cache:
            self.cache[key] = out
        return out

    def report(self, spec, queries=None, extra=(), cache=True):
        args = ['check-intent', spec] + (['--queries', queries] if queries else []) + list(extra) + ['--json']
        code, out, err = self.cli(args, cache)
        try:
            return code, json.loads(out)
        except ValueError:
            raise Failed('%s: output is not JSON (exit %d): %s' % (spec, code, err.strip()[-300:]))

    def write(self, name, text):
        self.scratch.mkdir(parents=True, exist_ok=True)
        path = self.scratch / name
        path.write_text(text)
        return 'build/intent/test/' + name


def spec(name):
    return SPECS + name + '.json'


def restater_present():
    return (ROOT / 'scripts/intent_restate.py').is_file()


def rows_by_cell(report):
    return {r['cell']: r for r in report['table']['rows']}


def scenario_of(ast, row):
    facts = {f: v for f, v in row['facts'].items() if v is not None and f in ast['facts']}
    other = 'UNLISTED'
    while other in ast['reasons']:
        other += '_'
    reason = other if row['reason'] == ic.UNNAMED else row['reason']
    return pm.scenario(reason, row['amount'], row['remaining'], row['reason_total'], facts)


def evaluator_allowed(ast, row):
    model = ic.Model(ast, [f for f in row['facts'] if f not in ast['facts']])
    inp = {'reason': ic.OTHER if row['reason'] == ic.UNNAMED else model.rx[row['reason']], 'amount': row['amount'],
           'remaining': row['remaining'], 'reason_total': row['reason_total'],
           'facts': [row['facts'][f] for f in model.facts]}
    return model.allowed(inp)


def case_loader(s):
    names = [spec(n) for n in GOOD] + EXTRA_A
    for name in names:
        ic.load_spec((ROOT / name).read_bytes())
    bad = {k: v.encode() for k, v in BAD.items()}
    bad.update({k: (ROOT / v).read_bytes() for k, v in BAD_FILES.items()})
    for label, data in bad.items():
        try:
            ic.load_spec(data)
        except pm.Malformed:
            continue
        raise Failed('the loader accepted ' + label)
    for label, text in BAD_QUERIES.items():
        try:
            ic.load_queries(text.encode())
        except pm.Malformed:
            continue
        raise Failed('the query loader accepted ' + label)
    before = s.dafny
    for label, data in bad.items():
        path = s.write('bad-%s.json' % label, data.decode('utf-8', 'replace')) if label not in BAD_FILES else BAD_FILES[label]
        code, out, err = s.cli(['check-intent', path])
        expect(code == 2 and 'MALFORMED' in out, '%s: exit %d' % (label, code))
        expect('work folder' not in err, '%s: a work folder was made' % label)
    for label, text in BAD_QUERIES.items():
        code, out, err = s.cli(['check-intent', spec('boundary-clean'), '--queries', s.write(label + '.json', text)])
        expect(code == 2, '%s: exit %d' % (label, code))
    expect(s.dafny == before, 'a Dafny process started for a malformed input')
    return '%d specs loaded; %d bad specs and %d bad query files refused (exit 2, 0 Dafny processes)' % (
        len(names), len(bad), len(BAD_QUERIES))


def case_ast(s):
    for name in [spec(n) for n in GOOD] + EXTRA_A:
        one, two = s.cli(['ast', name], cache=False), s.cli(['ast', name], cache=False)
        expect(one[0] == 0 and one == two, name + ': two ast runs differ or exit != 0')
        expect(one[1].encode() == ic.canonical(ic.load_spec((ROOT / name).read_bytes())[0]), name + ': not the canonical AST')
    ast = json.loads(s.cli(['ast', spec('shipping-clean')])[1])
    expect(ast['source_format'] == 'airlock-money-v1' and ast['facts'] == ['shipping_paid'], 'shipping AST head')
    expect(ast['rules'] == [{'index': 0, 'reason': 'SHIPPING', 'verdict': 'COMMIT', 'amount': [['<=', 10000]],
                             'when': [], 'cap_fact': 'shipping_paid'}], 'shipping AST rule: %s' % ast['rules'])
    ast = json.loads(s.cli(['ast', EXTRA_A[0]])[1])
    expect(ast['rules'][3]['amount'] == [['>=', 5001]] and ast['rules'][2]['amount'] == [['<=', 5000]], 'min/max map')
    expect(ast['reasons'] == ['DUPLICATE_CHARGE', 'GOODWILL', 'SHIPPING'], 'reasons sorted')
    vip = json.loads(s.cli(['ast', spec('vip-clean')])[1])
    expect(vip['rules'][0]['when'] == [['vip', '==', 0]] and vip['source_format'] == 'intent-spec-v1', 'format B when')
    return '%d fixtures: stable canonical AST; format A maps min/max/cap as designed' % (len(GOOD) + len(EXTRA_A))


def expected(code):
    """Exit 0/4 when the restater is present. Without it the run must say RESTATER_FAILED (3)."""
    return code if restater_present() else 3


def case_clean(s):
    parts = []
    for clean, _, queries, _, _ in PAIRS:
        code, rep = s.report(spec(clean), QUERIES + queries + '.json')
        expect(code == expected(0), '%s: exit %d (%s)' % (clean, code, rep['result']))
        expect(all(q['answer'] == 'NO' for q in rep['queries']), clean + ': a query is not NO')
        expect(rep['table']['seal']['same_cell'] == 'PROVED' and rep['table']['seal']['coverage'] == 'PROVED', clean + ': seal')
        expect(not rep['table']['undecided_cells'] and rep['end_to_end'] is False, clean + ': undecided cell')
        parts.append('%s %d rows, %d queries NO' % (clean, len(rep['table']['rows']), len(rep['queries'])))
    if not restater_present():
        raise NotRun('restater absent; exit 3 seen; ' + '; '.join(parts))
    return '; '.join(parts)


def case_planted(s):
    parts = []
    for clean, planted, queries, named, (cell_clean, cell_planted) in PAIRS:
        code, rep = s.report(spec(planted), QUERIES + queries + '.json')
        _, twin = s.report(spec(clean), QUERIES + queries + '.json')
        expect(code == expected(4), '%s: exit %d (%s)' % (planted, code, rep['result']))
        query = next(q for q in rep['queries'] if q['id'] == named)
        expect(query['answer'] == 'WARNING' and query['witness'], '%s: %s is %s' % (planted, named, query['answer']))
        expect(query['witness']['text'] == ic.INTENDED, 'warning sentence')
        expect(rep['table']['seal']['coverage'] == 'PROVED', planted + ': seal')
        before, after = rows_by_cell(twin)[cell_clean], rows_by_cell(rep)[cell_planted]
        expect(before['decision'] != after['decision'], '%s: the boundary row did not change' % planted)
        parts.append('%s: %s WARNING (%s); %s %s -> %s' % (planted, named, query['witness']['input'], cell_planted,
                                                           before['decision'], after['decision']))
    if not restater_present():
        raise NotRun('restater absent; exit 3 seen; ' + '; '.join(parts))
    return '; '.join(parts)


def case_ambiguous(s):
    code, rep = s.report(EXTRA_A[1])
    rows = [r for r in rep['table']['rows'] if 'AMBIGUOUS' in r['tags']]
    expect(rows and all(set(r['allowed']) == {'COMMIT', 'REQUIRE_HUMAN_COSIGN'} for r in rows), 'no AMBIGUOUS row')
    expect(any(w.startswith('AMBIGUOUS') for w in rep['warnings']), 'no AMBIGUOUS warning')
    expect(code == expected(4), 'exit %d (%s)' % (code, rep['result']))
    return '%d AMBIGUOUS rows (first: amount %d); exit %d' % (len(rows), rows[0]['amount'], code)


def case_dead_rule(s):
    code, rep = s.report(spec('t-dead-rule'))
    dead = [e for e in rep['table']['empty_cells'] if e['dead_rule']]
    expect([e['cell'] for e in dead] == ['rule 1 matches (REQUIRE_HUMAN_COSIGN)'], 'dead cells: %s' % dead)
    expect(any(w.startswith('DEAD RULE') for w in rep['warnings']) and code == expected(4), 'exit %d' % code)
    return 'DEAD RULE: %s; exit %d' % (dead[0]['cell'], code)


def case_faults(s):
    parts = []
    for name, fault, want in (('boundary-clean', 'drop-bound:0', 5), ('boundary-planted-inclusive', 'flip-op:0', 5),
                              ('boundary-clean', 'bodiless-lemma', 6), ('boundary-clean', 'expect', 6),
                              ('shipping-clean', 'flip-op:0', 5)):
        code, out, err = s.cli(['check-intent', spec(name), '--queries', QUERIES + name.split('-')[0] + '.json',
                                '--test-fault', fault])
        expect('TEST FAULT ACTIVE' in out, fault + ': no TEST FAULT ACTIVE line')
        expect(code == want, '%s on %s: exit %d, not %d' % (fault, name, code, want))
        parts.append('%s -> %d' % (fault, code))
    code, out, err = s.cli(['check-intent', spec('boundary-clean'), '--test-fault', 'flip-op:0'])
    expect(code == 1, 'a fault that changes nothing: exit %d, not 1' % code)
    return '; '.join(parts) + '; no-op fault refused (1)'


def case_undecided(s):
    code, rep = s.report(spec('boundary-clean'), QUERIES + 'boundary.json', ['--test-fault', 'scramble-candidate'])
    ast = ic.load_spec((ROOT / spec('boundary-clean')).read_bytes())[0]
    rows = rep['table']['rows']
    expect(rows and all(r['source'] == 'python-candidate' for r in rows), 'a row from the changed solver values')
    expect(all(r['amount'] <= pm.MAX_MONEY for r in rows), 'a row with the changed amount')
    expect(all(r['allowed'] == evaluator_allowed(ast, r) for r in rows), 'a row differs from the evaluator')
    first = code
    code, rep = s.report(spec('boundary-clean'), QUERIES + 'boundary.json', ['--test-fault', 'scramble-all'])
    expect(not rep['table']['rows'] and rep['table']['undecided_cells'], 'scramble-all showed a row')
    expect(code == 5 and rep['result'] == 'UNDECIDED', 'scramble-all: exit %d' % code)
    expect(not any(q['witness'] for q in rep['queries']), 'scramble-all showed a witness')
    return 'scramble-candidate: %d rows, all python-candidate, exit %d; scramble-all: 0 rows, %d undecided, exit 5' % (
        len(rows), first, len(rep['table']['undecided_cells']))


def case_pm_crosscheck(s):
    total = 0
    for name, queries in ((spec('shipping-clean'), QUERIES + 'shipping.json'),
                          (spec('shipping-planted-coarse-cap'), QUERIES + 'shipping.json'), (EXTRA_A[0], None), (EXTRA_A[1], None)):
        code, rep = s.report(name, queries)
        expect(rep['result'] != 'GENERATOR_MISMATCH', name + ': GENERATOR_MISMATCH')
        policy = pm.load_policy((ROOT / name).read_bytes())
        ast = ic.load_spec((ROOT / name).read_bytes())[0]
        for row in rep['table']['rows']:
            got = pm.allowed(policy, scenario_of(ast, row))
            expect(sorted(got) == sorted(row['allowed']), '%s row %d: %s vs %s' % (name, row['n'], got, row['allowed']))
            expect(pm.decide(policy, scenario_of(ast, row)) == row['decision'], '%s row %d decision' % (name, row['n']))
            total += 1
    return '%d format A rows over 4 specs agree with policy_model.allowed and decide' % total


def case_identical(s):
    parts = []
    for extra in ([], ['--json']):
        args = ['check-intent', spec('boundary-planted-inclusive'), '--queries', QUERIES + 'boundary.json'] + extra
        one, two = s.cli(args, cache=False), s.cli(args, cache=False)
        expect(one[:2] == two[:2], 'two runs differ (%s)' % (extra or 'text'))
        expect(re.search(r'(^|[\s("])/(Users|private|tmp|home|var)/', one[1]) is None, 'an absolute path in output')
        expect('build/intent' not in one[1], 'the work folder is in the output')
        parts.append('%s %d bytes exit %d' % ('json' if extra else 'text', len(one[1]), one[0]))
    return 'two runs byte-identical: ' + '; '.join(parts)


def case_too_large(s):
    before = s.dafny
    code, out, err = s.cli(['check-intent', spec('t-too-large')])
    expect(code == 9 and 'TABLE_TOO_LARGE' in out, 'exit %d' % code)
    expect(s.dafny == before and 'work folder' not in err, 'a Dafny process or a work folder')
    return re.search(r'the table has \d+ cells', out).group(0) + '; exit 9, 0 Dafny processes'


def case_restater(s):
    if not restater_present():
        raise NotRun('scripts/intent_restate.py absent')
    request = s.write('request.txt', 'Refund GOODWILL up to 49.99 without a human; from 50.00 a human cosigns.\n')
    code, out, err = s.cli(['check-intent', spec('boundary-clean'), '--request', request])
    sections = [line for line in out.splitlines() if line.startswith('== ')]
    expect(sections[-2:] == ['== blind restatement ==', '== request text (never given to the restater) =='], 'sections')
    block = out.split('== blind restatement ==\n', 1)[1].split('\n\n', 1)[0].splitlines()
    expect(block[0] == ic.TRUST and len(block) > 1 and all(b.startswith('- ') for b in block[1:]), 'bullets')
    expect('49.99' not in out.split('== request text')[0], 'the request text is before its section')
    expect(code == 0, 'exit %d' % code)
    return '%d bullets, trust line, request text in its own section; exit %d' % (len(block) - 1, code)


CASES = [('loader', case_loader), ('ast', case_ast), ('clean', case_clean), ('planted', case_planted),
         ('ambiguous', case_ambiguous), ('dead-rule', case_dead_rule), ('faults', case_faults),
         ('undecided', case_undecided), ('pm-crosscheck', case_pm_crosscheck), ('identical', case_identical),
         ('too-large', case_too_large), ('restater', case_restater)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--case', action='append', default=[])
    args = parser.parse_args()
    names = [name for name, _ in CASES]
    if any(c not in names for c in args.case):
        print('unknown case; cases: ' + ', '.join(names), file=sys.stderr)
        return 2
    print('restater: %s' % ('present' if restater_present() else 'ABSENT (cases that need it are NOT RUN)'))
    s, bad = Suite(), 0
    for name, function in CASES:
        if args.case and name not in args.case:
            continue
        s.codes, start, dafny_before = [], time.monotonic(), s.dafny
        try:
            detail, state = function(s), 'PASS'
        except NotRun as reason:
            state, detail, bad = 'NOT RUN', str(reason), bad + 1
        except Failed as reason:
            state, detail, bad = 'FAIL', str(reason), bad + 1
        codes = ','.join(str(c) for c in s.codes) or '-'
        print('%-13s %-7s exits=[%s] dafny_processes=%d wall=%.1fs | %s' % (
            name, state, codes if len(codes) < 60 else codes[:57] + '...', s.dafny - dafny_before,
            time.monotonic() - start, detail))
    shutil.rmtree(s.scratch, ignore_errors=True)
    print('RESULT: %s' % ('PASS' if bad == 0 else 'FAIL or NOT RUN (%d)' % bad))
    return 0 if bad == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
