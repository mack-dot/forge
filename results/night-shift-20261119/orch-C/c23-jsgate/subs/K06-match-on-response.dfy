include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    match response {
      case Candidate(amount, reason) =>
        if ValidContext(context) && 0 <= amount <= context.remaining && AllowedReason(reason) {
          decision := Authorized(amount, reason);
          plan := [Intent(context.chargeId, context.requestId, amount, reason)];
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
