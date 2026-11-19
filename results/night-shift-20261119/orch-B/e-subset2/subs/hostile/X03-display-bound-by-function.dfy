include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Make(): seq<int> { [1, 2, 3] }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var i := 0;
    while i < |Make()| { i := i + 1; }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
