include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      var scaled := response.amount * context.original;
      decision := Authorized(response.amount + 0 * scaled, response.reason);
      plan := [Intent(context.chargeId, context.requestId, decision.amount, decision.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
