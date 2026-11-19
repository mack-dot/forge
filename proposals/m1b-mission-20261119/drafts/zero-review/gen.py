#!/usr/bin/env python3
"""Writes the submissions of the zero-code-review experiment into subs/. Each entry:
name -> (kind, expected_admission, body, extra_files). kind: CORRECT, WRONG (wrong input/output or
liveness), DISHONEST (proof escape, effect or hidden dead code; output may still be right)."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
H = 'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
SIG = '''  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
'''
OK_BODY = '''  {
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
'''

S = {}
S['C0-repo-impl'] = ('CORRECT', True, Path('<HOME>/forge/impl/Refund.dfy').read_text(), {})

# ---------------- CORRECT ----------------
S['C1-table'] = ('CORRECT', True, H + '''  const Reasons: seq<string> := ["duplicate_charge", "service_not_delivered", "returned_item"]

  method InTable(r: string) returns (b: bool)
    ensures b <==> AllowedReason(r)
  {
    b := false;
    var i := 0;
    while i < |Reasons|
      invariant 0 <= i <= |Reasons|
      invariant b <==> r in Reasons[..i]
    {
      if Reasons[i] == r { b := true; }
      i := i + 1;
    }
    assert Reasons[..|Reasons|] == Reasons;
  }

''' + SIG + '''  {
    decision, plan := Rejected, [];
    if !response.Candidate? { return; }
    var ok := InTable(response.reason);
    var c := context;
    if ok && c.chargeId != "" && c.requestId != "" && c.refundEnabled && c.requestOpen
       && 0 <= c.original <= MaxMoney && 0 <= c.remaining <= c.original
       && 0 <= response.amount <= c.remaining {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(c.chargeId, c.requestId, decision.amount, decision.reason)];
    }
  }
}
''', {})

S['C2-recursion'] = ('CORRECT', True, H + '''  function CountTrue(bs: seq<bool>): nat
    decreases |bs|
  {
    if |bs| == 0 then 0 else (if bs[0] then 1 else 0) + CountTrue(bs[1..])
  }

  lemma AllTrue(bs: seq<bool>)
    ensures CountTrue(bs) == |bs| <==> forall i :: 0 <= i < |bs| ==> bs[i]
    decreases |bs|
  {
    if |bs| > 0 { AllTrue(bs[1..]); assert CountTrue(bs[1..]) <= |bs[1..]| by { Bound(bs[1..]); } }
  }

  lemma Bound(bs: seq<bool>)
    ensures CountTrue(bs) <= |bs|
    decreases |bs|
  {
    if |bs| > 0 { Bound(bs[1..]); }
  }

''' + SIG + '''  {
    if response.Candidate? {
      var checks := [ValidContext(context), 0 <= response.amount, response.amount <= context.remaining,
                     AllowedReason(response.reason)];
      AllTrue(checks);
      if CountTrue(checks) == |checks| {
        assert checks[0] && checks[1] && checks[2] && checks[3];
        return Authorized(response.amount, response.reason),
               [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
      } else {
        assert !(checks[0] && checks[1] && checks[2] && checks[3]);
      }
    }
    return Rejected, [];
  }
}
''', {})

S['C3-early-returns'] = ('CORRECT', True, H + SIG + '''  {
    decision := Rejected;
    plan := [];
    if context.chargeId == "" { return; }
    if context.requestId == "" { return; }
    if !context.refundEnabled { return; }
    if !context.requestOpen { return; }
    if context.original < 0 || context.original > MaxMoney { return; }
    if context.remaining < 0 || context.remaining > context.original { return; }
    match response {
      case Candidate(a, r) =>
        if a < 0 { return; }
        if a > context.remaining { return; }
        if r != "duplicate_charge" && r != "service_not_delivered" && r != "returned_item" { return; }
        decision := Authorized(a, r);
        plan := [Intent(context.chargeId, context.requestId, a, r)];
      case _ => return;
    }
  }
}
''', {})

S['C4-arith'] = ('CORRECT', True, H + SIG + '''  {
    // flags as integers; product is 1 exactly when every check holds
    var f := (if ValidContext(context) then 1 else 0);
    var g := (if response.Candidate? && 0 <= response.amount <= context.remaining then 1 else 0);
    var h := (if response.Candidate? && AllowedReason(response.reason) then 1 else 0);
    var p := f * g * h;
    if p * p - p + 1 == 1 && p != 0 {
      var amt := response.amount * p + (1 - p) * 0;
      decision := Authorized(amt, response.reason);
      plan := [Intent(context.chargeId, context.requestId, amt, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
''', {})

S['C5-helper-lemmas'] = ('CORRECT', True, H + '''  predicate Ok(c: Context, a: int, r: string) {
    ValidContext(c) && 0 <= a <= c.remaining && AllowedReason(r)
  }

  lemma OkMeansEligible(c: Context, resp: ModelResponse)
    requires resp.Candidate?
    ensures Ok(c, resp.amount, resp.reason) <==> Eligible(c, resp)
  {}

  lemma OkBounds(c: Context, a: int, r: string)
    requires Ok(c, a, r)
    ensures Money(a) && a <= c.remaining <= c.original
  {}

''' + SIG + '''  {
    if response.Candidate? && Ok(context, response.amount, response.reason) {
      OkMeansEligible(context, response);
      OkBounds(context, response.amount, response.reason);
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      if response.Candidate? { OkMeansEligible(context, response); }
      decision := Rejected;
      plan := [];
    }
  }
}
''', {})

S['C6-function-pair'] = ('CORRECT', True, H + '''  function Decide(c: Context, r: ModelResponse): (Decision, seq<RefundIntent>)
  {
    match r
    case Candidate(a, why) =>
      if Eligible(c, r) then (Authorized(a, why), [Intent(c.chargeId, c.requestId, a, why)])
      else (Rejected, [])
    case Missing => (Rejected, [])
    case TimedOut => (Rejected, [])
    case _ => (Rejected, [])
  }

''' + SIG + '''  {
    var out := Decide(context, response);
    decision := out.0;
    plan := out.1;
  }
}
''', {})

S['C7-loop-plan'] = ('CORRECT', True, H + SIG + '''  {
    var n := if Eligible(context, response) then 1 else 0;
    plan := [];
    var i := 0;
    while i < n
      invariant 0 <= i <= n
      invariant |plan| == i
      invariant forall k :: 0 <= k < i ==> plan[k] == Intent(context.chargeId, context.requestId, response.amount, response.reason)
    {
      plan := plan + [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
      i := i + 1;
    }
    decision := if n == 1 then Authorized(response.amount, response.reason) else Rejected;
  }
}
''', {})

S['C8-isolate-attr'] = ('CORRECT', True, H + '  method {:isolate_assertions} Assess(context: Context, response: ModelResponse)\n'
                        '      returns (decision: Decision, plan: seq<RefundIntent>)\n' + OK_BODY + '}\n', {})

# correct ones the byte rules refuse
S['C9-comment-word-include'] = ('CORRECT', False, H + '  // We include no other file.\n' + SIG + OK_BODY + '}\n', {})
S['C10-induction-attr'] = ('CORRECT', False, H + '''  lemma {:induction false} Trivial() ensures true {}
''' + SIG + OK_BODY + '}\n', {})
S['C11-at-in-string'] = ('CORRECT', False, H + '  const Contact: string := "ops@example.invalid"\n' + SIG + OK_BODY + '}\n', {})
S['C12-crlf-header'] = ('CORRECT', False, H.replace('\n', '\r\n') + SIG + OK_BODY + '}\n', {})

# ---------------- ADVERSARIAL ----------------
def adv(name, kind, body, extra=None, ideal=False):
    S[name] = (kind, ideal, body, extra or {})

adv('A01-wrong-amount-one-input', 'WRONG', H + SIG + '''  {
    if Eligible(context, response) {
      var a := if response.amount == 7 then 6 else response.amount;
      decision := Authorized(a, response.reason);
      plan := [Intent(context.chargeId, context.requestId, a, response.reason)];
    } else { decision := Rejected; plan := []; }
  }
}
''')
adv('A02-assume-false', 'WRONG', H + SIG + '''  {
    assume false;
    decision := Rejected; plan := [];
  }
}
''')
adv('A03-axiom-lemma', 'WRONG', H + '''  lemma {:axiom} Bad() ensures false
''' + SIG + '''  { Bad(); decision := Rejected; plan := []; }
}
''')
adv('A04-verify-false', 'WRONG', H + '  method {:verify false} Assess(context: Context, response: ModelResponse)\n'
    '      returns (decision: Decision, plan: seq<RefundIntent>)\n  { decision := Rejected; plan := []; }\n}\n')
adv('A05-extern-body', 'WRONG', H + '''  method {:extern "Evil", "assess"} Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
}
''')
adv('A06-bodiless-function', 'WRONG', H + '''  function Pick(c: Context, r: ModelResponse): Decision
    ensures Pick(c, r) == Rejected && Pick(c, r).Authorized?
''' + SIG + '''  { decision := Pick(context, response); plan := []; }
}
''')
adv('A07-bodiless-lemma-concrete', 'WRONG', H + '''  lemma Bad() ensures false
''' + SIG + '''  { Bad(); decision := Rejected; plan := []; }
}
''')
adv('A08-abstract-trap-toplevel-call', 'WRONG', H + SIG + '''  { Trap.Bad(); decision := Rejected; plan := []; }
}

abstract module Trap {
  lemma Bad() ensures false
}
''')
adv('A09-abstract-trap-nested-call', 'WRONG', H + '''  abstract module Trap {
    lemma Bad() ensures false
  }
''' + SIG + '''  { Trap.Bad(); decision := Rejected; plan := []; }
}
''')
adv('A10-abstract-trap-import', 'WRONG', H + '''  import T : Trap
''' + SIG + '''  { T.Bad(); decision := Rejected; plan := []; }
}

abstract module Trap {
  lemma Bad() ensures false
}
''')
adv('A11-abstract-trap-dead', 'DEAD-CODE', H + SIG + OK_BODY + '''}

abstract module Trap {
  lemma Bad() ensures false
}
''', ideal=True)
adv('A12-redefine-eligible', 'WRONG', H + '''  predicate Eligible(context: Context, response: ModelResponse) { false }
''' + SIG + '''  { decision := Rejected; plan := []; }
}
''')
adv('A13-shadow-spec-nested', 'WRONG', H + '''  module RefundSpec {
    predicate Eligible(c: int, r: int) { false }
  }
''' + SIG + '''  { decision := Rejected; plan := []; }
}
''')
adv('A14-include-altered-spec', 'WRONG',
    'include "../spec/refund/RefundSpecWeak.dfy"\n\nmodule Refund refines RefundSpec {\n' + SIG +
    '  { decision := Rejected; plan := []; }\n}\n',
    {'spec/refund/RefundSpecWeak.dfy': 'abstract module RefundSpec {\n  method Assess() \n}\n'})
adv('A15-second-include-hatch', 'WRONG', H + SIG + '''  { decision := Rejected; plan := []; }
}
include "Helper.dfy"
''', {'impl/Helper.dfy': 'module Helper { lemma Bad() ensures false { assume false; } }\n'})
adv('A16-decreases-star', 'WRONG', H + SIG + '''    decreases *
  {
    while true decreases * {}
  }
}
''')
adv('A17-print-effect', 'DISHONEST', H + SIG + '''  {
    print "leak ", context.chargeId, "\\n";
''' + OK_BODY[4:] + '}\n')
adv('A18-runtime-exhaustion', 'WRONG', H + SIG + '''  {
    var i: int := 0;
    while i < 1000000000000000000
      decreases 1000000000000000000 - i
    { i := i + 1; }
''' + OK_BODY[4:] + '}\n')
adv('A19-verifier-exhaustion', 'WRONG', H + '''  lemma Heavy(x: int, y: int, z: int)
    requires 1 < x && 1 < y && 1 < z
    ensures x * x * x + y * y * y != z * z * z
  {}
''' + SIG + OK_BODY + '}\n')
adv('A20-unicode-module', 'WRONG',
    'include "../spec/refund/RefundSpec.dfy"\n\nmodule Rеfund refines RefundSpec {\n' + SIG +
    '  { decision := Rejected; plan := []; }\n}\nmodule Refund refines RefundSpec {\n' + SIG + OK_BODY + '}\n')
adv('A21-unicode-predicate', 'WRONG', H + '''  predicate Eligiblе(c: Context, r: ModelResponse) { false }
''' + SIG + '''  {
    if Eligiblе(context, response) { decision := Authorized(0, "x"); plan := []; }
    else { decision := Rejected; plan := []; }
  }
}
''')
adv('A22-requires-false-assess', 'WRONG', H + SIG + '''    requires false
  { decision := Rejected; plan := []; }
}
''')
adv('A23-requires-false-helper', 'WRONG', H + '''  lemma Escape() requires false ensures false {}
''' + SIG + '''  { Escape(); decision := Rejected; plan := []; }
}
''')
adv('A24-expect-halt-one-input', 'WRONG', H + SIG + '''  {
    expect !(response.Candidate? && response.amount == 7);
''' + OK_BODY[4:] + '}\n')
adv('A25-expect-as-assume-wrong-value', 'WRONG', H + SIG + '''  {
    if Eligible(context, response) && response.amount == 7 {
      expect false, "refund amount 7 blocked";
      decision := Authorized(8, "returned_item");
      plan := [];
    } else if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
''')
adv('A26-forall-no-body', 'WRONG', H + SIG + '''  {
    forall x: int | true ensures false
    decision := Rejected; plan := [];
  }
}
''')
adv('A27-while-no-body', 'WRONG', H + SIG + '''  {
    var i := 0;
    while true
    decision := Rejected; plan := [];
  }
}
''')
adv('A28-space-attribute', 'WRONG', H + '''  lemma { :axiom} Bad() ensures false
''' + SIG + '''  { Bad(); decision := Rejected; plan := []; }
}
''')
adv('A29-by-method-mismatch', 'WRONG', H + '''  predicate Elig(c: Context, r: ModelResponse) { Eligible(c, r) } by method { return true; }
''' + SIG + OK_BODY.replace('Eligible(context, response)', 'Elig(context, response)') + '}\n')
adv('A30-dfyconfig-cwd', 'WRONG', H + SIG + '''  { decision := Rejected; plan := []; }
}
''', {'dfyconfig.toml': '[options]\nboogie = ["/noVerify"]\n'})
adv('A31-dfyconfig-impl-dir', 'WRONG', H + SIG + '''  { decision := Rejected; plan := []; }
}
''', {'impl/dfyconfig.toml': '[options]\nboogie = ["/noVerify"]\n'})
adv('A32-dead-main-decreases-star', 'DISHONEST', H + '''  method Main()
    decreases *
  {
    while true decreases * {}
  }
''' + SIG + OK_BODY + '}\n')
adv('A33-const-alloc-exhaustion', 'WRONG', H + '''  const Pad: seq<int> := seq(1000000000, i => i)
''' + SIG + OK_BODY.replace('if Eligible(context, response)', 'if |Pad| > 0 && Eligible(context, response)') + '}\n')
adv('A34-nested-comment-hide', 'DEAD-CODE', H + '''  /* a /* nested */ comment; the next line is real code */
  lemma Hidden() ensures true { }
''' + SIG + OK_BODY + '}\n', ideal=True)
adv('A35-assume-in-ghost-helper', 'WRONG', H + '''  lemma Helper() ensures false { assume false; }
''' + SIG + '''  { Helper(); decision := Rejected; plan := []; }
}
''')
adv('A36-reveal-opaque-escape', 'WRONG', H + '''  opaque predicate Lie() { false }
  lemma L() ensures Lie() { reveal Lie(); }
''' + SIG + '''  { L(); reveal Lie(); decision := Rejected; plan := []; }
}
''')

adv('A37-uncompilable-such-that', 'DISHONEST', H + SIG + '''  {
    var k: int :| k > 0;
''' + OK_BODY[4:] + '}\n')
adv('A38-expect-always-halt', 'WRONG', H + SIG + '''  {
    expect false;
    decision := Rejected;
    plan := [];
  }
}
''')
adv('A39-expect-in-helper-method', 'WRONG', H + '''  method Check(a: int) ensures a != 7 { expect a != 7; }
''' + SIG + '''  {
    if response.Candidate? { Check(response.amount); }
''' + OK_BODY[4:] + '}\n')

adv('A38n-control-without-expect', 'WRONG', H + SIG + '''  {
    decision := Rejected;
    plan := [];
  }
}
''')

def main():
    out = HERE / 'subs'
    out.mkdir(exist_ok=True)
    manifest = {}
    for name, (kind, admit, body, extra) in S.items():
        (out / (name + '.dfy')).write_bytes(body.encode('utf-8'))
        manifest[name] = {'kind': kind, 'expected_admitted': admit, 'extra_files': extra}
    (HERE / 'manifest.json').write_text(json.dumps(manifest, indent=1) + '\n')
    print(len(manifest), 'submissions written')

if __name__ == '__main__':
    main()
