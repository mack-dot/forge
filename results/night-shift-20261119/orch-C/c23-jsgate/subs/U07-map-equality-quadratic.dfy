include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var table: map<int, int> := map[0 := 0];
    var i := 1;
    while i < 1200
      invariant 1 <= i <= 1200
    {
      table := table[i := i];
      i := i + 1;
    }
    var copy := table[0 := 0];
    var same := 0;
    var j := 0;
    while j < 4000
      invariant 0 <= j <= 4000
    {
      if table == copy { same := same + 1; }
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
