include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const A: int := Fa(1)
  function Fa(x: int): int { if x > 0 then 0 else A }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var u := A;
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
