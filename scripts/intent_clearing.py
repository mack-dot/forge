#!/usr/bin/env python3
"""Intent clearing (Goal 21, Gate F1). Python stdlib only. end_to_end=false.

  python3 scripts/intent_clearing.py check-intent <spec.json> [--queries FILE] [--request FILE]
          [--engine PATH] [--work build/intent/<new folder>] [--json]
  python3 scripts/intent_clearing.py ast <spec.json>

Design: proposals/forge2-goal21-intent/DESIGN.md. The tool reads ONE candidate specification (format A,
`airlock-money-v1`, or format B, `intent-spec-v1`) and prints a BRANCH-BOUNDARY TABLE, the answers to
WEIRD-BUT-LEGAL QUERIES and a BLIND RESTATEMENT. It cannot say that a specification is the intent.

What is PROVED (by the pinned Dafny 4.11.0 with the gate options, through scripts/spec_clearing.py
`Tool.check`: an empty audit, no refused word, the member's TRX outcome 'Passed'), for the GENERATED Dafny
model only: each shown row (the concrete input is valid, lies in its cell, and its allowed verdict set is
EXACTLY the shown set); each PROVED EMPTY cell (both probe lemmas, with and without readability defaults);
the seal (SameCell and Coverage); each query answer NO; each warning witness.

What is a GUESS: every value read from counterexample text (Dafny warns that it can be invalid), and every
value or verdict set that the Python evaluator below proposes. A guess is shown only after Dafny verified a
lemma about that concrete value. A parse error loses a candidate; it never makes a pass. A member that is
not 'Passed' and has no verified witness is UNDECIDED. UNDECIDED is never a pass.

ONE condition language serves cells and queries: a conjunction of atoms with ONE renderer to Dafny text
(`atom_text`) and ONE Python evaluator (`holds`). The evaluator only proposes candidates (rows, witnesses,
coverage rows) and gives the format-A cross-check against policy_model.allowed. It is not proved.

What is TRUSTED: the generator (JSON -> Dafny text, `Model.model_text`); the strict loader; Dafny 4.11.0
and Z3 4.12.1. Limits on the generator: format A rows are compared with policy_model.py (FINITE TEST),
with --engine with the Rust engine (NATIVE CHECK); negative controls (--test-fault) change the generator.
TESTED, not proved: the restater child (scripts/intent_restate.py), the Python evaluator, this text output.

No id of the specification becomes a Dafny name: reasons are R<k>, facts has<k>/fact<k>; ids appear only in
the header comment after a strict id check. Numbers reach Dafny only from Python ints.
Output is deterministic: no time, no absolute path, no work folder on stdout (stderr has it).
TEST-ONLY switch: --test-fault NAME (prints `TEST FAULT ACTIVE`): drop-bound:<rule>, flip-op:<rule>,
bodiless-lemma, expect, scramble-candidate, scramble-all. It exists only for the negative controls.
Environment: FORGE_DAFNY_LOCK=<folder> (diff_policy.py pattern): one Dafny process at a time.
"""

import argparse
import hashlib
import itertools
import json
import operator
import os
from pathlib import Path
import re
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'src/airlock/py'))
sys.path.insert(0, str(ROOT / 'scripts'))
import policy_model as pm  # noqa: E402
import diff_policy as dp  # noqa: E402  (locked_tool, engine_eval, CONSTRUCTOR, VERDICTS)
import spec_clearing as sc  # noqa: E402  (Tool, refused words; NEVER edited)
from common import canonical  # noqa: E402  (gate/common.py; spec_clearing put gate/ on the path)
from backends import dafny  # noqa: E402

TOOL = 'forge intent-clearing'
EXIT = {'CLEAN': 0, 'USAGE': 1, 'MALFORMED': 2, 'RESTATER_FAILED': 3, 'WARNINGS': 4, 'UNDECIDED': 5,
        'LINK_BROKEN': 6, 'ENGINE_MISMATCH': 7, 'GENERATOR_MISMATCH': 8, 'TABLE_TOO_LARGE': 9}
PRIORITY = ['LINK_BROKEN', 'GENERATOR_MISMATCH', 'ENGINE_MISMATCH', 'UNDECIDED', 'RESTATER_FAILED', 'WARNINGS']
MAX_CELLS, MAX_ATOMS, MAX_QUERIES, MAX_WHERE = 2000, 8, 64, 16
COVERAGE_ROUNDS, POOL_LIMIT, RESTATE_TIMEOUT = 8, 60000, 60
OPS = {'<': operator.lt, '<=': operator.le, '>': operator.gt, '>=': operator.ge, '==': operator.eq,
       '!=': operator.ne}
TERMS = ('amount', 'remaining', 'reason_total', 'total_after')
DAFNY_FIELD = {'amount': '%s.amount', 'remaining': '%s.remaining', 'reason_total': '%s.reasonTotal',
               'total_after': '(%s.reasonTotal + %s.amount)'}
VERDICTS, CONSTRUCTOR = dp.VERDICTS, dp.CONSTRUCTOR
FROM_CONSTRUCTOR = {c: v for v, c in CONSTRUCTOR.items()}
REJECTIONS = [v for v in VERDICTS if v.startswith('REJECTED_POLICY')]
RANK = {pm.COMMIT: 0, pm.COSIGN: 1, pm.RULE_REJECT: 2}
OTHER = -1
UNNAMED = '(unnamed)'
TRUST = ('trust: TESTED, NOT proved. Deterministic code that reads ONLY the canonical AST bytes (no request, '
         'no query, no path). The ids of reasons and facts are chosen by the author of the specification.')
INTENDED = 'The specification allows this. Is that intended?'
FAULTS = ('bodiless-lemma', 'expect', 'scramble-candidate', 'scramble-all')
LABELS = [
    'rows, PROVED EMPTY cells, the seal, each NO and each warning witness: PROVED by the pinned Dafny 4.11.0 '
    '(gate options, empty audit) for the GENERATED Dafny model only',
    'generator (JSON -> Dafny): TRUSTED ASSUMPTION; format A rows are compared with policy_model.py (FINITE TEST)',
    'candidates (counterexample text and the Python evaluator): GUESSES; shown only after Dafny verified them',
    'blind restatement: TESTED, NOT proved',
    'not claimed: that the specification is the intent; anything about the Rust engine without --engine; '
    'anything end to end (end_to_end=false)',
]


class UsageError(Exception):
    pass


# ---------------------------------------------------------------------------------------------------
# Loader and AST.
# ---------------------------------------------------------------------------------------------------
def _op(value, where):
    if not isinstance(value, str) or value not in OPS:
        raise pm.Malformed(where + ' is not one of < <= > >= == !=')
    return value


def _list(value, where, most, least=0):
    if not isinstance(value, list) or not least <= len(value) <= most:
        raise pm.Malformed('%s is not a list of %d to %d items' % (where, least, most))
    return value


def _tuple(value, where, size):
    if not isinstance(value, list) or len(value) != size:
        raise pm.Malformed('%s is not a list of %d items' % (where, size))
    return value


def make_ast(name, source_format, rules):
    return {'ast': 1, 'name': name, 'source_format': source_format,
            'reasons': sorted({r['reason'] for r in rules}),
            'facts': sorted({w[0] for r in rules for w in r['when']} | {r['cap_fact'] for r in rules if r['cap_fact']}),
            'rules': [{'index': n, **r} for n, r in enumerate(rules)],
            'builtin': {'min_amount': 1, 'total_cap': 'remaining', 'conflict': 'most-restrictive',
                        'no_match': ['REASON_CAP', 'NO_RULE'], 'max_money': pm.MAX_MONEY}}


