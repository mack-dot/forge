include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method M1(n: nat) returns (r: nat) decreases n, 1 { r := 0; if n > 0 { r := M2(n); } }
  method M2(n: nat) returns (r: nat) decreases n, 0 { r := M1(n - 1); }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var v := M1(3);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
