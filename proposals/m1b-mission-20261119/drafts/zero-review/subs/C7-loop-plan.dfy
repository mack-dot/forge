include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var n := if Eligible(context, response) then 1 else 0;
    plan := [];
    var i := 0;
    while i < n
      invariant 0 <= i <= n
      invariant |plan| == i
      invariant forall k :: 0 <= k < i ==> plan[k] == Intent(context.chargeId, context.requestId, response.amount, response.reason)
    {
      plan := plan + [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
      i := i + 1;
    }
    decision := if n == 1 then Authorized(response.amount, response.reason) else Rejected;
  }
}