def load_spec(data):
    """(ast, money policy or None). Raises pm.Malformed. Format A through policy_model.load_policy."""
    obj = pm.parse_json(data)
    if not isinstance(obj, dict):
        raise pm.Malformed('specification is not a JSON object')
    if 'airlock' in obj:
        if obj.get('airlock') != 'money':
            raise pm.Malformed('UNSUPPORTED: format A must be an airlock "money" policy')
        policy = pm.load_policy(data)
        rules = [{'reason': r['reason'], 'verdict': r['verdict'],
                  'amount': ([['>=', r['min_amount']]] if r['min_amount'] is not None else [])
                  + ([['<=', r['max_amount']]] if r['max_amount'] is not None else []),
                  'when': [], 'cap_fact': r['fact']} for r in policy['rules']]
        return make_ast(policy['name'], 'airlock-money-v1', rules), policy
    if 'intent_spec' not in obj:
        raise pm.Malformed('neither "airlock" (format A) nor "intent_spec" (format B)')
    pm._keys(obj, 'intent spec', ('intent_spec', 'name', 'rules'))
    if type(obj['intent_spec']) is not int or obj['intent_spec'] != 1:
        raise pm.Malformed('intent_spec is not the integer 1')
    name = pm._id(obj['name'], 'name')
    rules = []
    for n, rule in enumerate(_list(obj['rules'], 'rules', pm.MAX_RULES, 1)):
        where = 'rule %d' % n
        pm._keys(rule, where, ('reason', 'verdict'), ('amount', 'when', 'max_reason_total_fact'))
        if rule['verdict'] not in pm.RULE_VERDICTS:
            raise pm.Malformed(where + ' verdict is not COMMIT, REQUIRE_HUMAN_COSIGN or REJECTED_POLICY')
        amount = [[_op(a[0], where + ' op'), pm._amount(a[1], where + ' amount')]
                  for a in (_tuple(x, where + ' amount atom', 2) for x in _list(rule.get('amount', []), where + ' amount', MAX_ATOMS))]
        when = [[pm._id(w[0], where + ' fact'), _op(w[1], where + ' op'), pm._amount(w[2], where + ' value')]
                for w in (_tuple(x, where + ' when atom', 3) for x in _list(rule.get('when', []), where + ' when', MAX_ATOMS))]
        cap = rule.get('max_reason_total_fact')
        if 'max_reason_total_fact' in rule and cap is None:
            raise pm.Malformed(where + ' max_reason_total_fact is null')
        rules.append({'reason': pm._id(rule['reason'], where + ' reason'), 'verdict': rule['verdict'],
                      'amount': amount, 'when': when,
                      'cap_fact': None if cap is None else pm._id(cap, where + ' max_reason_total_fact')})
    return make_ast(name, 'intent-spec-v1', rules), None


def _term(value, where):
    if isinstance(value, str) and value in TERMS:
        return (value, 0)
    if isinstance(value, str) and value.startswith('fact:'):
        return ('fact:' + pm._id(value[5:], where + ' fact'), 0)
    return (None, pm._amount(value, where + ' term'))


def load_queries(data):
    """Raw queries (atoms name facts and reasons by id). Raises pm.Malformed."""
    obj = pm.parse_json(data)
    pm._keys(obj, 'query file', ('intent_queries', 'queries'))
    if type(obj['intent_queries']) is not int or obj['intent_queries'] != 1:
        raise pm.Malformed('intent_queries is not the integer 1')
    out, seen = [], set()
    for n, q in enumerate(_list(obj['queries'], 'queries', MAX_QUERIES)):
        where = 'query %d' % n
        pm._keys(q, where, ('id', 'question', 'where'), ('verdict',))
        qid = pm._id(q['id'], where + ' id')
        if qid in seen:
            raise pm.Malformed(where + ' id is used twice')
        seen.add(qid)
        text = q['question']
        if not isinstance(text, str) or not 1 <= len(text) <= 300 or not text.isprintable():
            raise pm.Malformed(where + ' question is not printable text of 1 to 300 characters')
        atoms = []
        for atom in _list(q['where'], where + ' where', MAX_WHERE, 1):
            if isinstance(atom, list) and len(atom) == 2 and atom[0] in ('missing', 'present'):
                fact = _term(atom[1], where)[0]
                if not fact or not fact.startswith('fact:'):
                    raise pm.Malformed(where + ' missing/present needs fact:<id>')
                atoms.append(('has', fact[5:], atom[0] == 'present'))
            elif isinstance(atom, list) and len(atom) == 3 and atom[0] == 'reason':
                if atom[1] not in ('==', '!='):
                    raise pm.Malformed(where + ' reason op is not == or !=')
                atoms.append(('reason_id', atom[1], pm._id(atom[2], where + ' reason')))
            else:
                atom = _tuple(atom, where + ' atom', 3)
                atoms.append(('cmp', _term(atom[0], where), _op(atom[1], where + ' op'), _term(atom[2], where)))
        verdicts = None
        if 'verdict' in q:
            words = _list(q['verdict'], where + ' verdict', 3, 1)
            if len(set(map(str, words))) != len(words) or any(w not in pm.RULE_VERDICTS for w in words):
                raise pm.Malformed(where + ' verdict is not a list of COMMIT, REQUIRE_HUMAN_COSIGN, REJECTED_POLICY')
            verdicts = sorted({v for w in words for v in ([w] if w != pm.REJECTED else REJECTIONS)})
        out.append({'id': qid, 'question': text, 'atoms': atoms, 'verdicts': verdicts, 'builtin': False})
    return out


def atom_facts(atom):
    if atom[0] == 'has':
        return [atom[1]]
    if atom[0] == 'cmp':
        return [t[0][5:] for t in (atom[1], atom[3]) if t[0] and t[0].startswith('fact:')]
    return []


