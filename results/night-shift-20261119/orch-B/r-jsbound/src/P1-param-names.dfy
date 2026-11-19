include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function F1(BigNumber: int): int { BigNumber + 2 }
  function F2(Refund: int): int { if Refund > 0 then Refund else 3 }
  function F4(require: int, process: int, globalThis: int): int { require + process + globalThis }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var k := F1(5) + F2(1) + F4(1, 2, 3);
    if Eligible(context, response) {
      decision := Authorized(response.amount, response.reason);
      plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
    } else {
      decision := Rejected;
      plan := [];
    }
  }
}
