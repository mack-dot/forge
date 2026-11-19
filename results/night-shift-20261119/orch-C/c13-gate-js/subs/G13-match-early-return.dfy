include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    match response {
      case Candidate(amount, reason) =>
        if Eligible(context, response) {
          return Authorized(amount, reason), [Intent(context.chargeId, context.requestId, amount, reason)];
        }
      case _ =>
    }
    return Rejected, [];
  }
}
