include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function DecisionFor(context: Context, response: ModelResponse): Decision {
    if Eligible(context, response) then Authorized(response.amount, response.reason) else Rejected
  }
  function PlanFor(context: Context, d: Decision): seq<RefundIntent> {
    match d
    case Authorized(a, r) => [Intent(context.chargeId, context.requestId, a, r)]
    case Rejected => []
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := DecisionFor(context, response);
    plan := PlanFor(context, decision);
  }
}
