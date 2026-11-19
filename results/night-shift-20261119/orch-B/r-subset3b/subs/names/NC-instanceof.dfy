include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const instanceof: int := 7
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {

    if Eligible(context, response) && instanceof == 7 {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
