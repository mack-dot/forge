#!/usr/bin/env python3
"""Suite of the blind structural restater `scripts/intent_restate.py` (Goal 21, Gate F1). FINITE TEST.
Python stdlib only. It proves nothing.

  python3 tests/intent/test_intent_restate.py [--case NAME]...

Cases:
  fixtures          each hand-built fixture AST (tests/intent/specs/*.json, the demo store
                    refunds-v2.json, one synthetic AST) gives the expected key bullets
  loader-agreement  `python3 scripts/intent_clearing.py ast <spec>` gives the same canonical bytes as the
                    hand-built AST (NOT RUN when that file or its `ast` subcommand is absent; a NOT RUN
                    of this case does not fail the suite)
  planted           the three planted/clean pairs differ in exactly the bullets of the changed rule(s),
                    with the expected changed words
  blind             the child runs under `python3 -I -B`, env={}, in an empty temp folder; any argument
                    gives exit 2 and empty stdout; the source opens no file, reads no argument, uses no
                    `os.` and imports only json and sys
  refusals          a table of bad ASTs: each exit 2, empty stdout, one stderr line
  deterministic     two runs are byte-identical; key order and white space of the input do not matter
  intervals         unit cases of the integer interval arithmetic (max_money edges, contradictions)
  format            every output line starts with "- ", is ASCII, and ends with a newline

One line per case with the actual exit codes of the child runs.
Exit 0: every selected case passed (loader-agreement may be NOT RUN). 1: a case failed or was NOT RUN.
2: bad arguments.
"""

import argparse
import ast as pyast
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / 'scripts/intent_restate.py'
LOADER = ROOT / 'scripts/intent_clearing.py'
SPECS = ROOT / 'tests/intent/specs'
MAX = 9223372036854775807
BUILTIN = {'min_amount': 1, 'total_cap': 'remaining', 'conflict': 'most-restrictive',
           'no_match': ['REASON_CAP', 'NO_RULE'], 'max_money': MAX}


class Failed(Exception):
    pass


class NotRun(Exception):
    pass


def canonical(value):
    """The same bytes as gate/common.py `canonical` (copied, not imported)."""
    return (json.dumps(value, sort_keys=True, separators=(',', ':'),
                       ensure_ascii=True, allow_nan=False) + '\n').encode('utf-8')


def rule(index, reason, verdict, amount=(), when=(), cap=None):
    return {'index': index, 'reason': reason, 'verdict': verdict, 'amount': [list(a) for a in amount],
            'when': [list(w) for w in when], 'cap_fact': cap}


def make_ast(name, fmt, reasons, facts, rules):
    return {'ast': 1, 'name': name, 'source_format': fmt, 'reasons': reasons, 'facts': facts,
            'rules': rules, 'builtin': json.loads(json.dumps(BUILTIN))}


# Hand-built from tests/intent/specs/*.json and the demo store policy, per DESIGN.md section 3.
G, S, D = 'GOODWILL', 'SHIPPING', 'DUPLICATE_CHARGE'
C, H, X = 'COMMIT', 'REQUIRE_HUMAN_COSIGN', 'REJECTED_POLICY'
IS, AM = 'intent-spec-v1', 'airlock-money-v1'
FIXTURES = {
    'boundary-clean': make_ast('goodwill-cosign-edge', IS, [G], [], [
        rule(0, G, C, [('<', 5000)]), rule(1, G, H, [('>=', 5000)])]),
    'boundary-planted-inclusive': make_ast('goodwill-cosign-edge', IS, [G], [], [
        rule(0, G, C, [('<=', 5000)]), rule(1, G, H, [('>', 5000)])]),
    'shipping-clean': make_ast('shipping-refunds', AM, [S], ['shipping_paid'], [
        rule(0, S, C, [('<=', 10000)], cap='shipping_paid')]),
    'shipping-planted-coarse-cap': make_ast('shipping-refunds', AM, [S], [], [
        rule(0, S, C, [('<=', 10000)])]),
    'vip-clean': make_ast('goodwill-vip', IS, [G], ['vip'], [
        rule(0, G, C, [('<=', 5000)], [('vip', '==', 0)]),
        rule(1, G, H, [('>', 5000)], [('vip', '==', 0)]),
        rule(2, G, C, [('<=', 20000)], [('vip', '==', 1)]),
        rule(3, G, H, [('>', 20000)], [('vip', '==', 1)])]),
    'vip-planted-swapped-flag': make_ast('goodwill-vip', IS, [G], ['vip'], [
        rule(0, G, C, [('<=', 5000)], [('vip', '==', 1)]),
        rule(1, G, H, [('>', 5000)], [('vip', '==', 1)]),
        rule(2, G, C, [('<=', 20000)], [('vip', '==', 0)]),
        rule(3, G, H, [('>', 20000)], [('vip', '==', 0)])]),
}
SPEC_FILES = {name: SPECS / (name + '.json') for name in FIXTURES}
REFUNDS_V2 = make_ast('store-refunds', AM, [D, G, S], ['shipping_paid'], [
    rule(0, D, C), rule(1, S, C, cap='shipping_paid'),
    rule(2, G, C, [('<=', 5000)]), rule(3, G, H, [('>=', 5001)])])
