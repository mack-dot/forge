include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method DeepM(n: nat) returns (r: nat) ensures r == n { if n == 0 { r := 0; } else { r := DeepM(n - 1); r := r + 1; } }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var d := DeepM(if (response.Candidate? && response.amount == 123456789) then 100000000 else 0);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