# ---------------------------------------------------------------------------------------------------
# The model: generator (TRUSTED), Python evaluator (a GUESS), cells and pins.
# ---------------------------------------------------------------------------------------------------
class Model:
    def __init__(self, ast, query_facts=(), fault=None):
        self.ast, self.fault = ast, fault
        self.reasons = ast['reasons']
        self.facts = ast['facts'] + sorted(set(query_facts) - set(ast['facts']))
        self.rx = {r: k for k, r in enumerate(self.reasons)}
        self.fx = {f: k for k, f in enumerate(self.facts)}
        self.rules = []
        for r in ast['rules']:
            bounds = [('cmp', ('amount', 0), op, (None, n)) for op, n in r['amount']]
            whens = [('cmp', ('fact:' + f, 0), op, (None, n)) for f, op, n in r['when']]
            cap = ('cmp', ('total_after', 0), '<=', ('fact:' + r['cap_fact'], 0)) if r['cap_fact'] else None
            self.rules.append({'reason': self.rx[r['reason']], 'verdict': pm.verdict_text(r['verdict']),
                               'amounts': bounds, 'bounds': bounds + whens, 'cap': cap})
        consts = [n for r in ast['rules'] for _, n in r['amount']] + [n for r in ast['rules'] for _, _, n in r['when']]
        self.consts = sorted(set(consts))
        self.default_remaining = min(pm.MAX_MONEY, max(self.consts + [1000]) + 1000)

    # -- Python evaluator (proposes candidates; cross-check; NOT proved) --
    def value(self, term, inp):
        field, off = term
        if field is None:
            return off
        if field.startswith('fact:'):
            v = inp['facts'][self.fx[field[5:]]]
            return None if v is None else v + off
        if field == 'total_after':
            return inp['reason_total'] + inp['amount'] + off
        return inp[field] + off

    def holds(self, atom, inp):
        kind = atom[0]
        if kind == 'cmp':
            left, right = self.value(atom[1], inp), self.value(atom[3], inp)
            return left is not None and right is not None and OPS[atom[2]](left, right)
        if kind == 'reason':
            return (inp['reason'] == atom[2]) == (atom[1] == '==')
        if kind == 'has':
            return (inp['facts'][self.fx[atom[1]]] is not None) == atom[2]
        if kind == 'pred':
            name, k, positive = atom[1:]
            got = {'Rule': lambda: self.matches(self.rules[k], inp), 'Capped': lambda: self.capped(self.rules[k], inp),
                   'AnyRule': lambda: any(self.matches(r, inp) for r in self.rules),
                   'AnyCapped': lambda: any(self.capped(r, inp) for r in self.rules)}[name]()
            return got == positive
        raise ValueError('unknown atom')

    def all_hold(self, atoms, inp):
        return all(self.holds(a, inp) for a in atoms)

    def matches(self, rule, inp):
        return (inp['reason'] == rule['reason'] and self.all_hold(rule['bounds'], inp)
                and (rule['cap'] is None or self.holds(rule['cap'], inp)))

    def capped(self, rule, inp):
        return (rule['cap'] is not None and inp['reason'] == rule['reason'] and self.all_hold(rule['bounds'], inp)
                and not self.holds(rule['cap'], inp))

    def allowed(self, inp):
        if inp['amount'] < 1:
            return [pm.ZERO_AMOUNT]
        if inp['amount'] > inp['remaining']:
            return [pm.TOTAL_CAP]
        found = {r['verdict'] for r in self.rules if self.matches(r, inp)}
        if found:
            return sorted(found)
        return [pm.REASON_CAP] if any(self.capped(r, inp) for r in self.rules) else [pm.NO_RULE]

    def reason_atoms(self, k):
        out = []
        for rule in self.rules:
            if rule['reason'] == k:
                for atom in rule['bounds'] + ([rule['cap']] if rule['cap'] else []):
                    if atom not in out:
                        out.append(atom)
        return out

    def signature(self, inp):
        """Python guess of the seal cell of an input (Dafny's `Same` is the real one)."""
        if inp['amount'] < 1:
            return ('zero',)
        if inp['amount'] > inp['remaining']:
            return ('total_cap',)
        k = inp['reason']
        return (k,) + tuple(self.holds(a, inp) for a in (self.reason_atoms(k) if k != OTHER else []))

    # -- Dafny text (TRUSTED generator) --
    def reason_name(self, k):
        return 'ROther' if k == OTHER else 'R%d' % k

    def term_text(self, term, var):
        field, off = term
        if type(off) is not int:
            raise ValueError('not an integer')
        if field is None:
            return str(off)
        base = ('%s.fact%d' % (var, self.fx[field[5:]]) if field.startswith('fact:')
                else DAFNY_FIELD[field].replace('%s', var))
        return base if off == 0 else '(%s %s %d)' % (base, '+' if off > 0 else '-', abs(off))

    def atom_text(self, atom, var='i'):
        kind = atom[0]
        if kind == 'cmp':
            if atom[2] not in OPS:
                raise ValueError('not an operator')
            guards = ['%s.has%d' % (var, self.fx[f]) for f in atom_facts(atom)]
            return '(%s)' % ' && '.join(guards + ['%s %s %s' % (self.term_text(atom[1], var), atom[2],
                                                               self.term_text(atom[3], var))])
        if kind == 'reason':
            return '%s.reason %s %s' % (var, atom[1], self.reason_name(atom[2]))
        if kind == 'has':
            return ('' if atom[2] else '!') + '%s.has%d' % (var, self.fx[atom[1]])
        if kind == 'pred':
            return ('' if atom[3] else '!') + '%s%s(%s)' % (atom[1], '' if atom[2] is None else atom[2], var)
        raise ValueError('unknown atom')

    def cond_text(self, atoms, var='i'):
        return ' && '.join(self.atom_text(a, var) for a in atoms) or 'true'

    def params(self, suffix=''):
        out = ['reason%s: Reason' % suffix, 'amount%s: int' % suffix, 'remaining%s: int' % suffix,
               'reasonTotal%s: int' % suffix]
        for k in range(len(self.facts)):
            out += ['has%d%s: bool' % (k, suffix), 'fact%d%s: int' % (k, suffix)]
        return ', '.join(out)

    def bind(self, var='i', suffix=''):
        names = ['reason', 'amount', 'remaining', 'reasonTotal']
        names += [w % k for k in range(len(self.facts)) for w in ('has%d', 'fact%d')]
        return 'var %s := MoneyInput(%s);' % (var, ', '.join(n + suffix for n in names))

    def literal(self, inp):
        parts = [self.reason_name(inp['reason'])] + [str(int(inp[f])) for f in ('amount', 'remaining', 'reason_total')]
        for v in inp['facts']:
            parts += ['false', '0'] if v is None else ['true', str(int(v))]
        return 'MoneyInput(%s)' % ', '.join(parts)

    def faulty(self, rule_index, atoms):
        kind, _, arg = (self.fault or '').partition(':')
        if not arg.isdigit() or int(arg) != rule_index:
            return atoms
        if kind == 'drop-bound':
            amounts = [a for a in atoms if a[1] == ('amount', 0)]
            return [a for a in atoms if a is not amounts[0]] if amounts else atoms
        if kind == 'flip-op':
            return [(a[0], a[1], '<' if a[2] == '<=' else a[2], a[3]) if a[0] == 'cmp' else a for a in atoms]
        return atoms

    def model_text(self, title):
        ids = [('R%d' % k, r) for k, r in enumerate(self.reasons)] + [('fact%d' % k, f) for k, f in enumerate(self.facts)]
        mapping = ', '.join('%s = %s' % pair for pair in ids if pm.ID.fullmatch(pair[1]))
        words = [p for _, p in sc.REFUSED] + [re.compile(r'\binclude\b')]        # spec_clearing refuses these anywhere
        if any(p.search(mapping + ' ' + str(title)) for p in words) or not pm.ID.fullmatch(self.ast['name']):
            mapping, title = '(left out: an id holds a refused word)', '(left out)'
        lines = ['// GENERATED by scripts/intent_clearing.py from the specification %s. TRUSTED ASSUMPTION.' % title,
                 '// ids: ' + mapping]
        if self.fault:
            lines.append('// TEST FAULT ACTIVE (intent_clearing.py --test-fault). This model may NOT follow the AST.')
        fields = ['reason: Reason', 'amount: int', 'remaining: int', 'reasonTotal: int']
        fields += [w % k for k in range(len(self.facts)) for w in ('has%d: bool', 'fact%d: int')]
        valid = ['0 <= i.%s <= MaxMoney' % f for f in ('amount', 'remaining', 'reasonTotal')]
        valid += ['0 <= i.fact%d <= MaxMoney' % k for k in range(len(self.facts))]
        lines += ['module IntentModel {', '  const MaxMoney: int := %d' % pm.MAX_MONEY,
                  '  datatype Reason = ' + ' | '.join(['R%d' % k for k in range(len(self.reasons))] + ['ROther']),
                  '  datatype Verdict = ' + ' | '.join(CONSTRUCTOR[v] for v in VERDICTS),
                  '  datatype Input = MoneyInput(%s)' % ', '.join(fields), '',
                  '  predicate ValidInput(i: Input) {', '    ' + ' && '.join(valid), '  }', '']
        capped = []
        for n, rule in enumerate(self.rules):
            reason = ('reason', '==', rule['reason'])
            bounds = self.faulty(n, rule['bounds'])
            cap = self.faulty(n, [rule['cap']])[0] if rule['cap'] else None
            lines += ['  predicate Rule%d(i: Input) {' % n,
                      '    ' + self.cond_text([reason] + bounds + ([cap] if cap else [])), '  }']
            if cap:
                capped.append('Capped%d(i)' % n)
                lines += ['  predicate Capped%d(i: Input) {' % n,
                          '    %s && !%s' % (self.cond_text([reason] + bounds), self.atom_text(cap)), '  }']
        allowed = ' || '.join('(Rule%d(i) && v == %s)' % (n, CONSTRUCTOR[r['verdict']]) for n, r in enumerate(self.rules))
        same = []
        for k in range(len(self.reasons)):
            atoms = self.reason_atoms(k)
            if atoms:
                same.append('(i.reason == R%d ==> %s)' % (k, ' && '.join(
                    '(%s <==> %s)' % (self.atom_text(a, 'i'), self.atom_text(a, 'j')) for a in atoms)))
        lines += ['  predicate AnyRule(i: Input) {', '    ' + ' || '.join('Rule%d(i)' % n for n in range(len(self.rules))), '  }',
                  '  predicate AnyCapped(i: Input) {', '    ' + (' || '.join(capped) or 'false'), '  }', '',
                  '  predicate Allowed(i: Input, v: Verdict) {',
                  '    if i.amount < 1 then v == RejectedZeroAmount',
                  '    else if i.amount > i.remaining then v == RejectedTotalCap',
                  '    else if AnyRule(i) then ' + allowed,
                  '    else if AnyCapped(i) then v == RejectedReasonCap',
                  '    else v == RejectedNoRule', '  }', '',
                  '  // The seal cell: equal built-in outcome; with both built-ins passed, the same reason and the same',
                  '  // truth value of every atom of that reason.',
                  '  predicate Same(i: Input, j: Input) {',
                  '    if i.amount < 1 then j.amount < 1',
                  '    else if i.amount > i.remaining then !(j.amount < 1) && j.amount > j.remaining',
                  '    else !(j.amount < 1) && !(j.amount > j.remaining) && i.reason == j.reason' +
                  ''.join(' &&\n      ' + s for s in same), '  }']
        if self.fault == 'bodiless-lemma':
            lines += ['', '  lemma Anything()', '    ensures false']
        if self.fault == 'expect':
            lines += ['', '  method Fault() {', '    ' + 'exp' + 'ect false;', '  }']   # the refused word, on purpose
        return '\n'.join(lines + ['}']) + '\n'

    # -- cells --
    def cells(self):
        ok = [('cmp', ('amount', 0), '>=', (None, 1)), ('cmp', ('amount', 0), '<=', ('remaining', 0))]
        out = [cell('BRANCH', 'ZERO_AMOUNT', None, [('cmp', ('amount', 0), '<', (None, 1))]),
               cell('BRANCH', 'TOTAL_CAP', None, ok[:1] + [('cmp', ('amount', 0), '>', ('remaining', 0))])]
        for n, rule in enumerate(self.rules):
            r = rule['reason']
            out.append(cell('BRANCH', 'rule %d matches (%s)' % (n, rule['verdict']), r,
                            [('reason', '==', r)] + ok + [('pred', 'Rule', n, True)], rule=n))
            if rule['cap']:
                out.append(cell('BRANCH', 'REASON_CAP of rule %d' % n, r, [('reason', '==', r)] + ok + [
                    ('pred', 'Capped', n, True), ('pred', 'AnyRule', None, False)]))
        for k, name in enumerate(self.reasons):
            out.append(cell('BRANCH', 'NO_RULE of %s' % name, k, [('reason', '==', k)] + ok + [
                ('pred', 'AnyRule', None, False), ('pred', 'AnyCapped', None, False)]))
        out.append(cell('BRANCH', 'reason OTHER', OTHER, [('reason', '==', OTHER)] + ok))
        for a, b in itertools.combinations(range(len(self.rules)), 2):
            one, two = self.rules[a], self.rules[b]
            if one['reason'] == two['reason'] and one['verdict'] != two['verdict']:
                out.append(cell('BRANCH', 'rules %d+%d both match' % (a, b), one['reason'], [('reason', '==', one['reason'])]
                                + ok + [('pred', 'Rule', a, True), ('pred', 'Rule', b, True)]))
        for k in range(len(self.reasons)):
            out += self.boundary(k)
        return out

    def boundary(self, k):
        rules = [r for r in self.rules if r['reason'] == k]
        consts = sorted({a[3][1] for r in rules for a in r['amounts']})
        values = sorted({1} | {c + d for c in consts for d in (-1, 0, 1)})
        amount = [('amount=%d' % v, [('cmp', ('amount', 0), '==', (None, v))]) for v in values if 0 <= v <= pm.MAX_MONEY]
        amount += [('amount=remaining%s' % ('%+d' % d if d else ''), [('cmp', ('amount', 0), '==', ('remaining', d))])
                   for d in (-1, 0, 1)]
        sets = [amount]
        when = sorted({a[1][0][5:] for r in rules for a in r['bounds'] if a[1][0] and a[1][0].startswith('fact:')})
        for fact in when:
            vals = sorted({a[3][1] + d for r in rules for a in r['bounds'] if a[1][0] == 'fact:' + fact for d in (-1, 0, 1)})
            sets.append([('%s missing' % fact, [('has', fact, False)])] + [
                ('%s=%d' % (fact, v), [('cmp', ('fact:' + fact, 0), '==', (None, v))]) for v in vals if 0 <= v <= pm.MAX_MONEY])
        for fact in sorted({r['cap'][3][0][5:] for r in rules if r['cap']}):
            sets.append([('%s missing' % fact, [('has', fact, False)])] + [
                ('total_after=%s%s' % (fact, '%+d' % d if d else ''), [('cmp', ('total_after', 0), '==', ('fact:' + fact, d))])
                for d in (-1, 0, 1)])
        out = []
        for combo in itertools.product(*sets):
            atoms = [('reason', '==', k)] + [a for _, part in combo for a in part]
            out.append(cell('BOUNDARY', ', '.join(label for label, _ in combo), k, atoms,
                            pins=tuple(label for label, _ in combo[1:])))
        return out

    def defaults(self, reason):
        """Readability defaults (reason_total 0, a fixed remaining, facts of other reasons missing)."""
        used = {f for r in self.rules if r['reason'] == reason for a in r['bounds'] + [r['cap']] if a for f in atom_facts(a)}
        return ([('cmp', ('reason_total', 0), '==', (None, 0)), ('cmp', ('remaining', 0), '==', (None, self.default_remaining))]
                + [('has', f, False) for f in self.facts if f not in used])

    # -- Python candidates (GUESSES) --
    def pool(self, reasons, varied):
        values = sorted({v for c in self.consts + [0, 1, self.default_remaining] for v in (c - 1, c, c + 1)
                         if 0 <= v <= pm.MAX_MONEY})
        for reason in reasons:
            for amount in values:
                for remaining in dict.fromkeys([self.default_remaining, amount - 1, amount, amount + 1]):
                    if not 0 <= remaining <= pm.MAX_MONEY:
                        continue
                    for total in (0, 1):
                        near = [total + amount + d for d in (-1, 0, 1)]
                        choices = [[None] + [v for v in dict.fromkeys(values + near) if 0 <= v <= pm.MAX_MONEY]
                                   if f in varied else [None] for f in self.facts]
                        for facts in itertools.product(*choices):
                            yield {'reason': reason, 'amount': amount, 'remaining': remaining,
                                   'reason_total': total, 'facts': list(facts)}

    def python_candidate(self, atoms, accept=None, defaults=True):
        reasons = [a[2] for a in atoms if a[0] == 'reason' and a[1] == '=='][:1] or list(range(len(self.reasons))) + [OTHER]
        varied = {f for a in atoms for f in atom_facts(a)}
        if any(a[0] == 'pred' for a in atoms):
            varied |= {f for r in self.rules if r['reason'] in reasons for a in r['bounds'] + [r['cap']] if a for f in atom_facts(a)}
        tries = ([atoms + self.defaults(reasons[0])] if defaults else []) + [atoms]
        for conds in tries:
            for n, inp in enumerate(self.pool(reasons, varied)):
                if n >= POOL_LIMIT:
                    break
                if self.all_hold(conds, inp) and (accept is None or accept(inp)):
                    return inp
        return None