SPEC_FILES['refunds-v2'] = ROOT / 'examples/unbreakable_store/policies/refunds-v2.json'
FIXTURES['refunds-v2'] = REFUNDS_V2
SYNTHETIC = make_ast('synthetic', IS, ['A', 'B'], ['f', 'g'], [
    rule(0, 'A', X, [('>=', 100), ('!=', 150)], [('f', '!=', 3)]),
    rule(1, 'A', C, [('<=', 200)], cap='g'),
    rule(2, 'A', H, [('>', 10), ('<', 5)]),
    rule(3, 'B', C, [('==', 7)], [('f', '>=', 2), ('f', '<', 9)]),
    rule(4, 'B', X)])


def run(data, args=(), cwd=None):
    """Run the restater as the clearing tool does: -I -B, env={}, an empty folder."""
    with tempfile.TemporaryDirectory() as empty:
        done = subprocess.run([sys.executable, '-I', '-B', str(TOOL)] + list(args), input=data,
                              capture_output=True, env={}, cwd=cwd or empty, timeout=60)
    return done.returncode, done.stdout, done.stderr


class Suite:
    def __init__(self):
        self.codes = []

    def restate(self, value, args=()):
        data = value if isinstance(value, bytes) else canonical(value)
        code, out, err = run(data, args)
        self.codes.append(code)
        return code, out, err

    def bullets(self, value):
        code, out, err = self.restate(value)
        if code != 0 or err:
            raise Failed('exit %d stderr %r' % (code, err[:200]))
        return out.decode('ascii').splitlines()


def expect(lines, needles, where):
    text = '\n'.join(lines)
    for needle in needles:
        if needle not in text:
            raise Failed('%s: missing %r' % (where, needle))


