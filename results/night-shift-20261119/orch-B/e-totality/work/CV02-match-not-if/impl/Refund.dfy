include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    match response {
      case Candidate(a, why) =>
        if ValidContext(context) && 0 <= a <= context.remaining && AllowedReason(why) {
          decision := Authorized(a, why);
          plan := [Intent(context.chargeId, context.requestId, a, why)];
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
