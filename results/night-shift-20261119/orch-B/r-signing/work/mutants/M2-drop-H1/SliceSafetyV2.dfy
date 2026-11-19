// Night shift 2026-11-19, Orchestrator B, task b-signing. A DRAFT in an evidence folder. NOT approved.
// NOT gate evidence. M1-B stays OPEN. end_to_end=false. A Dafny-MODEL statement only. It says nothing about
// sink.ts, minter.ts, Ed25519, compiled code, the HOL model, CakeML or native execution.
//
// Purpose. SliceSafety (inputs/SliceTheorem.dfy, byte-equal copy) needs A1 = the GLOBAL IdealMac at each
// delivery. U478 proved that no total verifier meets it. SliceSafetyV2 below drops it. It uses a realizable
// signing and issuance model with five SEPARATE parts:
//   1. H1_SignatureAuthenticity (trace, step-local, claim-level, the symbolic form of EUF-CMA): at each
//      delivery, IF the presented claim and tag verify, THEN a MintAct for that CLAIM (any tag) occurs EARLIER
//      in the trace. It speaks only of the presented pairs. It is consistent with a TOTAL verifier
//      (SliceWitnessV2.MainWitness).
//   2. A2_MintOnlyOnCheck (reused unchanged from SliceTheorem): the key holder signs a claim for our ids only
//      when RefundFinality.Check issues a token for it. About MintAct actions only.
//   3. Signed bytes: H3a_SerInjective, H3b_SinkRebuildsSignedBytes, H3c_VerifyTagIsByteVerifier, plus the
//      byte-level forms H1B_ByteUnforgeability and B5_ByteVerifierMatchesAtEachDelivery. Lemma
//      BytesGiveClaimAuthenticity derives H1 (and A5) from them. Control NonInjectiveSerBreaksClaimLevel.
//   4. Key secrecy and trust: STRUCTURAL. Lemma OnlyMintActionsSign proves that the signed set of every
//      reachable state is exactly the set of MintAct pairs of the trace; a delivery never adds to it. The
//      adversary chooses every Deliver action (token, tag, order, replays). The real-world reading (EUF-CMA of
//      Ed25519, private key only in the issuer, probabilistic) is an ASSUMPTION written in REPORT.md.
//   5. The protected sink behaviour: SinkCore.Step, unchanged (inputs/transport/sink/SinkCore.dfy, byte-equal).
// A5 (sigOk equals VerifyTag) and A6 (ValidArtifact) stay hypotheses, as in SliceSafety.
// Uninterpreted symbol: VerifyTag (FinalityProtocol, inherited bodiless into SinkCore). No assume, no axiom,
// no bodiless lemma in this file.
include "../../inputs/SliceTheorem.dfy"

module SliceTheoremV2 {
  import opened SinkCore
  import opened SliceTheorem

  // =============================================================================================
  // Item 4 (structural): only mint actions add to the signed set.
  ghost function MintsOf(acts: seq<Act>): set<(Claim, Tag)>
    decreases |acts|
  {
    if |acts| == 0 then {}
    else MintsOf(acts[..|acts| - 1]) +
         (if acts[|acts| - 1].MintAct? then {(acts[|acts| - 1].c, acts[|acts| - 1].tag)} else {})
  }

  lemma OnlyMintActionsSign(init: State, acts: seq<Act>)
    ensures Exec(init, acts).s.minted == MintsOf(acts)
    decreases |acts|
  {
    if |acts| > 0 {
      var p := acts[..|acts| - 1];
      OnlyMintActionsSign(init, p);
      var r := Exec(init, p);
      assert Exec(init, acts) == Next(r, acts[|acts| - 1]);
      match acts[|acts| - 1]
      case MintAct(c, tag) =>
      case Deliver(tok, sigOk) =>
        assert Commit(r.s, ClaimOf(tok), tok.sig).minted == r.s.minted;
    }
  }

  lemma MintInMintsOf(acts: seq<Act>, j: int)
    requires 0 <= j < |acts| && acts[j].MintAct?
    ensures (acts[j].c, acts[j].tag) in MintsOf(acts)
    decreases |acts|
  {
    if j < |acts| - 1 {
      var p := acts[..|acts| - 1];
      assert p[j] == acts[j];
      MintInMintsOf(p, j);
    }
  }

  lemma MintsOfHasSource(acts: seq<Act>, c: Claim, t: Tag)
    requires (c, t) in MintsOf(acts)
    ensures exists j :: 0 <= j < |acts| && acts[j] == MintAct(c, t)
    decreases |acts|
  {
    var n := |acts|;
    var p := acts[..n - 1];
    if (c, t) in MintsOf(p) {
      MintsOfHasSource(p, c, t);
      var j :| 0 <= j < |p| && p[j] == MintAct(c, t);
      assert acts[j] == p[j];
    } else {
      assert acts[n - 1] == MintAct(c, t);
    }
  }

  // =============================================================================================
  // Item 1: signature authenticity as a trace property (claim level; the tag may differ).
  ghost predicate SignedBefore(acts: seq<Act>, k: int, c: Claim)
  {
    exists j :: 0 <= j < k && j < |acts| && acts[j].MintAct? && acts[j].c == c
  }

