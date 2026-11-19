include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var steps := 0;
    if response.Candidate? && 0 <= response.amount {
      var i := 0;
      while i < response.amount
        invariant 0 <= i <= response.amount
        decreases response.amount - i
      {
        i := i + 1;
        steps := steps + 1;
      }
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
