include "../spec/refund/RefundSpec.dfy"

module Refund refines RefundSpec {
  function Default(): int { 1 }
  function dtor_amount(dtor_reason: int): int { dtor_reason + 1 }
  predicate is_Candidate(x: int) { x == 2 }
  function of(x: int): int { x + 3 }
  function Tuple(x: int): int { x + 4 }
  function a_(x: int): int { x + 5 }
  function create_Rejected(x: int): int { x + 6 }
  method Assess(context: Context, response: ModelResponse)
      returns (decision: Decision, plan: seq<RefundIntent>)
  {
    var source0 := Default();
    var Lmatch0 := dtor_amount(source0);
    var p' := of(Lmatch0);
    var p_k := Tuple(p');
    var a := a_(p_k) + create_Rejected(0);
    match (response, a) {
      case (Candidate(_, _), 20) =>
        if Eligible(context, response) && is_Candidate(Lmatch0) {
          decision := Authorized(response.amount, response.reason);
          plan := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];
          return;
        }
      case _ =>
    }
    decision := Rejected;
    plan := [];
  }
}
