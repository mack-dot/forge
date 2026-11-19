include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  datatype Check = Check(is_Check: bool, amount: int)

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var c := Check(response.Candidate?, 0);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
