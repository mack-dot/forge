// NEGATIVE CONTROL for Slice 1. This core decides correctly, but Check prints and is marked {:print} (F1.2: the binding callers are not marked).
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

  method {:print} Check(pre: Charge, preStateHash: string, t: Transition)
      returns (verdict: Verdict, plan: seq<R.RefundIntent>)
    modifies {}
    ensures verdict.Issue? ==>
      R.Eligible(ContextOf(pre, t.request.requestId), R.Candidate(t.request.amount, t.request.reason)) &&
      t.post == pre.(remaining := pre.remaining - t.request.amount) &&
      t.intent == R.Intent(pre.chargeId, t.request.requestId, t.request.amount, t.request.reason)
    ensures R.Eligible(ContextOf(pre, t.request.requestId), R.Candidate(t.request.amount, t.request.reason)) &&
      t.post == pre.(remaining := pre.remaining - t.request.amount) &&
      t.intent == R.Intent(pre.chargeId, t.request.requestId, t.request.amount, t.request.reason)
      ==> verdict.Issue?
    ensures verdict.Issue? ==>
      verdict.token == Token(preStateHash, t.request.requestId, t.post, t.intent)
    ensures verdict.Refuse? ==> plan == []
    ensures verdict.Issue? ==> plan == [t.intent]
  {
    print "unrequested diagnostic\n";
    var decision, assessed := R.Assess(
      ContextOf(pre, t.request.requestId), R.Candidate(t.request.amount, t.request.reason));
    if decision.Authorized? && |assessed| == 1 &&
       t.post == pre.(remaining := pre.remaining - decision.amount) &&
       t.intent == assessed[0] {
      verdict := Issue(Token(preStateHash, t.request.requestId, t.post, t.intent));
      plan := [t.intent];
    } else {
      verdict := Refuse;
      plan := [];
    }
  }
}
