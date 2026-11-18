// CONTROL for Slice 3 clearing: the two-run lemma for the PLANTED loose specification. The pinned
// Dafny must reject SpecIsDeterministic (Post allows a token and a refusal for one accepted proposal).
include "BookingCertificateSpecLoose.dfy"

abstract module BookingCertificateLooseClearing {
  import S : BookingCertificateSpecLoose

  ghost predicate Post(batch: S.Batch, p: S.Proposal, verdict: S.Verdict) {
    verdict.Issue? ==> S.Accepts(batch, p) && verdict == S.Issue(p.x, p.alphaBps)
  }

  method DecideThenPost(batch: S.Batch, p: S.Proposal) returns (verdict: S.Verdict)
    ensures Post(batch, p, verdict)
  {
    verdict := S.Decide(batch, p);
  }

  lemma SpecIsDeterministic(batch: S.Batch, p: S.Proposal, v1: S.Verdict, v2: S.Verdict)
    requires Post(batch, p, v1)
    requires Post(batch, p, v2)
    ensures v1 == v2
  {
  }
}