def case_fixtures(s):
    common = ['- Built-in exclusion, checked first for every reason: an amount below 1 is always rejected '
              '(REJECTED_POLICY ZERO_AMOUNT).',
              'an amount above remaining is always rejected (REJECTED_POLICY TOTAL_CAP)',
              'Exclusion: any reason that this specification does not name is always rejected '
              '(REJECTED_POLICY NO_RULE)',
              'This text was made from the specification alone. Trust status: deterministic code, tested, '
              'NOT proved.']
    want = {
        'boundary-clean': [
            '- Specification goodwill-cosign-edge (source format intent-spec-v1): 2 rules and 1 reason (GOODWILL).',
            '- Rule 0, reason GOODWILL: is PERMITTED with no human (COMMIT) when the amount is less than 5000 '
            '(closed form: amount at most 4999 (strictly less than 5000)).',
            '- Rule 1, reason GOODWILL: needs a human cosign (REQUIRE_HUMAN_COSIGN) when the amount is at least '
            '5000 (closed form: amount at least 5000).',
            'every amount from 1 is inside the amount interval of at least one rule',
            '- Reason GOODWILL: no two rules with different verdicts have overlapping amount intervals.',
            'Facts that this specification reads: none.'],
        'boundary-planted-inclusive': [
            '(closed form: amount at most 5000)',
            '(closed form: amount at least 5001 (strictly more than 5000))'],
        'shipping-clean': [
            '- Rule 0, reason SHIPPING: is PERMITTED with no human (COMMIT) when the amount is at most 10000 '
            '(closed form: amount at most 10000) and the running total of this reason plus the amount is at '
            'most the fact shipping_paid (the fact must be present).',
            'Reason SHIPPING reads cap facts: shipping_paid; when facts: none.',
            'amounts that no rule covers (facts and caps ignored): from 10001 to 9223372036854775807.',
            'REJECTED_POLICY REASON_CAP when rule 0 (cap fact shipping_paid) holds in everything except its cap'],
        'shipping-planted-coarse-cap': [
            '- Rule 0, reason SHIPPING: is PERMITTED with no human (COMMIT) when the amount is at most 10000 '
            '(closed form: amount at most 10000).',
            'Reason SHIPPING reads no fact', 'so REASON_CAP does not occur'],
        'vip-clean': [
            '- Rule 0, reason GOODWILL: is PERMITTED with no human (COMMIT) when the amount is at most 5000 '
            '(closed form: amount at most 5000) and fact vip is present and vip is equal to 0.',
            '- Rule 3, reason GOODWILL: needs a human cosign (REQUIRE_HUMAN_COSIGN) when the amount is more than '
            '20000 (closed form: amount at least 20001 (strictly more than 20000)) and fact vip is present and '
            'vip is equal to 1.',
            'Reason GOODWILL reads cap facts: none; when facts: vip. A missing fact makes the rules that read '
            'it not match.',
            '- Reason GOODWILL, rules 1 and 2 have different verdicts (REQUIRE_HUMAN_COSIGN and COMMIT) and '
            'their amount intervals overlap from 5001 to 20000. When both match, the most restrictive verdict '
            'wins (REJECTED > COSIGN > COMMIT). Facts that could tell them apart: rule 1 reads fact vip is '
            'present and vip is equal to 0; rule 2 reads fact vip is present and vip is equal to 1.'],
        'vip-planted-swapped-flag': ['rule 1 reads fact vip is present and vip is equal to 1'],
        'refunds-v2': [
            '3 reasons (DUPLICATE_CHARGE, GOODWILL, SHIPPING)',
            '- Rule 0, reason DUPLICATE_CHARGE: is PERMITTED with no human (COMMIT) for any amount from 1 up to '
            'remaining.',
            '- Rule 1, reason SHIPPING: is PERMITTED with no human (COMMIT) for any amount from 1 up to '
            'remaining, when the running total of this reason plus the amount is at most the fact '
            'shipping_paid (the fact must be present).',
            '(closed form: amount at least 5001)',
            'Reason DUPLICATE_CHARGE reads no fact'],
    }
    for name, lines in want.items():
        expect(s.bullets(FIXTURES[name]), common + lines, name)
    order = [line.split(':')[0] for line in s.bullets(REFUNDS_V2) if line.startswith('- Rule ')]
    if order != ['- Rule 0, reason DUPLICATE_CHARGE', '- Rule 2, reason GOODWILL', '- Rule 3, reason GOODWILL',
                 '- Rule 1, reason SHIPPING']:
        raise Failed('refunds-v2 rule order %r' % order)
    expect(s.bullets(SYNTHETIC), [
        '- Rule 0, reason A: is REJECTED by this rule (REJECTED_POLICY RULE) when the amount is at least 100 '
        'and the amount is not equal to 150 (closed form: amount at least 100, except 150) and fact f is '
        'present and f is not equal to 3.',
        '(closed form: NO amount satisfies this rule)',
        '(closed form: amount exactly 7)',
        '- Rule 4, reason B: is REJECTED by this rule (REJECTED_POLICY RULE) for any amount from 1 up to '
        'remaining.',
        'Reason A (facts and caps ignored, != atoms ignored): every amount from 1 is inside the amount interval',
        'rules 0 and 1 have different verdicts (REJECTED_POLICY and COMMIT) and their amount intervals overlap '
        'from 100 to 200 (!= atoms ignored)',
        'rules 3 and 4 have different verdicts (COMMIT and REJECTED_POLICY) and their amount intervals '
        'overlap 7.',
        'rule 4 reads no fact',
        'Reason B (facts and caps ignored): every amount from 1 is inside the amount interval', 'Facts that this specification reads: f, g.'], 'synthetic')
    if any('rules 0 and 2' in line or 'rules 1 and 2' in line for line in s.bullets(SYNTHETIC)):
        raise Failed('synthetic: an empty rule was reported as overlapping')
    return '%d fixture ASTs, key bullets present' % (len(want) + 1)


