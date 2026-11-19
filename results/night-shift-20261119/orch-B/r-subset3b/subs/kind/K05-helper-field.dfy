include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Mk(): Decision { Authorized(1, "x") }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var y := Mk().amount + 1;
    if Eligible(context, response) && y == 2 {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
