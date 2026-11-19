#!/usr/bin/env python3
"""Policy model of `diff-policy` (Goal 20, forge-airlock). Python stdlib only. NOT proved.

This file holds three things:
  1. A STRICT loader for the money and saga policy JSON of proposals/forge2-goal20-sdk/DESIGN.md.
     It refuses unknown keys, duplicate keys, floats, non-canonical decimal strings and ids outside
     [A-Za-z0-9_-]{1,24}. When in doubt it refuses: a policy that the engine accepts can be refused here,
     but this loader must never accept a policy that the engine refuses.
  2. An INDEPENDENT Python evaluator of the money rules (DESIGN.md "Policy files"). It gives the SET of
     verdicts that the policy text allows for one input, and the verdict that the engine must pick
     (most restrictive). It is a second transcription of the rules; it can be wrong in the same way
     as the engine.
  3. The finite, deterministic list of boundary scenarios for two money policies.

Rule semantics (DESIGN.md): built in and first, `amount >= 1` (else REJECTED_POLICY ZERO_AMOUNT) and
`amount <= remaining` (else REJECTED_POLICY TOTAL_CAP). A rule matches when the reason is equal,
`min_amount <= amount <= max_amount` (each optional), and, with `max_reason_total_fact`,
`reason_total + amount <= facts[fact]`. A rule that names a fact that the input does not hold does not
match (fail closed). Rules that match with different verdicts: the engine takes the most restrictive
(REJECTED_POLICY > REQUIRE_HUMAN_COSIGN > COMMIT). No rule matches: REJECTED_POLICY REASON_CAP if at
least one fact rule of the reason passed its amount bounds but failed its fact cap (or its fact is
missing), else REJECTED_POLICY NO_RULE.
DEPARTURE from DESIGN.md (which says only NO_RULE): the REASON_CAP code is the engine's
(src/airlock/policy.rs, eval_money). This file follows the engine; the difference is a finding to record.
"""

import hashlib
import json
import re

MAX_MONEY = 9223372036854775807
MAX_POLICY_BYTES = 1 << 20
MAX_RULES = 64
MAX_STATES = 64
MAX_TRANSITIONS = 1024
ID = re.compile(r'[A-Za-z0-9_-]{1,24}')
DECIMAL = re.compile(r'0|[1-9][0-9]{0,18}')

COMMIT = 'COMMIT'
COSIGN = 'REQUIRE_HUMAN_COSIGN'
REJECTED = 'REJECTED_POLICY'
RULE_VERDICTS = (COMMIT, COSIGN, REJECTED)
ZERO_AMOUNT = 'REJECTED_POLICY ZERO_AMOUNT'
TOTAL_CAP = 'REJECTED_POLICY TOTAL_CAP'
NO_RULE = 'REJECTED_POLICY NO_RULE'
REASON_CAP = 'REJECTED_POLICY REASON_CAP'
# The answer line of the engine for a rule whose verdict is REJECTED_POLICY. DESIGN.md does not name
# this code; the engine (src/airlock/policy.rs) uses RULE. The engine cross-check (TABLE_MISMATCH)
# catches a difference.
RULE_REJECT = 'REJECTED_POLICY RULE'
RANK = {COMMIT: 0, COSIGN: 1, RULE_REJECT: 2}

# Scenario constants. A fixed fact value gives fixed, readable rows.
FACT_VALUE = 1000
REMAINING_MARGIN = 10


class Malformed(Exception):
    """A policy that this loader refuses. Nothing starts after it."""


def _no_duplicates(pairs):
    seen = {}
    for key, value in pairs:
        if key in seen:
            raise Malformed('duplicate key: ' + key)
        seen[key] = value
    return seen


def _refuse_float(text):
    raise Malformed('a JSON number with a fraction or exponent: ' + text)


def _refuse_constant(text):
    raise Malformed('a JSON constant that is not JSON: ' + text)


def parse_json(data):
    """Strict JSON: UTF-8 without BOM, at most 1 MiB, no duplicate key, no float, no NaN."""
    if not isinstance(data, bytes):
        raise Malformed('policy input is not bytes')
    if len(data) > MAX_POLICY_BYTES:
        raise Malformed('policy file is larger than 1 MiB')
    if data.startswith(b'\xef\xbb\xbf'):
        raise Malformed('policy file starts with a byte order mark')
    try:
        text = data.decode('utf-8', 'strict')
    except UnicodeDecodeError:
        raise Malformed('policy file is not UTF-8')
    try:
        return json.loads(text, object_pairs_hook=_no_duplicates, parse_float=_refuse_float,
                          parse_constant=_refuse_constant)
    except Malformed:
        raise
    except (ValueError, RecursionError) as error:
        raise Malformed('policy file is not JSON: ' + str(error).split(':')[0])


def _keys(obj, where, required, optional=()):
    if not isinstance(obj, dict):
        raise Malformed(where + ' is not a JSON object')
    unknown = sorted(set(obj) - set(required) - set(optional))
    if unknown:
        raise Malformed(where + ' has an unknown key: ' + unknown[0])
    missing = sorted(set(required) - set(obj))
    if missing:
        raise Malformed(where + ' lacks the key: ' + missing[0])


