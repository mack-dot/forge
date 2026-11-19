include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate KnownReason(s: string) {
    s == "duplicate_charge" || s == "service_not_delivered" || s == "returned_item"
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && ValidContext(context) && KnownReason(response.reason)
       && 0 <= response.amount <= context.remaining {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
