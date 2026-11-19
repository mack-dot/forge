include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Both(c: Context, r: ModelResponse): ((bool, int), string) {
    ((Eligible(c, r), if r.Candidate? then r.amount else 0), if r.Candidate? then r.reason else "")
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var b := Both(context, response);
    if b.0.0 {
      decision := Authorized(b.0.1, b.1);
      plan := [Intent(context.chargeId, context.requestId, b.0.1, b.1)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
