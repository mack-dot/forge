include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  datatype Bag = Bag(items: set<int>)

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var seen: set<int> := {0};
    var i := 1;
    while i < 1800
      invariant 1 <= i <= 1800
    {
      seen := seen + {i};
      i := i + 1;
    }
    var a := Bag(seen);
    var b := Bag(seen + {0});
    var same := 0;
    var j := 0;
    while j < 4000
      invariant 0 <= j <= 4000
    {
      if a == b { same := same + 1; }
      j := j + 1;
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
