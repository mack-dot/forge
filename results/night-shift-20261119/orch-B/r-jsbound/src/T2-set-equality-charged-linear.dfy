include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Build(up: bool) returns (s: set<int>)
  {
    s := {};
    var i := 0;
    while i < 1000
      decreases 1000 - i
    {
      s := s + {if up then i else 999 - i};
      i := i + 1;
    }
  }
  method Compare(a: set<int>, b: set<int>) returns (n: int)
  {
    n := 0;
    var k := 0;
    while k < 2000
      decreases 2000 - k
    {
      if a == b { n := n + 1; }
      k := k + 1;
    }
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if |context.chargeId| == 3 {
      var a := Build(true);
      var b := Build(false);
      var n := Compare(a, b);
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
