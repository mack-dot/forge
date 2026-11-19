include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Weight(s: string): nat
    decreases |s|
  {
    if |s| == 0 then 1 else Weight(s[1..]) + Weight(s[1..])
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var w := 0;
    if response.Candidate? {
      w := Weight(response.reason);
    }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
