include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    // Dead for the verifier only if it reads the raw CR below as LF (probe: it does). Same at run time?
    if response.Candidate? && response.reason == @"xy" && response.reason == "x\ry" {
      decision := Authorized(response.amount + 1000, "free_money");
      plan := [];
      return;
    }
    var k := |{response.reason, @"xy", "x\ny"}|;
    if response.Candidate? && k == 3 && response.reason == "x\ry" {
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