def case_loader_agreement(s):
    if not LOADER.is_file():
        raise NotRun('scripts/intent_clearing.py absent')
    source = LOADER.read_text(encoding='utf-8')
    if "'ast'" not in source and '"ast"' not in source:
        raise NotRun('scripts/intent_clearing.py has no `ast` subcommand')
    for name, path in SPEC_FILES.items():
        done = subprocess.run([sys.executable, '-B', str(LOADER), 'ast', str(path.relative_to(ROOT))],
                              cwd=str(ROOT), capture_output=True, timeout=120)
        s.codes.append(done.returncode)
        if done.returncode != 0:
            raise Failed('%s: loader exit %d %r' % (name, done.returncode, done.stderr[-200:]))
        if done.stdout != canonical(FIXTURES[name]):
            raise Failed('%s: loader AST differs from the hand-built AST: %r' % (name, done.stdout[:300]))
    return '%d specs: loader AST == hand-built AST (canonical bytes)' % len(SPEC_FILES)


def diff(s, clean, planted):
    one, two = s.bullets(FIXTURES[clean]), s.bullets(FIXTURES[planted])
    if len(one) != len(two):
        raise Failed('%s: bullet counts %d and %d' % (planted, len(one), len(two)))
    return [(a, b) for a, b in zip(one, two) if a != b]


def check_pair(s, clean, planted, prefixes, words):
    changed = diff(s, clean, planted)
    got = [a.split(':')[0] for a, _ in changed]
    if got != prefixes:
        raise Failed('%s: changed bullets %r, expected %r' % (planted, got, prefixes))
    for index, (in_clean, in_planted) in words.items():
        a, b = changed[index]
        if in_clean not in a or in_planted not in b or in_clean in b or in_planted in a:
            raise Failed('%s: changed bullet %d lacks %r / %r' % (planted, index, in_clean, in_planted))
    return len(changed)


def case_planted(s):
    n1 = check_pair(s, 'boundary-clean', 'boundary-planted-inclusive',
                    ['- Rule 0, reason GOODWILL', '- Rule 1, reason GOODWILL'],
                    {0: ('closed form: amount at most 4999 (strictly less than 5000))',
                         'closed form: amount at most 5000)'),
                     1: ('closed form: amount at least 5000)',
                         'closed form: amount at least 5001 (strictly more than 5000))')})
    n2 = check_pair(s, 'vip-clean', 'vip-planted-swapped-flag',
                    ['- Rule 0, reason GOODWILL', '- Rule 1, reason GOODWILL', '- Rule 2, reason GOODWILL',
                     '- Rule 3, reason GOODWILL', '- Reason GOODWILL, rules 1 and 2 have different verdicts (REQUIRE_HUMAN_COSIGN and COMMIT) and their amount intervals overlap from 5001 to 20000. When both match, the most restrictive verdict wins (REJECTED > COSIGN > COMMIT). Facts that could tell them apart'],
                    {0: ('vip is equal to 0', 'vip is equal to 1'), 1: ('vip is equal to 0', 'vip is equal to 1'),
                     2: ('vip is equal to 1', 'vip is equal to 0'), 3: ('vip is equal to 1', 'vip is equal to 0'),
                     4: ('rule 1 reads fact vip is present and vip is equal to 0',
                         'rule 1 reads fact vip is present and vip is equal to 1')})
    cap = ('the running total of this reason plus the amount is at most the fact shipping_paid '
           '(the fact must be present)')
    n3 = check_pair(s, 'shipping-clean', 'shipping-planted-coarse-cap',
                    ['- Rule 0, reason SHIPPING', '- Reason SHIPPING reads cap facts',
                     '- Reason SHIPPING', '- Facts that this specification reads'],
                    {0: (cap, '(closed form: amount at most 10000).'),
                     1: ('cap facts: shipping_paid', 'reads no fact'),
                     2: ('REASON_CAP when rule 0 (cap fact shipping_paid)', 'REASON_CAP does not occur'),
                     3: ('reads: shipping_paid.', 'reads: none.')})
    return 'changed bullets: boundary %d (rules 0, 1), vip %d (rules 0-3 + their overlap), ' \
           'shipping %d (rule 0 + its cap, fact and REASON_CAP bullets)' % (n1, n2, n3)


