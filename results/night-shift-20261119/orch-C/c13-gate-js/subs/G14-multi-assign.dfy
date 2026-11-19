include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision, plan := Rejected, [];
    if Eligible(context, response) {
      decision, plan := Authorized(response.amount, response.reason), [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    }
  }
}
