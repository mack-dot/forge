include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Grow(bs: seq<bool>): nat
    decreases |bs|
  {
    if |bs| == 0 then 0 else Grow(bs[1..] + [true])
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var c := Grow([true, true]);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
