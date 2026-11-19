include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function hide(n: nat): nat
  {
    if n == 0 then 0 else var r := hide(n - 1); var t := hide(n - 1); r - t
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var z := hide(if context.original < 0 then 0 else context.original);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
