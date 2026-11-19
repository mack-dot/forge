include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && AllowedReason(response.reason) && response.amount <= context.remaining
       && 0 <= response.amount && context.remaining <= context.original && 0 <= context.remaining
       && Money(context.original) && context.requestOpen && context.refundEnabled
       && context.requestId != "" && context.chargeId != "" {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
