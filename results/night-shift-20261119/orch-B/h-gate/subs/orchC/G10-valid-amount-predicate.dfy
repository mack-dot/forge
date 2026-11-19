include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate ValidAmount(c: Context, amount: int)
    requires ValidContext(c)
  {
    0 <= amount && amount <= c.remaining
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if ValidContext(context) && response.Candidate? && ValidAmount(context, response.amount)
        && AllowedReason(response.reason) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
