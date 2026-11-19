include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    plan := [];
    decision := Rejected;
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := plan + [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    }
  }
}
