include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Apply(f: nat -> nat, x: nat): nat { f(x) }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && response.amount == 123456789 { var z := Apply(x => x, 3); }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
