include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Heavy(x: int): int { x + x + x }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    assert Heavy(1) == 3;
    if Eligible(context, response) && true {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
