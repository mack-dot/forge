// Slice 3: the claims about the CANDIDATE specification of the certificate checker, for the clearing
// tool of Slice 2 (scripts/spec_clearing.py). NOT an approved specification. NOT gate evidence.
// Post is the postcondition of S.Decide as a predicate. DecideThenPost is the forward link: Dafny
// checks it against the specified method. Every claim below is about every refinement of the
// specification; the tool checks a non-abstract instance that is bound to impl/BookingCertificate.dfy.
include "BookingCertificateSpec.dfy"

abstract module BookingCertificateClearing {
  import S : BookingCertificateSpec
  import W = BookingDualCertWitness

  ghost predicate Post(batch: S.Batch, preStateHash: string, batchHash: string, requestId: string,
                       p: S.Proposal, verdict: S.Verdict)
  {
    (verdict.Issue? <==> S.Accepts(batch, p)) &&
    (verdict.Issue? ==>
      |p.x| == |batch.w| && S.C.Shape(batch.A, batch.c, |p.x|) &&
      verdict.token == S.Token(preStateHash, batchHash, requestId, p.x, p.alphaBps,
                               S.C.Dot(batch.w, p.x), S.Remaining(batch, p.x)))
  }

  // Forward link: the result of the specified method satisfies Post.
  method DecideThenPost(batch: S.Batch, preStateHash: string, batchHash: string, requestId: string, p: S.Proposal)
      returns (verdict: S.Verdict)
    ensures Post(batch, preStateHash, batchHash, requestId, p, verdict)
  {
    verdict := S.Decide(batch, preStateHash, batchHash, requestId, p);
  }

  // Two-run lemma: Post allows at most one verdict.
  lemma SpecIsDeterministic(batch: S.Batch, preStateHash: string, batchHash: string, requestId: string,
                            p: S.Proposal, v1: S.Verdict, v2: S.Verdict)
    requires Post(batch, preStateHash, batchHash, requestId, p, v1)
    requires Post(batch, preStateHash, batchHash, requestId, p, v2)
    ensures v1 == v2
  {
  }

  // Post is not weaker than the specification: every verdict that satisfies Post IS the returned one.
  method PostIsExact(batch: S.Batch, preStateHash: string, batchHash: string, requestId: string,
                     p: S.Proposal, verdict: S.Verdict)
    requires Post(batch, preStateHash, batchHash, requestId, p, verdict)
  {
    var returned := DecideThenPost(batch, preStateHash, batchHash, requestId, p);
    SpecIsDeterministic(batch, preStateHash, batchHash, requestId, p, verdict, returned);
    assert verdict == returned;
  }

  // Q1 safety. A token is only for an allocation that is 0/1 and uses no slot above its capacity.
  // No capacity that remains is negative, and the token holds exactly those capacities.
  lemma IssueIsFeasible(batch: S.Batch, preStateHash: string, batchHash: string, requestId: string,
                        p: S.Proposal, verdict: S.Verdict)
    requires Post(batch, preStateHash, batchHash, requestId, p, verdict) && verdict.Issue?
    ensures |p.x| == |batch.w| && S.C.Shape(batch.A, batch.c, |p.x|) && S.C.Feasible(batch.A, batch.c, p.x)
    ensures |verdict.token.remaining| == |batch.c|
    ensures forall i | 0 <= i < |batch.c| ::
      verdict.token.remaining[i] == batch.c[i] - S.C.Dot(batch.A[i], p.x) && 0 <= verdict.token.remaining[i]
  {
  }

  // Q2 quality. The value of the allocation of a token is within the stated gap of the value of EVERY
  // feasible allocation: (10000 - alphaBps) * value(alt) <= 10000 * value(x). With alphaBps == 0 the
  // allocation is a global optimum of the integer problem. The proof is weak duality (Rounds 2 and 3).
  lemma IssueIsNearOptimal(batch: S.Batch, preStateHash: string, batchHash: string, requestId: string,
                           p: S.Proposal, verdict: S.Verdict, alt: seq<int>)
    requires Post(batch, preStateHash, batchHash, requestId, p, verdict) && verdict.Issue?
    requires |alt| == |batch.w| && S.C.Shape(batch.A, batch.c, |alt|) && S.C.Feasible(batch.A, batch.c, alt)
    ensures 0 <= p.alphaBps <= 10000 && |p.x| == |batch.w|
    ensures (10000 - p.alphaBps) * S.C.Dot(batch.w, alt) <= 10000 * S.C.Dot(batch.w, p.x)
  {
    S.C.Quality(batch.A, batch.c, batch.w, p.x, p.y, p.z, p.alphaBps, alt);
  }

