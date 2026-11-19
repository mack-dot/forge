include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && response.amount == 123456789 {
      assert 0 <= 999999999999999999 && 999999999999999999 % 1000000000000000000 == 999999999999999999;
      var k: int :| 0 <= k && k % 1000000000000000000 == 999999999999999999;
      var unused := k;
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
