include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Check(context: Context, response: ModelResponse) returns (ok: bool, why: string)
    ensures ok == Eligible(context, response)
  {
    if !ValidContext(context) { return false, "context"; }
    if !response.Candidate? { return false, "shape"; }
    ok := Eligible(context, response);
    why := if ok then "" else "rule";
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var ok, why := Check(context, response);
    if ok {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
