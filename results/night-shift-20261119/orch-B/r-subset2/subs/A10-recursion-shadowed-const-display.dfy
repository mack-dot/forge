include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const C := [0]

  function Len(P: string): int
    decreases |P|
  {
    if |P| == 0 then 0 else 1 + Len(P[1..])
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var C := context.chargeId;
    var depth := Len(C);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
