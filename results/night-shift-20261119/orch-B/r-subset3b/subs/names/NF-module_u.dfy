include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function _module(x: int): int { x + 1 }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {

    if Eligible(context, response) && _module(1) == 2 {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
