#!/usr/bin/env python3
"""forge-airlock `diff-policy` (Goal 20, L2). Python stdlib only. end_to_end=false.

  python3 src/airlock/py/diff_policy.py <old.json> <new.json> [--engine PATH] [--no-clearing]
                                        [--allow-no-engine] [--work build/airlock/diff-XXXX] [--json]

What it does, for two MONEY policies (proposals/forge2-goal20-sdk/DESIGN.md):
  1. Loads both with the strict loader of policy_model.py. A refused policy stops the run before any
     engine or Dafny start.
  2. SCENARIO TABLE. A finite, deterministic list of boundary scenarios from the thresholds of BOTH
     policies. Each scenario is evaluated under Old and New by the ENGINE (`airlock-engine eval
     <policy.json>`, one `EVAL ...` line per scenario) and by an independent Python evaluator. Any
     difference is TABLE_MISMATCH. Label: NATIVE CHECK (engine, not proved) on FINITE scenarios.
     Without the engine binary every row says `engine: NOT RUN`.
  3. GENERATOR CROSS-CHECK. A small deterministic generator writes ONE policy as Dafny text: a
     relation Allowed(input, verdict) that follows the rule list (built-in total cap first; a matching
     rule allows its verdict; no rule -> REJECTED_POLICY REASON_CAP or NO_RULE, as the engine does; see
     policy_model.py). For every table scenario the
     generator writes one lemma: the set of verdicts that the Dafny model allows is EXACTLY the set that
     the Python evaluator allows (and the engine answer must be the most restrictive one of that set,
     step 2). The pinned Dafny must verify every lemma. A generator that does not follow the JSON on a
     boundary scenario fails here (CROSSCHECK_FAILED). The generator is a TRUSTED ASSUMPTION (owner
     decision, Goal 20 plan line 8); this check and the negative controls in
     tests/airlock/test_diff_policy.py limit it. They do not prove it.
  4. NO_CHOICE through scripts/spec_clearing.py (by import; its main() reads only
     clearing/subjects.json). This file builds the subject, calls spec_clearing.clear_spec, and prints
     the verdict that spec_clearing returns. It never upgrades a verdict. For a CHOICE the witness is
     two refinements of the generated specification that Dafny verified; this file prints the input and
     the two verdicts that the witness asserts. Label: PROVED CORE for the GENERATED Dafny model only.
     Nothing is said about inputs outside that model or about the Rust engine.
     Semantic point: the engine resolves an ambiguous match by "most restrictive wins", so an ambiguous
     policy is not unsafe in the engine. CHOICE says that the POLICY TEXT allows two different verdicts
     for one input; a developer should fix the text.

For two SAGA policies: transitions removed / added / kept, states added / removed, initial and
in-flight changes. No NO_CHOICE claim: a transition table is a set of pairs, not a function to a
verdict, so there is no verdict that can be ambiguous.

Exit codes (when several apply, the first one in this list wins):
  6  TABLE_MISMATCH      the engine and the Python evaluator differ on a scenario
  9  ENGINE_ERROR        the engine ran but did not answer one valid line per scenario with exit 0
  8  CROSSCHECK_FAILED   the generated Dafny model differs from the evaluator on a boundary scenario
  5  UNDECIDED or LINK_BROKEN  from spec_clearing, for at least one policy
  4  CHOICE              spec_clearing verified an ambiguity witness for at least one policy
  7  ENGINE_NOT_RUN      no engine binary, and --allow-no-engine was not given
  3  CLEARING_NOT_RUN    --no-clearing: table printed, no Dafny started, nothing proved
  0  OK                  table printed; money: the engine and the evaluator agree, the cross-check
                         passed and both policies are NO_CHOICE; saga: table printed
  2  MALFORMED           a policy was refused (also: old and new are different airlock kinds)
  1  USAGE               bad arguments, work folder, Dafny lock or Dafny binary missing

--work: a NEW folder under build/, relative to the repository root (default build/airlock/diff-<hash>).
Output is deterministic: no time, no absolute path, no work folder (that goes to stderr).
Test-only switch: --test-fault {drop-bound:N,bodiless-lemma,expect}. It changes the generator and
prints `TEST FAULT ACTIVE`. It exists only for the negative controls.
Environment: FORGE_DAFNY_LOCK=<folder>: each Dafny start takes this folder as a mkdir lock.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import policy_model as pm  # noqa: E402

EXIT = {'OK': 0, 'USAGE': 1, 'MALFORMED': 2, 'CLEARING_NOT_RUN': 3, 'CHOICE': 4, 'UNDECIDED_OR_LINK_BROKEN': 5,
        'TABLE_MISMATCH': 6, 'ENGINE_NOT_RUN': 7, 'CROSSCHECK_FAILED': 8, 'ENGINE_ERROR': 9}
PRIORITY = ['TABLE_MISMATCH', 'ENGINE_ERROR', 'CROSSCHECK_FAILED', 'UNDECIDED_OR_LINK_BROKEN', 'CHOICE',
            'ENGINE_NOT_RUN', 'CLEARING_NOT_RUN']
DEFAULT_ENGINE = 'build/airlock/airlock-engine'
ENGINE_TIMEOUT = 120
LOCK_TIMEOUT = 7200
LABELS = [
    'table rows: NATIVE CHECK (engine, not proved) on FINITE scenarios; the Python evaluator is a second '
    'transcription of the same rules',
    'NO_CHOICE / CHOICE: PROVED CORE (Dafny through scripts/spec_clearing.py) for the GENERATED Dafny model only',
    'generator (JSON -> Dafny): TRUSTED ASSUMPTION (owner decision, plan line 8), limited by the boundary '
    'cross-check and the negative controls; not proved',
    'not claimed: anything about inputs outside the Dafny model, about the Rust engine, or end to end '
    '(end_to_end=false)',
]
SEMANTIC_NOTE = ('the engine resolves an ambiguous match by "most restrictive wins", so an ambiguous policy is '
                 'not unsafe in the engine; CHOICE says the POLICY TEXT allows two different verdicts for one '
                 'input, which a developer should fix')
SAGA_NOTE = ('no NO_CHOICE claim for saga: a transition table is a set of pairs, not a function to a verdict; '
             'there is no verdict that can be ambiguous')

CONSTRUCTOR = {pm.COMMIT: 'Commit', pm.COSIGN: 'RequireHumanCosign', pm.RULE_REJECT: 'RejectedRule',
               pm.ZERO_AMOUNT: 'RejectedZeroAmount', pm.TOTAL_CAP: 'RejectedTotalCap', pm.NO_RULE: 'RejectedNoRule',
               pm.REASON_CAP: 'RejectedReasonCap'}
VERDICTS = [pm.COMMIT, pm.COSIGN, pm.RULE_REJECT, pm.ZERO_AMOUNT, pm.TOTAL_CAP, pm.NO_RULE, pm.REASON_CAP]
SPEC, IMPL, CLAIM, CROSS, WITNESS = 'AirlockMoneySpec', 'AirlockMoneyImpl', 'AirlockMoneyClaim', \
    'AirlockMoneyCrossCheck', 'AirlockMoneyChoice'


class UsageError(Exception):
    pass


# ---------------------------------------------------------------------------------------------------
# Generator: ONE money policy -> Dafny text. TRUSTED ASSUMPTION. Ids are checked again here, so that no
# policy text can reach the Dafny text except as a plain id inside a string literal or as a decimal.
# ---------------------------------------------------------------------------------------------------
def _lit(word):
    if not pm.ID.fullmatch(word):
        raise ValueError('not an id')
    return '"%s"' % word


def _num(value):
    if type(value) is not int:
        raise ValueError('not an integer')
    return str(value)


def dafny_input(prefix, item):
    facts = ', '.join('%s := %s' % (_lit(k), _num(v)) for k, v in item['facts'])
    return '%sMoneyInput(%s, %s, %s, %s, map[%s])' % (
        prefix, _lit(item['reason']), _num(item['amount']), _num(item['remaining']),
        _num(item['reason_total']), facts)


def parse_fault(fault):
    if fault is None:
        return None, None
    if fault in ('bodiless-lemma', 'expect'):
        return fault, None
    if fault.startswith('drop-bound:') and fault[len('drop-bound:'):].isdigit():
        return 'drop-bound', int(fault[len('drop-bound:'):])
    raise UsageError('unknown --test-fault')


def fact_condition(rule):
    fact = _lit(rule['fact'])
    return '(%s in i.facts && i.reasonTotal + i.amount <= i.facts[%s])' % (fact, fact)


def bounds_condition(rule, drop):
    """Dafny condition of the reason and amount bounds of one rule. `drop` (test fault only) leaves out one bound."""
    parts = ['i.reason == %s' % _lit(rule['reason'])]
    low, high = rule['min_amount'], rule['max_amount']
    if drop:
        if high is not None:
            high = None
        else:
            low = None
    if low is not None:
        parts.append('%s <= i.amount' % _num(low))
    if high is not None:
        parts.append('i.amount <= %s' % _num(high))
    return ' && '.join(parts)


def rule_condition(rule, drop):
    condition = bounds_condition(rule, drop)
    return condition + (' && ' + fact_condition(rule) if rule['fact'] is not None else '')


def honest_body(policy, indent):
    lines = ['if i.amount < 1 {', '  v := RejectedZeroAmount;', '} else if i.amount > i.remaining {',
             '  v := RejectedTotalCap;']
    for index, rule in enumerate(policy['rules']):
        lines += ['} else if Rule%d(i) {' % index, '  v := %s;' % CONSTRUCTOR[pm.verdict_text(rule['verdict'])]]
    lines += ['} else if AnyCapped(i) {', '  v := RejectedReasonCap;', '} else {', '  v := RejectedNoRule;', '}']
    return [indent + line for line in lines]


def generate(policy, digest, fault=None):
    """Dafny files for one money policy: {file name: text}. Deterministic."""
    kind, index = parse_fault(fault)
    head = ['// GENERATED by src/airlock/py/diff_policy.py from the money policy %s (policy file sha256 %s).'
            % (_lit(policy['name']), digest),
            '// The generator is a TRUSTED ASSUMPTION (Goal 20 plan line 8). Not an approved specification.']
    if kind:
        # The fault name stays out of the Dafny text: the word of one fault is a word that spec_clearing refuses.
        head.append('// TEST FAULT ACTIVE (diff_policy.py --test-fault). This model does NOT follow the policy.')
    rules = policy['rules']
    spec = head + [
        'abstract module %s {' % SPEC,
        '  const MaxMoney: int := 9223372036854775807',
        '',
        '  datatype Verdict = ' + ' | '.join(CONSTRUCTOR[v] for v in VERDICTS),
        '  datatype Input = MoneyInput(reason: string, amount: int, remaining: int, reasonTotal: int,',
        '                              facts: map<string, int>)',
        '',
        '  predicate ValidInput(i: Input) {',
        '    0 <= i.amount <= MaxMoney && 0 <= i.remaining <= MaxMoney && 0 <= i.reasonTotal <= MaxMoney &&',
        '    forall k | k in i.facts :: 0 <= i.facts[k] <= MaxMoney',
        '  }',
        '']
    for number, rule in enumerate(rules):
        spec += ['  // rule %d: verdict %s' % (number, rule['verdict']),
                 '  predicate Rule%d(i: Input) {' % number,
                 '    ' + rule_condition(rule, kind == 'drop-bound' and index == number),
                 '  }', '']
        if rule['fact'] is not None:
            spec += ['  // rule %d passed its amount bounds and failed its fact cap' % number,
                     '  predicate Capped%d(i: Input) {' % number,
                     '    %s && !%s' % (bounds_condition(rule, kind == 'drop-bound' and index == number),
                                       fact_condition(rule)),
                     '  }', '']
    capped = ['Capped%d(i)' % n for n, rule in enumerate(rules) if rule['fact'] is not None]
    spec += ['  predicate AnyRule(i: Input) {',
             '    ' + ' || '.join('Rule%d(i)' % n for n in range(len(rules))),
             '  }', '',
             '  predicate AnyCapped(i: Input) {',
             '    ' + (' || '.join(capped) if capped else 'false'),
             '  }', '',
             '  // Built-in total cap first; a matching rule allows its verdict; no rule: RejectedReasonCap when a',
             '  // fact rule of the reason failed only its fact cap, else RejectedNoRule.',
             '  predicate Allowed(i: Input, v: Verdict) {',
             '    if i.amount < 1 then v == RejectedZeroAmount',
             '    else if i.amount > i.remaining then v == RejectedTotalCap',
             '    else if !AnyRule(i) then (if AnyCapped(i) then v == RejectedReasonCap else v == RejectedNoRule)',
             '    else ' + ' || '.join('(Rule%d(i) && v == %s)' % (n, CONSTRUCTOR[pm.verdict_text(r['verdict'])])
                                     for n, r in enumerate(rules)),
             '  }', '',
             '  method Decide(i: Input) returns (v: Verdict)',
             '    requires ValidInput(i)',
             '    ensures Allowed(i, v)',
             '}']
    impl = head + ['include "Spec.dfy"', '', 'module %s refines %s {' % (IMPL, SPEC),
                   '  method Decide(i: Input) returns (v: Verdict)', '  {'] + honest_body(policy, '    ') + ['  }', '}']
    if kind == 'expect':
        link = ['    v := S.Decide(i);', '    ' + 'exp' + 'ect v == S.Commit;']   # the refused word, on purpose
        link_ensures = ['    ensures S.Allowed(i, v) && v == S.Commit']
    else:
        link = ['    v := S.Decide(i);']
        link_ensures = ['    ensures S.Allowed(i, v)']
    claim = head + ['include "Spec.dfy"', '', 'abstract module %s {' % CLAIM, '  import S : %s' % SPEC, '',
                    '  // Forward link: the result of the specified method is allowed (an implementation exists).',
                    '  method DecideThenAllowed(i: S.Input) returns (v: S.Verdict)',
                    '    requires S.ValidInput(i)'] + link_ensures + ['  {'] + link + ['  }', '']
    if kind == 'bodiless-lemma':
        claim += ['  lemma Anything()', '    ensures false', '']
    claim += ['  // The claim: two allowed results for one valid input are equal.',
              '  lemma NoChoice(i: S.Input, v1: S.Verdict, v2: S.Verdict)',
              '    requires S.ValidInput(i)',
              '    requires S.Allowed(i, v1)',
              '    requires S.Allowed(i, v2)',
              '    ensures v1 == v2',
              '  {']
    if kind == 'bodiless-lemma':
        claim += ['    Anything();']
    claim += ['  }', '}']
    return {'Spec.dfy': '\n'.join(spec) + '\n', 'Impl.dfy': '\n'.join(impl) + '\n',
            'Claim.dfy': '\n'.join(claim) + '\n'}


def crosscheck_text(policy, digest, items, expected):
    """One lemma per scenario: the Dafny model allows EXACTLY the expected verdict set."""
    lines = ['// GENERATED by src/airlock/py/diff_policy.py: boundary cross-check of the generated model of %s.'
             % _lit(policy['name']),
             '// Each lemma states the exact set of allowed verdicts that the Python evaluator gives.',
             'include "Impl.dfy"', '', 'module %s {' % CROSS, '  import M = %s' % IMPL]
    for number, (item, want) in enumerate(zip(items, expected)):
        term = dafny_input('M.', item)
        lines += ['', '  lemma Scenario%03d()' % number]
        for verdict in VERDICTS:
            lines.append('    ensures %sM.Allowed(%s, M.%s)' % ('' if verdict in want else '!', term,
                                                                  CONSTRUCTOR[verdict]))
        lines += ['  {', '  }']
    lines.append('}')
    return '\n'.join(lines) + '\n'


def witness_text(policy, item, one, two):
    """Two refinements of the generated specification that differ at ONE input (spec_clearing checks it)."""
    term = dafny_input('', item)
    lines = ['// GENERATED by src/airlock/py/diff_policy.py: an ambiguity witness for the generated model of %s.'
             % _lit(policy['name']),
             '// Two modules that refine the specification. At ONE input they return different verdicts.',
             'include "Spec.dfy"']
    for module, verdict in (('ChoiceA', one), ('ChoiceB', two)):
        lines += ['', 'module %s refines %s {' % (module, SPEC),
                  '  method Decide(i: Input) returns (v: Verdict)',
                  '    ensures i == %s ==> v == %s' % (term, CONSTRUCTOR[verdict]),
                  '  {', '    if i == %s {' % term, '      v := %s;' % CONSTRUCTOR[verdict], '    } else {']
        lines += honest_body(policy, '      ')
        lines += ['    }', '  }', '}']
    lines += ['', 'module %s {' % WITNESS, '  import A = ChoiceA', '  import B = ChoiceB', '',
              '  method TwoRefinementsDiffer()', '  {',
              '    var a := A.Decide(%s);' % dafny_input('A.', item),
              '    var b := B.Decide(%s);' % dafny_input('B.', item),
              '    assert a == A.%s;' % CONSTRUCTOR[one],
              '    assert b == B.%s;' % CONSTRUCTOR[two],
              '    assert a.%s? && b.%s?;' % (CONSTRUCTOR[one], CONSTRUCTOR[two]),
              '  }', '}']
    return '\n'.join(lines) + '\n'


# ---------------------------------------------------------------------------------------------------
# Dafny through scripts/spec_clearing.py.
# ---------------------------------------------------------------------------------------------------
def spec_clearing():
    sys.path.insert(0, str(ROOT / 'scripts'))
    import spec_clearing as module  # noqa: E402
    return module


def dafny_binary():
    sys.path.insert(0, str(ROOT / 'gate'))
    from backends import dafny  # noqa: E402
    return Path(dafny.DAFNY)


class Lock:
    """FORGE_DAFNY_LOCK: a folder created with mkdir is the lock. One Dafny process at a time."""

    def __init__(self):
        self.path = os.environ.get('FORGE_DAFNY_LOCK')

    def __enter__(self):
        if self.path:
            start = time.monotonic()
            while True:
                try:
                    os.mkdir(self.path)
                    break
                except FileExistsError:
                    if time.monotonic() - start > LOCK_TIMEOUT:
                        raise UsageError('the Dafny lock was not free in time')
                    time.sleep(2)
        return self

    def __exit__(self, *exc):
        if self.path:
            os.rmdir(self.path)


def locked_tool(work):
    """spec_clearing.Tool whose every process start holds the Dafny lock. No other change."""
    sc = spec_clearing()

    class LockedTool(sc.Tool):
        def run(self, argv, name):
            with Lock():
                return super().run(argv, name)
    return LockedTool(work)


def no_path(text):
    """A message of spec_clearing without the folder part of a file path (deterministic output)."""
    return None if text is None else re.sub(r'\S*/([^/\s]+)', r'\1', text)


def rel(path):
    return os.path.relpath(path, ROOT)


def run_crosscheck(policy, digest, items, side_work):
    model = side_work / 'model'
    expected = [pm.allowed(policy, item) for item in items]
    text = crosscheck_text(policy, digest, items, expected)
    (model / 'CrossCheck.dfy').write_text(text)
    tool = locked_tool(side_work / 'crosscheck')
    result = tool.check([rel(model / 'CrossCheck.dfy')])
    members = ['%s.Scenario%03d (correctness)' % (CROSS, n) for n in range(len(items))]
    ok = spec_clearing().passed(result, members)
    failed = sorted(m.split('.', 1)[1].split(' ')[0] for m in members if result['members'].get(m) != 'Passed')
    return {'passed': ok, 'lemmas': len(members), 'failed': failed, 'refused': no_path(result['refused']),
            'audit_exit': result['audit_exit'], 'checker_exit': result['checker_exit']}, len(tool.commands)


def choice_candidate(policy, items):
    """A Python guess of an input with two allowed verdicts. It counts only when Dafny verifies it."""
    for item in items:
        found = pm.allowed(policy, item)
        if len(found) >= 2:
            return item, found[0], found[1]
    facts = sorted({rule['fact'] for rule in policy['rules'] if rule['fact']})
    item = pm.overlap_point(policy, facts)
    if item is not None:
        found = pm.allowed(policy, item)
        if len(found) >= 2:
            return item, found[0], found[1]
    return None


def run_clearing(policy, digest, items, side_work, label):
    model = side_work / 'model'
    claim, impl, spec = (rel(model / name) for name in ('Claim.dfy', 'Impl.dfy', 'Spec.dfy'))
    member = '%s.NoChoice (correctness)' % CLAIM
    subject = {
        'id': 'airlock-money-' + label,
        'title': 'generated Dafny model of the money policy ' + policy['name'],
        'spec': spec, 'planted': False,
        'claim': {'files': [claim], 'member': member},
        'proof': {'files': [claim, impl], 'instances': [[CLAIM, {'S': IMPL}]],
                  'members': [member, '%s.DecideThenAllowed (correctness)' % CLAIM]},
        'candidates': [],
        'spec_probe': {'files': [spec], 'modules': [[SPEC, {}]], 'open': [SPEC + '.Decide']},
    }
    guess = choice_candidate(policy, items)
    if guess:
        item, one, two = guess
        (model / 'Witness.dfy').write_text(witness_text(policy, item, one, two))
        subject['candidates'].append({'source': 'supplied', 'witness': {
            'files': [rel(model / 'Witness.dfy')], 'instances': [],
            'members': ['ChoiceA.Decide (correctness)', 'ChoiceB.Decide (correctness)',
                        '%s.TwoRefinementsDiffer (correctness)' % WITNESS],
            'example': {'input': item, 'result_one': one, 'result_two': two}}})
    sc = spec_clearing()
    tool = locked_tool(side_work / 'clearing')
    record = sc.clear_spec(tool, subject, side_work / 'generated')
    out = {'verdict': record['verdict'], 'scope': record['scope'],
           'claim': {'audit_exit': record['claim']['audit_exit'], 'checker_exit': record['claim']['checker_exit'],
                     'failed': record['claim']['failed'], 'refused': no_path(record['claim']['refused'])},
           'proof_passed': (record['proof'] or {}).get('passed'),
           'spec_probe_passed': (record['spec_probe'] or {}).get('passed'),
           'candidates_tried': len(record['candidates']),
           'witness': None}
    if record['verdict'] == 'CHOICE':
        example = record['examples'][0]
        out['witness'] = {'input': describe(example['input']), 'verdict_one': example['result_one'],
                          'verdict_two': example['result_two'],
                          'checked': 'Dafny verified two refinements of the generated specification whose '
                                     'results at this input are asserted to be these two verdicts'}
    return out, len(tool.commands)


# ---------------------------------------------------------------------------------------------------
# Engine.
# ---------------------------------------------------------------------------------------------------
def engine_eval(engine, policy_path, items):
    """(answers, error). answers: one line per scenario, or None."""
    data = ''.join(pm.eval_line(item) + '\n' for item in items).encode()
    try:
        child = subprocess.run([str(engine), 'eval', str(policy_path)], input=data, capture_output=True,
                               timeout=ENGINE_TIMEOUT, cwd=ROOT, env={'PATH': '/usr/bin:/bin', 'LANG': 'C'})
    except (OSError, subprocess.TimeoutExpired) as error:
        return None, 'engine did not run: ' + type(error).__name__
    lines = child.stdout.decode('utf-8', 'replace').split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    if child.returncode != 0:
        return None, 'engine exit %d' % child.returncode
    if len(lines) != len(items):
        return None, 'engine gave %d lines for %d scenarios' % (len(lines), len(items))
    good = set(VERDICTS)
    for line in lines:
        if line not in good and not (line.startswith('REJECTED_POLICY ') and line[16:].replace('_', '').isalnum()
                                     and line[16:].isupper()):
            return None, 'engine gave a line that is not a verdict'
    return lines, None


# ---------------------------------------------------------------------------------------------------
# Output.
# ---------------------------------------------------------------------------------------------------
def describe(item):
    facts = ','.join('%s=%d' % pair for pair in item['facts']) or '-'
    return 'reason=%s amount=%d remaining=%d reason_total=%d facts=%s' % (
        item['reason'], item['amount'], item['remaining'], item['reason_total'], facts)


def money_report(old, new, digests, items, before, after, engine_state, checks, clearing, fault):
    rows = []
    for number, item in enumerate(items):
        row = {'n': number, 'reason': item['reason'], 'amount': item['amount'], 'remaining': item['remaining'],
               'reason_total': item['reason_total'], 'facts': ','.join('%s=%d' % p for p in item['facts']) or '-',
               'before': before[number]['shown'], 'after': after[number]['shown'],
               'changed': before[number]['shown'] != after[number]['shown'],
               'engine': engine_state, 'mismatch': before[number]['mismatch'] or after[number]['mismatch'],
               'ambiguous_before': len(before[number]['set']) > 1, 'ambiguous_after': len(after[number]['set']) > 1}
        rows.append(row)
    return {'tool': 'forge-airlock diff-policy', 'end_to_end': False, 'airlock': 'money',
            'old': {'name': old['name'], 'sha256': digests[0]}, 'new': {'name': new['name'], 'sha256': digests[1]},
            'engine': engine_state, 'rows': rows, 'changed_rows': sum(r['changed'] for r in rows),
            'crosscheck': checks, 'clearing': clearing, 'labels': LABELS, 'semantic_note': SEMANTIC_NOTE,
            'test_fault': fault}


def money_text(report):
    out = ['forge-airlock diff-policy (end_to_end=false)', 'airlock: money']
    if report['test_fault']:
        out.append('TEST FAULT ACTIVE: %s (the generated model does NOT follow the policy)' % report['test_fault'])
    for side in ('old', 'new'):
        out.append('%s: %s (sha256 %s)' % (side, report[side]['name'], report[side]['sha256']))
    out.append('engine: %s' % report['engine'])
    if report['engine'] == 'RAN':
        out += ['', '== scenario table: NATIVE CHECK (engine) on FINITE scenarios; Python evaluator agrees per row ==']
    else:
        out += ['', '== scenario table: Python evaluator only; engine: NOT RUN (FINITE scenarios) ==']
    head = ['#', 'reason', 'amount', 'remaining', 'reason_total', 'facts', 'Before', 'After', 'changed?', 'engine']
    table = [head]
    for r in report['rows']:
        mark = 'MISMATCH' if r['mismatch'] else r['engine']
        before = r['before'] + (' (ambiguous)' if r['ambiguous_before'] else '')
        after = r['after'] + (' (ambiguous)' if r['ambiguous_after'] else '')
        table.append([str(r['n']), r['reason'], str(r['amount']), str(r['remaining']), str(r['reason_total']),
                      r['facts'], before, after, 'CHANGED' if r['changed'] else 'same', mark])
    widths = [max(len(row[c]) for row in table) for c in range(len(head))]
    for row in table:
        out.append(' | '.join(cell.ljust(widths[c]) for c, cell in enumerate(row)).rstrip())
    out.append('rows: %d, changed: %d' % (len(report['rows']), report['changed_rows']))
    out += ['', '== generator cross-check: generated Dafny model vs evaluator on the same FINITE scenarios ==']
    for side in ('old', 'new'):
        check = report['crosscheck'][side]
        if check is None:
            out.append('%s: NOT RUN' % side)
        else:
            state = 'PASSED' if check['passed'] else 'FAILED'
            detail = '' if check['passed'] else ' failed=%s refused=%s audit_exit=%d checker_exit=%d' % (
                ','.join(check['failed']) or '-', check['refused'], check['audit_exit'], check['checker_exit'])
            out.append('%s: %s (%d lemmas)%s' % (side, state, check['lemmas'], detail))
    out += ['', '== ambiguity: NO_CHOICE through scripts/spec_clearing.py (PROVED CORE for the GENERATED model) ==']
    for side in ('old', 'new'):
        result = report['clearing'][side]
        if result is None:
            out.append('%s: clearing: NOT RUN' % side)
            continue
        line = '%s: %s' % (side, result['verdict'])
        if result.get('reused'):
            line += ' (same policy bytes as old; result reused)'
        out.append(line)
        if result['witness']:
            w = result['witness']
            out.append('  witness input: %s' % w['input'])
            out.append('  two allowed verdicts: %s / %s (%s)' % (w['verdict_one'], w['verdict_two'], w['checked']))
        claim = result['claim']
        out.append('  detail: claim audit_exit=%d checker_exit=%d failed=%s refused=%s; proof_passed=%s; '
                   'spec_probe_passed=%s; candidates_tried=%d' % (
                       claim['audit_exit'], claim['checker_exit'], ','.join(claim['failed']) or '-', claim['refused'],
                       result['proof_passed'], result['spec_probe_passed'], result['candidates_tried']))
        out.append('  scope: %s' % result['scope'])
    out += ['', 'note: ' + report['semantic_note'], 'labels:'] + ['  - ' + label for label in report['labels']]
    out.append('RESULT: %s (exit %d)' % (report['result'], EXIT[report['result']]))
    return '\n'.join(out) + '\n'


def saga_report(old, new, digests):
    old_t, new_t = set(old['transitions']), set(new['transitions'])
    return {'tool': 'forge-airlock diff-policy', 'end_to_end': False, 'airlock': 'saga',
            'old': {'name': old['name'], 'sha256': digests[0]}, 'new': {'name': new['name'], 'sha256': digests[1]},
            'transitions_removed': sorted(old_t - new_t), 'transitions_added': sorted(new_t - old_t),
            'transitions_kept': sorted(old_t & new_t),
            'states_added': sorted(set(new['states']) - set(old['states'])),
            'states_removed': sorted(set(old['states']) - set(new['states'])),
            'initial': [old['initial'], new['initial']],
            'in_flight_added': sorted(set(new['in_flight']) - set(old['in_flight'])),
            'in_flight_removed': sorted(set(old['in_flight']) - set(new['in_flight'])),
            'clearing': 'NOT APPLICABLE', 'note': SAGA_NOTE, 'result': 'OK',
            'labels': ['saga table: FINITE comparison of two JSON transition sets; nothing proved']}


def saga_text(report):
    out = ['forge-airlock diff-policy (end_to_end=false)', 'airlock: saga']
    for side in ('old', 'new'):
        out.append('%s: %s (sha256 %s)' % (side, report[side]['name'], report[side]['sha256']))
    out += ['', '== transitions ==']
    for word, key in (('removed', 'transitions_removed'), ('added', 'transitions_added'), ('kept', 'transitions_kept')):
        for source, target in report[key]:
            out.append('%-7s | %s -> %s' % (word, source, target))
    out += ['', '== states ==']
    out += ['added   | %s' % s for s in report['states_added']] + ['removed | %s' % s for s in report['states_removed']]
    out += ['in_flight added   | %s' % s for s in report['in_flight_added']]
    out += ['in_flight removed | %s' % s for s in report['in_flight_removed']]
    out.append('initial | %s -> %s%s' % (report['initial'][0], report['initial'][1],
                                         '' if report['initial'][0] != report['initial'][1] else ' (same)'))
    out += ['', 'clearing: NOT APPLICABLE', 'note: ' + report['note'], 'labels:'] + ['  - ' + l for l in report['labels']]
    out.append('RESULT: OK (exit 0)')
    return '\n'.join(out) + '\n'


# ---------------------------------------------------------------------------------------------------
# Main.
# ---------------------------------------------------------------------------------------------------
class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise UsageError(message)


def new_work(given, data):
    if given:
        work = (ROOT / given).resolve()
        if not work.is_relative_to((ROOT / 'build').resolve()) or work.exists():
            raise UsageError('--work must be a new folder under build/')
        return work
    base = ROOT / 'build/airlock' / ('diff-' + hashlib.sha256(data).hexdigest()[:12])
    work, number = base, 1
    while work.exists():
        number += 1
        work = Path('%s-%d' % (base, number))
    return work


def evaluate_side(policy, items, answers):
    rows = []
    for number, item in enumerate(items):
        want = pm.decide(policy, item)
        got = answers[number] if answers is not None else None
        rows.append({'set': pm.allowed(policy, item), 'python': want, 'engine': got,
                     'shown': got if got is not None else want, 'mismatch': got is not None and got != want})
    return rows


def run(argv):
    parser = Parser(prog='diff_policy.py', add_help=True)
    parser.add_argument('old')
    parser.add_argument('new')
    parser.add_argument('--engine', default=None)
    parser.add_argument('--no-clearing', action='store_true')
    parser.add_argument('--allow-no-engine', action='store_true')
    parser.add_argument('--work', default=None)
    parser.add_argument('--json', action='store_true')
    parser.add_argument('--test-fault', default=None)
    args = parser.parse_args(argv)
    parse_fault(args.test_fault)
    paths = [Path(args.old), Path(args.new)]
    data = []
    for path in paths:
        try:
            data.append(path.read_bytes())
        except OSError:
            raise UsageError('cannot read a policy file')
    digests = [pm.sha256(d) for d in data]
    try:
        old, new = pm.load_policy(data[0]), pm.load_policy(data[1])
    except pm.Malformed as reason:
        return {'result': 'MALFORMED', 'reason': str(reason)}, 'MALFORMED: %s\nRESULT: MALFORMED (exit 2)\n' % reason, 0
    if old['airlock'] != new['airlock']:
        return ({'result': 'MALFORMED', 'reason': 'old and new are different airlock kinds'},
                'MALFORMED: old and new are different airlock kinds\nRESULT: MALFORMED (exit 2)\n', 0)
    if old['airlock'] == 'saga':
        report = saga_report(old, new, digests)
        return report, saga_text(report), 0

    items = pm.scenarios(old, new)
    engine = Path(args.engine) if args.engine else ROOT / DEFAULT_ENGINE
    flags = []
    if engine.is_file() and os.access(engine, os.X_OK):
        engine_state = 'RAN'
        answers = []
        for path in paths:
            lines, error = engine_eval(engine.resolve(), path.resolve(), items)
            if error:
                flags.append('ENGINE_ERROR')
                print('engine error: ' + error, file=sys.stderr)
            answers.append(lines)
    else:
        engine_state = 'NOT RUN'
        answers = [None, None]
        if not args.allow_no_engine:
            flags.append('ENGINE_NOT_RUN')
    before, after = evaluate_side(old, items, answers[0]), evaluate_side(new, items, answers[1])
    if any(r['mismatch'] for r in before + after):
        flags.append('TABLE_MISMATCH')

    checks, clearing, processes = {'old': None, 'new': None}, {'old': None, 'new': None}, 0
    if args.no_clearing:
        flags.append('CLEARING_NOT_RUN')
    else:
        if not dafny_binary().is_file():
            raise UsageError('the pinned Dafny binary is missing')
        work = new_work(args.work, data[0] + b'\0' + data[1] + b'\0' + str(args.test_fault).encode())
        print('work folder: ' + rel(work), file=sys.stderr)
        for side, policy, digest in (('old', old, digests[0]), ('new', new, digests[1])):
            if side == 'new' and data[1] == data[0]:
                checks['new'], clearing['new'] = checks['old'], {**clearing['old'], 'reused': True}
                continue
            side_work = work / side
            (side_work / 'model').mkdir(parents=True)
            for name, text in generate(policy, digest, args.test_fault).items():
                (side_work / 'model' / name).write_text(text)
            checks[side], count = run_crosscheck(policy, digest, items, side_work)
            processes += count
            clearing[side], count = run_clearing(policy, digest, items, side_work, side)
            processes += count
        if not all(checks[s]['passed'] for s in checks):
            flags.append('CROSSCHECK_FAILED')
        verdicts = [clearing[s]['verdict'] for s in clearing]
        if any(v in ('UNDECIDED', 'LINK_BROKEN') for v in verdicts):
            flags.append('UNDECIDED_OR_LINK_BROKEN')
        if 'CHOICE' in verdicts:
            flags.append('CHOICE')
        if any(v not in ('NO_CHOICE', 'CHOICE', 'UNDECIDED', 'LINK_BROKEN') for v in verdicts):
            flags.append('UNDECIDED_OR_LINK_BROKEN')
    report = money_report(old, new, digests, items, before, after, engine_state, checks, clearing, args.test_fault)
    report['result'] = next((name for name in PRIORITY if name in flags), 'OK')
    return report, money_text(report), processes


def main(argv=None):
    try:
        report, text, processes = run(sys.argv[1:] if argv is None else argv)
    except UsageError as reason:
        print('USAGE: %s' % reason, file=sys.stderr)
        return EXIT['USAGE']
    print('dafny_processes=%d' % processes, file=sys.stderr)
    if '--json' in (sys.argv[1:] if argv is None else argv):
        sys.stdout.write(json.dumps(report, sort_keys=True, indent=1) + '\n')
    else:
        sys.stdout.write(text)
    return EXIT[report['result']]


if __name__ == '__main__':
    sys.exit(main())
