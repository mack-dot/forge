include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const K: seq<int> := [9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999, 9999999999999999999]
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {

    if Eligible(context, response) && |K| == 16 {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
