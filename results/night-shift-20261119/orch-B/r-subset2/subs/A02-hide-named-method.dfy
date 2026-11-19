include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method hide(n: int)
    decreases if n < 0 then 0 else n
  {
    if n > 0 { hide(n - 1); hide(n - 1); }
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    hide(context.original);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