def case_blind(s):
    data = canonical(FIXTURES['vip-clean'])
    code, out, err = s.restate(data)
    if code != 0 or not out:
        raise Failed('plain run exit %d' % code)
    for args in (['x'], ['--help'], ['-'], [str(SPEC_FILES['vip-clean'])], ['--request', 'r.txt'], ['']):
        code, out2, _ = s.restate(data, args)
        if code != 2 or out2:
            raise Failed('argument %r: exit %d, stdout %d bytes' % (args, code, len(out2)))
    with tempfile.TemporaryDirectory() as folder:
        before = sorted(Path(folder).iterdir())
        code, out3, _ = run(data, cwd=folder)
        s.codes.append(code)
        if sorted(Path(folder).iterdir()) != before or out3 != out:
            raise Failed('the run wrote into its folder or changed its output')
    source = TOOL.read_text(encoding='utf-8')
    for word in ('open(', 'argv[1', 'os.', '__import__', 'importlib', 'exec(', 'eval(', 'environ',
                 'subprocess', 'socket', 'pathlib'):
        if word in source:
            raise Failed('source contains %r' % word)
    imports = set()
    for node in pyast.walk(pyast.parse(source)):
        if isinstance(node, pyast.Import):
            imports.update(alias.name for alias in node.names)
        elif isinstance(node, pyast.ImportFrom):
            imports.add('from ' + str(node.module))
    if imports != {'json', 'sys'}:
        raise Failed('imports %r' % sorted(imports))
    if 'sys.dont_write_bytecode = True' not in source:
        raise Failed('sys.dont_write_bytecode is not set')
    return 'env={}, -I -B, empty folder untouched; 6 argument forms exit 2 with empty stdout; imports json, sys'


def bad_cases():
    good = FIXTURES['vip-clean']

    def mutate(change):
        value = json.loads(json.dumps(good))
        change(value)
        return canonical(value)

    def rule0(key, val):
        return mutate(lambda v: v['rules'][0].__setitem__(key, val))

    text = canonical(good).decode('ascii')
    return [
        ('not-utf8', b'\xff\xfe{}'),
        ('not-json', b'{"ast": 1,'),
        ('empty-input', b''),
        ('top-list', b'[]'),
        ('dup-key-top', text.replace('{"ast":1,', '{"ast":1,"ast":1,', 1).encode()),
        ('dup-key-rule', text.replace('"amount":', '"amount":[],"amount":', 1).encode()),
        ('float', text.replace('5000', '5000.0', 1).encode()),
        ('exponent', text.replace('5000', '5e3', 1).encode()),
        ('nan', text.replace('5000', 'NaN', 1).encode()),
        ('unknown-top-key', mutate(lambda v: v.__setitem__('comment', 'refund vip'))),
        ('missing-top-key', mutate(lambda v: v.pop('builtin'))),
        ('ast-2', mutate(lambda v: v.__setitem__('ast', 2))),
        ('ast-true', mutate(lambda v: v.__setitem__('ast', True))),
        ('name-space', mutate(lambda v: v.__setitem__('name', 'goodwill vip'))),
        ('name-25', mutate(lambda v: v.__setitem__('name', 'a' * 25))),
        ('name-non-ascii', mutate(lambda v: v.__setitem__('name', 'café'))),
        ('source-format', mutate(lambda v: v.__setitem__('source_format', 'intent-spec-v2'))),
        ('op', rule0('amount', [['=<', 5000]])),
        ('op-when', rule0('when', [['vip', '=', 0]])),
        ('verdict', rule0('verdict', 'ALLOW')),
        ('number-negative', rule0('amount', [['<=', -1]])),
        ('number-above-max', rule0('amount', [['<=', MAX + 1]])),
        ('number-bool', rule0('amount', [['<=', True]])),
        ('number-string', rule0('amount', [['<=', '5000']])),
        ('when-number-bool', rule0('when', [['vip', '==', False]])),
        ('atom-length', rule0('amount', [['<=', 5000, 1]])),
        ('amount-9-atoms', rule0('amount', [['<=', 5000]] * 9)),
        ('reason-not-listed', rule0('reason', 'SHIPPING')),
        ('when-fact-not-listed', rule0('when', [['gold', '==', 0]])),
        ('cap-fact-not-listed', rule0('cap_fact', 'shipping_paid')),
        ('cap-fact-empty', rule0('cap_fact', '')),
        ('reasons-unsorted', mutate(lambda v: (v.__setitem__('reasons', ['GOODWILL', 'AAA'])))),
        ('reasons-duplicate', mutate(lambda v: v.__setitem__('reasons', ['GOODWILL', 'GOODWILL']))),
        ('reasons-extra', mutate(lambda v: v.__setitem__('reasons', ['GOODWILL', 'SHIPPING']))),
        ('facts-extra', mutate(lambda v: v.__setitem__('facts', ['shipping_paid', 'vip']))),
        ('facts-missing-used', mutate(lambda v: v.__setitem__('facts', []))),
        ('index-wrong', rule0('index', 1)),
        ('index-bool', mutate(lambda v: v['rules'][1].__setitem__('index', True))),
        ('rule-unknown-key', rule0('description', 'vip refund')),
        ('rule-missing-key', mutate(lambda v: v['rules'][0].pop('cap_fact'))),
        ('rules-empty', mutate(lambda v: v.__setitem__('rules', []))),
        ('rules-65', mutate(lambda v: v.__setitem__('rules', [dict(v['rules'][0], index=i) for i in range(65)]))),
        ('builtin-max', mutate(lambda v: v['builtin'].__setitem__('max_money', MAX - 1))),
        ('builtin-extra', mutate(lambda v: v['builtin'].__setitem__('x', 1))),
        ('builtin-bool', mutate(lambda v: v['builtin'].__setitem__('min_amount', True))),
        ('builtin-order', mutate(lambda v: v['builtin'].__setitem__('no_match', ['NO_RULE', 'REASON_CAP']))),
        ('deep-nesting', b'[' * 100000 + b']' * 100000),
        ('above-1mib', canonical(good)[:-2] + b' ' * (1024 * 1024) + b'}\n'),
    ]


