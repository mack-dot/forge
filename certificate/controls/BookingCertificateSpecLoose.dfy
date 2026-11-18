// CONTROL for Slice 3 clearing. A PLANTED candidate specification of the certificate checker that is
// sound but leaves a choice: a token only for an accepted certificate, but the checker may refuse any
// proposal. The clearing tool must NOT answer NO_CHOICE for it. Not an approved specification.
include "../../proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy"

abstract module BookingCertificateSpecLoose {
  import C = BookingDualCert

  datatype Batch = Batch(A: seq<seq<int>>, c: seq<int>, w: seq<int>)
  datatype Proposal = Proposal(x: seq<int>, y: seq<int>, z: seq<int>, alphaBps: int)
  datatype Verdict = Refuse | Issue(x: seq<int>, alphaBps: int)

  predicate Accepts(batch: Batch, p: Proposal) {
    0 <= p.alphaBps && C.Accepts(batch.A, batch.c, batch.w, p.x, p.y, p.z, p.alphaBps)
  }

  method Decide(batch: Batch, p: Proposal) returns (verdict: Verdict)
    ensures verdict.Issue? ==> Accepts(batch, p) && verdict == Issue(p.x, p.alphaBps)
}