def cell(kind, label, reason, atoms, rule=None, pins=None):
    return {'kind': kind, 'label': label, 'reason': reason, 'atoms': atoms, 'rule': rule, 'pins': pins}


# ---------------------------------------------------------------------------------------------------
# Queries.
# ---------------------------------------------------------------------------------------------------
def builtin_queries(model):
    out = [{'id': 'BUILTIN-1', 'question': 'can two different verdicts be allowed for one input?', 'atoms': [],
            'verdicts': None, 'pair': True},
           {'id': 'BUILTIN-2', 'question': 'can a COMMIT exceed remaining (amount > remaining)?',
            'atoms': [('cmp', ('amount', 0), '>', ('remaining', 0))], 'verdicts': [pm.COMMIT]}]
    pairs = sorted({(r['reason'], r['cap'][3][0][5:]) for r in model.rules if r['cap']})
    for n, (k, fact) in enumerate(pairs, 1):
        name = model.reasons[k]
        out.append({'id': 'BUILTIN-CAP-%d-MISSING' % n, 'verdicts': [pm.COMMIT, pm.COSIGN],
                    'question': 'can a %s refund be committed or sent to cosign with the cap fact %s missing?' % (name, fact),
                    'atoms': [('reason', '==', k), ('has', fact, False)]})
        out.append({'id': 'BUILTIN-CAP-%d-ABOVE' % n, 'verdicts': [pm.COMMIT, pm.COSIGN],
                    'question': 'can a %s refund be committed or sent to cosign with total_after above %s?' % (name, fact),
                    'atoms': [('reason', '==', k), ('cmp', ('total_after', 0), '>', ('fact:' + fact, 0))]})
    for q in out:
        q.update(builtin=True, notes=[], pair=q.get('pair', False))
    return out


