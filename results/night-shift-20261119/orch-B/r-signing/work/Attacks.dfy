// Night shift 2026-11-19, Orchestrator B, task r-signing (adversarial review of b-signing). Dafny model only.
// NOT gate evidence. No assume, no axiom, no bodiless lemma. Each lemma is an attack on SliceSafetyV2.
include "SliceSafetyV2OnBytes.dfy"

module Attacks {
  import opened SinkCore
  import opened SliceTheorem
  import opened SliceTheoremV2
  import opened SliceWitnessV2
  import SW = SliceWitness

  // ---------------------------------------------------------------------------------------------
  // ATTACK 2a. For ANY reading of VerifyTag: a delivery of a never-minted claim with a tag that does not
  // verify for it keeps every trace hypothesis. H1 has no global quantifier over unpresented pairs.
  lemma UnmintedNonVerifyingDeliveryKeepsHyps(tok: SinkToken)
    requires !VerifyTag(ClaimOf(tok), tok.sig)
    ensures A2_MintOnlyOnCheck([Deliver(tok, false)])
    ensures A5_VerifierMatchesAtEachDelivery([Deliver(tok, false)])
    ensures H1_SignatureAuthenticity([Deliver(tok, false)])
  {
  }

  // ---------------------------------------------------------------------------------------------
  // ATTACK 5 / 2b. Tag substitution with only ONE fact about VerifyTag (no SigReading): the issuer mints the
  // claim of V_TOK with tag T_OTHER; the adversary presents the SAME claim with a DIFFERENT tag that verifies.
  // All V2 hypotheses hold; the effect commits; ApprovedSpec and UniqueAuthorizationV2 hold; the pair-level
  // H1P and the OLD UniqueAuthorization (pair in minted) FAIL. So V2's uniqueness is strictly weaker than V1's
  // and needs no pair; and non-vacuity needs only one verifying pair, not a total reading.
  const T_OTHER: Tag := "minted_tag_differs"
  function SubActs(): seq<Act> { [MintAct(ClaimOf(V_TOK), T_OTHER), Deliver(V_TOK, true)] }

