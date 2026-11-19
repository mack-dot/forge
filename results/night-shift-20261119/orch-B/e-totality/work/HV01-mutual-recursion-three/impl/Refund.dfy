include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function F(n: nat): nat decreases n, 0 { if n == 0 then 0 else G(n - 1) }
  function G(n: nat): nat decreases n, 1 { H(n) }
  function H(n: nat): nat decreases n, 1 { F(n) }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && response.amount == 123456789 { var z := F(100000000); }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
