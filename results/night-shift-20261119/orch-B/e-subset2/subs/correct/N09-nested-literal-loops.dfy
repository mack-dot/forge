include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var count := 0;
    var i := 0;
    while i < 3
      invariant 0 <= i <= 3
      invariant count == 2 * i
      decreases 3 - i
    {
      var j := 0;
      while j < 2
        invariant 0 <= j <= 2
        invariant count == 2 * i + j
        decreases 2 - j
      {
        count := count + 1;
        j := j + 1;
      }
      i := i + 1;
    }
    if count == 6 && Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
