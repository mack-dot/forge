include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Down(s: seq<bool>, n: nat): nat
    decreases n
  {
    if n == 0 then 0 else 1 + Down(s, n - 1)
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var c := if response.Candidate? && response.amount >= 0 then Down([true], response.amount) else 0;
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