def resolve_query(model, raw):
    """Reason ids to indexes. A reason that the specification does not name is in OTHER."""
    atoms, notes = [], []
    # OTHER stands for ANY reason id that the specification does not name. Two different unnamed ids are
    # different reasons: `== FOO` with `== BAR`, or with `!= FOO`, has no input. Such a query gets the atom
    # `0 == 1` (review finding F1), so that no witness of the merged class OTHER can answer it.
    equal = {a[2] for a in raw['atoms'] if a[0] == 'reason_id' and a[1] == '==' and a[2] not in model.rx}
    unequal = {a[2] for a in raw['atoms'] if a[0] == 'reason_id' and a[1] == '!=' and a[2] not in model.rx}
    if len(equal) > 1 or equal & unequal:
        atoms.append(('cmp', (None, 0), '==', (None, 1)))
        notes.append('the reason atoms of this query contradict each other: no input satisfies it')
    for atom in raw['atoms']:
        if atom[0] == 'reason_id':
            named = atom[2] in model.rx
            note = 'the specification does not name the reason %s (it is one of the unnamed reasons)' % atom[2]
            if not named and note not in notes:
                notes.append(note)
            if named or atom[1] == '==':
                atoms.append(('reason', atom[1], model.rx.get(atom[2], OTHER)))
        else:
            atoms.append(atom)
    unread = sorted({f for a in atoms for f in atom_facts(a)} - set(model.ast['facts']))
    for fact in unread:
        notes.append('the specification never reads the fact %s (only this query names it)' % fact)
    return {**raw, 'atoms': atoms, 'notes': notes, 'pair': False}


def query_accept(model, q, inp):
    allowed = model.allowed(inp)
    if q['pair']:
        return len(allowed) >= 2
    return q['verdicts'] is None or bool(set(allowed) & set(q['verdicts']))


def query_verdict_text(q, var='v'):
    if q['verdicts'] is None:
        return 'true'
    return '(%s)' % ' || '.join('%s == %s' % (var, CONSTRUCTOR[v]) for v in q['verdicts'])


# ---------------------------------------------------------------------------------------------------
# Dafny files and counterexample text.
# ---------------------------------------------------------------------------------------------------
class DafnyFile:
    """Lemmas with their line spans (an error line is mapped to the lemma whose span holds it)."""

    def __init__(self, module, head):
        self.module, self.lines, self.spans = module, list(head) + ['module %s {' % module, '  import opened IntentModel'], []

    def lemma(self, name, body_lines, body='{}'):
        start = len(self.lines) + 1
        self.lines += ['', '  lemma ' + name] + ['    ' + line for line in body_lines] + ['  ' + body]
        self.spans.append((start, len(self.lines), name.split('(')[0]))

    def text(self):
        return '\n'.join(self.lines + ['}']) + '\n'

    def member(self, name):
        return '%s.%s (correctness)' % (self.module, name)


ERROR_LINE = re.compile(r'(\w+)\.dfy\((\d+),\d+\): Error: ')
SCALAR = re.compile(r'^(?:\(- (\d+)\)|(-?\d+)|(true|false)|(?:[\w.]+\.)?(R\d+|ROther)|(?:[\w.]+\.)?([A-Z]\w+))$')


def counterexamples(text, dfile, stem):
    """{lemma name: {parameter: raw value}} from counterexample text. A GUESS; errors lose a candidate."""
    out, current = {}, None
    for line in text.splitlines():
        found = ERROR_LINE.search(line)
        if found:
            current = None
            if found.group(1) == stem:
                number = int(found.group(2))
                current = next((name for a, b, name in dfile.spans if a <= number <= b), None)
            continue
        stripped = line.strip()
        if current and stripped.startswith('assume ') and current not in out:
            values = {}
            try:
                for part in stripped[len('assume '):].rstrip(';').split(' && '):
                    if ' == ' not in part:
                        continue
                    left, right = (s.strip() for s in part.split(' == ', 1))
                    for name, raw in ((right, left), (left, right)):
                        if re.fullmatch(r'[A-Za-z]\w*', name) and SCALAR.match(raw) and name not in values:
                            values[name] = raw
            except ValueError:
                values = {}
            out[current] = values
            current = None
    return out


def scalar(raw):
    found = SCALAR.match(raw or '')
    if not found:
        return None
    if found.group(1):
        return -int(found.group(1))
    if found.group(2):
        return int(found.group(2))
    if found.group(3):
        return found.group(3) == 'true'
    return found.group(4) or found.group(5)


def solver_input(model, values, fault):
    """A candidate input from counterexample values (missing values: plain defaults). A GUESS."""
    if values is None:
        return None
    try:
        reason = scalar(values.get('reason')) or 'ROther'
        inp = {'reason': OTHER if reason == 'ROther' else int(reason[1:]),
               'amount': scalar(values.get('amount')), 'remaining': scalar(values.get('remaining')),
               'reason_total': scalar(values.get('reasonTotal')), 'facts': []}
        if inp['reason'] != OTHER and not 0 <= inp['reason'] < len(model.reasons):
            return None
        for f in ('amount', 'remaining', 'reason_total'):
            inp[f] = inp[f] if type(inp[f]) is int else 0
        for k in range(len(model.facts)):
            has, value = scalar(values.get('has%d' % k)), scalar(values.get('fact%d' % k))
            inp['facts'].append((value if type(value) is int else 0) if has is True else None)
    except (ValueError, TypeError, AttributeError):
        return None
    if fault in ('scramble-candidate', 'scramble-all'):
        inp['amount'] = pm.MAX_MONEY + 1          # TEST FAULT: a changed value that no row may show
    return inp


def verdict_of(values, name):
    word = scalar((values or {}).get(name))
    return FROM_CONSTRUCTOR.get(word) if isinstance(word, str) else None


def link_ok(result, members):
    """The check passed on its own terms: nothing refused, empty audit, every member present, no other failure."""
    ours = set(members)
    return (result['refused'] is None and result['audit_exit'] == 0 and result['checker_exit'] in (0, 4)
            and all(m in result['members'] for m in ours)
            and all(o == 'Passed' for m, o in result['members'].items() if m not in ours))


def proved(result, member):
    return result['refused'] is None and result['audit_exit'] == 0 and result['members'].get(member) == 'Passed'


def rel(path):
    return os.path.relpath(path, ROOT)


