include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Fib(s: seq<int>): bool
    decreases |s|
  {
    if |s| == 0 then true else Fib(s[1..]) && Fib(s[1..])
  }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var c := Fib([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
