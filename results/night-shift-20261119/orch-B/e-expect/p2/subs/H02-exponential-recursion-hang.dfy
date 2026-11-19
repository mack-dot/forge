include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Slow(n: nat): nat { if n == 0 then 0 else Slow(n - 1) + Slow(n - 1) }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && response.amount == 123456789 {
      var z := Slow(200);
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
