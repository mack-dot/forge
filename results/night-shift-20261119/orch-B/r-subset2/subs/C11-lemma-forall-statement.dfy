include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  lemma PlanFacts(p: seq<RefundIntent>)
    ensures forall i :: 0 <= i < |p| ==> p[i] in p
  {
    forall i | 0 <= i < |p|
      ensures p[i] in p
    {
    }
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
      PlanFacts(plan);
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
