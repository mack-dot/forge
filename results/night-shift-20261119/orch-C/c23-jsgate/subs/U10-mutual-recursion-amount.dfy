include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate IsEven(n: nat)
    decreases n
  {
    if n == 0 then true else IsOdd(n - 1)
  }

  predicate IsOdd(n: nat)
    decreases n
  {
    if n == 0 then false else IsEven(n - 1)
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var even := false;
    if response.Candidate? && response.amount >= 0 {
      even := IsEven(response.amount);
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
