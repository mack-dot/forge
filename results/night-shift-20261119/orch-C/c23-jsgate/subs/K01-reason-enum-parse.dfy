include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  datatype Reason = Duplicate | NotDelivered | Returned | Other

  function Parse(s: string): Reason {
    if s == "duplicate_charge" then Duplicate
    else if s == "service_not_delivered" then NotDelivered
    else if s == "returned_item" then Returned
    else Other
  }

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var ok := ValidContext(context) && response.Candidate? &&
      0 <= response.amount <= context.remaining && Parse(response.reason) != Other;
    if ok {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
