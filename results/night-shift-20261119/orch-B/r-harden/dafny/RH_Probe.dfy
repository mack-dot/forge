// r-harden probes (copies; not part of the tree). Each method is a witness that MUST verify, unless marked MUSTFAIL.
include "IssueOnce.dfy"
module RHProbe {
  import opened IssueOnce
  import IB = IssueBytes2
  import SM = SerModel
  import F = RefundFinality

  // W1: a REFUSED attempt does not close the pair. Same (charge id, request id): first 61 (> remaining 60) is
  // refused by the core, then 40 with the SAME request id is Issued. protocol.md:61-62 says rejection closes the attempt.
  method RefuseThenIssue() returns (a: Outcome, b: Outcome)
    ensures a.RefusedByCore? && b.Issued?
    ensures KeyOf(W_PRE, IB.T(W_PRE, "rq_x", 61)) == KeyOf(W_PRE, IB.T(W_PRE, "rq_x", 40))
  {
    var m: Memory := map[];
    var m1: Memory, m2: Memory;
    m1, a := Issue(m, W_PRE, IB.T(W_PRE, "rq_x", 61), SM.ZERO64, SM.ZERO64, IB.HEXA);
    IssuableT("rq_x", 40);
    m2, b := NoFreeze(m1, W_PRE, IB.T(W_PRE, "rq_x", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // W2: RunSeq's postconditions are met by a reject-all loop (they are safety only; no liveness over a sequence).
  method RunSeqRejectAll(m0: Memory, calls: seq<Call>) returns (m: Memory, outs: seq<Outcome>)
    ensures |outs| == |calls|
    ensures Extends(m0, m)
    ensures forall i, j | 0 <= i < |calls| && 0 <= j < |calls| ::
              KeyOfCall(calls[i]) == KeyOfCall(calls[j]) && outs[i].Signs() && outs[j].Signs() ==>
              outs[i].bytes == outs[j].bytes
    ensures forall i | 0 <= i < |calls| ::
              outs[i].Signs() && KeyOfCall(calls[i]) in m0 ==> outs[i].bytes == m0[KeyOfCall(calls[i])]
    ensures forall i | 0 <= i < |calls| :: SignsAuthorized(calls[i], outs[i])
  {
    m := m0; outs := seq(|calls|, _ => RefusedByCore);
    forall i | 0 <= i < |calls| ensures SignsAuthorized(calls[i], outs[i]) { reveal SignsAuthorized(); }
  }

  // W3: retry against a NEWER pre-state (after the sink committed rq_9 for 40) is refused (by design).
  method RetryAfterCommit() returns (a: Outcome, b: Outcome)
    ensures a.Issued? && !b.Signs()
  {
    IssuableT("rq_9", 40);
    var m1: Memory, m2: Memory;
    m1, a := NoFreeze(map[], W_PRE, IB.T(W_PRE, "rq_9", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
    var post := W_PRE.(remaining := 20);
    m2, b := Issue(m1, post, IB.T(post, "rq_9", 10), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // MUSTFAIL V1: environment consistency. If this verifies, the context is inconsistent.
  method VacEnv() { var a, b, c := ZeroZeroPositive(); assert false; }
  // MUSTFAIL V2: OtherCandidate's requires is not contradictory.
  method VacOther(pre1: F.Charge, t1: F.Transition, pre2: F.Charge, t2: F.Transition, sh: string, ch: string, h1: string, h2: string)
    requires KeyOf(pre1, t1) == KeyOf(pre2, t2)
    requires IB.BodyFor(sh, ch, h1, t1) != IB.BodyFor(sh, ch, h2, t2)
  { assert false; }
  // MUSTFAIL V3: NoFreeze's requires is not contradictory.
  method VacNoFreeze(m: Memory, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
    requires KeyOf(pre, t) !in m && Issuable(pre, t, sh, ch, h)
  { assert false; }
}
