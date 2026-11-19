include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate Ok(c: Context, r: ModelResponse) {
    r.Candidate? && ValidContext(c) && 0 <= r.amount <= c.remaining && AllowedReason(r.reason)
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Ok(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