  // Q3 binding. A token holds exactly the two given hash texts, the request id, the checked
  // allocation, the stated gap and the value of that allocation.
  lemma IssueBindsTheToken(batch: S.Batch, preStateHash: string, batchHash: string, requestId: string,
                           p: S.Proposal, verdict: S.Verdict)
    requires Post(batch, preStateHash, batchHash, requestId, p, verdict) && verdict.Issue?
    ensures verdict.token.preStateHash == preStateHash && verdict.token.batchHash == batchHash
    ensures verdict.token.requestId == requestId && verdict.token.x == p.x
    ensures verdict.token.alphaBps == p.alphaBps && 0 <= verdict.token.alphaBps <= 10000
    ensures |p.x| == |batch.w| && verdict.token.value == S.C.Dot(batch.w, p.x)
  {
  }

  // The specification is not vacuous. One instance with a real conflict (Round 1 witness): two slots of
  // capacity 1; request 0 (value 3) needs both; requests 1 and 2 (value 2 each) need one slot each.
  lemma WitnessValues()
    ensures S.C.Shape(W.A0, W.C0, 3)
    ensures S.C.Dot(W.W0, [0, 1, 1]) == 4 && S.C.Dot(W.W0, [1, 0, 0]) == 3
    ensures S.Remaining(S.Batch(W.A0, W.C0, W.W0), [0, 1, 1]) == [0, 0]
    ensures S.Remaining(S.Batch(W.A0, W.C0, W.W0), [1, 0, 0]) == [0, 0]
  {
    assert W.A0[0] == [1, 1, 0] && W.A0[1] == [1, 0, 1] && W.C0 == [1, 1] && W.W0 == [3, 2, 2];
    assert S.C.Dot([3, 2, 2], [0, 1, 1]) == 4;
    assert S.C.Dot([3, 2, 2], [1, 0, 0]) == 3;
    assert S.C.Dot([1, 1, 0], [0, 1, 1]) == 1 && S.C.Dot([1, 0, 1], [0, 1, 1]) == 1;
    assert S.C.Dot([1, 1, 0], [1, 0, 0]) == 1 && S.C.Dot([1, 0, 1], [1, 0, 0]) == 1;
    var first := S.Remaining(S.Batch(W.A0, W.C0, W.W0), [0, 1, 1]);
    assert |first| == 2 && first[0] == 0 && first[1] == 0;
    var second := S.Remaining(S.Batch(W.A0, W.C0, W.W0), [1, 0, 0]);
    assert |second| == 2 && second[0] == 0 && second[1] == 0;
  }

  // The optimum with a zero-gap certificate gets a token. A suboptimal allocation (value 3 of 4) gets a
  // token at the gap 2500 (basis points).
  lemma IssueWitnesses()
    ensures Post(S.Batch(W.A0, W.C0, W.W0), "state", "batch", "rq_1", S.Proposal([0, 1, 1], [2, 2], [0, 0, 0], 0),
                 S.Issue(S.Token("state", "batch", "rq_1", [0, 1, 1], 0, 4, [0, 0])))
    ensures Post(S.Batch(W.A0, W.C0, W.W0), "state", "batch", "rq_1", S.Proposal([1, 0, 0], [2, 2], [0, 0, 0], 2500),
                 S.Issue(S.Token("state", "batch", "rq_1", [1, 0, 0], 2500, 3, [0, 0])))
  {
    W.OptimumAcceptedWithZeroGap();
    W.SuboptimalRejectedAtZeroGapAcceptedAtQuarterGap();
    WitnessValues();
  }

  // Refusals: an overbooked allocation (also with the largest gap); dual values that are too small (a
  // forged certificate for the optimum); the suboptimal allocation at the gaps 0 and 2499; a gap below 0.
  lemma RefuseWitnesses()
    ensures Post(S.Batch(W.A0, W.C0, W.W0), "state", "batch", "rq_1", S.Proposal([1, 1, 0], [2, 2], [0, 0, 0], 10000),
                 S.Refuse)
    ensures Post(S.Batch(W.A0, W.C0, W.W0), "state", "batch", "rq_1", S.Proposal([0, 1, 1], [1, 1], [0, 0, 0], 0),
                 S.Refuse)
    ensures Post(S.Batch(W.A0, W.C0, W.W0), "state", "batch", "rq_1", S.Proposal([1, 0, 0], [2, 2], [0, 0, 0], 0),
                 S.Refuse)
    ensures Post(S.Batch(W.A0, W.C0, W.W0), "state", "batch", "rq_1", S.Proposal([1, 0, 0], [2, 2], [0, 0, 0], 2499),
                 S.Refuse)
    ensures Post(S.Batch(W.A0, W.C0, W.W0), "state", "batch", "rq_1", S.Proposal([0, 1, 1], [2, 2], [0, 0, 0], -1),
                 S.Refuse)
  {
    W.OverbookingRejected();
    W.InvalidDualRejected();
    W.SuboptimalRejectedAtZeroGapAcceptedAtQuarterGap();
  }
}
