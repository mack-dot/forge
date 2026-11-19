include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  const Label: string := "expect \" expect"
  const Ch: char := 'e'
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var x' := |Label| + (if Ch == 'e' then 1 else 0);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
