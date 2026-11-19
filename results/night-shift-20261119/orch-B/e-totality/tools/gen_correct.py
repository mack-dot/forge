#!/usr/bin/env python3
"""Write the NEW correct variants (same behaviour as impl/Refund.dfy, other shapes)."""
from pathlib import Path
OUT = Path(__file__).resolve().parent.parent / 'subs/correct'
HEAD = 'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
SIG = '''  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
'''
STD = '''  {
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
'''
V = {}
V['CV01-helper-predicate'] = '''  predicate Ok(c: Context, r: ModelResponse) {
    r.Candidate? && ValidContext(c) && 0 <= r.amount <= c.remaining && AllowedReason(r.reason)
  }
''' + SIG + '''  {
    if Ok(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
'''
V['CV02-match-not-if'] = SIG + '''  {
    match response {
      case Candidate(a, why) =>
        if ValidContext(context) && 0 <= a <= context.remaining && AllowedReason(why) {
          decision := Authorized(a, why);
          plan := [Intent(context.chargeId, context.requestId, a, why)];
        } else {
          decision := Rejected;
          plan := [];
        }
      case _ =>
        decision := Rejected;
        plan := [];
    }
  }
'''
V['CV03-extra-lemma'] = '''  lemma EligibleBounds(c: Context, r: ModelResponse)
    requires Eligible(c, r)
    ensures Money(r.amount) && r.amount <= c.remaining <= c.original
  {
    assert ValidContext(c);
  }
''' + SIG + '''  {
    if Eligible(context, response) {
      EligibleBounds(context, response);
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
'''
V['CV04-reordered-conjuncts'] = SIG + '''  {
    if response.Candidate? && AllowedReason(response.reason) && response.amount <= context.remaining
       && 0 <= response.amount && context.remaining <= context.original && 0 <= context.remaining
       && Money(context.original) && context.requestOpen && context.refundEnabled
       && context.requestId != "" && context.chargeId != "" {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
'''
V['CV05-local-constants'] = '''  const NoPlan: seq<RefundIntent> := []
  const Refusal: Decision := Rejected
''' + SIG + '''  {
    var ok := Eligible(context, response);
    var none := NoPlan;
    decision, plan := Refusal, none;
    if ok {
      var amount := response.amount;
      var why := response.reason;
      decision := Authorized(amount, why);
      plan := [Intent(context.chargeId, context.requestId, amount, why)];
    }
  }
'''
V['CV06-ghost-recursive-lemma'] = '''  ghost function Sum(n: nat): nat
    decreases n
  {
    if n == 0 then 0 else n + Sum(n - 1)
  }

  lemma SumBound(n: nat)
    ensures Sum(n) <= n * n
    decreases n
  {
    if n > 0 { SumBound(n - 1); }
  }
''' + SIG + '''  {
    SumBound(3);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
'''
V['CV07-odd-comments'] = '''  // while for forall expect assume print seq( :| new class -- comments only; ünïcödé ✓ 𝔘   text
  /* a /* nested */ block with while (true) { } and "an unclosed quote
     and a 'char */
''' + SIG + '''  {
    /* the decision */ if Eligible(context, response) /* guard */ {
      decision := Authorized(response.amount, response.reason); // ✓ granted
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected; // 拒否
      plan := [];
    }
  }
'''
V['CV08-helper-used-twice'] = '''  predicate Ok(c: Context, r: ModelResponse) { Eligible(c, r) }
''' + SIG + '''  {
    decision := if Ok(context, response) then Authorized(response.amount, response.reason) else Rejected;
    plan := if Ok(context, response)
            then [Intent(context.chargeId, context.requestId, response.amount, response.reason)] else [];
  }
'''
V['CV09-helper-method-chain'] = '''  method MakePlan(c: Context, a: int, why: string) returns (p: seq<RefundIntent>)
    ensures p == [Intent(c.chargeId, c.requestId, a, why)]
  {
    p := [Intent(c.chargeId, c.requestId, a, why)];
  }

  method Grant(c: Context, r: ModelResponse) returns (d: Decision, p: seq<RefundIntent>)
    requires Eligible(c, r)
    ensures d == Authorized(r.amount, r.reason)
    ensures p == [Intent(c.chargeId, c.requestId, r.amount, r.reason)]
  {
    d := Authorized(r.amount, r.reason);
    p := MakePlan(c, r.amount, r.reason);
  }
''' + SIG + '''  {
    if Eligible(context, response) {
      decision, plan := Grant(context, response);
    } else {
      decision, plan := Rejected, [];
    }
  }
'''
V['CV10-expression-form'] = SIG + '''  {
    var e := Eligible(context, response);
    decision := if e then Authorized(response.amount, response.reason) else Rejected;
    plan := if e then [Intent(context.chargeId, context.requestId, response.amount, response.reason)] else [];
  }
'''
V['CV11-early-returns-assert-by'] = SIG + '''  {
    decision, plan := Rejected, [];
    if !response.Candidate? { return; }
    if !ValidContext(context) { return; }
    if response.amount < 0 || response.amount > context.remaining { return; }
    if !AllowedReason(response.reason) { return; }
    assert Eligible(context, response) by {
      assert response.Candidate? && ValidContext(context);
    }
    decision := Authorized(response.amount, response.reason);
    plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
  }
'''
V['CV12-ghost-var-quantified-assert'] = SIG + '''  {
    ghost var before := Eligible(context, response);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
      assert forall i :: 0 <= i < |plan| ==> plan[i].chargeId == context.chargeId;
    } else {
      decision := Rejected;
      plan := [];
      assert forall x: RefundIntent :: x !in plan;
    }
    assert before == decision.Authorized?;
  }
'''
V['CV13-ghost-loop-in-lemma'] = '''  lemma CountToThree()
    ensures true
  {
    var i := 0;
    while i < 3
      invariant 0 <= i <= 3
      decreases 3 - i
    {
      i := i + 1;
    }
    assert i == 3;  // v2: run 1 had a trigger-less quantifier (warning = exit 2)
  }
''' + SIG + '''  {
    CountToThree();
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
'''
V['CV14-literal-arithmetic'] = SIG + '''  {
    if response.Candidate? && ValidContext(context) && AllowedReason(response.reason)
       && response.amount + 1 > 0 && context.remaining - response.amount >= 0 && 2 * response.amount >= 0 {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
'''
V['CV15-reason-in-seq-literal'] = '''  const Reasons: seq<string> := ["duplicate_charge", "service_not_delivered", "returned_item"]
''' + SIG + '''  {
    if response.Candidate? && ValidContext(context) && 0 <= response.amount <= context.remaining
       && response.reason in Reasons {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
'''
V['CV16-isolate-attr-and-crlf'] = None  # written below with CRLF line ends
for name, body in V.items():
    if body is None:
        text = (HEAD + '  method {:isolate_assertions} Assess(context: Context, response: ModelResponse)\n'
                '      returns (decision: Decision, plan: seq<RefundIntent>)\n' + STD + '}\n')
        text = HEAD + text[len(HEAD):].replace('\n', '\r\n')
    else:
        text = HEAD + body + '}\n'
    (OUT / (name + '.dfy')).write_bytes(text.encode('utf-8'))
print(len(V))
# CV17 (added after the first run): CV07 with the U+2028 character replaced by the text "U+2028".
_t = (OUT / 'CV07-odd-comments.dfy').read_text(encoding='utf-8')
(OUT / 'CV17-odd-comments-no-line-separator.dfy').write_text(_t.replace(' ', 'U+2028'), encoding='utf-8')
