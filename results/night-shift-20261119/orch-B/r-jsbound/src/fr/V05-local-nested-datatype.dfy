include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  datatype Grant = Grant(amount: int, reason: string)
  datatype Verdict = Approve(g: Grant) | Deny
  function Judge(context: Context, response: ModelResponse): Verdict {
    if Eligible(context, response) then Approve(Grant(response.amount, response.reason)) else Deny
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var v := Judge(context, response);
    match v {
      case Approve(Grant(a, r)) =>
        decision := Authorized(a, r);
        plan := [Intent(context.chargeId, context.requestId, a, r)];
      case Deny =>
        decision := Rejected;
        plan := [];
    }
  }
}
