include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var y := 0;
    match (context.original, context.original, context.original, context.original) {
      case (_, _, _, 0) => y := 1;
      case (_, _, 0, _) => y := 2;
      case (_, 0, _, _) => y := 3;
      case (0, _, _, _) => y := 4;
      case _ => y := 0;
    }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
