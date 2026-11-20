#!/usr/bin/env python3
"""policy_to_dfy (V1.1 primitive 9, part B): one declarative JSON policy -> one concrete Dafny module. Python stdlib only.

  python3 src/primitives_v2/py/policy_to_dfy.py gen <policy.json> [--out DIR]
  python3 src/primitives_v2/py/policy_to_dfy.py vectors <policy.json> --work DIR [--out DIR]
  python3 src/primitives_v2/py/policy_to_dfy.py clear <policy.json> --work DIR [--out DIR]

LABELS (no claim beyond these):
  * This generator is unverified Python: a TRUSTED ASSUMPTION, exactly as the Goal 20 money generator
    (src/airlock/py/diff_policy.py). Its controls (FINITE TEST): byte-identical output twice; different policies give
    different modules; changed copies of this file that the Dafny verification or the differential test must catch
    (tests/primitives_v2/mutants_p9.py).
  * The generated Dafny is a MODEL of the policy. What `dafny verify` proves is a statement about that MODEL only
    (PROVED CORE for the generated model, when a run of the pinned Dafny exits 0 with 0 errors and the audit is empty).
  * The engines run RUST (src/airlock for money, src/primitives_v2 for rate_window and transfer), not this model.
    The tie between model and engine built here is a FINITE TEST: `vectors` RUNS the verified Dafny decision function
    (compiled by the pinned Dafny's Python back end; that compiled code is the Dafny compiler's output, trusted, not
    proved) on thousands of inputs, including every boundary that the generator derives from the policy, and writes the
    table; tests/primitives_v2/test_policy_to_dfy.py replays the table against the real engine binary. Nothing here
    turns a policy of the engine into a source_proof core: the engine's Rust is not proved and not compiled from Dafny
    (the Dafny 4.11 Rust back end needs the `dafny_runtime` crate; see the P9 report).

Kinds (the policy file says which):
  money        Goal 20 parametric money policy {"airlock": "money", "profile": "parametric", "rules": [...]}, loaded by
               the strict loader of src/airlock/py/policy_model.py (read-only reuse). Decision = DESIGN.md rules as the
               engine applies them (built-in ZERO_AMOUNT and TOTAL_CAP first; most restrictive matching rule; else
               REASON_CAP or NO_RULE).
  rate_window  primitive 6 policy {"primitive": "rate_window", ...} (src/primitives_v2/rate.rs). Decision of `acquire`.
  transfer     primitive 7 ledger policy {"primitive": "ledger_graph", "kind": "ledger", ...}: the decision of the
               two-account `transfer` op only (see the module text for the fields that the model uses).

Output: <out>/<kind>-<name>.dfy (default out: domains/compiled_policies). One file, four modules:
  <P>Spec   abstract: the policy's constants, the declarative relation Post (what an allowed decision is) and the
            specified method Decide (no body).
  <P>       refines <P>Spec: the compiled decision function, Decide's body, and the property lemmas.
  <P>Claim  abstract: the forward link (calling Decide gives Post) and NoChoice (two results with Post are equal), the
            shape that scripts/spec_clearing.py clears.
  <P>Witness non-abstract: concrete accepted inputs.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import re
import subprocess
import sys
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'src/airlock/py'))
import policy_model as pm  # noqa: E402  (Goal 20 strict money loader; read-only reuse)

GENERATOR = 'src/primitives_v2/py/policy_to_dfy.py v1'
OUT = ROOT / 'domains/compiled_policies'
DAFNY = '/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/dafny'
DAFNY_ROOT = Path('/Users/mackianni/forge')      # the checkout that holds the pinned toolchain (cwd of every Dafny run)
U64 = (1 << 64) - 1
ID = re.compile(r'[A-Za-z0-9_-]{1,24}')
DECIMAL = re.compile(r'0|[1-9][0-9]{0,19}')


class Malformed(Exception):
    pass


# ---------------------------------------------------------------------------------------------------------------------
# Loading (strict). Every value that reaches Dafny text is an id or a decimal integer, checked here again.
# ---------------------------------------------------------------------------------------------------------------------
def _dec(obj, key, low, high):
    v = obj.get(key)
    if not isinstance(v, str) or not DECIMAL.fullmatch(v) or not low <= int(v) <= high:
        raise Malformed('%s is not a canonical decimal string in %d..%d' % (key, low, high))
    return int(v)


def _exact_keys(obj, keys):
    if set(obj) != set(keys):
        raise Malformed('key set differs: unknown %s, missing %s' % (sorted(set(obj) - set(keys))[:1], sorted(set(keys) - set(obj))[:1]))


def load(data):
    """(kind, policy) from the bytes of one policy file. Raises Malformed."""
    obj = pm.parse_json(data)          # strict JSON: no duplicate key, no float, at most 1 MiB
    if not isinstance(obj, dict):
        raise Malformed('not a JSON object')
    if obj.get('airlock') == 'money':
        try:
            p = pm.load_policy(data)
        except pm.Malformed as e:
            raise Malformed(str(e))
        return 'money', p
    if type(obj.get('version')) is not int or obj.get('version') != 1:
        raise Malformed('version is not the integer 1')
    if not isinstance(obj.get('name'), str) or not ID.fullmatch(obj['name']):
        raise Malformed('name is not an id')
    if obj.get('primitive') == 'rate_window':
        _exact_keys(obj, ['primitive', 'version', 'name', 'max_ops_per_window', 'max_volume_per_window', 'window_ms',
                          'cooldown_after', 'cooldown_ms'])
        p = {'name': obj['name'], 'max_ops': _dec(obj, 'max_ops_per_window', 1, 65536),
             'max_volume': _dec(obj, 'max_volume_per_window', 0, U64), 'window_ms': _dec(obj, 'window_ms', 1, U64),
             'cooldown_after': _dec(obj, 'cooldown_after', 0, 1024), 'cooldown_ms': _dec(obj, 'cooldown_ms', 0, U64)}
        if p['cooldown_after'] > 0 and p['cooldown_ms'] == 0:
            raise Malformed('cooldown_ms >= 1 with a cooldown')
        return 'rate_window', p
    if obj.get('primitive') == 'ledger_graph' and obj.get('kind') == 'ledger':
        _exact_keys(obj, ['primitive', 'version', 'name', 'kind', 'issuance', 'max_balance', 'max_legs'])
        if obj['issuance'] not in ('fixed', 'mint_burn'):
            raise Malformed('issuance is not fixed or mint_burn')
        return 'transfer', {'name': obj['name'], 'issuance': obj['issuance'], 'max_balance': _dec(obj, 'max_balance', 1, U64),
                            'max_legs': _dec(obj, 'max_legs', 2, 16)}
    raise Malformed('not a money, rate_window or ledger (transfer) policy')


def canonical(policy):
    return json.dumps(policy, sort_keys=True, separators=(',', ':'))


def lit(word):
    if not isinstance(word, str) or not ID.fullmatch(word):
        raise Malformed('not an id: %r' % (word,))
    return '"%s"' % word


def num(v):
    if type(v) is not int:
        raise Malformed('not an integer')
    return str(v)


def prefix(kind, policy):
    base = {'money': 'CompiledMoney', 'rate_window': 'CompiledRate', 'transfer': 'CompiledTransfer'}[kind]
    return '%s_%s' % (base, policy['name'].encode().hex())


def file_name(kind, policy):
    return '%s-%s.dfy' % (kind, policy['name'])


def header(kind, policy, sha):
    return ['// GENERATED by %s from the %s policy %s.' % (GENERATOR, kind, lit(policy['name'])),
            '// Policy file sha256: %s' % sha,
            '// Checked policy (canonical JSON): %s' % canonical(policy),
            '// A MODEL of the policy, not the engine. The generator is a TRUSTED ASSUMPTION. Do not edit by hand.']


# ---------------------------------------------------------------------------------------------------------------------
# money
# ---------------------------------------------------------------------------------------------------------------------
MONEY_VERDICT = {pm.COMMIT: 'Commit', pm.COSIGN: 'RequireHumanCosign', pm.REJECTED: 'RejectedRule'}
MONEY_TEXT = {'Commit': 'COMMIT', 'RequireHumanCosign': 'REQUIRE_HUMAN_COSIGN', 'RejectedRule': 'REJECTED_POLICY RULE',
              'RejectedZeroAmount': 'REJECTED_POLICY ZERO_AMOUNT', 'RejectedTotalCap': 'REJECTED_POLICY TOTAL_CAP',
              'RejectedNoRule': 'REJECTED_POLICY NO_RULE', 'RejectedReasonCap': 'REJECTED_POLICY REASON_CAP'}


def money_rule(r):
    opt = lambda v: 'None' if v is None else 'Some(%s)' % num(v)
    fact = 'NoFact' if r['fact'] is None else 'Fact(%s)' % lit(r['fact'])
    return 'Rule(%s, %s, %s, %s, %s)' % (lit(r['reason']), opt(r['min_amount']), opt(r['max_amount']), fact, MONEY_VERDICT[r['verdict']])


def case_split(n, indent):
    """`if k == 0 { } else if k == 1 { } ...`: makes Dafny look at each rule of the literal list."""
    if n == 0:
        return []
    return [indent + ' else '.join('if k == %d { }' % k for k in range(n))]


def money_caps(policy):
    """Per reason: the largest max_amount of its COMMIT rules, when every COMMIT rule of it has one."""
    out = []
    for reason in sorted({r['reason'] for r in policy['rules']}):
        commits = [r for r in policy['rules'] if r['reason'] == reason and r['verdict'] == pm.COMMIT]
        if commits and all(r['max_amount'] is not None for r in commits):
            out.append((reason, max(r['max_amount'] for r in commits)))
    return out


def money_never(policy):
    return [reason for reason in sorted({r['reason'] for r in policy['rules']})
            if not any(r['reason'] == reason and r['verdict'] == pm.COMMIT for r in policy['rules'])]


def money_witness(policy):
    """An input that the policy commits (checked with the Goal 20 Python evaluator), or None."""
    facts = sorted({r['fact'] for r in policy['rules'] if r['fact']})
    for r in policy['rules']:
        if r['verdict'] != pm.COMMIT:
            continue
        amount = max(1, r['min_amount'] or 0)
        item = pm.scenario(r['reason'], amount, amount, 0, {f: pm.MAX_MONEY for f in facts})
        if pm.decide(policy, item) == pm.COMMIT:
            return item
    return None


def money_input(item, q=''):
    facts = ', '.join('%s := %s' % (lit(k), num(v)) for k, v in item['facts'])
    return '%sInput(%s, %s, %s, %s, map[%s])' % (q, lit(item['reason']), num(item['amount']), num(item['remaining']),
                                                 num(item['reason_total']), facts)


def gen_money(policy, sha):
    P = prefix('money', policy)
    rules = policy['rules']
    reasons = sorted({r['reason'] for r in rules})
    n = len(rules)
    L = header('money', policy, sha)
    L += ['', '// The specification of the decision. Domain: every Input with 0 <= amount, remaining, reasonTotal, facts',
          '// <= MaxMoney (ValidInput). Post(i, v): v is an allowed verdict (Allowed: built-in ZERO_AMOUNT and TOTAL_CAP',
          '// first; else the verdict of a matching rule; else REASON_CAP when a fact rule of the reason failed only its',
          '// fact cap, else NO_RULE) and no allowed verdict is more restrictive (Rank).',
          'abstract module %sSpec {' % P,
          '  const PolicyName: string := %s' % lit(policy['name']),
          '  const PolicySha256: string := "%s"' % sha,
          '  const MaxMoney: int := 9223372036854775807',
          '',
          '  datatype Verdict = Commit | RequireHumanCosign | RejectedRule | RejectedZeroAmount | RejectedTotalCap',
          '                   | RejectedNoRule | RejectedReasonCap',
          '  datatype Opt = None | Some(v: int)',
          '  datatype FactName = NoFact | Fact(name: string)',
          '  datatype Rule = Rule(reason: string, minAmount: Opt, maxAmount: Opt, fact: FactName, verdict: Verdict)',
          '  datatype Input = Input(reason: string, amount: int, remaining: int, reasonTotal: int, facts: map<string, int>)',
          '',
          '  // The rules of the policy, in file order.',
          '  const Rules: seq<Rule> := [']
    L += ['    %s%s' % (money_rule(r), ',' if k + 1 < n else '') for k, r in enumerate(rules)]
    L += ['  ]',
          '  const Reasons: set<string> := {%s}' % ', '.join(lit(r) for r in reasons),
          '',
          '  predicate ValidInput(i: Input) {',
          '    0 <= i.amount <= MaxMoney && 0 <= i.remaining <= MaxMoney && 0 <= i.reasonTotal <= MaxMoney &&',
          '    forall f | f in i.facts :: 0 <= i.facts[f] <= MaxMoney',
          '  }',
          '',
          '  // The reason is equal and the amount bounds hold.',
          '  predicate Bounds(r: Rule, i: Input) {',
          '    r.reason == i.reason && (r.minAmount.Some? ==> r.minAmount.v <= i.amount) &&',
          '    (r.maxAmount.Some? ==> i.amount <= r.maxAmount.v)',
          '  }',
          '  // The fact cap holds: the named fact is present and reasonTotal + amount <= its value.',
          '  predicate FactOk(r: Rule, i: Input) {',
          '    r.fact.Fact? ==> (r.fact.name in i.facts && i.reasonTotal + i.amount <= i.facts[r.fact.name])',
          '  }',
          '  predicate Match(r: Rule, i: Input) { Bounds(r, i) && FactOk(r, i) }',
          '  predicate Capped(r: Rule, i: Input) { r.fact.Fact? && Bounds(r, i) && !FactOk(r, i) }',
          '  predicate AnyMatch(i: Input) { exists k | 0 <= k < |Rules| :: Match(Rules[k], i) }',
          '  predicate MatchWith(i: Input, v: Verdict) { exists k | 0 <= k < |Rules| :: Rules[k].verdict == v && Match(Rules[k], i) }',
          '  predicate AnyCapped(i: Input) { exists k | 0 <= k < |Rules| :: Capped(Rules[k], i) }',
          '',
          '  predicate Allowed(i: Input, v: Verdict) {',
          '    if i.amount < 1 then v == RejectedZeroAmount',
          '    else if i.amount > i.remaining then v == RejectedTotalCap',
          '    else if !AnyMatch(i) then (if AnyCapped(i) then v == RejectedReasonCap else v == RejectedNoRule)',
          '    else MatchWith(i, v)',
          '  }',
          '',
          '  // REJECTED_POLICY > REQUIRE_HUMAN_COSIGN > COMMIT; the built-in refusals are alone when allowed.',
          '  function Rank(v: Verdict): int {',
          '    match v',
          '    case Commit => 0',
          '    case RequireHumanCosign => 1',
          '    case RejectedRule => 2',
          '    case _ => 3',
          '  }',
          '',
          '  predicate Post(i: Input, v: Verdict) {',
          '    Allowed(i, v) && forall w: Verdict :: Allowed(i, w) ==> Rank(w) <= Rank(v)',
          '  }',
          '',
          '  // Every rule verdict is COMMIT, REQUIRE_HUMAN_COSIGN or REJECTED_POLICY (the loader allows no other).',
          '  lemma RuleVerdicts()',
          '    ensures forall k | 0 <= k < |Rules| :: Rules[k].verdict in {Commit, RequireHumanCosign, RejectedRule}',
          '  {',
          '    forall k | 0 <= k < |Rules|',
          '      ensures Rules[k].verdict in {Commit, RequireHumanCosign, RejectedRule}',
          '    {']
    L += case_split(n, '      ')
    L += ['    }',
          '  }',
          '',
          '  // Two verdicts with Post for one input are equal (used by the claim below).',
          '  lemma PostUnique(i: Input, v1: Verdict, v2: Verdict)',
          '    requires Post(i, v1) && Post(i, v2)',
          '    ensures v1 == v2',
          '  {',
          '    RuleVerdicts();',
          '    assert Rank(v1) == Rank(v2);',
          '    if 1 <= i.amount <= i.remaining && AnyMatch(i) {',
          '      var k1 :| 0 <= k1 < |Rules| && Rules[k1].verdict == v1 && Match(Rules[k1], i);',
          '      var k2 :| 0 <= k2 < |Rules| && Rules[k2].verdict == v2 && Match(Rules[k2], i);',
          '    }',
          '  }',
          '',
          '  method Decide(i: Input) returns (v: Verdict)',
          '    requires ValidInput(i)',
          '    ensures Post(i, v)',
          '}',
          '',
          '// The compiled decision function of this policy and its properties.',
          'module %s refines %sSpec {' % (P, P),
          '  // Total (no precondition) and deterministic (a function). The most restrictive matching verdict wins.',
          '  function DecideF(i: Input): Verdict {',
          '    if i.amount < 1 then RejectedZeroAmount',
          '    else if i.amount > i.remaining then RejectedTotalCap',
          '    else if MatchWith(i, RejectedRule) then RejectedRule',
          '    else if MatchWith(i, RequireHumanCosign) then RequireHumanCosign',
          '    else if MatchWith(i, Commit) then Commit',
          '    else if AnyCapped(i) then RejectedReasonCap',
          '    else RejectedNoRule',
          '  }',
          '',
          '  // M1: the compiled decision is allowed and most restrictive (it meets the specification, for EVERY input).',
          '  lemma DecideFPost(i: Input)',
          '    ensures Post(i, DecideF(i))',
          '  {',
          '    RuleVerdicts();',
          '    if 1 <= i.amount <= i.remaining && AnyMatch(i) {',
          '      var k :| 0 <= k < |Rules| && Match(Rules[k], i);',
          '      assert MatchWith(i, Rules[k].verdict);',
          '    }',
          '  }',
          '',
          '  method Decide(i: Input) returns (v: Verdict)',
          '  {',
          '    v := DecideF(i);',
          '    DecideFPost(i);',
          '  }',
          '',
          '  // M2: a commit never exceeds the remaining amount.',
          '  lemma CommitWithinRemaining(i: Input)',
          '    requires DecideF(i) == Commit',
          '    ensures 1 <= i.amount <= i.remaining',
          '  {',
          '  }',
          '',
          '  // M3: a commit has a COMMIT rule whose reason, amount bounds and fact cap all hold, and NO matching rule',
          '  // says REQUIRE_HUMAN_COSIGN or REJECTED_POLICY.',
          '  lemma CommitHasRule(i: Input)',
          '    requires DecideF(i) == Commit',
          '    ensures exists k | 0 <= k < |Rules| :: Rules[k].verdict == Commit && Match(Rules[k], i)',
          '    ensures forall k | 0 <= k < |Rules| :: Match(Rules[k], i) ==> Rules[k].verdict == Commit',
          '  {',
          '    RuleVerdicts();',
          '  }',
          '',
          '  // M4: an input whose reason no rule names is never committed (ZERO_AMOUNT, TOTAL_CAP or NO_RULE).',
          '  lemma UnlistedReason(i: Input)',
          '    requires i.reason !in Reasons',
          '    ensures DecideF(i) in {RejectedZeroAmount, RejectedTotalCap, RejectedNoRule}',
          '  {',
          '    forall k | 0 <= k < |Rules|',
          '      ensures Rules[k].reason in Reasons',
          '    {']
    L += case_split(n, '      ')
    L += ['    }',
          '  }']
    for number, (reason, cap) in enumerate(money_caps(policy)):
        L += ['',
              '  // M5.%d: per-reason cap: every COMMIT rule of reason %s has max_amount <= %s, so no commit of it' % (number, lit(reason), num(cap)),
              '  // exceeds %s.' % num(cap),
              '  lemma CommitCap%d(i: Input)' % number,
              '    requires DecideF(i) == Commit && i.reason == %s' % lit(reason),
              '    ensures i.amount <= %s' % num(cap),
              '  {',
              '    CommitHasRule(i);',
              '    var k :| 0 <= k < |Rules| && Rules[k].verdict == Commit && Match(Rules[k], i);']
        L += case_split(n, '    ')
        L += ['  }']
    for number, reason in enumerate(money_never(policy)):
        L += ['',
              '  // M6.%d: reason %s has no COMMIT rule, so it is never committed.' % (number, lit(reason)),
              '  lemma NeverCommits%d(i: Input)' % number,
              '    requires i.reason == %s' % lit(reason),
              '    ensures DecideF(i) != Commit',
              '  {',
              '    if DecideF(i) == Commit {',
              '      CommitHasRule(i);',
              '      var k :| 0 <= k < |Rules| && Rules[k].verdict == Commit && Match(Rules[k], i);']
        L += case_split(n, '      ')
        L += ['    }',
              '  }']
    L += ['}',
          '',
          '// The shape that scripts/spec_clearing.py clears: a forward link and the two-run claim.',
          'abstract module %sClaim {' % P,
          '  import S : %sSpec' % P,
          '',
          '  method DecideThenPost(i: S.Input) returns (v: S.Verdict)',
          '    requires S.ValidInput(i)',
          '    ensures S.Post(i, v)',
          '  {',
          '    v := S.Decide(i);',
          '  }',
          '',
          '  lemma NoChoice(i: S.Input, v1: S.Verdict, v2: S.Verdict)',
          '    requires S.ValidInput(i)',
          '    requires S.Post(i, v1)',
          '    requires S.Post(i, v2)',
          '    ensures v1 == v2',
          '  {',
          '    S.PostUnique(i, v1, v2);',
          '  }',
          '}']
    item = money_witness(policy)
    L += ['', '// Non-vacuity: a concrete input that the compiled decision commits%s.' % ('' if item else ' (none found by the generator: no lemma)'),
          'module %sWitness {' % P, '  import M = %s' % P]
    if item:
        L += ['', '  lemma Accepts()', '    ensures M.DecideF(%s) == M.Commit' % money_input(item, 'M.'), '  {']
        L += ['    assert M.Match(M.Rules[%d], %s);' % (k, money_input(item, 'M.')) for k, r in enumerate(rules)
              if r['verdict'] == pm.COMMIT and pm.rule_matches(r, item)][:1]
        L += ['  }']
    L += ['}']
    return '\n'.join(L) + '\n'


# ---------------------------------------------------------------------------------------------------------------------
# rate_window
# ---------------------------------------------------------------------------------------------------------------------
def gen_rate(policy, sha):
    P = prefix('rate_window', policy)
    L = header('rate_window', policy, sha)
    L += ['', '// The specification of `acquire` for one key. Domain: natural times and volumes, unbounded (the engine uses',
          '// u64; an expiry that overflows u64 is NOT modelled). State: every committed event (t, v) of the key, the count',
          '// of consecutive counted rejections, the end of the cooldown (0: none). An event at t counts at `now` while',
          '// now < t + WindowMs. Post: (1) v > MaxVolume: VolumeAboveCap; (2) now < cooldownUntil: CooldownActive with',
          '// the exact rest; (3) it fits: Commit; (4) else RateLimited(n) where n is the LEAST d >= 1 at which the same',
          '// request fits with no new event (and it does not fit at any d < n, d = 0 included).',
          'abstract module %sSpec {' % P,
          '  const PolicyName: string := %s' % lit(policy['name']),
          '  const PolicySha256: string := "%s"' % sha,
          '  const MaxOps: int := %s' % num(policy['max_ops']),
          '  const MaxVolume: int := %s' % num(policy['max_volume']),
          '  const WindowMs: int := %s' % num(policy['window_ms']),
          '  const CooldownAfter: int := %s' % num(policy['cooldown_after']),
          '  const CooldownMs: int := %s' % num(policy['cooldown_ms']),
          '',
          '  datatype Event = Event(t: nat, v: nat)',
          '  datatype State = State(events: seq<Event>, rejections: nat, cooldownUntil: nat)',
          '  datatype Verdict = Commit | VolumeAboveCap | CooldownActive(retryAfter: int) | RateLimited(retryAfter: int)',
          '  const Init: State := State([], 0, 0)',
          '',
          '  // The number and the volume of the events that count at `now`.',
          '  function LiveOps(es: seq<Event>, now: int): int {',
          '    if |es| == 0 then 0 else LiveOps(es[..|es| - 1], now) + (if now < es[|es| - 1].t + WindowMs then 1 else 0)',
          '  } by method {',
          '    // the same sum as a loop (linear time in the compiled code); Dafny proves it equal to the function',
          '    var acc := 0;',
          '    var k := 0;',
          '    while k < |es|',
          '      invariant 0 <= k <= |es|',
          '      invariant acc == LiveOps(es[..k], now)',
          '    {',
          '      assert es[..k + 1][..k] == es[..k];',
          '      acc := acc + (if now < es[k].t + WindowMs then 1 else 0);',
          '      k := k + 1;',
          '    }',
          '    assert es[..|es|] == es;',
          '    return acc;',
          '  }',
          '  function LiveVol(es: seq<Event>, now: int): int {',
          '    if |es| == 0 then 0 else LiveVol(es[..|es| - 1], now) + (if now < es[|es| - 1].t + WindowMs then es[|es| - 1].v else 0)',
          '  } by method {',
          '    // the same sum as a loop (linear time in the compiled code); Dafny proves it equal to the function',
          '    var acc := 0;',
          '    var k := 0;',
          '    while k < |es|',
          '      invariant 0 <= k <= |es|',
          '      invariant acc == LiveVol(es[..k], now)',
          '    {',
          '      assert es[..k + 1][..k] == es[..k];',
          '      acc := acc + (if now < es[k].t + WindowMs then es[k].v else 0);',
          '      k := k + 1;',
          '    }',
          '    assert es[..|es|] == es;',
          '    return acc;',
          '  }',
          '  predicate Fits(es: seq<Event>, now: int, v: int) {',
          '    LiveOps(es, now) + 1 <= MaxOps && LiveVol(es, now) + v <= MaxVolume',
          '  }',
          '',
          '  predicate Post(s: State, now: nat, v: nat, r: Verdict) {',
          '    if v > MaxVolume then r == VolumeAboveCap',
          '    else if now < s.cooldownUntil then r == CooldownActive(s.cooldownUntil - now)',
          '    else if Fits(s.events, now, v) then r == Commit',
          '    else r.RateLimited? && r.retryAfter >= 1 && Fits(s.events, now + r.retryAfter, v) &&',
          '         forall tau: int | now <= tau < now + r.retryAfter :: !Fits(s.events, tau, v)',
          '  }',
          '',
          '  method Decide(s: State, now: nat, v: nat) returns (r: Verdict)',
          '    ensures Post(s, now, v, r)',
          '}',
          '',
          '// The compiled decision and state change of this policy, and their properties.',
          'module %s refines %sSpec {' % (P, P),
          '  // The time from which no event counts any more (0 for no event).',
          '  function Horizon(es: seq<Event>): nat {',
          '    if |es| == 0 then 0 else',
          '      var h := Horizon(es[..|es| - 1]); var e := es[|es| - 1].t + WindowMs;',
          '      if e > h then e else h',
          '  }',
          '',
          '  // The least d in [d0, end] at which v fits, or `end`.',
          '  function SearchFrom(es: seq<Event>, now: nat, v: nat, d0: nat, end: nat): nat',
          '    requires d0 <= end',
          '    decreases end - d0',
          '  {',
          '    if d0 == end || Fits(es, now + d0, v) then d0 else SearchFrom(es, now, v, d0 + 1, end)',
          '  }',
          '',
          '  function Retry(es: seq<Event>, now: nat, v: nat): nat {',
          '    var end := if Horizon(es) > now + 1 then Horizon(es) - now else 1;',
          '    SearchFrom(es, now, v, 1, end)',
          '  }',
          '',
          '  // Total and deterministic (a function without precondition).',
          '  function DecideF(s: State, now: nat, v: nat): Verdict {',
          '    if v > MaxVolume then VolumeAboveCap',
          '    else if now < s.cooldownUntil then CooldownActive(s.cooldownUntil - now)',
          '    else if Fits(s.events, now, v) then Commit',
          '    else RateLimited(Retry(s.events, now, v))',
          '  }',
          '',
          '  // The state after the request: a commit adds the event and clears the rejection count; with',
          '  // CooldownAfter > 0 a RateLimited refusal counts, and the CooldownAfter-th one starts the cooldown.',
          '  function StepF(s: State, now: nat, v: nat): State {',
          '    match DecideF(s, now, v)',
          '    case Commit => State(s.events + [Event(now, v)], 0, s.cooldownUntil)',
          '    case RateLimited(_) =>',
          '      if CooldownAfter == 0 then s',
          '      else if s.rejections + 1 >= CooldownAfter then State(s.events, 0, now + CooldownMs)',
          '      else State(s.events, s.rejections + 1, s.cooldownUntil)',
          '    case _ => s',
          '  }',
          '',
          '  lemma AllDead(es: seq<Event>, tau: int)',
          '    requires tau >= Horizon(es)',
          '    ensures LiveOps(es, tau) == 0 && LiveVol(es, tau) == 0',
          '  {',
          '    if |es| > 0 {',
          '      AllDead(es[..|es| - 1], tau);',
          '    }',
          '  }',
          '',
          '  lemma SearchIsLeast(es: seq<Event>, now: nat, v: nat, d0: nat, end: nat)',
          '    requires d0 <= end && Fits(es, now + end, v)',
          '    requires forall tau: int | now <= tau < now + d0 :: !Fits(es, tau, v)',
          '    ensures var n := SearchFrom(es, now, v, d0, end);',
          '      d0 <= n <= end && Fits(es, now + n, v) && forall tau: int | now <= tau < now + n :: !Fits(es, tau, v)',
          '    decreases end - d0',
          '  {',
          '    var n := SearchFrom(es, now, v, d0, end);',
          '    if d0 == end || Fits(es, now + d0, v) {',
          '      assert n == d0;',
          '    } else {',
          '      forall tau: int | now <= tau < now + d0 + 1',
          '        ensures !Fits(es, tau, v)',
          '      {',
          '        if tau == now + d0 { }',
          '      }',
          '      SearchIsLeast(es, now, v, d0 + 1, end);',
          '      assert n == SearchFrom(es, now, v, d0 + 1, end);',
          '    }',
          '  }',
          '',
          '  // R1: the retry time is the LEAST waiting time (the request fits at now + n and at no earlier time).',
          '  lemma DecideFPost(s: State, now: nat, v: nat)',
          '    ensures Post(s, now, v, DecideF(s, now, v))',
          '  {',
          '    if v <= MaxVolume && now >= s.cooldownUntil && !Fits(s.events, now, v) {',
          '      var es := s.events;',
          '      var end := if Horizon(es) > now + 1 then Horizon(es) - now else 1;',
          '      AllDead(es, now + end);',
          '      forall tau: int | now <= tau < now + 1',
          '        ensures !Fits(es, tau, v)',
          '      {',
          '        assert tau == now;',
          '      }',
          '      SearchIsLeast(es, now, v, 1, end);',
          '      assert Retry(es, now, v) == SearchFrom(es, now, v, 1, end);',
          '    }',
          '  }',
          '',
          '  method Decide(s: State, now: nat, v: nat) returns (r: Verdict)',
          '  {',
          '    r := DecideF(s, now, v);',
          '    DecideFPost(s, now, v);',
          '  }',
          '',
          '  // The events that count in the window that ends at T: t <= T < t + WindowMs.',
          '  function InWinOps(es: seq<Event>, T: int): int {',
          '    if |es| == 0 then 0 else InWinOps(es[..|es| - 1], T) + (if es[|es| - 1].t <= T < es[|es| - 1].t + WindowMs then 1 else 0)',
          '  }',
          '  function InWinVol(es: seq<Event>, T: int): int {',
          '    if |es| == 0 then 0 else InWinVol(es[..|es| - 1], T) + (if es[|es| - 1].t <= T < es[|es| - 1].t + WindowMs then es[|es| - 1].v else 0)',
          '  }',
          '  ghost predicate Bounded(es: seq<Event>) {',
          '    forall T: int :: InWinOps(es, T) <= MaxOps && InWinVol(es, T) <= MaxVolume',
          '  }',
          '  predicate Before(es: seq<Event>, now: int) {',
          '    forall k | 0 <= k < |es| :: es[k].t <= now',
          '  }',
          '',
          '  lemma InWinLeLive(es: seq<Event>, T: int, now: int)',
          '    requires Before(es, now) && T >= now',
          '    ensures InWinOps(es, T) <= LiveOps(es, now) && InWinVol(es, T) <= LiveVol(es, now)',
          '  {',
          '    if |es| > 0 {',
          '      InWinLeLive(es[..|es| - 1], T, now);',
          '    }',
          '  }',
          '',
          '  lemma InWinAppend(es: seq<Event>, e: Event, T: int)',
          '    ensures InWinOps(es + [e], T) == InWinOps(es, T) + (if e.t <= T < e.t + WindowMs then 1 else 0)',
          '    ensures InWinVol(es + [e], T) == InWinVol(es, T) + (if e.t <= T < e.t + WindowMs then e.v else 0)',
          '  {',
          '    assert (es + [e])[..|es + [e]| - 1] == es;',
          '  }',
          '',
          '  // One request keeps every window of WindowMs within MaxOps operations and MaxVolume volume.',
          '  lemma StepBounded(s: State, now: nat, v: nat)',
          '    requires Bounded(s.events) && Before(s.events, now)',
          '    ensures Bounded(StepF(s, now, v).events) && Before(StepF(s, now, v).events, now)',
          '  {',
          '    if DecideF(s, now, v) == Commit {',
          '      var es := s.events;',
          '      var e := Event(now, v);',
          '      assert Before(es + [e], now);',
          '      forall T: int',
          '        ensures InWinOps(es + [e], T) <= MaxOps && InWinVol(es + [e], T) <= MaxVolume',
          '      {',
          '        InWinAppend(es, e, T);',
          '        if T >= now {',
          '          InWinLeLive(es, T, now);',
          '        }',
          '      }',
          '    }',
          '  }',
          '',
          '  // Requests (now, v) in non-decreasing time order, applied from Init.',
          '  function Run(reqs: seq<(nat, nat)>): State {',
          '    if |reqs| == 0 then Init else StepF(Run(reqs[..|reqs| - 1]), reqs[|reqs| - 1].0, reqs[|reqs| - 1].1)',
          '  }',
          '  predicate Sorted(reqs: seq<(nat, nat)>) {',
          '    forall a, b | 0 <= a < b < |reqs| :: reqs[a].0 <= reqs[b].0',
          '  }',
          '',
          '  // R2: for EVERY accepted sequence of requests in time order, and EVERY window [T - WindowMs + 1, T], the',
          '  // committed events in the window number at most MaxOps and their volume is at most MaxVolume.',
          '  lemma RunBounded(reqs: seq<(nat, nat)>)',
          '    requires Sorted(reqs)',
          '    ensures Bounded(Run(reqs).events)',
          '    ensures |reqs| > 0 ==> Before(Run(reqs).events, reqs[|reqs| - 1].0)',
          '  {',
          '    if |reqs| > 0 {',
          '      var pre := reqs[..|reqs| - 1];',
          '      assert Sorted(pre);',
          '      RunBounded(pre);',
          '      var now := reqs[|reqs| - 1].0;',
          '      if |pre| > 0 {',
          '        assert pre[|pre| - 1].0 <= now;',
          '      }',
          '      StepBounded(Run(pre), now, reqs[|reqs| - 1].1);',
          '    }',
          '  }',
          '',
          '  // R3: during a cooldown nothing commits; the CooldownAfter-th consecutive RateLimited refusal starts a',
          '  // cooldown of exactly CooldownMs.',
          '  lemma CooldownBlocks(s: State, now: nat, v: nat)',
          '    requires now < s.cooldownUntil',
          '    ensures DecideF(s, now, v) != Commit',
          '  {',
          '  }',
          '  lemma NthRejectionStartsCooldown(s: State, now: nat, v: nat)',
          '    requires CooldownAfter > 0 && DecideF(s, now, v).RateLimited? && s.rejections + 1 >= CooldownAfter',
          '    ensures StepF(s, now, v).cooldownUntil == now + CooldownMs',
          '  {',
          '  }',
          '}',
          '',
          '// The shape that scripts/spec_clearing.py clears: a forward link and the two-run claim.',
          'abstract module %sClaim {' % P,
          '  import S : %sSpec' % P,
          '',
          '  method DecideThenPost(s: S.State, now: nat, v: nat) returns (r: S.Verdict)',
          '    ensures S.Post(s, now, v, r)',
          '  {',
          '    r := S.Decide(s, now, v);',
          '  }',
          '',
          '  lemma NoChoice(s: S.State, now: nat, v: nat, r1: S.Verdict, r2: S.Verdict)',
          '    requires S.Post(s, now, v, r1)',
          '    requires S.Post(s, now, v, r2)',
          '    ensures r1 == r2',
          '  {',
          '    if r1.RateLimited? && r2.RateLimited? && r1.retryAfter != r2.retryAfter {',
          '      if r1.retryAfter < r2.retryAfter {',
          '        assert !S.Fits(s.events, now + r1.retryAfter, v);',
          '      } else {',
          '        assert !S.Fits(s.events, now + r2.retryAfter, v);',
          '      }',
          '    }',
          '  }',
          '}',
          '',
          '// Non-vacuity: the first request of volume 0 commits; a request above the volume cap is refused.',
          'module %sWitness {' % P,
          '  import M = %s' % P,
          '',
          '  lemma Accepts()',
          '    ensures M.DecideF(M.Init, 1000, 0) == M.Commit',
          '    ensures M.DecideF(M.Init, 1000, %s) == M.VolumeAboveCap' % num(policy['max_volume'] + 1),
          '  {',
          '  }',
          '}']
    return '\n'.join(L) + '\n'


# ---------------------------------------------------------------------------------------------------------------------
# transfer (primitive 7 ledger policy; the two-account `transfer` op)
# ---------------------------------------------------------------------------------------------------------------------
def gen_transfer(policy, sha):
    P = prefix('transfer', policy)
    L = header('transfer', policy, sha)
    L += ['', '// The specification of the two-account `transfer` op of primitive 7 for ONE ledger policy, on the balances',
          '// of the two accounts. Fields of the policy used: max_balance. Not used here: issuance (it governs open, mint',
          '// and burn, not transfer) and max_legs (it governs post). Not modelled: accounts, tenants, ledgers, the order',
          '// of the engine\'s refusals before the balances (grammar, policy, account checks); the model starts at the',
          '// balance checks. Post (in the order of the engine): from == to: SelfTransfer; amount 0: ZeroAmount; balance below amount:',
          '// InsufficientFunds; the receiver above max_balance after it: BalanceLimit; else Commit with the new balances.',
          'abstract module %sSpec {' % P,
          '  const PolicyName: string := %s' % lit(policy['name']),
          '  const PolicySha256: string := "%s"' % sha,
          '  const MaxBalance: int := %s' % num(policy['max_balance']),
          '',
          '  datatype Verdict = Commit(fromAfter: int, toAfter: int) | ZeroAmount | SelfTransfer | InsufficientFunds | BalanceLimit',
          '  datatype Input = Input(sameAccount: bool, fromBalance: nat, toBalance: nat, amount: nat)',
          '',
          '  predicate ValidInput(i: Input) {',
          '    i.fromBalance <= MaxBalance && i.toBalance <= MaxBalance && (i.sameAccount ==> i.fromBalance == i.toBalance)',
          '  }',
          '',
          '  predicate Post(i: Input, r: Verdict) {',
          '    if i.sameAccount then r == SelfTransfer',
          '    else if i.amount == 0 then r == ZeroAmount',
          '    else if i.fromBalance < i.amount then r == InsufficientFunds',
          '    else if i.toBalance + i.amount > MaxBalance then r == BalanceLimit',
          '    else r == Commit(i.fromBalance - i.amount, i.toBalance + i.amount)',
          '  }',
          '',
          '  method Decide(i: Input) returns (r: Verdict)',
          '    requires ValidInput(i)',
          '    ensures Post(i, r)',
          '}',
          '',
          'module %s refines %sSpec {' % (P, P),
          '  function DecideF(i: Input): Verdict {',
          '    if i.sameAccount then SelfTransfer',
          '    else if i.amount == 0 then ZeroAmount',
          '    else if i.fromBalance < i.amount then InsufficientFunds',
          '    else if i.toBalance + i.amount > MaxBalance then BalanceLimit',
          '    else Commit(i.fromBalance - i.amount, i.toBalance + i.amount)',
          '  }',
          '',
          '  method Decide(i: Input) returns (r: Verdict)',
          '  {',
          '    r := DecideF(i);',
          '  }',
          '',
          '  // T1: a commit conserves the sum of the two balances, never makes a balance negative, and never puts a',
          '  // balance above MaxBalance.',
          '  lemma CommitConservesAndBounds(i: Input)',
          '    requires ValidInput(i) && DecideF(i).Commit?',
          '    ensures DecideF(i).fromAfter + DecideF(i).toAfter == i.fromBalance + i.toBalance',
          '    ensures 0 <= DecideF(i).fromAfter <= MaxBalance && 0 <= DecideF(i).toAfter <= MaxBalance',
          '    ensures !i.sameAccount && i.amount >= 1',
          '  {',
          '  }',
          '}',
          '',
          'abstract module %sClaim {' % P,
          '  import S : %sSpec' % P,
          '',
          '  method DecideThenPost(i: S.Input) returns (r: S.Verdict)',
          '    requires S.ValidInput(i)',
          '    ensures S.Post(i, r)',
          '  {',
          '    r := S.Decide(i);',
          '  }',
          '',
          '  lemma NoChoice(i: S.Input, r1: S.Verdict, r2: S.Verdict)',
          '    requires S.ValidInput(i)',
          '    requires S.Post(i, r1)',
          '    requires S.Post(i, r2)',
          '    ensures r1 == r2',
          '  {',
          '  }',
          '}',
          '',
          'module %sWitness {' % P,
          '  import M = %s' % P,
          '',
          '  lemma Accepts()',
          '    ensures M.DecideF(M.Input(false, 1, 0, 1)) == M.Commit(0, 1)',
          '  {',
          '  }',
          '}']
    return '\n'.join(L) + '\n'


GENERATORS = {'money': gen_money, 'rate_window': gen_rate, 'transfer': gen_transfer}


def generate(data):
    """(file name, Dafny text, kind, policy) from the bytes of one policy file. Deterministic."""
    kind, policy = load(data)
    sha = hashlib.sha256(data).hexdigest()
    return file_name(kind, policy), GENERATORS[kind](policy, sha), kind, policy


# ---------------------------------------------------------------------------------------------------------------------
# Running Dafny (one process at a time; wait while another Dafny process runs).
# ---------------------------------------------------------------------------------------------------------------------
def wait_slot(limit=3600):
    waited = 0
    while subprocess.run(['pgrep', '-f', 'dafny/dafny'], capture_output=True).returncode == 0:
        if waited >= limit:
            return False
        time.sleep(30)
        waited += 30
    return True


def run_dafny(args, log):
    if not wait_slot():
        log.append({'argv': [DAFNY] + args, 'exit_code': None, 'result': 'NOT RUN: Dafny slot not free in 60 min'})
        return None
    p = subprocess.run([DAFNY] + args, cwd=DAFNY_ROOT, capture_output=True, text=True)
    log.append({'argv': [DAFNY] + args, 'cwd': str(DAFNY_ROOT), 'exit_code': p.returncode,
                'last_line': (p.stdout.strip().splitlines() or [''])[-1]})
    return p


# ---------------------------------------------------------------------------------------------------------------------
# Decision vectors: inputs derived from the policy, decisions computed by RUNNING the Dafny-compiled decision function.
# ---------------------------------------------------------------------------------------------------------------------
def load_compiled(folder, module):
    sys.path.insert(0, str(folder))
    import importlib
    import _dafny  # noqa: F401  (the Dafny Python runtime, from the build output)
    return importlib.import_module(module.replace('_', '__')), _dafny   # the Python back end doubles '_' in names


def dstr(_dafny, s):
    return _dafny.SeqWithoutIsStrInference(map(_dafny.CodePoint, s))


def money_inputs(policy, rnd, count):
    items = pm.scenarios(policy, policy)
    reasons = sorted({r['reason'] for r in policy['rules']}) + ['UNLISTED_X']
    facts = sorted({r['fact'] for r in policy['rules'] if r['fact']})
    bounds = sorted({b for r in policy['rules'] for b in (r['min_amount'], r['max_amount']) if b is not None} | {0, 1, 1000})
    for _ in range(count):
        amount = max(0, rnd.choice(bounds) + rnd.randint(-2, 2))
        remaining = max(0, rnd.choice([amount, amount - 1, amount + 1, rnd.randint(0, 10 ** 6), pm.MAX_MONEY]))
        remaining = min(remaining, pm.MAX_MONEY)
        amount = min(amount, pm.MAX_MONEY)
        fv = {f: rnd.choice([0, 1, 500, 999, 1000, 1001, 10 ** 6]) for f in facts if rnd.random() < 0.85}
        total = rnd.choice([0, 1, 499, 500, 998, 999, 1000])
        items.append(pm.scenario(rnd.choice(reasons), amount, remaining, total, fv))
    return items


def money_vectors(policy, mod, _dafny, rnd, count):
    out = []
    for item in money_inputs(policy, rnd, count):
        facts = _dafny.Map({dstr(_dafny, k): v for k, v in item['facts']})
        i = mod.Input_Input(dstr(_dafny, item['reason']), item['amount'], item['remaining'], item['reason_total'], facts)
        v = mod.default__.DecideF(i)
        out.append({'input': {'reason': item['reason'], 'amount': item['amount'], 'remaining': item['remaining'],
                              'reason_total': item['reason_total'], 'facts': [list(f) for f in item['facts']]},
                    'decision': MONEY_TEXT[type(v).__name__.split('_', 1)[1]]})
    return out


def rate_verdict(v):
    name = type(v).__name__.split('_', 1)[1]
    if name in ('CooldownActive', 'RateLimited'):
        return [{'CooldownActive': 'COOLDOWN_ACTIVE', 'RateLimited': 'RATE_LIMIT_EXCEEDED'}[name], v.retryAfter]
    return [{'Commit': 'COMMITTED', 'VolumeAboveCap': 'VOLUME_ABOVE_CAP'}[name]]


def rate_vectors(policy, mod, _dafny, rnd, count):
    """Traces of requests (time, volume); the decision of each step and the next state come from the Dafny model."""
    W, V = policy['window_ms'], policy['max_volume']
    traces, steps = [], 0
    while steps < count:
        s = mod.default__.Init
        t = 10_000_000
        trace = []
        pending = []
        for _ in range(rnd.randint(20, 120)):
            if pending:
                t = pending.pop(0)
            else:
                t += rnd.choice([0, 0, 1, rnd.randint(0, max(1, W // 3)), rnd.randint(0, W + 2), W, W - 1 if W > 1 else 0])
            v = rnd.choice([0, 1, rnd.randint(0, max(1, V // max(1, policy['max_ops']))), rnd.randint(0, V) if V < 1 << 62 else 1,
                            V, V + 1] if V < U64 else [0, 1, 2])
            d = mod.default__.DecideF(s, t, v)
            verdict = rate_verdict(d)
            trace.append([t, v, verdict])
            if verdict[0] in ('RATE_LIMIT_EXCEEDED', 'COOLDOWN_ACTIVE') and rnd.random() < 0.6:
                n = verdict[1]
                pending = [t + n - 1, t + n] if n >= 1 else []    # the boundary: one ms before and at the retry time
            s = mod.default__.StepF(s, t, v)
        traces.append(trace)
        steps += len(trace)
    return traces


def transfer_vectors(policy, mod, _dafny, rnd, count):
    M = policy['max_balance']
    out = []
    edges = [0, 1, 2, M - 1, M, M + 1]
    for k in range(count):
        fb = rnd.choice([0, 1, 5, 100, M // 2, M - 1, M, rnd.randint(0, M)])
        tb = rnd.choice([0, 1, 5, 100, M // 2, M - 1, M, rnd.randint(0, M)])
        fb, tb = max(0, min(fb, M)), max(0, min(tb, M))
        amount = rnd.choice([0, 1, fb, fb + 1, max(0, fb - 1), M - tb, M - tb + 1, rnd.randint(0, M)] + edges)
        amount = max(0, min(amount, U64))
        same = k % 23 == 0
        if same:
            tb = fb
        r = mod.default__.DecideF(mod.Input_Input(same, fb, tb, amount))
        name = type(r).__name__.split('_', 1)[1]
        out.append({'input': [same, fb, tb, amount],
                    'decision': ['COMMITTED', r.fromAfter, r.toAfter] if name == 'Commit' else [name]})
    return out


def build_py(dfy, work, log):
    out = Path(work) / 'py'
    p = run_dafny(['build', '--target', 'py', str(Path(dfy).resolve()), '--no-verify', '--output', str(out / 'model')], log)
    if p is None or p.returncode != 0:
        return None
    return out / 'model-py'


def vectors(data, out_dir, work, count=None):
    name, text, kind, policy = generate(data)
    dfy = Path(out_dir) / name
    if not dfy.is_file() or dfy.read_text() != text:
        raise SystemExit('the generated file is missing or differs from a fresh generation; run `gen` first')
    log = []
    folder = build_py(dfy, work, log)
    if folder is None:
        print(json.dumps({'vectors': 'NOT RUN', 'dafny': log}, indent=1))
        return 3
    P = prefix(kind, policy)
    mod, _dafny = load_compiled(folder, P)
    rnd = random.Random(hashlib.sha256(data).hexdigest())
    fn = {'money': money_vectors, 'rate_window': rate_vectors, 'transfer': transfer_vectors}[kind]
    table = fn(policy, mod, _dafny, rnd, count or {'money': 3000, 'rate_window': 3000, 'transfer': 3000}[kind])
    record = {'generator': GENERATOR, 'kind': kind, 'policy': policy['name'], 'policy_sha256': hashlib.sha256(data).hexdigest(),
              'model_file': name, 'model_sha256': hashlib.sha256(text.encode()).hexdigest(),
              'computed_by': 'the Dafny-compiled (pinned Dafny, Python back end) function %s.DecideF%s' % (P, ' and StepF' if kind == 'rate_window' else ''),
              'dafny': [{k: v for k, v in c.items() if k != 'cwd'} for c in log], 'vectors': table}
    target = Path(out_dir) / (name[:-4] + '.vectors.json')
    target.write_text(json.dumps(record, sort_keys=True, separators=(',', ':')) + '\n')
    n = sum(len(x) for x in table) if kind == 'rate_window' else len(table)
    print('VECTORS %s %d decisions (%s)' % (target.name, n, record['computed_by']))
    return 0


# ---------------------------------------------------------------------------------------------------------------------
# Spec clearing by import (as src/airlock/py/diff_policy.py does): scripts/spec_clearing.py is not changed, and no file
# goes under clearing/. Its main() reads only clearing/subjects.json; clear_spec takes a subject built here.
# ---------------------------------------------------------------------------------------------------------------------
def clear(data, out_dir, work):
    name, text, kind, policy = generate(data)
    dfy = (Path(out_dir) / name).resolve()
    if not dfy.is_file() or dfy.read_text() != text:
        raise SystemExit('the generated file is missing or differs from a fresh generation; run `gen` first')
    scripts = DAFNY_ROOT / 'scripts'
    sys.path.insert(0, str(scripts))
    import spec_clearing as sc  # noqa: E402  (the main checkout's copy: it holds the pinned toolchain under its ROOT)

    class SlotTool(sc.Tool):
        def run(self, argv, label):
            if not wait_slot():
                raise SystemExit('NOT RUN: Dafny slot not free in 60 min')
            return super().run(argv, label)

    P = prefix(kind, policy)
    rel = os.path.relpath(dfy, sc.ROOT)
    claim = '%sClaim.NoChoice (correctness)' % P
    subject = {'id': 'p9-%s-%s' % (kind, policy['name']), 'title': 'generated Dafny model of the %s policy %s' % (kind, policy['name']),
               'spec': rel, 'planted': False,
               'claim': {'files': [rel], 'member': claim},
               'proof': {'files': [rel], 'instances': [['%sClaim' % P, {'S': P}]],
                         'members': [claim, '%sClaim.DecideThenPost (correctness)' % P]},
               'candidates': [],
               'spec_probe': {'files': [rel], 'modules': [['%sSpec' % P, {}]], 'open': ['%sSpec.Decide' % P]}}
    if 'Accepts()' in text:
        subject['acceptance'] = {'purpose': 'a concrete accepted input of the compiled decision', 'files': [rel], 'instances': [],
                                 'members': ['%sWitness.Accepts (correctness)' % P]}
    work = Path(work).resolve()
    tool = SlotTool(work / 'clearing')
    record = sc.clear_spec(tool, subject, work / 'generated')
    short = {'subject': subject['id'], 'verdict': record['verdict'], 'acceptance': record.get('acceptance', {}).get('result'),
             'scope': record['scope'], 'claim': {k: record['claim'][k] for k in ('audit_exit', 'checker_exit', 'failed', 'refused', 'members')},
             'proof_passed': (record['proof'] or {}).get('passed'), 'spec_probe_passed': (record['spec_probe'] or {}).get('passed'),
             'commands': [{'argv': c['argv'][:3] + ['...'], 'exit_code': c['exit_code']} for c in tool.commands],
             'source': 'scripts/spec_clearing.py clear_spec (imported, unchanged), subject built by policy_to_dfy.py'}
    (work / 'clearing-record.json').write_text(json.dumps(record, sort_keys=True, indent=1, default=str) + '\n')
    print(json.dumps(short, indent=1))
    return 0 if record['verdict'] == 'NO_CHOICE' else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('command', choices=['gen', 'vectors', 'clear'])
    ap.add_argument('policy')
    ap.add_argument('--out', default=str(OUT))
    ap.add_argument('--work')
    ap.add_argument('--count', type=int)
    args = ap.parse_args()
    data = Path(args.policy).read_bytes()
    try:
        name, text, kind, policy = generate(data)
    except (Malformed, pm.Malformed) as e:
        print('MALFORMED %s' % e)
        return 2
    if args.command == 'gen':
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        (out / name).write_text(text)
        print('GENERATED %s sha256=%s kind=%s' % (name, hashlib.sha256(text.encode()).hexdigest(), kind))
        return 0
    if not args.work:
        print('usage: --work DIR is required')
        return 2
    Path(args.work).mkdir(parents=True, exist_ok=True)
    if args.command == 'vectors':
        return vectors(data, args.out, args.work, args.count)
    return clear(data, args.out, args.work)


if __name__ == '__main__':
    sys.exit(main())
