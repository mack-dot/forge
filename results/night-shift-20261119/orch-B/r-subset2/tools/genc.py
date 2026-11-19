#!/usr/bin/env python3
"""Correct refund implementations in natural styles (false-refusal probe for subset_rule2)."""
import os
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'subs')
HEAD = 'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
SIG = ('  method Assess(context: Context, response: ModelResponse)\n'
       '      returns (decision: Decision, plan: seq<RefundIntent>)\n  {\n')
OK = ('decision := Authorized(response.amount, response.reason);\n'
      '      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];')
NO = 'decision := Rejected;\n      plan := [];'
def c(name, body, members=''):
    open(os.path.join(D, name + '.dfy'), 'w').write(HEAD + members + SIG + body + '  }\n}\n')

c('C01-early-return', '    if !Eligible(context, response) {\n      return Rejected, [];\n    }\n'
  '    return Authorized(response.amount, response.reason), '
  '[Intent(context.chargeId, context.requestId, response.amount, response.reason)];\n')
c('C02-match-tuple', '    match (ValidContext(context), response) {\n'
  '      case (true, Candidate(a, r)) =>\n'
  '        if 0 <= a <= context.remaining && AllowedReason(r) {\n'
  '          decision := Authorized(a, r);\n          plan := [Intent(context.chargeId, context.requestId, a, r)];\n'
  '        } else {\n          ' + NO + '\n        }\n'
  '      case _ =>\n        ' + NO + '\n    }\n')
c('C03-set-literal-reasons', '    var allowed := {"duplicate_charge", "service_not_delivered", "returned_item"};\n'
  '    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining\n'
  '        && response.reason in allowed {\n      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n')
c('C04-local-datatype-verdict', '    var v := if Eligible(context, response) then Ok else Bad;\n'
  '    if v == Ok {\n      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n',
  members='  datatype Verdict = Ok | Bad\n\n')
c('C05-loop-over-local-reason-list', '    var reasons := ["duplicate_charge", "service_not_delivered", "returned_item"];\n'
  '    var found := false;\n    var i := 0;\n'
  '    while i < |reasons|\n      invariant 0 <= i <= |reasons|\n'
  '      invariant found <==> response.Candidate? && exists j :: 0 <= j < i && reasons[j] == response.reason\n    {\n'
  '      if response.Candidate? && reasons[i] == response.reason { found := true; }\n      i := i + 1;\n    }\n'
  '    assert found ==> response.Candidate? && response.reason in reasons;\n'
  '    assert !found ==> !(response.Candidate? && response.reason in reasons);\n'
  '    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining && found {\n'
  '      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n')
c('C06-reason-index-loop-early-exit', '    var i := 0;\n    var hit := false;\n'
  '    while i < |Reasons| && !hit\n      invariant 0 <= i <= |Reasons|\n'
  '      invariant hit <==> (i > 0 && response.Candidate? && Reasons[i - 1] == response.reason)\n'
  '      invariant !hit ==> forall j :: 0 <= j < i ==> !(response.Candidate? && Reasons[j] == response.reason)\n    {\n'
  '      hit := response.Candidate? && Reasons[i] == response.reason;\n      i := i + 1;\n    }\n'
  '    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining && hit {\n'
  '      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n',
  members='  const Reasons := ["duplicate_charge", "service_not_delivered", "returned_item"]\n\n')
c('C07-tuple-destructure', '    var (d, p) := Decide(context, response);\n    decision, plan := d, p;\n',
  members=('  function Decide(context: Context, response: ModelResponse): (Decision, seq<RefundIntent>)\n'
           '  {\n    if Eligible(context, response) then\n'
           '      (Authorized(response.amount, response.reason), [Intent(context.chargeId, context.requestId, response.amount, response.reason)])\n'
           '    else (Rejected, [])\n  }\n\n'))
c('C08-label-assert', '    if Eligible(context, response) {\n      label ok:\n      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n')
c('C09-string-prefix-helper', '    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining\n'
  '        && Allowed(response.reason) {\n      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n',
  members=('  function Allowed(r: string): bool\n    ensures Allowed(r) == AllowedReason(r)\n  {\n'
           '    r == "duplicate_charge" || r == "service_not_delivered" || r == "returned_item"\n  }\n\n'))
