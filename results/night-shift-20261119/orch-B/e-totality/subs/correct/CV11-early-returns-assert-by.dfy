include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision, plan := Rejected, [];
    if !response.Candidate? { return; }
    if !ValidContext(context) { return; }
    if response.amount < 0 || response.amount > context.remaining { return; }
    if !AllowedReason(response.reason) { return; }
    assert Eligible(context, response) by {
      assert response.Candidate? && ValidContext(context);
    }
    decision := Authorized(response.amount, response.reason);
    plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
  }
}
