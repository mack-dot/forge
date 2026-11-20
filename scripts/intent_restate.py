#!/usr/bin/env python3
"""Blind structural restater (Goal 21, Gate F1; DESIGN.md sections 3, 4 and 8).

Input: ONLY the canonical AST JSON bytes on standard input (at most 1 MiB). No argument, no file,
no request text, no query. Output: plain-English bullets, one bullet per line, each line starts
with "- ", ASCII only. Same input bytes give the same output bytes.

Exit 0: bullets printed. Exit 2: an argument was given, or the AST was refused (a one-line reason
on standard error, nothing on standard output).

Trust status: deterministic code, tested, NOT proved. Imports: json and sys only.
"""

import json
import sys

sys.dont_write_bytecode = True

MAX_MONEY = 9223372036854775807
MAX_INPUT = 1024 * 1024
OPS = ('<', '<=', '>', '>=', '==', '!=')
VERDICTS = ('COMMIT', 'REQUIRE_HUMAN_COSIGN', 'REJECTED_POLICY')
SOURCE_FORMATS = ('intent-spec-v1', 'airlock-money-v1')
TOP_KEYS = ('ast', 'builtin', 'facts', 'name', 'reasons', 'rules', 'source_format')
RULE_KEYS = ('amount', 'cap_fact', 'index', 'reason', 'verdict', 'when')
BUILTIN = {'min_amount': 1, 'total_cap': 'remaining', 'conflict': 'most-restrictive',
           'no_match': ['REASON_CAP', 'NO_RULE'], 'max_money': MAX_MONEY}
ID_CHARS = frozenset('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-')
VERDICT_WORDS = {
    'COMMIT': 'is PERMITTED with no human (COMMIT)',
    'REQUIRE_HUMAN_COSIGN': 'needs a human cosign (REQUIRE_HUMAN_COSIGN)',
    'REJECTED_POLICY': 'is REJECTED by this rule (REJECTED_POLICY RULE)',
}
OP_WORDS = {'<': 'less than', '<=': 'at most', '>': 'more than', '>=': 'at least',
            '==': 'equal to', '!=': 'not equal to'}


class Refused(Exception):
    pass


# ---------------------------------------------------------------------------------------------------
# Strict reading and validation.
# ---------------------------------------------------------------------------------------------------
def _pairs(items):
    out = {}
    for key, value in items:
        if key in out:
            raise Refused('duplicate key %r' % key)
        out[key] = value
    return out


def _no_float(text):
    raise Refused('float %r' % text)


def _no_constant(text):
    raise Refused('non-finite number %r' % text)


def parse(data):
    if len(data) > MAX_INPUT:
        raise Refused('input above 1 MiB')
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        raise Refused('input is not UTF-8')
    try:
        return json.loads(text, object_pairs_hook=_pairs, parse_float=_no_float,
                          parse_constant=_no_constant)
    except Refused:
        raise
    except (ValueError, RecursionError) as error:
        raise Refused('input is not JSON (%s)' % type(error).__name__)


def is_int(value):
    return type(value) is int


def check_id(value, where):
    if type(value) is not str or not 1 <= len(value) <= 24 or any(c not in ID_CHARS for c in value):
        raise Refused('%s is not an id [A-Za-z0-9_-]{1,24}' % where)
    return value


def check_number(value, where):
    if not is_int(value) or not 0 <= value <= MAX_MONEY:
        raise Refused('%s is not an integer 0..%d' % (where, MAX_MONEY))
    return value


def check_keys(obj, keys, where):
    if type(obj) is not dict:
        raise Refused('%s is not an object' % where)
    if tuple(sorted(obj)) != keys:
        raise Refused('%s keys are not exactly %s' % (where, ', '.join(keys)))


def check_sorted_unique(value, where):
    if type(value) is not list:
        raise Refused('%s is not a list' % where)
    for i, item in enumerate(value):
        check_id(item, '%s[%d]' % (where, i))
    if any(value[i] >= value[i + 1] for i in range(len(value) - 1)):
        raise Refused('%s is not sorted and unique' % where)
    return value


