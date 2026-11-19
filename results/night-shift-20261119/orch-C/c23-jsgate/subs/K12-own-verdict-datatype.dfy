include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  datatype Verdict = Approve(amount: int, reason: string) | Deny

  function Decide(context: Context, response: ModelResponse): Verdict {
    if Eligible(context, response) then Approve(response.amount, response.reason) else Deny
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var v := Decide(context, response);
    match v {
      case Approve(a, r) =>
        decision := Authorized(a, r);
        plan := [Intent(context.chargeId, context.requestId, a, r)];
      case Deny =>
        decision := Rejected;
        plan := [];
    }
  }
}
