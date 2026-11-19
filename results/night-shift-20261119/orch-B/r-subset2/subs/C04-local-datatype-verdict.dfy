include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  datatype Verdict = Ok | Bad

  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var v := if Eligible(context, response) then Ok else Bad;
    if v == Ok {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
