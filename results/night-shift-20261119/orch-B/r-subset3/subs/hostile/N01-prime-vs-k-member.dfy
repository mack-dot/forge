include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate A_k(c: Context, r: ModelResponse) { Eligible(c, r) }
  predicate A'(c: Context, r: ModelResponse) { A_k(c, r) }
  function B'(x: int): int { x + 1 }
  function B_k(x: int): int { x + 2 }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var p' := 1;
    var p_k := 2;
    var q := B'(p') + B_k(p_k);
    if A'(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