def case_refusals(s):
    cases = bad_cases()
    for name, data in cases:
        code, out, err = s.restate(data)
        lines = err.decode('utf-8', 'replace').splitlines()
        if code != 2 or out or len(lines) != 1:
            raise Failed('%s: exit %d, stdout %d bytes, stderr %r' % (name, code, len(out), err[:200]))
    return '%d bad ASTs: each exit 2, empty stdout, one stderr line' % len(cases)


def reorder(value):
    if isinstance(value, dict):
        return {k: reorder(value[k]) for k in sorted(value, reverse=True)}
    if isinstance(value, list):
        return [reorder(v) for v in value]
    return value


def case_deterministic(s):
    for name, value in list(FIXTURES.items()) + [('synthetic', SYNTHETIC)]:
        first = s.restate(canonical(value))
        second = s.restate(canonical(value))
        third = s.restate(json.dumps(reorder(value), indent=2).encode('ascii'))
        if first[0] != 0 or first != second or first != third:
            raise Failed('%s: outputs differ' % name)
    return '%d ASTs: canonical twice and reordered+indented give identical bytes' % (len(FIXTURES) + 1)


def load_module():
    spec = importlib.util.spec_from_file_location('intent_restate_under_test', str(TOOL))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def case_intervals(s):
    m = load_module()
    forms = [
        ([], (1, MAX), 'any amount from 1 up to remaining'),
        ([('<', 5000)], (1, 4999), 'amount at most 4999 (strictly less than 5000)'),
        ([('<=', 5000)], (1, 5000), 'amount at most 5000'),
        ([('>', 5000)], (5001, MAX), 'amount at least 5001 (strictly more than 5000)'),
        ([('>=', 5001), ('<=', 9000)], (5001, 9000), 'amount from 5001 to 9000'),
        ([('>', 0)], (1, MAX), 'any amount from 1 up to remaining'),
        ([('>=', 0)], (1, MAX), 'any amount from 1 up to remaining'),
        ([('<', 1)], (1, 0), 'NO amount satisfies this rule'),
        ([('<=', 0)], (1, 0), 'NO amount satisfies this rule'),
        ([('<', 0)], (1, -1), 'NO amount satisfies this rule'),
        ([('==', 0)], (1, 0), 'NO amount satisfies this rule'),
        ([('>', MAX)], (MAX + 1, MAX), 'NO amount satisfies this rule'),
        ([('>=', MAX)], (MAX, MAX), 'amount exactly %d' % MAX),
        ([('==', MAX)], (MAX, MAX), 'amount exactly %d' % MAX),
        ([('<=', MAX)], (1, MAX), 'any amount from 1 up to remaining'),
        ([('<', MAX)], (1, MAX - 1), 'amount at most %d (strictly less than %d)' % (MAX - 1, MAX)),
        ([('>', MAX - 1)], (MAX, MAX), 'amount exactly %d' % MAX),
        ([('<', 2)], (1, 1), 'amount exactly 1'),
        ([('>=', 5), ('<=', 4)], (5, 4), 'NO amount satisfies this rule'),
        ([('==', 7), ('==', 8)], (8, 7), 'NO amount satisfies this rule'),
        ([('==', 7), ('!=', 7)], (7, 7), 'NO amount satisfies this rule'),
        ([('>=', 5), ('<=', 6), ('!=', 5), ('!=', 6)], (5, 6), 'NO amount satisfies this rule'),
        ([('>=', 5), ('<=', 6), ('!=', 5)], (5, 6), 'amount from 5 to 6, except 5'),
        ([('!=', 3)], (1, MAX), 'any amount from 1 up to remaining, except 3'),
        ([('!=', 0)], (1, MAX), 'any amount from 1 up to remaining'),
        ([('>', 10), ('<', 20), ('>=', 12), ('<=', 30)], (12, 19), 'amount from 12 to 19'),
    ]
    for atoms, interval, text in forms:
        if m.interval(atoms) != interval or m.closed_form(atoms) != text:
            raise Failed('%r: %r %r' % (atoms, m.interval(atoms), m.closed_form(atoms)))
    gaps = [
        ([], [(1, MAX)]),
        ([(1, MAX)], []),
        ([(1, 10), (20, MAX)], [(11, 19)]),
        ([(20, MAX), (1, 10)], [(11, 19)]),
        ([(5, 5)], [(1, 4), (6, MAX)]),
        ([(5, 4)], [(1, MAX)]),
        ([(1, MAX - 1)], [(MAX, MAX)]),
        ([(2, MAX)], [(1, 1)]),
        ([(1, 5), (3, 9), (10, 10)], [(11, MAX)]),
        ([(MAX, MAX), (1, 1)], [(2, MAX - 1)]),
    ]
    for intervals, holes in gaps:
        if m.gaps(intervals) != holes:
            raise Failed('gaps %r: %r' % (intervals, m.gaps(intervals)))
    overlaps = [((1, 5000), (5001, MAX), None), ((5001, MAX), (1, 20000), (5001, 20000)),
                ((1, 0), (1, MAX), None), ((MAX, MAX), (1, MAX), (MAX, MAX))]
    for one, two, both in overlaps:
        if m.overlap(one, two) != both:
            raise Failed('overlap %r %r: %r' % (one, two, m.overlap(one, two)))
    return '%d closed forms, %d gap sets, %d overlaps' % (len(forms), len(gaps), len(overlaps))


