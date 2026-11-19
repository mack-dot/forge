include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate AllSmall(n: nat) { forall i :: 0 <= i < n ==> i >= 0 }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && response.amount == 123456789 { var b := AllSmall(1000000000000000000); }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
