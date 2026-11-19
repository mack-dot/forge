include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Pick(d1: Decision, d2: Decision, d3: Decision, d4: Decision, d5: Decision, d6: Decision): int {
    1 + match (d1, d2, d3, d4, d5, d6)
      case (_, _, _, _, _, Rejected) => 1 + 1 + 1
      case (_, _, _, _, Rejected, _) => 2
      case (_, _, _, Rejected, _, _) => 3
      case (_, _, Rejected, _, _, _) => 4
      case (_, Rejected, _, _, _, _) => 5
      case (Rejected, _, _, _, _, _) => 6
      case _ => 0
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Rejected;
    var y := Pick(decision, decision, decision, decision, decision, decision);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