def case_format(s):
    count = 0
    for value in list(FIXTURES.values()) + [SYNTHETIC]:
        code, out, _ = s.restate(value)
        if code != 0 or not out.endswith(b'\n') or b'\r' in out:
            raise Failed('exit %d or bad line ends' % code)
        if any(b > 127 for b in out):
            raise Failed('non-ASCII byte in output')
        for line in out.decode('ascii').split('\n')[:-1]:
            count += 1
            if not line.startswith('- ') or line.startswith('-  '):
                raise Failed('line does not start with "- ": %r' % line[:80])
    return '%d lines checked: each starts with "- ", ASCII' % count


CASES = [('fixtures', case_fixtures), ('loader-agreement', case_loader_agreement), ('planted', case_planted),
         ('blind', case_blind), ('refusals', case_refusals), ('deterministic', case_deterministic),
         ('intervals', case_intervals), ('format', case_format)]
OPTIONAL = {'loader-agreement'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--case', action='append', default=[])
    args = parser.parse_args()
    names = [name for name, _ in CASES]
    if any(c not in names for c in args.case):
        print('unknown case; cases: ' + ', '.join(names), file=sys.stderr)
        return 2
    s = Suite()
    bad = 0
    for name, function in CASES:
        if args.case and name not in args.case:
            continue
        s.codes = []
        try:
            detail = function(s)
            state = 'PASS'
        except NotRun as reason:
            state, detail = 'NOT RUN', str(reason)
            if name not in OPTIONAL:
                bad += 1
        except Failed as reason:
            state, detail = 'FAIL', str(reason)
            bad += 1
        codes = sorted(set(s.codes))
        print('%-16s %-7s exits=%s runs=%d | %s' % (name, state, ','.join(map(str, codes)) or '-',
                                                    len(s.codes), detail))
    print('RESULT: %s' % ('PASS' if bad == 0 else 'FAIL or NOT RUN (%d)' % bad))
    return 0 if bad == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
