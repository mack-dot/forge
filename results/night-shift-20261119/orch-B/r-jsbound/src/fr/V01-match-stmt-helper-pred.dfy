include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  predicate Approved(r: string) {
    r == "duplicate_charge" || r == "service_not_delivered" || r == "returned_item"
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var ok := ValidContext(context);
    match response {
      case Candidate(amount, reason) =>
        if ok && 0 <= amount <= context.remaining && Approved(reason) {
          decision := Authorized(amount, reason);
          plan := [Intent(context.chargeId, context.requestId, amount, reason)];
        } else {
          decision := Rejected;
          plan := [];
        }
      case _ =>
        decision := Rejected;
        plan := [];
    }
  }
}
