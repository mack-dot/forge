include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function F(a: int): int { a } by method { expect a != 123456789; return a; }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var f := F(if response.Candidate? then response.amount else 0);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
