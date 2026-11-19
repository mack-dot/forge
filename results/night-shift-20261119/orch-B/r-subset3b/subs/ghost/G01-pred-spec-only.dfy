include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate Pos(x: int) { x > 0 }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    assert Pos(1);
    if Eligible(context, response) && true {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
