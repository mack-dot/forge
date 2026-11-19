include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Reasons: seq<string> := ["duplicate_charge", "service_not_delivered", "returned_item"]
  lemma ReasonsAgree(r: string)
    ensures (r in Reasons) == AllowedReason(r)
  {
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    ReasonsAgree(if response.Candidate? then response.reason else "");
    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining &&
       response.reason in Reasons {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