  lemma TagSubstitutionCommits()
    requires VerifyTag(ClaimOf(V_TOK), V_TOK.sig)
    ensures InitOk(SW.W_PRE)
    ensures A2_MintOnlyOnCheck(SubActs())
    ensures A5_VerifierMatchesAtEachDelivery(SubActs())
    ensures H1_SignatureAuthenticity(SubActs())
    ensures !H1P_PairAuthenticity(SubActs())
    ensures Exec(SW.W_PRE, SubActs()).core.outbox == [SW.W_INTENT]
    ensures ApprovedSpec(SW.W_PRE, SubActs(), 0) && UniqueAuthorizationV2(SW.W_PRE, SubActs(), 0)
    ensures !UniqueAuthorization(SW.W_PRE, SubActs(), 0)
  {
    var acts := SubActs();
    var init := SW.W_PRE;
    assert V_TOK.sig != T_OTHER;
    assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(V_TOK));
    assert ClaimOf(V_TOK) == CheckedClaim(V_TOK.pre, SW.CheckedTransition(V_TOK));
    forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c)
      ensures exists pre: F.Charge, t2: F.Transition :: F.Authorizes(pre, t2) && acts[k].c == CheckedClaim(pre, t2)
    {
      assert k == 0;
      assert F.Authorizes(V_TOK.pre, SW.CheckedTransition(V_TOK)) && acts[k].c == CheckedClaim(V_TOK.pre, SW.CheckedTransition(V_TOK));
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver? && VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig)
      ensures SignedBefore(acts, k, ClaimOf(acts[k].tok))
    {
      assert k == 1;
      assert acts[0].MintAct? && acts[0].c == ClaimOf(acts[1].tok);
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures A5_VerifierMatches(acts[k].tok, acts[k].sigOk)
    {
      assert k == 1;
    }
    assert !H1P_PairAuthenticity(acts) by {
      assert acts[1].Deliver? && VerifyTag(ClaimOf(acts[1].tok), acts[1].tok.sig);
      if exists j :: 0 <= j < 1 && acts[j] == MintAct(ClaimOf(acts[1].tok), acts[1].tok.sig) {
        var j :| 0 <= j < 1 && acts[j] == MintAct(ClaimOf(acts[1].tok), acts[1].tok.sig);
        assert j == 0;
        assert acts[0].tag == T_OTHER;
      }
    }
    ExecStep(init, acts, 0);
    ExecStep(init, acts, 1);
    assert acts[..0] == [];
    assert acts[..2] == acts;
    var r0 := Exec(init, acts[..0]);
    assert r0 == RunSt(Core(init, {}, []), Sys(init, [], {}, [], {}), []);
    var r1 := Exec(init, acts[..1]);
    assert r1.core == Core(init, {}, []) && r1.toks == [];
    assert r1.s.minted == {(ClaimOf(V_TOK), T_OTHER)};
    assert Step(r1.core, V_TOK, true).out.Committed?;
    var r := Exec(init, acts);
    assert r.toks == [V_TOK] && r.core.outbox == [SW.W_INTENT];
    assert r.s.minted == {(ClaimOf(V_TOK), T_OTHER)};
    FlatSpecFnMeetsA6();
    PerEntryV2(init, acts, FlatSpecFn, 0);
    assert (ClaimOf(V_TOK), V_TOK.sig) !in r.s.minted;
  }

  // ---------------------------------------------------------------------------------------------
  // ATTACK 3. Which conjuncts are STRUCTURAL (no hypothesis at all)? Token request ids are distinct, every
  // committed token's id is settled, and the outbox is the list of token intents, for EVERY trace.
  lemma Structural(init: State, acts: seq<Act>)
    ensures var r := Exec(init, acts);
      |r.toks| == |r.core.outbox| &&
      (forall i | 0 <= i < |r.toks| :: r.toks[i].requestId in r.core.settled && r.core.outbox[i] == r.toks[i].intent) &&
      (forall x | x in r.core.settled :: exists i :: 0 <= i < |r.toks| && r.toks[i].requestId == x) &&
      (forall i, j | 0 <= i < j < |r.toks| :: r.toks[i].requestId != r.toks[j].requestId)
    decreases |acts|
  {
    if |acts| > 0 {
      var p := acts[..|acts| - 1];
      Structural(init, p);
      var r := Exec(init, p);
      assert Exec(init, acts) == Next(r, acts[|acts| - 1]);
      match acts[|acts| - 1]
      case MintAct(c, tag) =>
      case Deliver(tok, sigOk) =>
        var res := Step(r.core, tok, sigOk);
        if res.out.Committed? {
          var r' := Exec(init, acts);
          assert r'.toks == r.toks + [tok];
          assert r'.core.outbox == r.core.outbox + [tok.intent];
          assert r'.core.settled == r.core.settled + {tok.requestId};
          assert tok.requestId !in r.core.settled;
          forall x | x in r'.core.settled
            ensures exists i :: 0 <= i < |r'.toks| && r'.toks[i].requestId == x
          {
            if x == tok.requestId {
              assert r'.toks[|r.toks|] == tok;
            } else {
              var i :| 0 <= i < |r.toks| && r.toks[i].requestId == x;
              assert r'.toks[i] == r.toks[i];
            }
          }
        }
    }
  }

  // ATTACK 3 (cont.). Without H1, even the EFFECT-level uniqueness fails: two unminted tokens with different
  // token request ids carry two intents with the SAME request id; both verify (SigReading) and both commit.
  // A2 and A5 hold. So outbox request-id uniqueness is NOT structural: it rests on H1 + A2 (via SpecRel).
  const D_I: R.RefundIntent := R.Intent("ch_1", "rq_1", 1, "duplicate_charge")
  const D_P1: F.Charge := F.Charge("ch_1", 100, 59, true)
  const D_P2: F.Charge := F.Charge("ch_1", 100, 58, true)
  const D_X: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, SW.W_PRE, "rq_x", D_P1, D_I, "sig_rq_x")
  const D_Y: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, D_P1, "rq_y", D_P2, D_I, "sig_rq_y")
  function DupActs(): seq<Act> { [Deliver(D_X, true), Deliver(D_Y, true)] }

  lemma NoH1DuplicateEffectIds()
    requires SigReading()
    ensures A2_MintOnlyOnCheck(DupActs()) && A5_VerifierMatchesAtEachDelivery(DupActs())
    ensures !H1_SignatureAuthenticity(DupActs())
    ensures Exec(SW.W_PRE, DupActs()).core.outbox == [D_I, D_I]
    ensures Exec(SW.W_PRE, DupActs()).core.outbox[0].requestId == Exec(SW.W_PRE, DupActs()).core.outbox[1].requestId
  {
    var acts := DupActs();
    var init := SW.W_PRE;
    SigOf(D_X);
    SigOf(D_Y);
    assert VerifyTag(ClaimOf(D_X), D_X.sig) && VerifyTag(ClaimOf(D_Y), D_Y.sig);
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures A5_VerifierMatches(acts[k].tok, acts[k].sigOk)
    {
      assert k == 0 || k == 1;
    }
    assert !SignedBefore(acts, 0, ClaimOf(D_X));
    ExecStep(init, acts, 0);
    ExecStep(init, acts, 1);
    assert acts[..0] == [];
    assert acts[..2] == acts;
    var r0 := Exec(init, acts[..0]);
    assert r0 == RunSt(Core(init, {}, []), Sys(init, [], {}, [], {}), []);
    var r1 := Exec(init, acts[..1]);
    assert r1.core == Core(D_P1, {"rq_x"}, [D_I]);
    assert "rq_y" !in {"rq_x"};
    var r2 := Exec(init, acts[..2]);
    assert r2.core == Core(D_P2, {"rq_x", "rq_y"}, [D_I, D_I]);
  }

  // ---------------------------------------------------------------------------------------------
  // ATTACK 2 (absurd consequences). Under SigReading the hypotheses do NOT imply "at most one commit" and do
  // NOT imply "nothing commits": MainActs has two commits.
  lemma NotAtMostOneCommit()
    requires SigReading()
    ensures !(forall init: State, acts: seq<Act> |
                InitOk(init) && A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts) &&
                H1_SignatureAuthenticity(acts) :: |Exec(init, acts).core.outbox| <= 1)
  {
    MainWitness();
    var init := SW.W_PRE;
    var acts := MainActs();
    assert |Exec(init, acts).core.outbox| == 2;
    assert InitOk(init) && A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts) &&
           H1_SignatureAuthenticity(acts) && !(|Exec(init, acts).core.outbox| <= 1);
  }

  // ---------------------------------------------------------------------------------------------
  // ATTACK 4 (cross-spec). A MintAct for a claim with OTHER ids never helps a claim with our ids: H1 is
  // claim-level and the claim holds specId and checkerId. A tag minted for the other-id claim that also
  // verifies for our claim is a delivery that H1 forbids (the hypothesis absorbs the cross-spec risk; in bytes,
  // H3a must therefore cover specId and checkerId).
  const XS_TOK: SinkToken := SinkToken(9, PINNED_CHK, SW.W_PRE, "rq_1", SW.W_POST, SW.W_INTENT, "sig_rq_1")
  lemma CrossSpecMintDoesNotSatisfyH1()
    requires VerifyTag(ClaimOf(V_TOK), V_TOK.sig)
    ensures !H1_SignatureAuthenticity([MintAct(ClaimOf(XS_TOK), V_TOK.sig), Deliver(V_TOK, true)])
    ensures A2_MintOnlyOnCheck([MintAct(ClaimOf(XS_TOK), V_TOK.sig), Deliver(V_TOK, true)])
  {
    var acts := [MintAct(ClaimOf(XS_TOK), V_TOK.sig), Deliver(V_TOK, true)];
    assert !Ours(ClaimOf(XS_TOK));
    assert ClaimOf(XS_TOK) != ClaimOf(V_TOK) by { assert ClaimOf(XS_TOK).specId == 9; }
    assert !SignedBefore(acts, 1, ClaimOf(V_TOK)) by {
      if SignedBefore(acts, 1, ClaimOf(V_TOK)) {
        var j :| 0 <= j < 1 && j < |acts| && acts[j].MintAct? && acts[j].c == ClaimOf(V_TOK);
        assert j == 0;
        assert acts[0].c == ClaimOf(XS_TOK);
      }
    }
    assert acts[1].Deliver? && acts[1].tok == V_TOK;
    assert VerifyTag(ClaimOf(acts[1].tok), acts[1].tok.sig) && !SignedBefore(acts, 1, ClaimOf(acts[1].tok));
    forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c)
      ensures false
    {
      assert k == 0;
    }
  }
}
