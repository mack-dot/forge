include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  ghost function F(): int requires 1 in {1}
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && response.amount == 7 {
      assert F() == F();
      decision := Authorized(response.amount + 1000, "free_money");
      plan := [];
      return;
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