  ghost predicate H1_SignatureAuthenticity(acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? ::
      VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig) ==> SignedBefore(acts, k, ClaimOf(acts[k].tok))
  }

  // The pair-level form (strong unforgeability). It implies the claim-level form; V2 needs only the latter.
  ghost predicate H1P_PairAuthenticity(acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? ::
      VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig) ==>
        exists j :: 0 <= j < k && acts[j] == MintAct(ClaimOf(acts[k].tok), acts[k].tok.sig)
  }

  lemma PairLevelGivesClaimLevel(acts: seq<Act>)
    requires H1P_PairAuthenticity(acts)
    ensures H1_SignatureAuthenticity(acts)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? && VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig)
      ensures SignedBefore(acts, k, ClaimOf(acts[k].tok))
    {
      var j :| 0 <= j < k && acts[j] == MintAct(ClaimOf(acts[k].tok), acts[k].tok.sig);
      assert acts[j].MintAct? && acts[j].c == ClaimOf(acts[k].tok);
    }
  }

  // The step-local premise on a model state (only the presented pair).
  // Some tag of claim c is in the signed set.
  ghost predicate ClaimHasSig(s: System, c: Claim)
  {
    exists t' :: (c, t') in s.minted
  }

  ghost predicate LocalClaimSigned(s: System, c: Claim, t: Tag)
  {
    VerifyTag(c, t) ==> ClaimHasSig(s, c)
  }

  // Every logged claim has some signed tag.
  ghost predicate ClaimsSigned(s: System)
  {
    forall i | 0 <= i < |s.log| :: ClaimHasSig(s, s.log[i])
  }

  // =============================================================================================
  // The model invariant under the step-local, claim-level premise (no IdealMac).
  lemma LocalClaimSignedKeepsInv(init: State, s: System, c: Claim, t: Tag)
    requires Inv(init, s)
    requires LocalClaimSigned(s, c, t)
    ensures Inv(init, Commit(s, c, t))
  {
    CommitKeepsChain(init, s, c, t);
    CommitKeepsDistinctIds(s, c, t);
    CommitKeepsSettledIsLog(s, c, t);
    CommitKeepsOutboxIsLog(s, c, t);
    if SinkAccepts(s, c, t) {
      var t' :| (c, t') in s.minted;
      assert Ours(c) && SpecRel(c.pre, c.req, c.post, c.eff);
      var log' := s.log + [c];
      forall i | 0 <= i < |log'|
        ensures Ours(log'[i]) && SpecRel(log'[i].pre, log'[i].req, log'[i].post, log'[i].eff)
      {
        if i < |s.log| {
          assert log'[i] == s.log[i];
        } else {
          assert log'[i] == c;
        }
      }
    }
  }

  lemma CommitKeepsClaimsSigned(s: System, c: Claim, t: Tag)
    requires ClaimsSigned(s) && LocalClaimSigned(s, c, t)
    ensures ClaimsSigned(Commit(s, c, t))
  {
    if SinkAccepts(s, c, t) {
      var s' := Commit(s, c, t);
      assert s'.minted == s.minted && s'.log == s.log + [c];
      var tc :| (c, tc) in s.minted;
      forall i | 0 <= i < |s'.log|
        ensures ClaimHasSig(s', s'.log[i])
      {
        if i < |s.log| {
          assert s'.log[i] == s.log[i];
          var t' :| (s.log[i], t') in s.minted;
          assert (s'.log[i], t') in s'.minted;
        } else {
          assert s'.log[i] == c;
          assert (s'.log[i], tc) in s'.minted;
        }
      }
      assert ClaimsSigned(s');
    }
  }

  lemma MintKeepsClaimsSigned(s: System, c: Claim, t: Tag)
    requires ClaimsSigned(s)
    ensures ClaimsSigned(s.(minted := s.minted + {(c, t)}))
  {
    var s' := s.(minted := s.minted + {(c, t)});
    assert s'.log == s.log;
    forall i | 0 <= i < |s'.log|
      ensures ClaimHasSig(s', s'.log[i])
    {
      assert s'.log[i] == s.log[i];
      var t' :| (s.log[i], t') in s.minted;
      assert (s'.log[i], t') in s'.minted;
    }
    assert ClaimsSigned(s');
  }

  // Secondary item: the sink-core step lemma restated under the step-local premise.
  lemma StepPreservesInvV2(init: State, core: Core, s: System, toks: seq<SinkToken>, tok: SinkToken, sigOk: bool)
    requires A5_VerifierMatches(tok, sigOk)
    requires Rel(core, s, toks) && Inv(init, s) && LocalClaimSigned(s, ClaimOf(tok), tok.sig)
    ensures Inv(init, Commit(s, ClaimOf(tok), tok.sig))
    ensures Rel(Step(core, tok, sigOk).core, Commit(s, ClaimOf(tok), tok.sig),
                NextToks(toks, tok, Step(core, tok, sigOk).out))
    ensures Step(core, tok, sigOk).out.Committed? <==> SinkAccepts(s, ClaimOf(tok), tok.sig)
  {
    StepRefinesCommit(core, s, toks, tok, sigOk);
    LocalClaimSignedKeepsInv(init, s, ClaimOf(tok), tok.sig);
  }

  // Secondary item: RefundSliceShape (T1 without the pair-in-minted part, T2 to T5) without IdealMac.
  lemma RefundSliceShapeV2(init: State, core: Core, s: System, toks: seq<SinkToken>)
    requires Rel(core, s, toks) && Inv(init, s) && InitOk(init)
    ensures |toks| == |s.log| == |core.outbox|
    ensures forall i | 0 <= i < |toks| :: s.log[i] == ClaimOf(toks[i]) && VerifyTag(s.log[i], toks[i].sig)
    ensures forall i, j | 0 <= i < j < |toks| :: toks[i].requestId != toks[j].requestId && toks[i] != toks[j]
    ensures forall i, j | 0 <= i < j < |core.outbox| :: core.outbox[i].requestId != core.outbox[j].requestId
    ensures forall i | 0 <= i < |toks| ::
      core.outbox[i] == toks[i].intent && toks[i].intent.requestId == toks[i].requestId && 0 <= core.outbox[i].amount
    ensures 0 <= core.charge.remaining <= core.charge.original == init.original
    ensures SumIntents(core.outbox) == init.remaining - core.charge.remaining
    ensures 0 <= SumIntents(core.outbox) <= init.original
  {
    InvMeaning(init, s);
    forall i | 0 <= i < |toks|
      ensures toks[i].intent.requestId == toks[i].requestId && 0 <= toks[i].intent.amount
    {
      assert SpecRel(s.log[i].pre, s.log[i].req, s.log[i].post, s.log[i].eff);
    }
    forall i, j | 0 <= i < j < |toks|
      ensures toks[i].requestId != toks[j].requestId
    {
      assert s.log[i].reqId != s.log[j].reqId;
    }
    SumsAgree(core.outbox, s.log);
    ChainSum(init, s.log, s.store);
  }

  // =============================================================================================
  // Reachability under the V2 hypotheses.
  lemma PrefixHypsV2(acts: seq<Act>)
    requires |acts| > 0
    requires A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts) 
    ensures var p := acts[..|acts| - 1];
      A2_MintOnlyOnCheck(p) && A5_VerifierMatchesAtEachDelivery(p) 
  {
    var p := acts[..|acts| - 1];
    forall k | 0 <= k < |p|
      ensures p[k] == acts[k]
    {
    }
    forall k | 0 <= k < |p| && p[k].Deliver? && VerifyTag(ClaimOf(p[k].tok), p[k].tok.sig)
      ensures SignedBefore(p, k, ClaimOf(p[k].tok))
    {
      assert acts[k] == p[k];
      var j :| 0 <= j < k && j < |acts| && acts[j].MintAct? && acts[j].c == ClaimOf(acts[k].tok);
      assert p[j] == acts[j];
    }
  }

  lemma ExecInvV2(init: State, acts: seq<Act>)
    requires A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts) 
    ensures Rel(Exec(init, acts).core, Exec(init, acts).s, Exec(init, acts).toks)
    ensures Inv(init, Exec(init, acts).s)
    ensures ClaimsSigned(Exec(init, acts).s)
    decreases |acts|
  {
    if |acts| == 0 {
      InitInv(init);
      InitRel(init);
    } else {
      var n := |acts|;
      var p := acts[..n - 1];
      PrefixHypsV2(acts);
      ExecInvV2(init, p);
      OnlyMintActionsSign(init, p);
      var r := Exec(init, p);
      assert Exec(init, acts) == Next(r, acts[n - 1]);
      match acts[n - 1]
      case MintAct(c, tag) =>
        if Ours(c) {
          assert acts[n - 1].MintAct? && Ours(acts[n - 1].c);
          var pre: F.Charge, t: F.Transition :| F.Authorizes(pre, t) && c == CheckedClaim(pre, t);
          CheckedClaimAllowed(pre, t);
        }
        assert MintAllowed(c);
        MintPreservesInv(init, r.s, c, tag);
        MintKeepsRel(r.core, r.s, r.toks, c, tag);
        assert Mint(r.s, c, tag) == r.s.(minted := r.s.minted + {(c, tag)});
        MintKeepsClaimsSigned(r.s, c, tag);
      case Deliver(tok, sigOk) =>
        assert acts[n - 1].Deliver?;
        var cl := ClaimOf(tok);
        if VerifyTag(cl, tok.sig) {
          assert SignedBefore(acts, n - 1, cl);
          var j :| 0 <= j < n - 1 && j < |acts| && acts[j].MintAct? && acts[j].c == cl;
          assert p[j] == acts[j];
          MintInMintsOf(p, j);
          assert (cl, acts[j].tag) in r.s.minted;
        }
        assert LocalClaimSigned(r.s, cl, tok.sig);
        assert A5_VerifierMatches(tok, sigOk);
        StepPreservesInvV2(init, r.core, r.s, r.toks, tok, sigOk);
        CommitKeepsClaimsSigned(r.s, cl, tok.sig);
    }
  }

  // =============================================================================================
  // The conclusions. ApprovedSpec and FlatResultAgrees are reused unchanged from SliceTheorem.
  // UniqueAuthorizationV2 = UniqueAuthorization with the pair-in-minted conjunct replaced by the claim-level
  // form (some tag of that claim is signed) and its trace form (a MintAct of that claim occurs in the trace).
  ghost predicate UniqueAuthorizationV2(init: State, acts: seq<Act>, i: int)
  {
    var r := Exec(init, acts);
    0 <= i < |r.toks| && |r.toks| == |r.s.log| == |r.core.outbox| &&
    r.s.log[i] == ClaimOf(r.toks[i]) && VerifyTag(r.s.log[i], r.toks[i].sig) &&
    ClaimHasSig(r.s, r.s.log[i]) &&
    SignedBefore(acts, |acts|, r.s.log[i]) &&
    r.core.outbox[i].requestId == r.toks[i].requestId && r.toks[i].requestId in r.core.settled &&
    (forall j | 0 <= j < |r.core.outbox| && j != i ::
       r.core.outbox[j].requestId != r.core.outbox[i].requestId && r.toks[j] != r.toks[i])
  }

  lemma PerEntryV2(init: State, acts: seq<Act>, art: FlatFn, i: int)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(acts)
    requires A5_VerifierMatchesAtEachDelivery(acts)
    requires A6_ArtifactComputesFlatContract(art)
    requires 0 <= i < |Exec(init, acts).core.outbox|
    ensures ApprovedSpec(init, acts, i) && FlatResultAgrees(art, init, acts, i) && UniqueAuthorizationV2(init, acts, i)
  {
    var r := Exec(init, acts);
    ExecInvV2(init, acts);
    ExecCommitWitness(init, acts);
    OnlyMintActionsSign(init, acts);
    InvMeaning(init, r.s);
    assert |r.toks| == |r.s.log| == |r.core.outbox|;
    RefundSliceShapeV2(init, r.core, r.s, r.toks);
    var tok := r.toks[i];
    assert r.s.log[i] == ClaimOf(tok);
    assert r.s.outbox[i] == r.s.log[i].eff;
    assert SpecRel(r.s.log[i].pre, r.s.log[i].req, r.s.log[i].post, r.s.log[i].eff);
    FlatPath(art, tok.pre, F.Request(tok.requestId, tok.intent.amount, tok.intent.reason), tok.post, tok.intent);
    assert r.s.log[i].reqId in r.s.settled;
    EncSetMember(r.core.settled, tok.requestId);
    var t' :| (r.s.log[i], t') in r.s.minted;
    MintsOfHasSource(acts, r.s.log[i], t');
    var j :| 0 <= j < |acts| && acts[j] == MintAct(r.s.log[i], t');
    assert acts[j].MintAct? && acts[j].c == r.s.log[i];
    assert SignedBefore(acts, |acts|, r.s.log[i]);
  }

  // =============================================================================================
  // THE COMPOSED THEOREM V2 (Dafny model only). No IdealMac.
  lemma SliceSafetyV2(init: State, acts: seq<Act>, art: FlatFn)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(acts)                  // item 2 (issuance)
    requires A5_VerifierMatchesAtEachDelivery(acts)    // crypto boolean equals VerifyTag
    requires A6_ArtifactComputesFlatContract(art)      // ValidArtifact
    ensures forall e | CommittedEffect(init, acts, e) ::
      exists i :: (0 <= i < |Exec(init, acts).core.outbox| && Exec(init, acts).core.outbox[i] == e &&
        ApprovedSpec(init, acts, i) && FlatResultAgrees(art, init, acts, i) && UniqueAuthorizationV2(init, acts, i))
    ensures 0 <= Exec(init, acts).core.charge.remaining <= Exec(init, acts).core.charge.original == init.original
    ensures SumIntents(Exec(init, acts).core.outbox) == init.remaining - Exec(init, acts).core.charge.remaining
  {
    var r := Exec(init, acts);
    ExecInvV2(init, acts);
    InvMeaning(init, r.s);
    RefundSliceShapeV2(init, r.core, r.s, r.toks);
    forall e | CommittedEffect(init, acts, e)
      ensures exists i :: (0 <= i < |r.core.outbox| && r.core.outbox[i] == e &&
        ApprovedSpec(init, acts, i) && FlatResultAgrees(art, init, acts, i) && UniqueAuthorizationV2(init, acts, i))
    {
      var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e;
      PerEntryV2(init, acts, art, i);
    }
  }

  // =============================================================================================
  // Item 3: signed bytes. The real verifier checks BYTES. MintAct(c, tag) means: the issuer signs Ser(c).
  type Msg = seq<bv8>
  type SerFn = Claim -> Msg
  type ByteVerifier = (Msg, Tag) -> bool
  type RebuildFn = SinkToken -> Msg

  // H3a: the serialization is injective on claims.
  ghost predicate H3a_SerInjective(ser: SerFn)
  {
    forall c1: Claim, c2: Claim :: ser(c1) == ser(c2) ==> c1 == c2
  }

  // H3b: at each delivery, the sink rebuilds exactly Ser(ClaimOf(tok)) from the token it parsed.
  ghost predicate H3b_SinkRebuildsSignedBytes(ser: SerFn, rebuild: RebuildFn, acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? :: rebuild(acts[k].tok) == ser(ClaimOf(acts[k].tok))
  }

  // H3c: the model's claim-level VerifyTag is the byte verifier applied to Ser(claim).
  ghost predicate H3c_VerifyTagIsByteVerifier(ser: SerFn, vb: ByteVerifier)
  {
    forall c: Claim, t: Tag :: VerifyTag(c, t) <==> vb(ser(c), t)
  }

  // B5: the crypto layer's boolean is the byte verifier on the rebuilt bytes.
  ghost predicate B5_ByteVerifierMatchesAtEachDelivery(vb: ByteVerifier, rebuild: RebuildFn, acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? :: acts[k].sigOk == vb(rebuild(acts[k].tok), acts[k].tok.sig)
  }

  ghost predicate BytesSignedBefore(ser: SerFn, acts: seq<Act>, k: int, m: Msg)
  {
    exists j :: 0 <= j < k && j < |acts| && acts[j].MintAct? && ser(acts[j].c) == m
  }

  // H1B: byte-level unforgeability (symbolic EUF-CMA): bytes and tag that verify were signed earlier.
  ghost predicate H1B_ByteUnforgeability(ser: SerFn, vb: ByteVerifier, rebuild: RebuildFn, acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? ::
      vb(rebuild(acts[k].tok), acts[k].tok.sig) ==> BytesSignedBefore(ser, acts, k, rebuild(acts[k].tok))
  }

  // The claim-level conclusion stated without VerifyTag (so the control below needs no reading of VerifyTag).
  ghost predicate ClaimSignedWhenBytesVerify(vb: ByteVerifier, rebuild: RebuildFn, acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? ::
      vb(rebuild(acts[k].tok), acts[k].tok.sig) ==> SignedBefore(acts, k, ClaimOf(acts[k].tok))
  }

  lemma BytesToClaims(ser: SerFn, vb: ByteVerifier, rebuild: RebuildFn, acts: seq<Act>)
    requires H3a_SerInjective(ser)
    requires H3b_SinkRebuildsSignedBytes(ser, rebuild, acts)
    requires H1B_ByteUnforgeability(ser, vb, rebuild, acts)
    ensures ClaimSignedWhenBytesVerify(vb, rebuild, acts)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? && vb(rebuild(acts[k].tok), acts[k].tok.sig)
      ensures SignedBefore(acts, k, ClaimOf(acts[k].tok))
    {
      var j :| 0 <= j < k && j < |acts| && acts[j].MintAct? && ser(acts[j].c) == rebuild(acts[k].tok);
      assert ser(acts[j].c) == ser(ClaimOf(acts[k].tok));
      assert acts[j].c == ClaimOf(acts[k].tok);
    }
  }

  lemma BytesGiveClaimAuthenticity(ser: SerFn, vb: ByteVerifier, rebuild: RebuildFn, acts: seq<Act>)
    requires H3a_SerInjective(ser)
    requires H3b_SinkRebuildsSignedBytes(ser, rebuild, acts)
    requires H3c_VerifyTagIsByteVerifier(ser, vb)
    requires H1B_ByteUnforgeability(ser, vb, rebuild, acts)
    requires B5_ByteVerifierMatchesAtEachDelivery(vb, rebuild, acts)
    ensures H1_SignatureAuthenticity(acts)
    ensures A5_VerifierMatchesAtEachDelivery(acts)
  {
    BytesToClaims(ser, vb, rebuild, acts);
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig) <==> vb(rebuild(acts[k].tok), acts[k].tok.sig)
    {
    }
  }

  // The composed theorem with byte-level hypotheses in place of H1 and A5.
  lemma SliceSafetyV2Bytes(init: State, acts: seq<Act>, art: FlatFn, ser: SerFn, vb: ByteVerifier, rebuild: RebuildFn)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(acts)
    requires H3a_SerInjective(ser)
    requires H3b_SinkRebuildsSignedBytes(ser, rebuild, acts)
    requires H3c_VerifyTagIsByteVerifier(ser, vb)
    requires H1B_ByteUnforgeability(ser, vb, rebuild, acts)
    requires B5_ByteVerifierMatchesAtEachDelivery(vb, rebuild, acts)
    requires A6_ArtifactComputesFlatContract(art)
    ensures forall e | CommittedEffect(init, acts, e) ::
      exists i :: (0 <= i < |Exec(init, acts).core.outbox| && Exec(init, acts).core.outbox[i] == e &&
        ApprovedSpec(init, acts, i) && FlatResultAgrees(art, init, acts, i) && UniqueAuthorizationV2(init, acts, i))
    ensures 0 <= Exec(init, acts).core.charge.remaining <= Exec(init, acts).core.charge.original == init.original
    ensures SumIntents(Exec(init, acts).core.outbox) == init.remaining - Exec(init, acts).core.charge.remaining
  {
    BytesGiveClaimAuthenticity(ser, vb, rebuild, acts);
    SliceSafetyV2(init, acts, art);
  }

  // Control for item 3: without injectivity the derivation fails. Two different claims, one message.
  function ConstSer(c: Claim): Msg { [] }
  function AcceptAllBytes(m: Msg, t: Tag): bool { true }
  function ConstRebuild(tok: SinkToken): Msg { ConstSer(ClaimOf(tok)) }

  const CX_PRE: F.Charge := F.Charge("ch_1", 100, 60, true)
  const CX_SIGNED: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, CX_PRE, "rq_1", F.Charge("ch_1", 100, 20, true),
                                          R.Intent("ch_1", "rq_1", 40, "duplicate_charge"), "t")
  const CX_OTHER: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, CX_PRE, "rq_b", F.Charge("ch_1", 100, -1, true),
                                         R.Intent("ch_1", "rq_b", 61, "duplicate_charge"), "t")

  function CXActs(): seq<Act>
  {
    [MintAct(ClaimOf(CX_SIGNED), "t"), Deliver(CX_OTHER, true)]
  }

  lemma NonInjectiveSerBreaksClaimLevel()
    ensures ClaimOf(CX_SIGNED) != ClaimOf(CX_OTHER) && ConstSer(ClaimOf(CX_SIGNED)) == ConstSer(ClaimOf(CX_OTHER))
    ensures !H3a_SerInjective(ConstSer)
    ensures H3b_SinkRebuildsSignedBytes(ConstSer, ConstRebuild, CXActs())
    ensures H1B_ByteUnforgeability(ConstSer, AcceptAllBytes, ConstRebuild, CXActs())
    ensures B5_ByteVerifierMatchesAtEachDelivery(AcceptAllBytes, ConstRebuild, CXActs())
    ensures !ClaimSignedWhenBytesVerify(AcceptAllBytes, ConstRebuild, CXActs())
  {
    var acts := CXActs();
    assert ClaimOf(CX_SIGNED).eff.amount == 40 && ClaimOf(CX_OTHER).eff.amount == 61;
    assert BytesSignedBefore(ConstSer, acts, 1, ConstRebuild(CX_OTHER)) by {
      assert acts[0].MintAct? && ConstSer(acts[0].c) == ConstRebuild(CX_OTHER);
    }
    assert !SignedBefore(acts, 1, ClaimOf(CX_OTHER)) by {
      if SignedBefore(acts, 1, ClaimOf(CX_OTHER)) {
        var j :| 0 <= j < 1 && j < |acts| && acts[j].MintAct? && acts[j].c == ClaimOf(CX_OTHER);
        assert j == 0;
      }
    }
    assert acts[1].Deliver? && AcceptAllBytes(ConstRebuild(acts[1].tok), acts[1].tok.sig);
  }
}

