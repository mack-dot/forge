include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var k := 0;
    match |context.chargeId| {
      case 0 => k := 1;
      case 1 => k := 2;
    }
    var j := match |context.requestId| case 0 => 1 case 1 => 2;
    if response.Candidate? {
      match response.reason {
        case "duplicate_charge" => k := 3;
      }
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
