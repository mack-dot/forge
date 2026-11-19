// Slice 1 of the master idea (items F2.1 to F2.3): the checker core of the refund finality boundary.
// An untrusted proposer supplies a candidate transition. Check compares it with the APPROVED refund
// specification through the gate-verified Refund.Assess (impl/Refund.dfy). It returns the token payload
// to sign, or a refusal with no intent.
//
// NOT an approved specification. NOT gate evidence. The approved refund specification has no stored
// state. Three rules below are choices of this file and are not ratified intent:
//   1. the stored state of a charge is (chargeId, original, remaining, refundEnabled);
//   2. an authorized refund decreases `remaining` by the authorized amount and changes nothing else;
//   3. the request is taken as open. The sink, not this core, decides that a request id is fresh.
// The pre-state hash is an input. This core copies it into the token. It does not compute a hash.
include "Refund.dfy"

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
       t.intent == assessed[0] {
      verdict := Issue(Token(preStateHash, t.request.requestId, t.post, t.intent));
      plan := [t.intent];
    } else {
      verdict := Refuse;
      plan := [];
    }
  }
}
