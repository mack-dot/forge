include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Walk(bs: seq<bool>) returns (n: nat)
    decreases |bs|
  {
    n := 0;
    for i := 0 to 2 {
      if |bs| > 0 { n := Walk(bs[1..]); }
    }
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var c := 0;
    for i := 0 to 3 {
      c := Walk([true, true]);
    }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
