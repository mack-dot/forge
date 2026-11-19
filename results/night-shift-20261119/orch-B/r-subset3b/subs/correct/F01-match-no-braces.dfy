include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    match response
    case Candidate(amt, why) =>
      if Eligible(context, response) {
        decision := Authorized(amt, why);
        plan := [Intent(context.chargeId, context.requestId, amt, why)];
      } else {
        decision := Rejected;
        plan := [];
      }
    case _ =>
      decision := Rejected;
      plan := [];
  }
}
