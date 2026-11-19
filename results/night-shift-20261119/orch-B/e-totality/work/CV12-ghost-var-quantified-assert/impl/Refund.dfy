include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    ghost var before := Eligible(context, response);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
      assert forall i :: 0 <= i < |plan| ==> plan[i].chargeId == context.chargeId;
    } else {
      decision := Rejected;
      plan := [];
      assert forall x: RefundIntent :: x !in plan;
    }
    assert before == decision.Authorized?;
  }
}
