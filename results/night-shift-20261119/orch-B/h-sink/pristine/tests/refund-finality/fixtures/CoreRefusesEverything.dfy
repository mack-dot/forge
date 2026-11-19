// NEGATIVE CONTROL for Slice 1. This core refuses every candidate transition. Safety holds; exact acceptance does not.
// Verified beside tests/refund-finality/Bindings.dfy. The pinned Dafny MUST reject it.
// A rejection means "could not be proved". It is not a proof that this core is unsafe.
include "../../../impl/Refund.dfy"

module RefundFinality {
  import R = Refund

  datatype Charge = Charge(chargeId: string, original: int, remaining: int, refundEnabled: bool)
  datatype Request = Request(requestId: string, amount: int, reason: string)
  datatype Transition = Transition(request: Request, post: Charge, intent: R.RefundIntent)
  datatype Token = Token(preStateHash: string, requestId: string, post: Charge, intent: R.RefundIntent)
  datatype Verdict = Refuse | Issue(token: Token)

  function ContextOf(pre: Charge, requestId: string): R.Context {
    R.ChargeContext(pre.chargeId, requestId, pre.original, pre.remaining, pre.refundEnabled, true)
  }

  method Check(pre: Charge, preStateHash: string, t: Transition)
      returns (verdict: Verdict, plan: seq<R.RefundIntent>)
    modifies {}
    ensures verdict == Refuse && plan == []
  {
    verdict := Refuse;
    plan := [];
  }
}