def same_builtin(value, expected):
    if type(expected) is dict:
        return type(value) is dict and sorted(value) == sorted(expected) and \
            all(same_builtin(value[k], expected[k]) for k in expected)
    if type(expected) is list:
        return type(value) is list and len(value) == len(expected) and \
            all(same_builtin(a, b) for a, b in zip(value, expected))
    return type(value) is type(expected) and value == expected


def validate(ast):
    check_keys(ast, TOP_KEYS, 'AST')
    if not is_int(ast['ast']) or ast['ast'] != 1:
        raise Refused('ast is not 1')
    check_id(ast['name'], 'name')
    if type(ast['source_format']) is not str or ast['source_format'] not in SOURCE_FORMATS:
        raise Refused('source_format is not one of %s' % ', '.join(SOURCE_FORMATS))
    reasons = check_sorted_unique(ast['reasons'], 'reasons')
    facts = check_sorted_unique(ast['facts'], 'facts')
    if not same_builtin(ast['builtin'], BUILTIN):
        raise Refused('builtin is not the fixed built-in object')
    rules = ast['rules']
    if type(rules) is not list or not 1 <= len(rules) <= 64:
        raise Refused('rules is not a list of 1 to 64 rules')
    used_reasons, used_facts = set(), set()
    for position, rule in enumerate(rules):
        where = 'rules[%d]' % position
        check_keys(rule, RULE_KEYS, where)
        if not is_int(rule['index']) or rule['index'] != position:
            raise Refused('%s index is not its position %d' % (where, position))
        check_id(rule['reason'], where + ' reason')
        if rule['reason'] not in reasons:
            raise Refused('%s reason is not in reasons' % where)
        used_reasons.add(rule['reason'])
        if type(rule['verdict']) is not str or rule['verdict'] not in VERDICTS:
            raise Refused('%s verdict is not one of %s' % (where, ', '.join(VERDICTS)))
        amount = rule['amount']
        if type(amount) is not list or len(amount) > 8:
            raise Refused('%s amount is not a list of at most 8 atoms' % where)
        for k, atom in enumerate(amount):
            aw = '%s amount[%d]' % (where, k)
            if type(atom) is not list or len(atom) != 2:
                raise Refused('%s is not a pair [op, number]' % aw)
            if type(atom[0]) is not str or atom[0] not in OPS:
                raise Refused('%s op is not one of %s' % (aw, ' '.join(OPS)))
            check_number(atom[1], aw + ' number')
        when = rule['when']
        if type(when) is not list or len(when) > 8:
            raise Refused('%s when is not a list of at most 8 atoms' % where)
        for k, atom in enumerate(when):
            ww = '%s when[%d]' % (where, k)
            if type(atom) is not list or len(atom) != 3:
                raise Refused('%s is not a triple [fact, op, number]' % ww)
            check_id(atom[0], ww + ' fact')
            if atom[0] not in facts:
                raise Refused('%s fact is not in facts' % ww)
            if type(atom[1]) is not str or atom[1] not in OPS:
                raise Refused('%s op is not one of %s' % (ww, ' '.join(OPS)))
            check_number(atom[2], ww + ' number')
            used_facts.add(atom[0])
        cap = rule['cap_fact']
        if cap is not None:
            check_id(cap, where + ' cap_fact')
            if cap not in facts:
                raise Refused('%s cap_fact is not in facts' % where)
            used_facts.add(cap)
    if set(reasons) != used_reasons:
        raise Refused('reasons is not exactly the set of reasons of the rules')
    if set(facts) != used_facts:
        raise Refused('facts is not exactly the set of facts of the rules')
    return ast


# ---------------------------------------------------------------------------------------------------
# Integer interval arithmetic (amount atoms of ONE rule, inside 1..MAX_MONEY).
# ---------------------------------------------------------------------------------------------------
def interval(atoms):
    """Return (low, high) for the amount atoms, `!=` ignored; low > high means empty."""
    low, high = 1, MAX_MONEY
    for op, n in atoms:
        if op == '<':
            high = min(high, n - 1)
        elif op == '<=':
            high = min(high, n)
        elif op == '>':
            low = max(low, n + 1)
        elif op == '>=':
            low = max(low, n)
        elif op == '==':
            low, high = max(low, n), min(high, n)
    return low, high