// =================================================================================================
// Non-vacuity and refutations under a TOTAL verifier reading. VerifyTag is uninterpreted in SinkCore and cannot
// get a body here (refinement of SinkCore crashes the pinned Dafny). So each lemma is CONDITIONAL on
// SigReading(): VerifyTag(c, t) <==> t == SigFn(c). SigFn is a total function: EVERY claim has a verifying tag.
// TotalReading.dfy (a separate file) proves inside Dafny that a refinement of FinalityProtocol with the same types
// and the same SpecRel as SinkCore and this verifier body exists, and that in it the verifier is total.
module SliceWitnessV2 {
  import opened SinkCore
  import opened SliceTheorem
  import opened SliceTheoremV2
  import SW = SliceWitness

  function SigFn(c: Claim): Tag { "sig_" + c.req.requestId }

  ghost predicate HasTag(c: Claim) { exists t: Tag :: VerifyTag(c, t) }

  ghost predicate SigReading()
  {
    forall c: Claim, t: Tag :: VerifyTag(c, t) <==> t == SigFn(c)
  }

  lemma SigReadingIsTotal()
    requires SigReading()
    ensures forall c: Claim :: HasTag(c)
  {
    forall c: Claim
      ensures HasTag(c)
    {
      assert VerifyTag(c, SigFn(c));
    }
  }

