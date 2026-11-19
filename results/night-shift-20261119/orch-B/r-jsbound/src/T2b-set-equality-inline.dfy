include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if |context.chargeId| == 3 {
      var a: set<int> := {};
      var b: set<int> := {};
      var i := 0;
      while i < 1000
        decreases 1000 - i
      {
        a := a + {i};
        b := b + {999 - i};
        i := i + 1;
      }
      var n := 0;
      var k := 0;
      while k < 2000
        decreases 2000 - k
      {
        if a == b {
          n := n + 1;
        }
        k := k + 1;
      }
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
