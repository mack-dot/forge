include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const C := [0]

  method Spin(C: string) returns (n: int)
  {
    n := 0;
    for a := 0 to |C| {
      for b := 0 to |C| {
        for d := 0 to |C| {
          for e := 0 to |C| {
            for f := 0 to |C| {
              n := n + 1;
            }
          }
        }
      }
    }
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var spun := Spin(context.chargeId);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
