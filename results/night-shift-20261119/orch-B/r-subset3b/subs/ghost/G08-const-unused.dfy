include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Heavy(x: int): int { x + x + x }
  const K: int := Heavy(Heavy(Heavy(Heavy(5))))
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {

    if Eligible(context, response) && true {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