def exact_empty(atoms):
    """True when no amount in 1..MAX_MONEY satisfies every atom, `!=` included."""
    low, high = interval(atoms)
    if low > high:
        return True
    excluded = {n for op, n in atoms if op == '!='}
    return high - low + 1 <= len(excluded) and all(v in excluded for v in range(low, high + 1))


def closed_form(atoms):
    if exact_empty(atoms):
        return 'NO amount satisfies this rule'
    low, high = interval(atoms)
    if low == high:
        text = 'amount exactly %d' % low
    elif low == 1 and high == MAX_MONEY:
        text = 'any amount from 1 up to remaining'
    elif low == 1:
        text = 'amount at most %d' % high
        if any(op == '<' and n == high + 1 for op, n in atoms):
            text += ' (strictly less than %d)' % (high + 1)
    elif high == MAX_MONEY:
        text = 'amount at least %d' % low
        if any(op == '>' and n == low - 1 for op, n in atoms):
            text += ' (strictly more than %d)' % (low - 1)
    else:
        text = 'amount from %d to %d' % (low, high)
    excluded = sorted({n for op, n in atoms if op == '!=' and low <= n <= high})
    if excluded:
        text += ', except %s' % ', '.join(str(n) for n in excluded)
    return text


def span(low, high):
    return str(low) if low == high else 'from %d to %d' % (low, high)


def gaps(intervals):
    """Amounts in 1..MAX_MONEY that no interval covers, as a sorted list of (low, high)."""
    out, start = [], 1
    for low, high in sorted(i for i in intervals if i[0] <= i[1]):
        if low > start:
            out.append((start, low - 1))
        start = max(start, high + 1)
        if start > MAX_MONEY:
            break
    if start <= MAX_MONEY:
        out.append((start, MAX_MONEY))
    return out


def overlap(one, two):
    low, high = max(one[0], two[0]), min(one[1], two[1])
    return (low, high) if low <= high else None


# ---------------------------------------------------------------------------------------------------
# Bullets.
# ---------------------------------------------------------------------------------------------------
def plural(count, word):
    return '%d %s%s' % (count, word, '' if count == 1 else 's')


def fact_words(rule):
    words = ['fact %s is present and %s is %s %d' % (f, f, OP_WORDS[op], n) for f, op, n in rule['when']]
    if rule['cap_fact'] is not None:
        words.append('the running total of this reason plus the amount is at most the fact %s '
                     '(the fact must be present)' % rule['cap_fact'])
    return words


def rule_bullet(rule):
    head = 'Rule %d, reason %s: %s' % (rule['index'], rule['reason'], VERDICT_WORDS[rule['verdict']])
    conditions = fact_words(rule)
    if not rule['amount']:
        text = head + ' for any amount from 1 up to remaining'
        if conditions:
            text += ', when ' + ' and '.join(conditions)
    else:
        atoms = ' and '.join('the amount is %s %d' % (OP_WORDS[op], n) for op, n in rule['amount'])
        text = head + ' when %s (closed form: %s)' % (atoms, closed_form(rule['amount']))
        if conditions:
            text += ' and ' + ' and '.join(conditions)
    return text + '.'