c('C10-ghost-such-that', '    ghost var witnessAmount :| witnessAmount == 5;\n'
  '    if Eligible(context, response) {\n      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n')
c('C11-lemma-forall-statement', '    if Eligible(context, response) {\n      ' + OK + '\n      PlanFacts(plan);\n    } else {\n      ' + NO + '\n    }\n',
  members=('  lemma PlanFacts(p: seq<RefundIntent>)\n    ensures forall i :: 0 <= i < |p| ==> p[i] in p\n  {\n'
           '    forall i | 0 <= i < |p|\n      ensures p[i] in p\n    {\n    }\n  }\n\n'))
c('C12-calc-lemma', '    if Eligible(context, response) {\n      Twice(response.amount);\n      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n',
  members=('  lemma Twice(x: int)\n    ensures x + x == 2 * x\n  {\n    calc {\n      x + x;\n    ==\n      2 * x;\n    }\n  }\n\n'))
c('C13-match-expression-arms', '    var ok := match response\n      case Candidate(a, r) => ValidContext(context) && 0 <= a <= context.remaining && AllowedReason(r)\n'
  '      case _ => false;\n    if ok {\n      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n')
c('C14-amount-sum-check', '    var room := if response.Candidate? then context.remaining - response.amount else -1;\n'
  '    if ValidContext(context) && response.Candidate? && 0 <= response.amount && room >= 0 && AllowedReason(response.reason) {\n'
  '      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n')
c('C15-helper-multi-return', '    var ok, why := Check(context, response);\n    if ok {\n      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n',
  members=('  method Check(context: Context, response: ModelResponse) returns (ok: bool, why: string)\n'
           '    ensures ok == Eligible(context, response)\n  {\n'
           '    if !ValidContext(context) { return false, "context"; }\n'
           '    if !response.Candidate? { return false, "shape"; }\n'
           '    ok := Eligible(context, response);\n    why := if ok then "" else "rule";\n  }\n\n'))
c('C16-reason-string-concat-log', '    var note := "refund:" + (if response.Candidate? then response.reason else "none");\n'
  '    if Eligible(context, response) {\n      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n')
c('C17-percent-check', '    if Eligible(context, response) && (response.amount * 100) / 100 == response.amount {\n'
  '      ' + OK + '\n    } else if Eligible(context, response) {\n      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n')
c('C18-for-range-over-local-list', '    var reasons := ["duplicate_charge", "service_not_delivered", "returned_item"];\n'
  '    var found := false;\n'
  '    for i := 0 to |reasons|\n      invariant found <==> exists j :: 0 <= j < i && response.Candidate? && reasons[j] == response.reason\n    {\n'
  '      if response.Candidate? && reasons[i] == response.reason { found := true; }\n    }\n'
  '    assert found ==> response.Candidate? && response.reason in reasons;\n'
  '    assert !found ==> !(response.Candidate? && response.reason in reasons);\n'
  '    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining && found {\n'
  '      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n')
c('C19-map-reason-table', '    var table := map["duplicate_charge" := true, "service_not_delivered" := true, "returned_item" := true];\n'
  '    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining\n'
  '        && response.reason in table {\n      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n')
c('C20-loop-with-break', '    var found := false;\n    var i := 0;\n'
  '    while i < 3\n      invariant 0 <= i <= 3\n'
  '      invariant found <==> (response.Candidate? && exists j :: 0 <= j < i && Reasons[j] == response.reason)\n    {\n'
  '      if response.Candidate? && Reasons[i] == response.reason { found := true; break; }\n      i := i + 1;\n    }\n'
  '    assert found ==> response.Candidate? && response.reason in Reasons;\n'
  '    assert !found ==> !(response.Candidate? && response.reason in Reasons);\n'
  '    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining && found {\n'
  '      ' + OK + '\n    } else {\n      ' + NO + '\n    }\n',
  members='  const Reasons: seq<string> := ["duplicate_charge", "service_not_delivered", "returned_item"]\n\n')
