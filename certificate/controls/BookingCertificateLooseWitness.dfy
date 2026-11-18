// CONTROL for Slice 3 clearing: two refinements of the PLANTED loose specification that return
// different verdicts for one proposal (the optimum of the Round 1 instance with its zero-gap
// certificate). Both MUST verify. LooseRefusesAll is a fixture, never accepted code.
include "BookingCertificateSpecLoose.dfy"

module LooseExact refines BookingCertificateSpecLoose {
  function Result(batch: Batch, p: Proposal): Verdict {
    if Accepts(batch, p) then Issue(p.x, p.alphaBps) else Refuse
  }

  method Decide(batch: Batch, p: Proposal) returns (verdict: Verdict)
    ensures verdict == Result(batch, p)
  {
    verdict := Result(batch, p);
  }
}

module LooseRefusesAll refines BookingCertificateSpecLoose {
  function Result(batch: Batch, p: Proposal): Verdict {
    Refuse
  }

  method Decide(batch: Batch, p: Proposal) returns (verdict: Verdict)
    ensures verdict == Result(batch, p)
  {
    verdict := Result(batch, p);
  }
}

module LooseWitness {
  import E = LooseExact
  import R = LooseRefusesAll
  import W = BookingDualCertWitness

  lemma TwoAllowedVerdictsDiffer()
    ensures E.Result(E.Batch(W.A0, W.C0, W.W0), E.Proposal([0, 1, 1], [2, 2], [0, 0, 0], 0)) == E.Issue([0, 1, 1], 0)
    ensures R.Result(R.Batch(W.A0, W.C0, W.W0), R.Proposal([0, 1, 1], [2, 2], [0, 0, 0], 0)) == R.Refuse
  {
    W.OptimumAcceptedWithZeroGap();
  }
}
