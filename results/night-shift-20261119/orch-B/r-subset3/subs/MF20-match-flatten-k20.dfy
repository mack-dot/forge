include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var y := 0;
    match (context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original, context.original) {
      case (_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, 0) => y := 1;
      case (_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, 0, _) => y := 2;
      case (_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, 0, _, _) => y := 3;
      case (_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, 0, _, _, _) => y := 4;
      case (_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, 0, _, _, _, _) => y := 5;
      case (_, _, _, _, _, _, _, _, _, _, _, _, _, _, 0, _, _, _, _, _) => y := 6;
      case (_, _, _, _, _, _, _, _, _, _, _, _, _, 0, _, _, _, _, _, _) => y := 7;
      case (_, _, _, _, _, _, _, _, _, _, _, _, 0, _, _, _, _, _, _, _) => y := 8;
      case (_, _, _, _, _, _, _, _, _, _, _, 0, _, _, _, _, _, _, _, _) => y := 9;
      case (_, _, _, _, _, _, _, _, _, _, 0, _, _, _, _, _, _, _, _, _) => y := 10;
      case (_, _, _, _, _, _, _, _, _, 0, _, _, _, _, _, _, _, _, _, _) => y := 11;
      case (_, _, _, _, _, _, _, _, 0, _, _, _, _, _, _, _, _, _, _, _) => y := 12;
      case (_, _, _, _, _, _, _, 0, _, _, _, _, _, _, _, _, _, _, _, _) => y := 13;
      case (_, _, _, _, _, _, 0, _, _, _, _, _, _, _, _, _, _, _, _, _) => y := 14;
      case (_, _, _, _, _, 0, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => y := 15;
      case (_, _, _, _, 0, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => y := 16;
      case (_, _, _, 0, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => y := 17;
      case (_, _, 0, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => y := 18;
      case (_, 0, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => y := 19;
      case (0, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => y := 20;
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
