include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var x := if response.Candidate? && response.amount == 123456789 then 0 else if response.Candidate? && response.amount == 123456789 then 1 else if response.Candidate? && response.amount == 123456789 then 2 else if response.Candidate? && response.amount == 123456789 then 3 else if response.Candidate? && response.amount == 123456789 then 4 else if response.Candidate? && response.amount == 123456789 then 5 else if response.Candidate? && response.amount == 123456789 then 6 else if response.Candidate? && response.amount == 123456789 then 7 else if response.Candidate? && response.amount == 123456789 then 8 else if response.Candidate? && response.amount == 123456789 then 9 else if response.Candidate? && response.amount == 123456789 then 10 else if response.Candidate? && response.amount == 123456789 then 11 else if response.Candidate? && response.amount == 123456789 then 12 else if response.Candidate? && response.amount == 123456789 then 13 else if response.Candidate? && response.amount == 123456789 then 14 else if response.Candidate? && response.amount == 123456789 then 15 else if response.Candidate? && response.amount == 123456789 then 16 else if response.Candidate? && response.amount == 123456789 then 17 else if response.Candidate? && response.amount == 123456789 then 18 else if response.Candidate? && response.amount == 123456789 then 19 else if response.Candidate? && response.amount == 123456789 then 20 else if response.Candidate? && response.amount == 123456789 then 21 else if response.Candidate? && response.amount == 123456789 then 22 else if response.Candidate? && response.amount == 123456789 then 23 else if response.Candidate? && response.amount == 123456789 then 24 else if response.Candidate? && response.amount == 123456789 then 25 else if response.Candidate? && response.amount == 123456789 then 26 else if response.Candidate? && response.amount == 123456789 then 27 else if response.Candidate? && response.amount == 123456789 then 28 else if response.Candidate? && response.amount == 123456789 then 29 else if response.Candidate? && response.amount == 123456789 then 30 else if response.Candidate? && response.amount == 123456789 then 31 else if response.Candidate? && response.amount == 123456789 then 32 else if response.Candidate? && response.amount == 123456789 then 33 else if response.Candidate? && response.amount == 123456789 then 34 else if response.Candidate? && response.amount == 123456789 then 35 else if response.Candidate? && response.amount == 123456789 then 36 else if response.Candidate? && response.amount == 123456789 then 37 else if response.Candidate? && response.amount == 123456789 then 38 else if response.Candidate? && response.amount == 123456789 then 39 else 0;
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
