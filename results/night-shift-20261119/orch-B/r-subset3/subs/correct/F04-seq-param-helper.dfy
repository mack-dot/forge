include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Single(i: RefundIntent): seq<RefundIntent> { [i] }
  predicate NoPlan(p: seq<RefundIntent>) { |p| == 0 }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := Single(Intent(context.chargeId, context.requestId, response.amount, response.reason));
    } else {
      decision := Rejected;
      plan := [];
    }
    assert decision.Rejected? ==> NoPlan(plan);
  }
}
