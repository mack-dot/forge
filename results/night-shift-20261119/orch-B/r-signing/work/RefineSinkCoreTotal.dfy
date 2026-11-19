// r-signing: can SinkCore ITSELF (not only its parent) take the total verifier body? The pinned-Dafny crash was
// reported for an EMPTY refinement body `module X refines SinkCore {}`. This one gives VerifyTag a body.
include "inputs/transport/sink/SinkCore.dfy"

module SinkCoreTotal refines SinkCore {
  ghost predicate VerifyTag(c: Claim, t: Tag)
  {
    t == "sig_" + c.req.requestId
  }

  lemma ReadingHolds()
    ensures forall c: Claim, t: Tag :: VerifyTag(c, t) <==> t == "sig_" + c.req.requestId
  {
  }

  // One run of the executable Step with A5 met and a commit.
  lemma OneCommit()
    ensures var tok := SinkToken(PINNED_SPEC, PINNED_CHK, F.Charge("ch_1", 100, 60, true), "rq_1",
                                 F.Charge("ch_1", 100, 20, true), R.Intent("ch_1", "rq_1", 40, "duplicate_charge"), "sig_rq_1");
            A5_VerifierMatches(tok, true) &&
            Step(Core(F.Charge("ch_1", 100, 60, true), {}, []), tok, true).out == Committed
  {
  }
}
