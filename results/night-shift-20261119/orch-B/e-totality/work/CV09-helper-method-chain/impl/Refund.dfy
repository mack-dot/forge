include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method MakePlan(c: Context, a: int, why: string) returns (p: seq<RefundIntent>)
    ensures p == [Intent(c.chargeId, c.requestId, a, why)]
  {
    p := [Intent(c.chargeId, c.requestId, a, why)];
  }

  method Grant(c: Context, r: ModelResponse) returns (d: Decision, p: seq<RefundIntent>)
    requires Eligible(c, r)
    ensures d == Authorized(r.amount, r.reason)
    ensures p == [Intent(c.chargeId, c.requestId, r.amount, r.reason)]
  {
    d := Authorized(r.amount, r.reason);
    p := MakePlan(c, r.amount, r.reason);
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if Eligible(context, response) {
      decision, plan := Grant(context, response);
    } else {
      decision, plan := Rejected, [];
    }
  }
}
