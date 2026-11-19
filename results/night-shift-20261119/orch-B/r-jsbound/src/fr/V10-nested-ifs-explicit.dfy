include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    decision := Rejected;
    plan := [];
    if context.refundEnabled && context.requestOpen && |context.chargeId| > 0 && |context.requestId| > 0 {
      if 0 <= context.remaining && context.remaining <= context.original && context.original <= MaxMoney {
        if response.Candidate? {
          var a := response.amount;
          var r := response.reason;
          if 0 <= a && a <= context.remaining &&
             (r == "duplicate_charge" || r == "service_not_delivered" || r == "returned_item") {
            decision := Authorized(a, r);
            plan := [Intent(context.chargeId, context.requestId, a, r)];
          }
        }
      }
    }
  }
}
