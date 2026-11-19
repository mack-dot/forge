include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Count(s: string): nat
    decreases |s|
  {
    if |s| == 0 then 0 else 1 + Count(s[1..])
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var c := if response.Candidate? then Count(response.reason) else 0;
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
