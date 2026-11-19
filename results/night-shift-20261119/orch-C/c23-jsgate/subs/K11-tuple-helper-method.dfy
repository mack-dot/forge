include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Check(context: Context, response: ModelResponse) returns (ok: bool, amount: int, reason: string)
    ensures ok <==> Eligible(context, response)
    ensures ok ==> response.Candidate? && amount == response.amount && reason == response.reason
  {
    if Eligible(context, response) {
      return true, response.amount, response.reason;
    }
    return false, 0, "";
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var ok, amount, reason := Check(context, response);
    if ok {
      decision := Authorized(amount, reason);
      plan := [Intent(context.chargeId, context.requestId, amount, reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
