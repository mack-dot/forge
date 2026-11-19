include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var count := 0;
    var i := 0;
    while i < 2000
      invariant 0 <= i <= 2000
    {
      var j := 0;
      while j < 2000
        invariant 0 <= j <= 2000
      {
        var k := 0;
        while k < 2000
          invariant 0 <= k <= 2000
        {
          count := count + 1;
          k := k + 1;
        }
        j := j + 1;
      }
      i := i + 1;
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
