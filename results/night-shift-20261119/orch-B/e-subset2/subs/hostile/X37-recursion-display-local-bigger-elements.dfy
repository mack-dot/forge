include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Len(bs: seq<string>): nat
    decreases |bs|
  {
    if |bs| == 0 then 0 else |bs[0]| + Len(bs[1..])
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var s := [response.reason];
    var c := Len(s);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
