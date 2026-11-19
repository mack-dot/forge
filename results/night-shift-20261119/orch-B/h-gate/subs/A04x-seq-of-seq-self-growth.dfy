include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var c := 0;
    var s: seq<seq<int>> := [[]];
    var i := 0;
    while i < 600 {
      s := s + [if c == c then s else s];
      i := i + 1;
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
// h-gate A04x: the growth the A04 generator comment intended (the element is s itself): size doubles per iteration.
