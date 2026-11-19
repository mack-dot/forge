include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? {
      var ok := ValidContext(context) && 0 <= response.amount <= context.remaining && AllowedReason(response.reason);
      if ok {
        decision := Authorized(response.amount, response.reason);
        plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
        return;
      }
    } else {
      var ok := false;
    }
    decision := Rejected;
    plan := [];
  }
}