def _id(value, where):
    if not isinstance(value, str) or not ID.fullmatch(value):
        raise Malformed(where + ' is not an id [A-Za-z0-9_-]{1,24}')
    return value


def _amount(value, where):
    if not isinstance(value, str) or not DECIMAL.fullmatch(value) or int(value) > MAX_MONEY:
        raise Malformed(where + ' is not a canonical decimal string at most 9223372036854775807')
    return int(value)


def _version(value):
    if type(value) is not int or value != 1:
        raise Malformed('version is not the integer 1')


def load_policy(data):
    """Parsed, checked policy (a plain dict) from the bytes of one policy file. Raises Malformed."""
    obj = parse_json(data)
    if not isinstance(obj, dict):
        raise Malformed('policy is not a JSON object')
    kind = obj.get('airlock')
    if kind == 'money':
        return _money(obj)
    if kind == 'saga':
        return _saga(obj)
    if kind == 'inventory':
        raise Malformed('UNSUPPORTED: diff-policy handles money and saga policies only')
    raise Malformed('airlock is not "money" or "saga"')


def _money(obj):
    _keys(obj, 'money policy', ('airlock', 'version', 'name', 'profile'), ('rules',))
    _version(obj['version'])
    name = _id(obj['name'], 'name')
    if obj['profile'] == 'canonical-refund':
        if 'rules' in obj:
            raise Malformed('a canonical-refund policy has no rules')
        raise Malformed('UNSUPPORTED: diff-policy handles the parametric money profile only '
                        '(canonical-refund is decided by the CakeML binary)')
    if obj['profile'] != 'parametric':
        raise Malformed('profile is not "parametric" or "canonical-refund"')
    rules = obj.get('rules')
    if not isinstance(rules, list) or not rules:
        raise Malformed('a parametric policy needs a non-empty rules list')
    if len(rules) > MAX_RULES:
        raise Malformed('more than %d rules' % MAX_RULES)
    checked = []
    for index, rule in enumerate(rules):
        where = 'rule %d' % index
        _keys(rule, where, ('reason', 'verdict'), ('min_amount', 'max_amount', 'max_reason_total_fact'))
        if rule['verdict'] not in RULE_VERDICTS:
            raise Malformed(where + ' verdict is not COMMIT, REQUIRE_HUMAN_COSIGN or REJECTED_POLICY')
        item = {'reason': _id(rule['reason'], where + ' reason'), 'verdict': rule['verdict'],
                'min_amount': None, 'max_amount': None, 'fact': None}
        if 'min_amount' in rule:
            item['min_amount'] = _amount(rule['min_amount'], where + ' min_amount')
        if 'max_amount' in rule:
            item['max_amount'] = _amount(rule['max_amount'], where + ' max_amount')
        if 'max_reason_total_fact' in rule:
            item['fact'] = _id(rule['max_reason_total_fact'], where + ' max_reason_total_fact')
        if item['min_amount'] is not None and item['max_amount'] is not None \
                and item['min_amount'] > item['max_amount']:
            raise Malformed(where + ' min_amount is above max_amount')
        checked.append(item)
    return {'airlock': 'money', 'name': name, 'rules': checked}


def _saga(obj):
    _keys(obj, 'saga policy', ('airlock', 'version', 'name', 'states', 'initial', 'in_flight', 'transitions'))
    _version(obj['version'])
    name = _id(obj['name'], 'name')
    states = obj['states']
    if not isinstance(states, list) or not states or len(states) > MAX_STATES:
        raise Malformed('states is not a non-empty list of at most %d ids' % MAX_STATES)
    states = [_id(s, 'state') for s in states]
    if len(set(states)) != len(states):
        raise Malformed('a state is listed twice')
    initial = _id(obj['initial'], 'initial')
    if initial not in states:
        raise Malformed('initial is not a listed state')
    in_flight = obj['in_flight']
    if not isinstance(in_flight, list):
        raise Malformed('in_flight is not a list')
    in_flight = [_id(s, 'in_flight state') for s in in_flight]
    if len(set(in_flight)) != len(in_flight) or not set(in_flight) <= set(states):
        raise Malformed('in_flight lists a state twice or a state that is not listed')
    transitions = obj['transitions']
    if not isinstance(transitions, list) or len(transitions) > MAX_TRANSITIONS:
        raise Malformed('transitions is not a list of at most %d pairs' % MAX_TRANSITIONS)
    pairs = []
    for pair in transitions:
        if not isinstance(pair, list) or len(pair) != 2:
            raise Malformed('a transition is not a pair')
        source, target = _id(pair[0], 'transition state'), _id(pair[1], 'transition state')
        if source not in states or target not in states:
            raise Malformed('a transition names a state that is not listed')
        if source == target:
            raise Malformed('a transition from a state to itself')
        pairs.append((source, target))
    if len(set(pairs)) != len(pairs):
        raise Malformed('a transition is listed twice')
    return {'airlock': 'saga', 'name': name, 'states': states, 'initial': initial,
            'in_flight': in_flight, 'transitions': pairs}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


