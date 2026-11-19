include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Decide(context: Context, response: ModelResponse): Decision {
    match response
    case Candidate(a, r) => if Eligible(context, response) then Authorized(a, r) else Rejected
    case _ => Rejected
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Decide(context, response);
    plan := if decision.Authorized?
      then [Intent(context.chargeId, context.requestId, decision.amount, decision.reason)]
      else [];
  }
}
