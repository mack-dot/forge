include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Pad: seq<int> := seq(1000000000, i => i)
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if |Pad| > 0 && Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
