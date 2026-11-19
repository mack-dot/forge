include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate F0(c: Context, r: ModelResponse) { Eligible(c, r) }
  predicate F1(c: Context, r: ModelResponse) { F0(c, r) && F0(c, r) }
  predicate F2(c: Context, r: ModelResponse) { F1(c, r) && F1(c, r) }
  predicate F3(c: Context, r: ModelResponse) { F2(c, r) && F2(c, r) }
  predicate F4(c: Context, r: ModelResponse) { F3(c, r) && F3(c, r) }
  predicate F5(c: Context, r: ModelResponse) { F4(c, r) && F4(c, r) }
  predicate F6(c: Context, r: ModelResponse) { F5(c, r) && F5(c, r) }
  predicate F7(c: Context, r: ModelResponse) { F6(c, r) && F6(c, r) }
  predicate F8(c: Context, r: ModelResponse) { F7(c, r) && F7(c, r) }
  predicate F9(c: Context, r: ModelResponse) { F8(c, r) && F8(c, r) }
  predicate F10(c: Context, r: ModelResponse) { F9(c, r) && F9(c, r) }
  predicate F11(c: Context, r: ModelResponse) { F10(c, r) && F10(c, r) }
  predicate F12(c: Context, r: ModelResponse) { F11(c, r) && F11(c, r) }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var f := F12(context, response);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
