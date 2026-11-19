// NEGATIVE CONTROL for the M1 conformance check (Wave Gate 1). A WRONG checker core.
// It accepts an intent whose amount is below the authorized amount.
// Found by the fresh-context review (finding R2): the first tamper list changed each value in one
// direction only and did not report this core. It is NOT verified (its contract text is the contract
// of the true core and does not hold). The EXIT script compiles it with --no-verify. The comparison
// MUST report it with the check F-TAMPER.
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

  // The transition that a token may carry: the approved relation makes the request eligible for this
  // charge, the post-state is the pre-state with `remaining` decreased by the amount, and the intent
  // is the caller-bound one.
  ghost predicate Authorizes(pre: Charge, t: Transition) {
    R.Eligible(ContextOf(pre, t.request.requestId), R.Candidate(t.request.amount, t.request.reason)) &&
    t.post == pre.(remaining := pre.remaining - t.request.amount) &&
    t.intent == R.Intent(pre.chargeId, t.request.requestId, t.request.amount, t.request.reason)
  }

  // No precondition: every charge, every hash text and every candidate transition is in the domain.
  method Check(pre: Charge, preStateHash: string, t: Transition)
      returns (verdict: Verdict, plan: seq<R.RefundIntent>)
    modifies {}
    // Safety: a token is issued only for an authorized transition.
    ensures verdict.Issue? ==> Authorizes(pre, t)
    // Exact acceptance: every authorized transition gets a token.
    ensures Authorizes(pre, t) ==> verdict.Issue?
    // Binding: the token holds exactly the given pre-state hash, the request id and the checked
    // post-state and intent.
    ensures verdict.Issue? ==>
      verdict.token == Token(preStateHash, t.request.requestId, t.post, t.intent)
    // No intent on refusal; exactly the checked intent on issue.
    ensures verdict.Refuse? ==> plan == []
    ensures verdict.Issue? ==> plan == [t.intent]
  {
    var decision, assessed := R.Assess(
      ContextOf(pre, t.request.requestId), R.Candidate(t.request.amount, t.request.reason));
    if decision.Authorized? && |assessed| == 1 &&
       t.post == pre.(remaining := pre.remaining - decision.amount) &&
       t.intent.chargeId == assessed[0].chargeId && t.intent.requestId == assessed[0].requestId &&
       t.intent.reason == assessed[0].reason && t.intent.amount <= assessed[0].amount {
      verdict := Issue(Token(preStateHash, t.request.requestId, t.post, t.intent));
      plan := [t.intent];
    } else {
      verdict := Refuse;
      plan := [];
    }
  }
}
