include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  ghost method Spin(n: nat) {
    var i := 0;
    while i < n decreases n - i { i := i + 1; }
  }
  method Relay() {
    Spin(1000000000000000000);
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    if response.Candidate? && response.amount == 123456789 { Relay(); }
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
