include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Rejected;
    plan := [];
    if !ValidContext(context) {
      return;
    }
    if !response.Candidate? {
      return;
    }
    if response.amount < 0 || response.amount > context.remaining {
      return;
    }
    if !AllowedReason(response.reason) {
      return;
    }
    decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
  }
}
