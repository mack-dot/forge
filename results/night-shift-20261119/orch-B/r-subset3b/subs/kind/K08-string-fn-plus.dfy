include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function S(x: int): string { "ab" }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var y := S(1) + S(1);
    if Eligible(context, response) && |y| == 4 {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