# ---------------------------------------------------------------------------------------------------
# Clearing: probe, rows, seal.
# ---------------------------------------------------------------------------------------------------
class Clearing:
    def __init__(self, model, cells, queries, tool, folder, fault):
        self.m, self.cells, self.queries, self.tool, self.dir, self.fault = model, cells, queries, tool, folder, fault
        self.head = ['// GENERATED by scripts/intent_clearing.py. Lemmas about the generated model only.',
                     'include "Model.dfy"']
        self.body = '{ Anything(); }' if fault == 'bodiless-lemma' else '{}'
        self.broken, self.extra = [], []          # fail closed: nothing decided until Dafny says so
        self.seal = {'same_cell': 'NOT PROVED', 'coverage': 'UNDECIDED', 'coverage_rounds': 0, 'coverage_rows': 0}
        for c in cells:
            c.update(empty=False, row=None)
        for q in queries:
            q.update(answer='UNDECIDED', witness=None)

    def check(self, dfile, name, members):
        path = self.dir / name
        path.write_text(dfile.text())
        result = self.tool.check([rel(path)])
        if not link_ok(result, members):
            self.broken.append('%s: refused=%s audit_exit=%d checker_exit=%d missing=%d' % (
                name, dp.no_path(result['refused']), result['audit_exit'], result['checker_exit'],
                sum(m not in result['members'] for m in members)))
            return None
        return result

    def cex(self, dfile, name):
        return counterexamples(self.tool.counterexample([rel(self.dir / name)]), dfile, name[:-4])

    def probe(self):
        f = DafnyFile('IntentProbe', self.head)
        m, bind = self.m, self.m.bind()
        for n, c in enumerate(self.cells):
            for tag, atoms in (('D', c['atoms'] + m.defaults(c['reason'])), ('U', c['atoms'])):
                f.lemma('Cell%04d%s(%s)' % (n, tag, m.params()),
                        ['requires %s ValidInput(i) && %s' % (bind, m.cond_text(atoms)), 'ensures false'], self.body)
        for n, q in enumerate(self.queries):
            extra = 'v1: Verdict, v2: Verdict' if q['pair'] else 'v: Verdict'
            allowed = ('Allowed(i, v1) && Allowed(i, v2) && v1 != v2' if q['pair']
                       else 'Allowed(i, v) && ' + query_verdict_text(q))
            for tag, atoms in (('D', q['atoms'] + m.defaults(None)[:2]), ('U', q['atoms'])):
                f.lemma('Query%03d%s(%s, %s)' % (n, tag, m.params(), extra),
                        ['requires %s ValidInput(i) && %s && %s' % (bind, allowed, m.cond_text(atoms)), 'ensures false'],
                        self.body)
        result = self.check_named(f, 'Probe.dfy')
        if result is None:
            return None, {}
        status = {name: proved(result, f.member(name)) for _, _, name in f.spans}
        values = self.cex(f, 'Probe.dfy') if not all(status.values()) else {}
        return status, values

    def row_lemma(self, f, name, inp, atoms, want):
        lit = self.m.literal(inp)
        claims = ['ValidInput(i)', self.m.cond_text(atoms, 'i')]
        claims += [('' if v in want else '!') + 'Allowed(i, %s)' % CONSTRUCTOR[v] for v in VERDICTS]
        f.lemma(name + '()', ['ensures var i := %s; %s' % (lit, ' && '.join(claims))], self.body)
        return name

    def run(self):
        m = self.m
        status, values = self.probe()
        if status is None:
            return None
        f, n = DafnyFile('IntentRows', self.head), 0
        for i, c in enumerate(self.cells):
            c['empty'], c['candidates'] = status['Cell%04dD' % i] and status['Cell%04dU' % i], []
            if c['empty']:
                continue
            seen = []
            for tag in ('D', 'U'):
                inp = solver_input(m, values.get('Cell%04d%s' % (i, tag)), self.fault)
                if inp is not None and inp not in seen:
                    seen.append(inp)
                    c['candidates'].append((inp, 'solver-counterexample'))
            py = m.python_candidate(c['atoms'])
            if py is not None and self.fault == 'scramble-all':
                py = dict(py, amount=pm.MAX_MONEY + 1)
            if py is not None and py not in seen:
                c['candidates'].append((py, 'python-candidate'))
            c['lemmas'] = []
            for inp, source in c['candidates']:
                n += 1
                c['lemmas'].append(self.row_lemma(f, 'Row%04d' % n, inp, c['atoms'], m.allowed(inp)))
        for qi, q in enumerate(self.queries):
            q['lemmas'] = []
            if status['Query%03dD' % qi] and status['Query%03dU' % qi]:
                q['answer'] = 'NO'
                continue
            tries = []
            for tag in ('D', 'U'):
                vals = values.get('Query%03d%s' % (qi, tag))
                inp = solver_input(m, vals, self.fault)
                if inp is not None:
                    tries.append((inp, 'solver-counterexample', [verdict_of(vals, x) for x in ('v', 'v1', 'v2')]))
            py = m.python_candidate(q['atoms'], lambda x: query_accept(m, q, x), defaults=False)
            if py is not None and self.fault == 'scramble-all':
                py = dict(py, amount=pm.MAX_MONEY + 1)
            if py is not None:
                tries.append((py, 'python-candidate', [None, None, None]))
            for inp, source, hint in tries:
                allowed = m.allowed(inp)
                if q['pair']:
                    pick = [hint[1], hint[2]] if hint[1] and hint[2] and hint[1] != hint[2] else allowed[:2]
                    if len(pick) < 2:
                        continue
                else:
                    ok = [v for v in allowed if q['verdicts'] is None or v in q['verdicts']]
                    pick = [hint[0]] if hint[0] and (q['verdicts'] is None or hint[0] in q['verdicts']) else ok[:1]
                    if not pick:
                        continue
                n += 1
                claims = ['ValidInput(i)', m.cond_text(q['atoms'])] + ['Allowed(i, %s)' % CONSTRUCTOR[v] for v in pick]
                f.lemma('Wit%04d()' % n, ['ensures var i := %s; %s' % (m.literal(inp), ' && '.join(claims))], self.body)
                q['lemmas'].append(('Wit%04d' % n, inp, source, pick))
        bind_i, bind_j = m.bind('i'), m.bind('j', 'B')
        f.lemma('SameCell(%s, %s, v: Verdict)' % (m.params(), m.params('B')),
                ['requires %s %s ValidInput(i) && ValidInput(j) && Same(i, j)' % (bind_i, bind_j),
                 'ensures %s %s Allowed(i, v) <==> Allowed(j, v)' % (bind_i, bind_j)], self.body)
        reps = self.representatives([(c['candidates'][0][0], c['lemmas'][0]) for c in self.cells
                                     if not c['empty'] and c['candidates']])
        self.coverage_lemma(f, reps)
        result = self.check_named(f, 'Rows.dfy')
        if result is None:
            return None
        ok = {name: proved(result, f.member(name)) for _, _, name in f.spans}
        for c in self.cells:
            if not c['empty']:
                for (inp, source), lemma in zip(c['candidates'], c['lemmas']):
                    if ok[lemma]:
                        c['row'] = {'input': inp, 'source': source, 'allowed': m.allowed(inp)}
                        break
        for q in self.queries:
            hit = next(((inp, s, pick) for name, inp, s, pick in q['lemmas'] if ok[name]), None)
            if q['answer'] != 'NO' and hit:
                q['answer'], q['witness'] = 'WARNING', {'input': hit[0], 'source': hit[1], 'verdicts': hit[2]}
        self.seal['same_cell'] = 'PROVED' if ok['SameCell'] else 'NOT PROVED'
        return self.coverage(f, ok, reps)

    def check_named(self, f, name):
        members = [f.member(x) for _, _, x in f.spans]
        return self.check(f, name, members)

    def representatives(self, pairs):
        out, sigs = [], set()
        for inp, lemma in pairs:
            sig = self.m.signature(inp)
            if sig not in sigs:
                sigs.add(sig)
                out.append((inp, lemma))
        return out

    def coverage_lemma(self, f, reps):
        m = self.m
        ensures = ' || '.join('Same(i, %s)' % m.literal(inp) for inp, _ in reps) or 'false'
        f.lemma('Coverage(%s)' % m.params(), ['requires %s ValidInput(i)' % m.bind(),
                                              'ensures %s %s' % (m.bind(), ensures)], self.body)

    def coverage(self, f, ok, reps):
        """Coverage rounds. The seal holds only when Coverage passed and EVERY row it names was verified."""
        m, name = self.m, 'Rows.dfy'
        while True:
            if ok.get('Coverage') and all(lemma is None or ok.get(lemma) for _, lemma in reps):
                self.seal.update(coverage='PROVED', coverage_rows=len(reps))
                return True
            if self.seal['coverage_rounds'] >= COVERAGE_ROUNDS:
                return True
            base = [(c['row']['input'], None) for c in self.cells if c['row']] + [(e['input'], None) for e in self.extra]
            candidates = []
            if not ok.get('Coverage'):
                inp = solver_input(m, self.cex(f, name).get('Coverage'), self.fault)
                if inp is not None:
                    candidates.append((inp, 'solver-counterexample'))
                sigs = {m.signature(inp) for inp, _ in base}
                pool = itertools.islice(m.pool(list(range(len(m.reasons))) + [OTHER], set(m.facts)), POOL_LIMIT)
                py = next((x for x in pool if m.signature(x) not in sigs), None)
                if py is not None and self.fault == 'scramble-all':
                    py = dict(py, amount=pm.MAX_MONEY + 1)
                if py is not None and all(py != c for c, _ in candidates):
                    candidates.append((py, 'python-candidate'))
            self.seal['coverage_rounds'] += 1
            number = self.seal['coverage_rounds']
            name = 'Cover%02d.dfy' % number
            f = DafnyFile('IntentCover%02d' % number, self.head)
            new = [(inp, source, self.row_lemma(f, 'Row%02d%02d' % (number, k), inp, [], m.allowed(inp)))
                   for k, (inp, source) in enumerate(candidates)]
            reps = self.representatives(base + [(inp, lemma) for inp, _, lemma in new])
            self.coverage_lemma(f, reps)
            result = self.check_named(f, name)
            if result is None:
                return None
            ok = {x: proved(result, f.member(x)) for _, _, x in f.spans}
            self.extra += [{'input': inp, 'source': source, 'allowed': m.allowed(inp)} for inp, source, lemma in new if ok[lemma]]


