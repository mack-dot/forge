include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Bump(BigNumber: int): int { BigNumber + 2 }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if |context.chargeId| == 3 {
      var k := Bump(1);
    }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
