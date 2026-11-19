include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Cap := 1_000_000
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) && response.amount <= Cap * 1000 + MaxMoney {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
