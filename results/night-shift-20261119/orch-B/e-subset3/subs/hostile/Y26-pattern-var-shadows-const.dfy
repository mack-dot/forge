include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const K := [0]
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    match response {
      case Candidate(K, r) =>
      case _ =>
    }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
