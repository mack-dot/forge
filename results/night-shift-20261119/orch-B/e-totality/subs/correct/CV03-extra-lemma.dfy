include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  lemma EligibleBounds(c: Context, r: ModelResponse)
    requires Eligible(c, r)
    ensures Money(r.amount) && r.amount <= c.remaining <= c.original
  {
    assert ValidContext(c);
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      EligibleBounds(context, response);
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
