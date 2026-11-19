include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate Within(x: int, lo: int, hi: int) {
    lo <= x <= hi
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var lo, hi := 0, context.remaining;
    if ValidContext(context) && response.Candidate? && Within(response.amount, lo, hi) &&
       AllowedReason(response.reason) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
