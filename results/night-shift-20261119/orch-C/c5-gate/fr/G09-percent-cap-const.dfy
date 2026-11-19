include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const FullPercent: int := 100

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) && response.amount * FullPercent <= context.remaining * FullPercent {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