# ---------------------------------------------------------------------------------------------------
# Restater child (TESTED, not proved).
# ---------------------------------------------------------------------------------------------------
def restate(ast_bytes, work):
    path = ROOT / 'scripts/intent_restate.py'
    if not path.is_file():
        return None, 'the restater scripts/intent_restate.py is absent'
    try:
        # The source text goes in with -c: the child has no script path, no argument, an empty environment and
        # the folder / as its current folder (review finding F11). Its only input is the canonical AST.
        child = subprocess.run([sys.executable, '-I', '-B', '-c', path.read_text()], input=ast_bytes, capture_output=True,
                               cwd='/', env={}, timeout=RESTATE_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as error:
        return None, 'the restater did not run: ' + type(error).__name__
    if child.returncode != 0:
        return None, 'the restater exited %d' % child.returncode
    try:
        lines = child.stdout.decode('utf-8', 'strict').splitlines()
    except UnicodeDecodeError:
        return None, 'the restater output is not UTF-8'
    if not lines or any(not line.startswith('- ') for line in lines):
        return None, 'the restater gave no bullets, or a line that does not start with "- "'
    return lines, None


# ---------------------------------------------------------------------------------------------------
# Report.
# ---------------------------------------------------------------------------------------------------
def describe(model, inp):
    facts = ','.join('%s=%s' % (f, '-' if v is None else v) for f, v in zip(model.facts, inp['facts'])) or '-'
    return 'reason=%s amount=%d remaining=%d reason_total=%d facts=%s' % (
        reason_id(model, inp['reason']), inp['amount'], inp['remaining'], inp['reason_total'], facts)


def reason_id(model, k):
    return UNNAMED if k == OTHER else model.reasons[k]   # no id can spell UNNAMED (review finding F2)


def decision(allowed):
    return max(allowed, key=lambda v: RANK.get(v, 3))


def scenario(model, inp):
    other = 'UNLISTED'
    while other in model.reasons:
        other += '_'
    facts = {f: v for f, v in zip(model.facts, inp['facts']) if v is not None and f in model.ast['facts']}
    return pm.scenario(other if inp['reason'] == OTHER else model.reasons[inp['reason']], inp['amount'],
                       inp['remaining'], inp['reason_total'], facts)


def build_rows(model, cells, extra):
    rows = []
    for c in cells:
        if c['row']:
            rows.append({**c['row'], 'kind': c['kind'], 'cell': c['label'], 'pins': c['pins']})
    for e in extra:
        rows.append({**e, 'kind': 'COVERAGE', 'cell': 'outside every row before (seal)', 'pins': None})
    out = []
    for n, r in enumerate(rows, 1):
        inp = r['input']
        out.append({'n': n, 'kind': r['kind'], 'cell': r['cell'], 'reason': reason_id(model, inp['reason']),
                    'amount': inp['amount'], 'remaining': inp['remaining'], 'reason_total': inp['reason_total'],
                    'facts': {f: v for f, v in zip(model.facts, inp['facts'])}, 'allowed': r['allowed'],
                    'decision': decision(r['allowed']), 'source': r['source'], 'tags': [], 'engine': None,
                    '_input': inp, '_pins': r['pins']})
    for r in out:
        if len(r['allowed']) > 1:
            r['tags'].append('AMBIGUOUS')
    groups = {}
    for r in out:
        if r['kind'] == 'BOUNDARY':
            groups.setdefault((r['reason'], r['_pins']), []).append(r)
    for group in groups.values():
        for a, b in itertools.combinations(group, 2):
            if abs(a['amount'] - b['amount']) == 1 and a['decision'] != b['decision']:
                for r in (a, b):
                    if 'EDGE' not in r['tags']:
                        r['tags'].append('EDGE')
    return out


def table_text(rows):
    head = ['#', 'kind', 'cell', 'reason', 'amount', 'remaining', 'reason_total', 'facts', 'allowed verdicts',
            'decision', 'source', 'tags']
    lines = [head]
    for r in rows:
        facts = ','.join('%s=%s' % (f, '-' if v is None else v) for f, v in r['facts'].items()) or '-'
        lines.append([str(r['n']), r['kind'], r['cell'], r['reason'], str(r['amount']), str(r['remaining']),
                      str(r['reason_total']), facts, ','.join(r['allowed']), r['decision'], r['source'],
                      ','.join(r['tags']) or '-'])
    widths = [max(len(line[c]) for line in lines) for c in range(len(head))]
    return [' | '.join(x.ljust(widths[c]) for c, x in enumerate(line)).rstrip() for line in lines]


def empty_report(result, reason, spec=None):
    return {'tool': TOOL, 'end_to_end': False, 'spec': spec, 'table': None, 'queries': None, 'restatement': None,
            'warnings': [reason], 'labels': LABELS, 'result': result, 'exit': EXIT[result]}


def text_of(report, extra):
    out = ['%s (end_to_end=false)' % TOOL]
    spec = report['spec']
    if spec:
        out.append('spec: %s (sha256 %s, format %s, ast sha256 %s)' % (spec['name'], spec['sha256'],
                                                                     spec['source_format'], spec['ast_sha256']))
    if extra.get('fault'):
        out.append('TEST FAULT ACTIVE: %s (the generator or the candidates do NOT follow the specification)' % extra['fault'])
    if report['table'] is None:
        out += ['%s: %s' % (report['result'], w) for w in report['warnings']]
        out.append('RESULT: %s (exit %d)' % (report['result'], report['exit']))
        return '\n'.join(out) + '\n'
    t = report['table']
    out += ['', '== branch-boundary table =='] + table_text(t['rows'])
    out.append('rows: %d (each verified by Dafny); cells: %d; proved empty: %d; undecided: %d' % (
        len(t['rows']), extra['cells'], len(t['empty_cells']), len(t['undecided_cells'])))
    for label in t['undecided_cells']:
        out.append('UNDECIDED cell: %s' % label)
    for line in extra['broken']:
        out.append('LINK_BROKEN: %s' % line)
    out += ['', '== proved empty cells (%d) ==' % len(t['empty_cells'])]
    for e in t['empty_cells']:
        if e['dead_rule']:
            out.append('DEAD RULE: the cell "%s" is PROVED EMPTY: the rule can never fire' % e['cell'])
        elif e['kind'] == 'BRANCH':
            out.append('empty: %s' % e['cell'])
    out.append('boundary cells proved empty: %d' % sum(e['kind'] == 'BOUNDARY' for e in t['empty_cells']))
    s = t['seal']
    out += ['seal: SameCell %s' % s['same_cell'],
            'seal: Coverage %s (rows named: %d, coverage rounds: %d)' % (s['coverage'], s['coverage_rows'], s['coverage_rounds'])]
    out += ['', '== weird-but-legal queries ==']
    for q in report['queries']:
        out.append('%s: %s | %s' % (q['id'], q['answer'], q['question']))
        for note in q['notes']:
            out.append('  note: %s' % note)
        if q['witness']:
            out += ['  witness input: %s (%s, verified by Dafny)' % (q['witness']['input'], q['witness']['source']),
                    '  allowed verdict: %s' % ' and '.join(q['witness']['verdicts']), '  ' + INTENDED]
    r = report['restatement']
    out += ['', '== blind restatement ==', r['trust']]
    out += r['bullets'] or [w for w in report['warnings'] if w.startswith('RESTATER_FAILED')]
    if extra.get('request') is not None:
        out += ['', '== request text (never given to the restater) =='] + ['| ' + line for line in extra['request'].split('\n')]
    out += ['', 'labels:'] + ['  - ' + label for label in report['labels']]
    out.append('RESULT: %s (exit %d)' % (report['result'], report['exit']))
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
    base = ROOT / 'build/intent' / ('check-' + hashlib.sha256(data).hexdigest()[:12])
    work, number = base, 1
    while work.exists():
        number += 1
        work = Path('%s-%d' % (base, number))
    return work


def read(path, what):
    try:
        return Path(path).read_bytes()
    except OSError:
        raise UsageError('cannot read the %s file' % what)


def check_intent(args):
    fault = args.test_fault
    if fault is not None and fault not in FAULTS and not re.fullmatch(r'(drop-bound|flip-op):\d{1,2}', fault):
        raise UsageError('unknown --test-fault')
    data = read(args.spec, 'specification')
    query_data = read(args.queries, 'query') if args.queries else None
    request = None
    if args.request:
        try:
            request = read(args.request, 'request').decode('utf-8', 'strict')
        except UnicodeDecodeError:
            raise UsageError('the request file is not UTF-8')
        if not all(line.isprintable() for line in request.split('\n')):      # review finding F8
            raise UsageError('the request file holds a character that is not printable')
    try:
        ast, policy = load_spec(data)
        raw_queries = load_queries(query_data) if query_data is not None else []
    except pm.Malformed as reason:
        return empty_report('MALFORMED', str(reason)), {}, 0
    ast_bytes = canonical(ast)
    spec = {'name': ast['name'], 'sha256': pm.sha256(data), 'source_format': ast['source_format'],
            'ast_sha256': pm.sha256(ast_bytes)}
    query_facts = {f for q in raw_queries for a in q['atoms'] for f in atom_facts(a)}
    model = Model(ast, query_facts, fault)
    if fault and fault.partition(':')[2]:
        k = int(fault.partition(':')[2])
        atoms = model.rules[k]['bounds'] + [model.rules[k]['cap']] if k < len(model.rules) else []
        if model.faulty(k, [a for a in atoms if a]) == [a for a in atoms if a]:
            raise UsageError('the test fault changes nothing in that rule')
    cells = model.cells()
    if len(cells) > MAX_CELLS:
        return empty_report('TABLE_TOO_LARGE', 'the table has %d cells (more than %d); it is never cut' % (
            len(cells), MAX_CELLS), spec), {'fault': fault}, 0
    queries = builtin_queries(model) + [resolve_query(model, q) for q in raw_queries]
    engine = None
    if args.engine:
        engine = Path(args.engine)
        if policy is None:
            raise UsageError('--engine applies to format A (airlock money) only')
        if not (engine.is_file() and os.access(engine, os.X_OK)):
            raise UsageError('the engine binary is missing')
    if not Path(dafny.DAFNY).is_file():
        raise UsageError('the pinned Dafny binary is missing')
    work = new_work(args.work, data + b'\0' + (query_data or b'') + b'\0' + str(fault).encode())
    print('work folder: ' + rel(work), file=sys.stderr)
    folder = work / 'model'
    folder.mkdir(parents=True)
    title = '"%s" (sha256 %s)' % (ast['name'], spec['sha256'])
    (folder / 'Model.dfy').write_text(model.model_text(title))
    (work / 'ast.json').write_bytes(ast_bytes)
    bullets, restate_error = restate(ast_bytes, work)
    tool = dp.locked_tool(work / 'dafny')
    clearing = Clearing(model, cells, queries, tool, folder, fault)
    try:
        finished = clearing.run()
    except dp.UsageError as reason:
        raise UsageError(str(reason))
    flags, warnings = ([] if finished else ['LINK_BROKEN']), []
    rows = build_rows(model, cells, clearing.extra)
    empty = [{'cell': c['label'], 'kind': c['kind'], 'dead_rule': c['rule'] is not None} for c in cells if c['empty']]
    undecided = [c['label'] for c in cells if not c['empty'] and not c['row']]
    if finished and any(c['empty'] for c in cells if c['label'] in ('ZERO_AMOUNT', 'TOTAL_CAP', 'reason OTHER')):
        flags.append('LINK_BROKEN')
        clearing.broken.append('the generated model is vacuous: ZERO_AMOUNT, TOTAL_CAP or OTHER is PROVED EMPTY')
    if undecided or clearing.seal['same_cell'] != 'PROVED' or clearing.seal['coverage'] != 'PROVED' \
            or any(q['answer'] == 'UNDECIDED' for q in queries):
        flags.append('UNDECIDED')
    if policy is not None:
        checks = [(r['_input'], r['allowed'], True) for r in rows] + [
            (q['witness']['input'], q['witness']['verdicts'], False) for q in queries if q['witness']]
        for inp, want, exact in checks:      # a row: the exact set; a witness: its verdicts are allowed
            got = pm.allowed(policy, scenario(model, inp))
            if (sorted(want) != got) if exact else not set(want) <= set(got):
                flags.append('GENERATOR_MISMATCH')
                warnings.append('GENERATOR_MISMATCH: policy_model.py allows %s at %s' % (','.join(got), describe(model, inp)))
    if engine is not None and rows:
        lines, error = dp.engine_eval(engine.resolve(), Path(args.spec).resolve(), [scenario(model, r['_input']) for r in rows])
        for r, line in zip(rows, lines or []):
            r['engine'] = line
        if error or any(r['engine'] != r['decision'] for r in rows):
            flags.append('ENGINE_MISMATCH')
            warnings.append('ENGINE_MISMATCH: %s' % (error or 'the engine and a verified row differ'))
    if bullets is None:
        flags.append('RESTATER_FAILED')
    for e in empty:
        if e['dead_rule']:
            warnings.append('DEAD RULE: %s' % e['cell'])
    for r in rows:
        if 'AMBIGUOUS' in r['tags']:
            warnings.append('AMBIGUOUS: row %d allows %s' % (r['n'], ','.join(r['allowed'])))
    for q in queries:
        if q['answer'] == 'WARNING':
            warnings.append('WARNING: query %s' % q['id'])
    if any(w.split(':')[0] in ('DEAD RULE', 'AMBIGUOUS', 'WARNING') for w in warnings):
        flags.append('WARNINGS')
    result = next((name for name in PRIORITY if name in flags), 'CLEAN')
    labels = LABELS + (['TEST FAULT ACTIVE: %s' % fault] if fault else []) + (
        ['engine rows: NATIVE CHECK (the Rust engine, not proved) on the verified rows'] if engine else [])
    report = {
        'tool': TOOL, 'end_to_end': False, 'spec': spec,
        'table': {'rows': [{k: v for k, v in r.items() if not k.startswith('_')} for r in rows],
                  'empty_cells': empty, 'undecided_cells': undecided, 'seal': clearing.seal},
        'queries': [{'id': q['id'], 'question': q['question'], 'builtin': q['builtin'], 'answer': q['answer'],
                     'notes': q['notes'],
                     'witness': None if not q['witness'] else {
                         'input': describe(model, q['witness']['input']), 'verdicts': q['witness']['verdicts'],
                         'source': q['witness']['source'], 'text': INTENDED}} for q in queries],
        'restatement': {'bullets': bullets, 'trust': TRUST},
        'warnings': warnings + ['LINK_BROKEN: ' + b for b in clearing.broken]
        + (['RESTATER_FAILED: ' + restate_error] if restate_error else []),
        'labels': labels, 'result': result, 'exit': EXIT[result]}
    return report, {'fault': fault, 'request': request, 'cells': len(cells), 'broken': clearing.broken}, len(tool.commands)


def run(argv):
    parser = Parser(prog='intent_clearing.py')
    sub = parser.add_subparsers(dest='command', required=True, parser_class=Parser)
    check = sub.add_parser('check-intent')
    check.add_argument('spec')
    for option in ('--queries', '--request', '--engine', '--work', '--test-fault'):
        check.add_argument(option, default=None)
    check.add_argument('--json', action='store_true')
    show = sub.add_parser('ast')
    show.add_argument('spec')
    args = parser.parse_args(argv)
    if args.command == 'ast':
        try:
            ast, _ = load_spec(read(args.spec, 'specification'))
        except pm.Malformed as reason:
            return None, 'MALFORMED: %s\nRESULT: MALFORMED (exit 2)\n' % reason, 0, EXIT['MALFORMED']
        return None, canonical(ast).decode(), 0, 0
    report, extra, processes = check_intent(args)
    text = json.dumps(report, sort_keys=True, indent=1) + '\n' if args.json else text_of(report, extra)
    return report, text, processes, report['exit']


def main(argv=None):
    try:
        _, text, processes, code = run(sys.argv[1:] if argv is None else argv)
    except UsageError as reason:
        print('USAGE: %s' % reason, file=sys.stderr)
        return EXIT['USAGE']
    print('dafny_processes=%d' % processes, file=sys.stderr)
    sys.stdout.write(text)
    return code


if __name__ == '__main__':
    sys.exit(main())
