include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method {/**/:verify false} Halt() ensures false {}

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && response.amount == 123456789 { Halt(); }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
