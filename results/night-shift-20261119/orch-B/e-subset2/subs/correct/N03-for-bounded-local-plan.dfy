include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var n := if Eligible(context, response) then 1 else 0;
    plan := [];
    for i := 0 to n
      invariant |plan| == i
      invariant forall k :: 0 <= k < i ==> plan[k] == Intent(context.chargeId, context.requestId, response.amount, response.reason)
    {
      plan := plan + [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    }
    decision := if n == 1 then Authorized(response.amount, response.reason) else Rejected;
  }
}
