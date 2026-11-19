include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function defineProperty(x: int): int { x }
  function freeze(x: int): int { x }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var k := freeze(defineProperty(1));
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
