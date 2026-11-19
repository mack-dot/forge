include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Rejected;
    plan := [];
    if context.chargeId == "" { return; }
    if context.requestId == "" { return; }
    if !context.refundEnabled { return; }
    if !context.requestOpen { return; }
    if context.original < 0 || context.original > MaxMoney { return; }
    if context.remaining < 0 || context.remaining > context.original { return; }
    match response {
      case Candidate(a, r) =>
        if a < 0 { return; }
        if a > context.remaining { return; }
        if r != "duplicate_charge" && r != "service_not_delivered" && r != "returned_item" { return; }
        decision := Authorized(a, r);
        plan := [Intent(context.chargeId, context.requestId, a, r)];
      case _ => return;
    }
  }
}
