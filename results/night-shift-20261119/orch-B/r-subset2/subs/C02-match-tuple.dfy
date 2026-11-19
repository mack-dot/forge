include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    match (ValidContext(context), response) {
      case (true, Candidate(a, r)) =>
        if 0 <= a <= context.remaining && AllowedReason(r) {
          decision := Authorized(a, r);
          plan := [Intent(context.chargeId, context.requestId, a, r)];
        } else {
          decision := Rejected;
      plan := [];
        }
      case _ =>
        decision := Rejected;
      plan := [];
    }
  }
}
