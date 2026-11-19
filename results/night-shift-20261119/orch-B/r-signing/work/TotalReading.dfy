// Night shift 2026-11-19, Orchestrator B, task b-signing. A DRAFT. NOT gate evidence. Dafny model only.
// Purpose: show INSIDE Dafny that the reading SigReading of SliceWitnessV2 is realizable. This module refines the
// abstract FinalityProtocol (byte-equal copy) with the SAME types and the SAME SpecRel as SinkCore, and gives
// VerifyTag a concrete TOTAL body: t == SigFn(c). In this instance: every claim has a verifying tag; the global
// IdealMac is false in every state; under the step-local premise a signed claim commits, the invariant holds, and
// a forged pair is rejected. (Refining SinkCore itself crashes the pinned Dafny 4.11.0; this module refines its
// parent.) No assume, no axiom, no bodiless lemma of this file.
include "inputs/transport/model/FinalityProtocol.dfy"
include "inputs/transport/impl/RefundFinality.dfy"

module TotalReading refines FinalityProtocol {
  import F = RefundFinality
  import R = Refund

  type State = F.Charge
  type Request = F.Request
  type Effect = R.RefundIntent
  type Tag = string

  ghost const SPEC: int := 1
  ghost const CHK: int := 2

  ghost predicate SpecRel(pre: State, req: Request, post: State, eff: Effect)
  {
    F.Authorizes(pre, F.Transition(req, post, eff))
  }

  function SigFn(c: Claim): Tag { "sig_" + c.req.requestId }

  // The concrete, TOTAL verifier.
  ghost predicate VerifyTag(c: Claim, t: Tag)
  {
    t == SigFn(c)
  }

  ghost predicate HasTag(c: Claim) { exists t: Tag :: VerifyTag(c, t) }

  lemma ReadingHolds()
    ensures forall c: Claim, t: Tag :: VerifyTag(c, t) <==> t == SigFn(c)
  {
  }

  lemma Total()
    ensures forall c: Claim :: HasTag(c)
  {
    forall c: Claim
      ensures HasTag(c)
    {
      assert VerifyTag(c, SigFn(c));
    }
  }

  lemma Bound(xs: set<int>) returns (m: int)
    ensures forall x | x in xs :: x < m
    decreases |xs|
  {
    if xs == {} {
      m := 0;
    } else {
      var x :| x in xs;
      var m0 := Bound(xs - {x});
      m := if m0 > x + 1 then m0 else x + 1;
      forall y | y in xs
        ensures y < m
      {
        if y != x {
          assert y in xs - {x};
        }
      }
    }
  }

  lemma NoIdealMac(s: System)
    ensures !IdealMac(s)
  {
    var ids := set p | p in s.minted :: p.0.reqId;
    var m := Bound(ids);
    var ch := F.Charge("", 0, 0, false);
    var c := Claim(0, 0, ch, m, F.Request("", 0, ""), ch, R.Intent("", "", 0, ""));
    assert VerifyTag(c, SigFn(c));
    if IdealMac(s) {
      assert (c, SigFn(c)) in s.minted;
      assert m in ids;
      assert false;
    }
  }

  const PRE: F.Charge := F.Charge("ch_1", 100, 60, true)
  const POST: F.Charge := F.Charge("ch_1", 100, 20, true)
  const GOOD: Claim := Claim(1, 2, PRE, 7, F.Request("rq_1", 40, "duplicate_charge"), POST,
                             R.Intent("ch_1", "rq_1", 40, "duplicate_charge"))
  const BAD: Claim := Claim(1, 2, PRE, 8, F.Request("rq_b", 61, "duplicate_charge"), F.Charge("ch_1", 100, -1, true),
                            R.Intent("ch_1", "rq_b", 61, "duplicate_charge"))

  // A run in this instance: mint GOOD, deliver GOOD (commits), deliver BAD with GOOD's tag (rejected).
  lemma RunInTotalInstance()
    ensures MintAllowed(GOOD)
    ensures var s0 := Sys(PRE, [], {}, [], {});
            var s1 := Mint(s0, GOOD, SigFn(GOOD));
            var s2 := Commit(s1, GOOD, SigFn(GOOD));
            Inv(PRE, s1) && Inv(PRE, s2) && s2.outbox == [GOOD.eff] && s2.store == POST &&
            (VerifyTag(GOOD, SigFn(GOOD)) ==> exists t' :: (GOOD, t') in s1.minted) &&
            !VerifyTag(BAD, SigFn(GOOD)) && Commit(s2, BAD, SigFn(GOOD)) == s2
  {
    assert F.Authorizes(PRE, F.Transition(GOOD.req, GOOD.post, GOOD.eff));
    var s0 := Sys(PRE, [], {}, [], {});
    InitInv(PRE);
    MintPreservesInv(PRE, s0, GOOD, SigFn(GOOD));
    var s1 := Mint(s0, GOOD, SigFn(GOOD));
    assert (GOOD, SigFn(GOOD)) in s1.minted;
    assert SinkAccepts(s1, GOOD, SigFn(GOOD));
    var s2 := Commit(s1, GOOD, SigFn(GOOD));
    // Inv(PRE, s2) by the step-local argument (the same steps as Attack.LocalA1Suffices).
    CommitKeepsChain(PRE, s1, GOOD, SigFn(GOOD));
    CommitKeepsDistinctIds(s1, GOOD, SigFn(GOOD));
    CommitKeepsSettledIsLog(s1, GOOD, SigFn(GOOD));
    CommitKeepsOutboxIsLog(s1, GOOD, SigFn(GOOD));
    assert s2.log == [GOOD];
    assert SigFn(GOOD) == "sig_rq_1" && SigFn(BAD) == "sig_rq_b";
    assert "sig_rq_1"[7] != "sig_rq_b"[7];
    assert !VerifyTag(BAD, SigFn(GOOD));
  }
}
