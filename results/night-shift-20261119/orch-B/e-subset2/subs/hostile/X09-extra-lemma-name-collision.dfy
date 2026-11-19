include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Spin(n: int): int decreases if n < 0 then 0 else n { if n <= 0 then 0 else Spin(n - 1) }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var k := Spin(response.amount);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}

module Helpers {
  lemma Spin(n: int) { }
}
