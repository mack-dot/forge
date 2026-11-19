include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  lemma CountToThree()
    ensures true
  {
    var i := 0;
    while i < 3
      invariant 0 <= i <= 3
      decreases 3 - i
    {
      i := i + 1;
    }
    assert i == 3;  // v2: run 1 had a trigger-less quantifier (warning = exit 2)
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    CountToThree();
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