def restate(ast):
    rules, reasons, facts = ast['rules'], ast['reasons'], ast['facts']
    out = ['Specification %s (source format %s): %s and %s (%s). Amounts are integers in minor '
           'units from 0 to %d; the currency is not stated.' % (
               ast['name'], ast['source_format'], plural(len(rules), 'rule'),
               plural(len(reasons), 'reason'), ', '.join(reasons), MAX_MONEY)]
    out.append('Built-in exclusion, checked first for every reason: an amount below 1 is always '
               'rejected (REJECTED_POLICY ZERO_AMOUNT).')
    out.append('Built-in exclusion, checked second for every reason: an amount above remaining is '
               'always rejected (REJECTED_POLICY TOTAL_CAP). No rule can permit an amount above remaining.')
    by_reason = {r: [rule for rule in rules if rule['reason'] == r] for r in reasons}
    for r in reasons:
        for rule in by_reason[r]:
            out.append(rule_bullet(rule))
    for r in reasons:
        caps = sorted({rule['cap_fact'] for rule in by_reason[r] if rule['cap_fact'] is not None})
        whens = sorted({atom[0] for rule in by_reason[r] for atom in rule['when']})
        if not caps and not whens:
            out.append('Reason %s reads no fact: its rules do not depend on facts.' % r)
        else:
            out.append('Reason %s reads cap facts: %s; when facts: %s. A missing fact makes the rules '
                       'that read it not match.' % (r, ', '.join(caps) or 'none', ', '.join(whens) or 'none'))
    for r in reasons:
        has_ne = any(op == '!=' for rule in by_reason[r] for op, _ in rule['amount'])
        note = ' (facts and caps ignored%s)' % (', != atoms ignored' if has_ne else '')
        holes = gaps([interval(rule['amount']) for rule in by_reason[r]])
        if holes:
            out.append('Reason %s, amounts that no rule covers%s: %s. Such an amount is always rejected '
                       '(REJECTED_POLICY NO_RULE, or TOTAL_CAP above remaining).' % (r, note, '; '.join(span(a, b) for a, b in holes)))
        else:
            out.append('Reason %s%s: every amount from 1 is inside the amount interval of at least one rule (of any '
                       'verdict; a rule whose facts can never hold still counts here).' % (r, note))
    for r in reasons:
        found = 0
        group = by_reason[r]
        for i, one in enumerate(group):
            for two in group[i + 1:]:
                if one['verdict'] == two['verdict']:
                    continue
                both = overlap(interval(one['amount']), interval(two['amount']))
                if both is None:
                    continue
                found += 1
                has_ne = any(op == '!=' for rule in (one, two) for op, _ in rule['amount'])
                reads = []
                for rule in (one, two):
                    words = fact_words(rule)
                    reads.append('rule %d reads %s' % (rule['index'], ' and '.join(words) if words
                                                        else 'no fact'))
                out.append('Reason %s, rules %d and %d have different verdicts (%s and %s) and their amount '
                           'intervals overlap %s%s. When both match, the most restrictive verdict wins '
                           '(REJECTED > COSIGN > COMMIT). Facts that could tell them apart: %s.' % (
                               r, one['index'], two['index'], one['verdict'], two['verdict'],
                               span(*both), ' (!= atoms ignored)' if has_ne else '', '; '.join(reads)))
        if not found:
            out.append('Reason %s: no two rules with different verdicts have overlapping amount '
                       'intervals.' % r)
    out.append('Exclusion: any reason that this specification does not name is always rejected '
               '(REJECTED_POLICY NO_RULE). Named reasons: %s.' % ', '.join(reasons))
    for r in reasons:
        capped = [rule for rule in by_reason[r] if rule['cap_fact'] is not None]
        if capped:
            out.append('Reason %s: an input that no rule matches is rejected: REJECTED_POLICY REASON_CAP '
                       'when %s holds in everything except its cap (the fact is missing, or the running '
                       'total plus the amount is above it), else REJECTED_POLICY NO_RULE.' % (
                           r, ' or '.join('rule %d (cap fact %s)' % (rule['index'], rule['cap_fact'])
                                          for rule in capped)))
        else:
            out.append('Reason %s: an input that no rule matches is rejected (REJECTED_POLICY NO_RULE); '
                       'no rule of this reason has a cap, so REASON_CAP does not occur.' % r)
    out.append('Facts that this specification reads: %s. This text was made from the specification '
               'alone. Trust status: deterministic code, tested, NOT proved.' % (', '.join(facts) or 'none'))
    return ''.join('- %s\n' % line for line in out)


def main():
    if len(sys.argv) != 1:
        sys.stderr.write('usage: intent_restate.py takes no argument; it reads the AST on stdin\n')
        return 2
    try:
        data = sys.stdin.buffer.read(MAX_INPUT + 1)
        text = restate(validate(parse(data)))
        output = text.encode('ascii')
    except Refused as reason:
        sys.stderr.write('REFUSED: %s\n' % reason)
        return 2
    except UnicodeEncodeError:
        sys.stderr.write('REFUSED: output is not ASCII\n')
        return 2
    sys.stdout.buffer.write(output)
    sys.stdout.buffer.flush()
    return 0


if __name__ == '__main__':
    sys.exit(main())