  // Contrast: a copy of Attack.TotalVerifierBreaksIdealMac (review/Attack.dfy, U478). Under the same reading
  // the GLOBAL A1 of SliceSafety is false in every state, while the V2 witness below commits.
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

  lemma TotalVerifierBreaksIdealMacCopy(s: System)
    requires forall c: Claim :: HasTag(c)
    ensures !IdealMac(s)
  {
    var ids := set p | p in s.minted :: p.0.reqId;
    var m := Bound(ids);
    var ch := F.Charge("", 0, 0, false);
    var c := Claim(0, 0, ch, m, F.Request("", 0, ""), ch, R.Intent("", "", 0, ""));
    assert HasTag(c);
    var t :| VerifyTag(c, t);
    if IdealMac(s) {
      assert (c, t) in s.minted;
      assert m in ids;
      assert false;
    }
  }

  // ---- tokens: each honest tag is SigFn of its claim ----
  const V_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, SW.W_PRE, "rq_1", SW.W_POST, SW.W_INTENT, "sig_rq_1")
  const V0_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, SW.W_PRE, "rq_0", SW.W_PRE, SW.W0_INTENT, "sig_rq_0")
  const VZ_INTENT: R.RefundIntent := R.Intent("ch_1", "rq_z", 0, "duplicate_charge")
  const VZ_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, SW.W_PRE, "rq_z", SW.W_PRE, VZ_INTENT, "sig_rq_z")
  // A forgery attempt: an unsigned, unapproved claim (61 > remaining 60) with the tag of ANOTHER claim.
  const VF_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, SW.W_PRE, "rq_b", F.Charge("ch_1", 100, -1, true),
                                       SW.WB_INTENT, "sig_rq_1")
  // The same unapproved claim with the tag that DOES verify for it (used only in the refutations).
  const VB_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, SW.W_PRE, "rq_b", F.Charge("ch_1", 100, -1, true),
                                       SW.WB_INTENT, "sig_rq_b")

  lemma ExecStep(init: State, acts: seq<Act>, k: int)
    requires 0 <= k < |acts|
    ensures Exec(init, acts[..k + 1]) == Next(Exec(init, acts[..k]), acts[k])
  {
    assert acts[..k + 1][..k] == acts[..k];
    assert acts[..k + 1][k] == acts[k];
  }

  lemma SigOf(tok: SinkToken)
    ensures SigFn(ClaimOf(tok)) == "sig_" + tok.requestId
  {
  }

  // ---- generic two-action trace: mint the claim, deliver the token ----
  lemma WitnessFor2(tok: SinkToken)
    requires SigReading()
    requires tok.specId == PINNED_SPEC && tok.checkerId == PINNED_CHK && tok.sig == SigFn(ClaimOf(tok))
    ensures A5_VerifierMatchesAtEachDelivery(SW.ActsFor(tok))
    ensures H1_SignatureAuthenticity(SW.ActsFor(tok))
    ensures Exec(tok.pre, SW.ActsFor(tok)).core.outbox == [tok.intent]
    ensures Exec(tok.pre, SW.ActsFor(tok)).toks == [tok]
    ensures CommittedEffect(tok.pre, SW.ActsFor(tok), tok.intent)
    ensures F.Authorizes(tok.pre, SW.CheckedTransition(tok)) ==> A2_MintOnlyOnCheck(SW.ActsFor(tok))
  {
    var acts := SW.ActsFor(tok);
    var init := tok.pre;
    if F.Authorizes(tok.pre, SW.CheckedTransition(tok)) {
      assert ClaimOf(tok) == CheckedClaim(tok.pre, SW.CheckedTransition(tok));
      forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c)
        ensures exists pre: F.Charge, t2: F.Transition :: F.Authorizes(pre, t2) && acts[k].c == CheckedClaim(pre, t2)
      {
        assert k == 0;
        assert F.Authorizes(tok.pre, SW.CheckedTransition(tok)) && acts[k].c == CheckedClaim(tok.pre, SW.CheckedTransition(tok));
      }
    }
    assert VerifyTag(ClaimOf(tok), tok.sig);
    forall k | 0 <= k < |acts| && acts[k].Deliver? && VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig)
      ensures SignedBefore(acts, k, ClaimOf(acts[k].tok))
    {
      assert k == 1;
      assert acts[0].MintAct? && acts[0].c == ClaimOf(acts[1].tok);
    }
    ExecStep(init, acts, 0);
    ExecStep(init, acts, 1);
    assert acts[..0] == [];
    assert acts[..2] == acts;
    var r0 := Exec(init, acts[..0]);
    assert r0 == RunSt(Core(init, {}, []), Sys(init, [], {}, [], {}), []);
    var r1 := Exec(init, acts[..1]);
    assert r1.core == Core(init, {}, []) && r1.toks == [];
    assert Step(r1.core, tok, true).out.Committed?;
  }

  // ---- the main witness: six actions, a TOTAL verifier ----
  function MainActs(): seq<Act>
  {
    [MintAct(ClaimOf(V0_TOK), V0_TOK.sig), Deliver(V0_TOK, true),
     MintAct(ClaimOf(V_TOK), V_TOK.sig), Deliver(V_TOK, true),
     Deliver(VF_TOK, false),   // forged: rejected (SignatureInvalid)
     Deliver(V_TOK, true)]     // replay: rejected (RequestSettled)
  }

  lemma MainTrace()
    ensures Exec(SW.W_PRE, MainActs()).core.outbox == [SW.W0_INTENT, SW.W_INTENT]
    ensures Exec(SW.W_PRE, MainActs()).toks == [V0_TOK, V_TOK]
    ensures Exec(SW.W_PRE, MainActs()).core.charge == SW.W_POST
    ensures Step(Exec(SW.W_PRE, MainActs()[..4]).core, VF_TOK, false) ==
            StepResult(Exec(SW.W_PRE, MainActs()[..4]).core, Rejected(SignatureInvalid))
    ensures Step(Exec(SW.W_PRE, MainActs()[..5]).core, V_TOK, true) ==
            StepResult(Exec(SW.W_PRE, MainActs()[..5]).core, Rejected(RequestSettled))
  {
    var acts := MainActs();
    var init := SW.W_PRE;
    ExecStep(init, acts, 0);
    ExecStep(init, acts, 1);
    ExecStep(init, acts, 2);
    ExecStep(init, acts, 3);
    ExecStep(init, acts, 4);
    ExecStep(init, acts, 5);
    assert acts[..0] == [];
    assert acts[..6] == acts;
    var r0 := Exec(init, acts[..0]);
    assert r0 == RunSt(Core(init, {}, []), Sys(init, [], {}, [], {}), []);
    var r1 := Exec(init, acts[..1]);
    assert r1.core == Core(init, {}, []) && r1.toks == [];
    var r2 := Exec(init, acts[..2]);
    assert r2.core == Core(init, {"rq_0"}, [SW.W0_INTENT]) && r2.toks == [V0_TOK];
    var r3 := Exec(init, acts[..3]);
    assert r3.core == r2.core && r3.toks == r2.toks;
    var r4 := Exec(init, acts[..4]);
    assert "rq_1" !in {"rq_0"};
    assert r4.core == Core(SW.W_POST, {"rq_0", "rq_1"}, [SW.W0_INTENT, SW.W_INTENT]) && r4.toks == [V0_TOK, V_TOK];
    var r5 := Exec(init, acts[..5]);
    assert r5.core == r4.core && r5.toks == r4.toks;
    var r6 := Exec(init, acts[..6]);
    assert r6.core == r5.core && r6.toks == r5.toks;
  }

  lemma MainHyps()
    requires SigReading()
    ensures A2_MintOnlyOnCheck(MainActs())
    ensures A5_VerifierMatchesAtEachDelivery(MainActs())
    ensures H1_SignatureAuthenticity(MainActs())
    ensures !VerifyTag(ClaimOf(VF_TOK), VF_TOK.sig)
  {
    var acts := MainActs();
    SigOf(V0_TOK);
    SigOf(V_TOK);
    SigOf(VF_TOK);
    assert "sig_rq_1" != "sig_rq_b";
    assert VerifyTag(ClaimOf(V0_TOK), V0_TOK.sig);
    assert VerifyTag(ClaimOf(V_TOK), V_TOK.sig);
    assert !VerifyTag(ClaimOf(VF_TOK), VF_TOK.sig);
    assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(V0_TOK)) by {
      assert SW.W_PRE.(remaining := SW.W_PRE.remaining - 0) == SW.W_PRE;
    }
    assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(V_TOK));
    assert ClaimOf(V0_TOK) == CheckedClaim(V0_TOK.pre, SW.CheckedTransition(V0_TOK));
    assert ClaimOf(V_TOK) == CheckedClaim(V_TOK.pre, SW.CheckedTransition(V_TOK));
    forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c)
      ensures exists pre: F.Charge, t2: F.Transition :: F.Authorizes(pre, t2) && acts[k].c == CheckedClaim(pre, t2)
    {
      if k == 0 {
        assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(V0_TOK)) && acts[k].c == CheckedClaim(V0_TOK.pre, SW.CheckedTransition(V0_TOK));
      } else {
        assert k == 2;
        assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(V_TOK)) && acts[k].c == CheckedClaim(V_TOK.pre, SW.CheckedTransition(V_TOK));
      }
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures A5_VerifierMatches(acts[k].tok, acts[k].sigOk)
    {
      assert k == 1 || k == 3 || k == 4 || k == 5;
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver? && VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig)
      ensures SignedBefore(acts, k, ClaimOf(acts[k].tok))
    {
      if k == 1 {
        assert acts[0].MintAct? && acts[0].c == ClaimOf(acts[k].tok);
      } else {
        assert k == 3 || k == 5;
        assert acts[2].MintAct? && acts[2].c == ClaimOf(acts[k].tok);
      }
    }
  }

  // NON-VACUITY WITHOUT A RESTRICTED VERIFIER. Every hypothesis of SliceSafetyV2 holds; the verifier is TOTAL;
  // a zero-amount and a positive-amount effect commit; a forgery and a replay are rejected; the old A1 is false
  // in every state under the same reading.
  lemma MainWitness()
    requires SigReading()
    ensures forall c: Claim :: HasTag(c)
    ensures forall s: System :: !IdealMac(s)
    ensures InitOk(SW.W_PRE)
    ensures A2_MintOnlyOnCheck(MainActs())
    ensures A5_VerifierMatchesAtEachDelivery(MainActs())
    ensures H1_SignatureAuthenticity(MainActs())
    ensures A6_ArtifactComputesFlatContract(FlatSpecFn)
    ensures Exec(SW.W_PRE, MainActs()).core.outbox == [SW.W0_INTENT, SW.W_INTENT]
    ensures SW.W0_INTENT.amount == 0 && SW.W_INTENT.amount == 40
    ensures CommittedEffect(SW.W_PRE, MainActs(), SW.W0_INTENT) && CommittedEffect(SW.W_PRE, MainActs(), SW.W_INTENT)
    ensures !VerifyTag(ClaimOf(VF_TOK), VF_TOK.sig)
    ensures Step(Exec(SW.W_PRE, MainActs()[..4]).core, VF_TOK, false).out == Rejected(SignatureInvalid)
    ensures Step(Exec(SW.W_PRE, MainActs()[..5]).core, V_TOK, true).out == Rejected(RequestSettled)
    ensures ApprovedSpec(SW.W_PRE, MainActs(), 0) && ApprovedSpec(SW.W_PRE, MainActs(), 1)
  {
    SigReadingIsTotal();
    forall s: System
      ensures !IdealMac(s)
    {
      TotalVerifierBreaksIdealMacCopy(s);
    }
    MainHyps();
    MainTrace();
    FlatSpecFnMeetsA6();
    SliceSafetyV2(SW.W_PRE, MainActs(), FlatSpecFn);
    PerEntryV2(SW.W_PRE, MainActs(), FlatSpecFn, 0);
    PerEntryV2(SW.W_PRE, MainActs(), FlatSpecFn, 1);
  }

  // ZERO AMOUNT: two zero-amount tokens with different fresh ids both commit under the V2 hypotheses.
  function ZeroActs(): seq<Act>
  {
    [MintAct(ClaimOf(V0_TOK), V0_TOK.sig), Deliver(V0_TOK, true),
     MintAct(ClaimOf(VZ_TOK), VZ_TOK.sig), Deliver(VZ_TOK, true)]
  }

  lemma ZeroHyps()
    requires SigReading()
    ensures A2_MintOnlyOnCheck(ZeroActs())
    ensures A5_VerifierMatchesAtEachDelivery(ZeroActs())
    ensures H1_SignatureAuthenticity(ZeroActs())
  {
    var acts := ZeroActs();
    SigOf(V0_TOK);
    SigOf(VZ_TOK);
    assert VerifyTag(ClaimOf(V0_TOK), V0_TOK.sig);
    assert VerifyTag(ClaimOf(VZ_TOK), VZ_TOK.sig);
    assert SW.W_PRE.(remaining := SW.W_PRE.remaining - 0) == SW.W_PRE;
    assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(V0_TOK));
    assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(VZ_TOK));
    assert ClaimOf(V0_TOK) == CheckedClaim(V0_TOK.pre, SW.CheckedTransition(V0_TOK));
    assert ClaimOf(VZ_TOK) == CheckedClaim(VZ_TOK.pre, SW.CheckedTransition(VZ_TOK));
    forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c)
      ensures exists pre: F.Charge, t2: F.Transition :: F.Authorizes(pre, t2) && acts[k].c == CheckedClaim(pre, t2)
    {
      if k == 0 {
        assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(V0_TOK)) && acts[k].c == CheckedClaim(V0_TOK.pre, SW.CheckedTransition(V0_TOK));
      } else {
        assert k == 2;
        assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(VZ_TOK)) && acts[k].c == CheckedClaim(VZ_TOK.pre, SW.CheckedTransition(VZ_TOK));
      }
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures A5_VerifierMatches(acts[k].tok, acts[k].sigOk)
    {
      assert k == 1 || k == 3;
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver? && VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig)
      ensures SignedBefore(acts, k, ClaimOf(acts[k].tok))
    {
      if k == 1 {
        assert acts[0].MintAct? && acts[0].c == ClaimOf(acts[k].tok);
      } else {
        assert k == 3;
        assert acts[2].MintAct? && acts[2].c == ClaimOf(acts[k].tok);
      }
    }
  }

  lemma ZeroTrace()
    ensures Exec(SW.W_PRE, ZeroActs()).core == Core(SW.W_PRE, {"rq_0", "rq_z"}, [SW.W0_INTENT, VZ_INTENT])
  {
    var acts := ZeroActs();
    var init := SW.W_PRE;
    ExecStep(init, acts, 0);
    ExecStep(init, acts, 1);
    ExecStep(init, acts, 2);
    ExecStep(init, acts, 3);
    assert acts[..0] == [];
    assert acts[..4] == acts;
    var r0 := Exec(init, acts[..0]);
    assert r0 == RunSt(Core(init, {}, []), Sys(init, [], {}, [], {}), []);
    var r1 := Exec(init, acts[..1]);
    assert r1.core == Core(init, {}, []);
    var r2 := Exec(init, acts[..2]);
    assert r2.core == Core(init, {"rq_0"}, [SW.W0_INTENT]);
    var r3 := Exec(init, acts[..3]);
    assert r3.core == r2.core;
    assert "rq_z" !in {"rq_0"};
    var r4 := Exec(init, acts[..4]);
    assert r4.core == Core(init, {"rq_0", "rq_z"}, [SW.W0_INTENT, VZ_INTENT]);
  }

  lemma TwoZeroAmountCommits()
    requires SigReading()
    ensures InitOk(SW.W_PRE)
    ensures A2_MintOnlyOnCheck(ZeroActs())
    ensures A5_VerifierMatchesAtEachDelivery(ZeroActs())
    ensures H1_SignatureAuthenticity(ZeroActs())
    ensures Exec(SW.W_PRE, ZeroActs()).core.outbox == [SW.W0_INTENT, VZ_INTENT]
    ensures SW.W0_INTENT.amount == 0 && VZ_INTENT.amount == 0 && SW.W0_INTENT.requestId != VZ_INTENT.requestId
    ensures Exec(SW.W_PRE, ZeroActs()).core.charge == SW.W_PRE
  {
    ZeroHyps();
    ZeroTrace();
  }

  // ---- hypothesis-necessity refutations (each: the other hypotheses hold, the conclusion fails) ----

  // Drop H1 (authenticity): the adversary presents an UNSIGNED, unapproved claim with a tag that verifies for it
  // (a forgery). A2, A5 and A6 hold; an unapproved effect commits.
  function NoAuthActs(): seq<Act> { [Deliver(VB_TOK, true)] }

  lemma DropAuthenticityBreaksApprovedSpec()
    requires SigReading()
    ensures A2_MintOnlyOnCheck(NoAuthActs())
    ensures A5_VerifierMatchesAtEachDelivery(NoAuthActs())
    ensures A6_ArtifactComputesFlatContract(FlatSpecFn)
    ensures !H1_SignatureAuthenticity(NoAuthActs())
    ensures CommittedEffect(SW.W_PRE, NoAuthActs(), SW.WB_INTENT)
    ensures forall i :: !ApprovedSpec(SW.W_PRE, NoAuthActs(), i)
  {
    var acts := NoAuthActs();
    var init := SW.W_PRE;
    SigOf(VB_TOK);
    assert VerifyTag(ClaimOf(VB_TOK), VB_TOK.sig);
    assert A5_VerifierMatches(acts[0].tok, acts[0].sigOk);
    assert !SignedBefore(acts, 0, ClaimOf(VB_TOK));
    FlatSpecFnMeetsA6();
    ExecStep(init, acts, 0);
    assert acts[..0] == [];
    assert acts[..1] == acts;
    var r0 := Exec(init, acts[..0]);
    assert r0 == RunSt(Core(init, {}, []), Sys(init, [], {}, [], {}), []);
    assert Step(r0.core, VB_TOK, true).out.Committed?;
    var r := Exec(init, acts);
    assert r.core.outbox == [SW.WB_INTENT] && r.toks == [VB_TOK];
    forall i
      ensures !ApprovedSpec(init, acts, i)
    {
      if 0 <= i < |r.toks| {
        assert i == 0;
        assert !R.Eligible(F.ContextOf(VB_TOK.pre, "rq_b"), R.Candidate(61, "duplicate_charge"));
      }
    }
  }

  // Drop A2 (issuance): the issuer signs a claim that Check never issues. H1, A5, A6 hold; an unapproved effect
  // commits.
  lemma DropIssuanceBreaksApprovedSpec()
    requires SigReading()
    ensures H1_SignatureAuthenticity(SW.ActsFor(VB_TOK))
    ensures A5_VerifierMatchesAtEachDelivery(SW.ActsFor(VB_TOK))
    ensures A6_ArtifactComputesFlatContract(FlatSpecFn)
    ensures !A2_MintOnlyOnCheck(SW.ActsFor(VB_TOK))
    ensures CommittedEffect(SW.W_PRE, SW.ActsFor(VB_TOK), SW.WB_INTENT)
    ensures forall i :: !ApprovedSpec(SW.W_PRE, SW.ActsFor(VB_TOK), i)
  {
    SigOf(VB_TOK);
    WitnessFor2(VB_TOK);
    FlatSpecFnMeetsA6();
    var acts := SW.ActsFor(VB_TOK);
    assert acts[0].MintAct? && Ours(acts[0].c);
    forall pre: F.Charge, t: F.Transition | acts[0].c == CheckedClaim(pre, t)
      ensures !F.Authorizes(pre, t)
    {
      assert pre == SW.W_PRE && t.intent == SW.WB_INTENT && t.request.requestId == "rq_b";
    }
    var r := Exec(SW.W_PRE, acts);
    forall i
      ensures !ApprovedSpec(SW.W_PRE, acts, i)
    {
      if 0 <= i < |r.toks| {
        assert i == 0;
        assert !R.Eligible(F.ContextOf(VB_TOK.pre, "rq_b"), R.Candidate(61, "duplicate_charge"));
      }
    }
  }

  // Drop A6 (ValidArtifact): H1, A2, A5 hold; FlatResultAgrees fails for RejectAll.
  lemma DropA6BreaksFlatPath()
    requires SigReading()
    ensures H1_SignatureAuthenticity(SW.ActsFor(V_TOK))
    ensures A2_MintOnlyOnCheck(SW.ActsFor(V_TOK))
    ensures A5_VerifierMatchesAtEachDelivery(SW.ActsFor(V_TOK))
    ensures !A6_ArtifactComputesFlatContract(SW.RejectAll)
    ensures !FlatResultAgrees(SW.RejectAll, SW.W_PRE, SW.ActsFor(V_TOK), 0)
  {
    SigOf(V_TOK);
    assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(V_TOK));
    WitnessFor2(V_TOK);
    var x := FlatInputsOf(SW.W_PRE, SW.W_INTENT);
    assert !FlatContract(x, SW.RejectAll(x)) by {
      U.EncodedEmpty("ch_1");
      U.EncodedEmpty("rq_1");
      U.SameReasons("duplicate_charge");
    }
  }
}