# ---------------------------------------------------------------------------------------------------
# The independent evaluator (money).
# ---------------------------------------------------------------------------------------------------
def within_bounds(rule, scenario):
    amount = scenario['amount']
    if scenario['reason'] != rule['reason']:
        return False
    if rule['min_amount'] is not None and amount < rule['min_amount']:
        return False
    if rule['max_amount'] is not None and amount > rule['max_amount']:
        return False
    return True


def within_fact(rule, scenario):
    if rule['fact'] is None:
        return True
    facts = dict(scenario['facts'])
    return rule['fact'] in facts and scenario['reason_total'] + scenario['amount'] <= facts[rule['fact']]


def rule_matches(rule, scenario):
    return within_bounds(rule, scenario) and within_fact(rule, scenario)


def capped(rule, scenario):
    """A fact rule that passed its amount bounds and failed its fact cap."""
    return within_bounds(rule, scenario) and not within_fact(rule, scenario)


def verdict_text(rule_verdict):
    return RULE_REJECT if rule_verdict == REJECTED else rule_verdict


def allowed(policy, scenario):
    """The SET of verdicts that the policy text allows for this input (sorted list)."""
    if scenario['amount'] < 1:
        return [ZERO_AMOUNT]
    if scenario['amount'] > scenario['remaining']:
        return [TOTAL_CAP]
    found = {verdict_text(rule['verdict']) for rule in policy['rules'] if rule_matches(rule, scenario)}
    if found:
        return sorted(found)
    return [REASON_CAP] if any(capped(rule, scenario) for rule in policy['rules']) else [NO_RULE]


def decide(policy, scenario):
    """The verdict that the engine must give: the most restrictive allowed one."""
    choices = allowed(policy, scenario)
    return max(choices, key=lambda verdict: RANK.get(verdict, 3))


# ---------------------------------------------------------------------------------------------------
# Scenarios (money).
# ---------------------------------------------------------------------------------------------------
def scenario(reason, amount, remaining, reason_total, facts):
    return {'reason': reason, 'amount': amount, 'remaining': remaining, 'reason_total': reason_total,
            'facts': tuple(sorted(facts.items()))}


def scenarios(old, new):
    """A finite, deterministic list of boundary scenarios from the thresholds of BOTH policies."""
    rules = old['rules'] + new['rules']
    reasons = sorted({rule['reason'] for rule in rules})
    fact_names = sorted({rule['fact'] for rule in rules if rule['fact'] is not None})
    bounds = {r: sorted({b for rule in rules if rule['reason'] == r
                         for b in (rule['min_amount'], rule['max_amount']) if b is not None}) for r in reasons}
    every_bound = [b for r in reasons for b in bounds[r]]
    remaining = min(MAX_MONEY, max(every_bound + [FACT_VALUE + 2]) + REMAINING_MARGIN)
    base_facts = {name: FACT_VALUE for name in fact_names}
    out, seen = [], set()

    def add(item):
        key = json.dumps(item, sort_keys=True)
        if key not in seen:
            seen.add(key)
            out.append(item)

    for reason in reasons:
        amounts = {0, 1, remaining, remaining + 1}
        for bound in bounds[reason]:
            amounts.update((bound - 1, bound, bound + 1))
        for amount in sorted(a for a in amounts if 0 <= a <= MAX_MONEY):
            add(scenario(reason, amount, remaining, 0, base_facts))
        for fact in sorted({rule['fact'] for rule in rules if rule['reason'] == reason and rule['fact']}):
            cap = FACT_VALUE
            for total, amount in ((0, cap - 1), (0, cap), (0, cap + 1), (cap - 1, 1), (cap - 1, 2), (cap, 1)):
                add(scenario(reason, amount, remaining, total, base_facts))
            add(scenario(reason, 1, remaining, 0, {**base_facts, fact: 0}))
    unlisted = 'UNLISTED'
    while unlisted in reasons:
        unlisted += '_'
    add(scenario(unlisted, 1, remaining, 0, base_facts))
    return out


def eval_line(item):
    """One request line of `airlock-engine eval` (DESIGN.md grammar)."""
    parts = ['EVAL', item['reason'], str(item['amount']), str(item['remaining']), str(item['reason_total'])]
    parts += ['%s=%d' % pair for pair in item['facts']]
    return ' '.join(parts)


def overlap_point(policy, fact_names):
    """An input where two rules of one reason with different verdicts both match, or None.

    Exact for the rule semantics above: with reason_total 0 and every fact at MAX_MONEY, a fact rule
    matches every amount up to MAX_MONEY; the smallest common amount decides."""
    rules = policy['rules']
    for i, one in enumerate(rules):
        for two in rules[i + 1:]:
            if one['reason'] != two['reason'] or one['verdict'] == two['verdict']:
                continue
            low = max(1, one['min_amount'] or 0, two['min_amount'] or 0)
            high = min([MAX_MONEY] + [r['max_amount'] for r in (one, two) if r['max_amount'] is not None])
            if low <= high:
                facts = {name: MAX_MONEY for name in fact_names}
                return scenario(one['reason'], low, low, 0, facts)
    return None
