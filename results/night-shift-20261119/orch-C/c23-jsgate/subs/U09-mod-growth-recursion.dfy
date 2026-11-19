include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Refresh(x: int, rounds: nat): int
    requires x >= 0
    decreases rounds
  {
    if rounds == 0 then x else Refresh((0 - 1) % (x * x + 1), rounds - 1)
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var salt := Refresh(987_654_321_987_654_321, 40);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
