include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Allowed(r: string): bool
    ensures Allowed(r) == AllowedReason(r)
  {
    r == "duplicate_charge" || r == "service_not_delivered" || r == "returned_item"
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if ValidContext(context) && response.Candidate? && 0 <= response.amount <= context.remaining
        && Allowed(response.reason) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
