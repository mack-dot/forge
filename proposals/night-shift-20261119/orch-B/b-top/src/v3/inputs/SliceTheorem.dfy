// M1-B mission, worker Z9. A DRAFT in a scratch folder. NOT approved. NOT gate evidence. M1-B stays OPEN.
// end_to_end=false. A Dafny-MODEL statement only. It says nothing about sink.ts, minter.ts, compiled code,
// the HOL model, CakeML, or native execution.
//
// The owner's target for one refund slice:
//     forall e. Committed(e) ==> ApprovedSpec(e) && ValidArtifact(e) && UniqueAuthorization(e)
// This file states and proves the Dafny-model shape of it, `SliceSafety` below, by REUSE of byte-equal copies:
//   LinkedRefund.dfy             (LinkedRefund refines RefundSpec; Unflatten; DecodeEncoded)
//   transport/sink/SinkCore.dfy  (SinkCore refines FinalityProtocol; Step; Rel; RefundSliceShape)
//   transport/impl/RefundFinality.dfy (Check; Authorizes, which uses the approved Refund.Eligible)
// Nothing in those files is changed or retyped. The one restatement is FlatContract (the three ensures of
// FlatRefund.AssessFlat as a predicate); methods FlatContractFromAssessFlat and FlatContractIsAssessFlat prove
// that it is EQUAL to the AssessFlat contract (both directions, through calls of AssessFlat).
//
// Assumptions. Each one is a named predicate or a parameter in the statement of SliceSafety:
//   A1 A1_IdealMacAtEachDelivery  the model's IdealMac holds at the state before each delivery of a token.
//   A2 A2_MintOnlyOnCheck         each minted claim for our ids is the claim of a transition that
//                                 RefundFinality.Check issues a token for (CheckDecidesMint proves that
//                                 Check issues exactly when F.Authorizes holds).
//   A3 atomic commit              STRUCTURAL: Exec applies each Deliver as ONE Next step (SinkCore.Step together
//                                 with the model's Commit). It is not a predicate; it is the reachability relation.
//   A5 A5_VerifierMatchesAtEachDelivery  the crypto layer's boolean equals the uninterpreted VerifyTag.
//   A6 A6_ArtifactComputesFlatContract(art)  the artifact's flat function satisfies the flat contract on
//                                 every input. NOT proved anywhere. It is the ValidArtifact hypothesis.
//   A7 Dafny<->HOL link           the PARAMETER `art` stands for the HOL function refund_fields as read
//                                 through the export semantics. Dafny cannot state this; A6 is what the HOL
//                                 theorem (Route D step 4, not done) plus the export reading must give.
//   (A4 faithful state is not used: the core compares charge VALUES, not hashes.)
// Uninterpreted symbol: VerifyTag (FinalityProtocol, inherited bodiless into SinkCore; used here through the import).
include "LinkedRefund.dfy"
include "transport/sink/SinkCore.dfy"

// SliceTheorem IMPORTS SinkCore (it does not refine it): `module X refines SinkCore {}` crashes the pinned
// Dafny 4.11.0 resolver (NullReferenceException in PrecedenceLinter.PreResolve), see the report.
module SliceTheorem {
  import opened SinkCore
  import L = LinkedRefund
  import U = RefundUnicode
  import FR = FlatRefund

  // ---------------------------------------------------------------------------------------------
  // The artifact boundary: flat inputs, flat outputs, the flat contract.
  datatype FlatIn = FlatIn(chargeB: string, requestB: string, original: int, remaining: int,
                           enabled: bool, requestOpen: bool, candidate: bool, amount: int, reasonB: string)
  type FlatFn = FlatIn -> L.FlatTuple

  // The three ensures of FlatRefund.AssessFlat (FlatCore.dfy), as a predicate.
  predicate FlatContract(x: FlatIn, o: L.FlatTuple)
  {
    (o.0 <==>
      x.chargeB != "" && x.requestB != "" && x.enabled && x.requestOpen &&
      0 <= x.original <= 9223372036854775807 && 0 <= x.remaining <= x.original &&
      x.candidate && 0 <= x.amount <= x.remaining &&
      (x.reasonB == "duplicate_charge" || x.reasonB == "service_not_delivered" || x.reasonB == "returned_item")) &&
    (o.0 ==> o.1 == x.amount && o.2 == x.reasonB && o.3 == x.chargeB && o.4 == x.requestB && o.5 == 1) &&
    (!o.0 ==> o.1 == 0 && o.2 == "" && o.3 == "" && o.4 == "" && o.5 == 0)
  }

  // FlatContract is no stronger than the AssessFlat contract.
  method FlatContractFromAssessFlat(x: FlatIn) returns (o: L.FlatTuple)
    ensures FlatContract(x, o)
  {
    var ok, a, rb, cb, qb, n := FR.AssessFlat(x.chargeB, x.requestB, x.original, x.remaining, x.enabled,
                                              x.requestOpen, x.candidate, x.amount, x.reasonB);
    o := (ok, a, rb, cb, qb, n);
  }

  // FlatContract is no weaker: every tuple it allows equals every tuple the AssessFlat contract allows.
  method FlatContractIsAssessFlat(x: FlatIn, o: L.FlatTuple) returns (o2: L.FlatTuple)
    requires FlatContract(x, o)
    ensures o2 == o
  {
    var ok, a, rb, cb, qb, n := FR.AssessFlat(x.chargeB, x.requestB, x.original, x.remaining, x.enabled,
                                              x.requestOpen, x.candidate, x.amount, x.reasonB);
    o2 := (ok, a, rb, cb, qb, n);
  }

  // A6, named. The ValidArtifact hypothesis. NOT proved.
  ghost predicate A6_ArtifactComputesFlatContract(art: FlatFn)
  {
    forall x: FlatIn :: FlatContract(x, art(x))
  }

  // The flat inputs for a pre-state and an intent: the same encoding that LinkedRefund.Assess uses for
  // context F.ContextOf(pre, e.requestId) and response Candidate(e.amount, e.reason).
  function FlatInputsOf(pre: F.Charge, e: R.RefundIntent): FlatIn
  {
    FlatIn(U.Encoded(pre.chargeId), U.Encoded(e.requestId), pre.original, pre.remaining, pre.refundEnabled,
           true, true, e.amount, U.Encoded(e.reason))
  }

  // ---------------------------------------------------------------------------------------------
  // Reachability: an adversary-chosen sequence of mints and deliveries from the initial store.
  datatype Act = MintAct(c: Claim, tag: Tag) | Deliver(tok: SinkToken, sigOk: bool)
  datatype RunSt = RunSt(core: Core, s: System, toks: seq<SinkToken>)

  function CheckedClaim(pre: F.Charge, t: F.Transition): Claim
  {
    ClaimOf(SinkToken(PINNED_SPEC, PINNED_CHK, pre, t.request.requestId, t.post, t.intent, ""))
  }

  // One action. A mint adds (claim, tag) to the minted set with NO check here (A2 restricts it).
  // A delivery runs the executable SinkCore.Step on the core and the model's Commit on the model state.
  ghost function Next(r: RunSt, a: Act): RunSt
  {
    match a
    case MintAct(c, tag) => RunSt(r.core, r.s.(minted := r.s.minted + {(c, tag)}), r.toks)
    case Deliver(tok, sigOk) =>
      var res := Step(r.core, tok, sigOk);
      RunSt(res.core, Commit(r.s, ClaimOf(tok), tok.sig), NextToks(r.toks, tok, res.out))
  }

  ghost function Exec(init: State, acts: seq<Act>): RunSt
    decreases |acts|
  {
    if |acts| == 0 then RunSt(Core(init, {}, []), Sys(init, [], {}, [], {}), [])
    else Next(Exec(init, acts[..|acts| - 1]), acts[|acts| - 1])
  }

  // ---- the named assumptions over a trace ----
  ghost predicate A1_IdealMacAtEachDelivery(init: State, acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? :: IdealMac(Exec(init, acts[..k]).s)
  }

  ghost predicate A2_MintOnlyOnCheck(acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c) ::
      exists pre: F.Charge, t: F.Transition :: F.Authorizes(pre, t) && acts[k].c == CheckedClaim(pre, t)
  }

  ghost predicate A5_VerifierMatchesAtEachDelivery(acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? :: A5_VerifierMatches(acts[k].tok, acts[k].sigOk)
  }

  // ---- the conclusions ----
  ghost predicate CommittedEffect(init: State, acts: seq<Act>, e: R.RefundIntent)
  {
    e in Exec(init, acts).core.outbox
  }

  // Delivery k committed outbox entry i, and the stored charge at that moment equals the token's pre-state.
  ghost predicate CommittedAt(init: State, acts: seq<Act>, k: int, i: int)
  {
    0 <= k < |acts| && acts[k].Deliver? &&
    var before := Exec(init, acts[..k]);
    |before.toks| == i &&
    Step(before.core, acts[k].tok, acts[k].sigOk).out.Committed? &&
    before.core.charge == acts[k].tok.pre &&
    acts[k].tok.requestId !in before.core.settled &&
    i < |Exec(init, acts).toks| && Exec(init, acts).toks[i] == acts[k].tok
  }

  ghost predicate HasCommitWitness(init: State, acts: seq<Act>, i: int)
  {
    exists k :: CommittedAt(init, acts, k, i)
  }

  // ApprovedSpec: the approved eligibility (Refund.Eligible, inherited unchanged from RefundSpec) holds for the
  // STORED charge at commit time and the intent's request; Authorizes also fixes the post-state and the intent.
  ghost predicate ApprovedSpec(init: State, acts: seq<Act>, i: int)
  {
    var r := Exec(init, acts);
    0 <= i < |r.toks| && i < |r.core.outbox| &&
    var tok := r.toks[i];
    var e := r.core.outbox[i];
    HasCommitWitness(init, acts, i) &&
    e == tok.intent && e.requestId == tok.requestId && e.chargeId == tok.pre.chargeId &&
    R.Eligible(F.ContextOf(tok.pre, e.requestId), R.Candidate(e.amount, e.reason)) &&
    F.Authorizes(tok.pre, F.Transition(F.Request(e.requestId, e.amount, e.reason), tok.post, e))
  }

  // The flat-result path: the artifact's flat result on the encoded inputs, decoded by LinkedRefund.Unflatten,
  // is exactly the approved result (Authorized(amount, reason), [the intent]).
  ghost predicate FlatResultAgrees(art: FlatFn, init: State, acts: seq<Act>, i: int)
  {
    var r := Exec(init, acts);
    0 <= i < |r.toks| && i < |r.core.outbox| &&
    var e := r.core.outbox[i];
    var o := art(FlatInputsOf(r.toks[i].pre, e));
    L.Unflatten(o.0, o.1, o.2, o.3, o.4, o.5) ==
      (L.Authorized(e.amount, e.reason), [L.Intent(e.chargeId, e.requestId, e.amount, e.reason)])
  }

  ghost predicate UniqueAuthorization(init: State, acts: seq<Act>, i: int)
  {
    var r := Exec(init, acts);
    0 <= i < |r.toks| && |r.toks| == |r.s.log| == |r.core.outbox| &&
    r.s.log[i] == ClaimOf(r.toks[i]) && VerifyTag(r.s.log[i], r.toks[i].sig) &&
    (r.s.log[i], r.toks[i].sig) in r.s.minted &&
    r.core.outbox[i].requestId == r.toks[i].requestId && r.toks[i].requestId in r.core.settled &&
    (forall j | 0 <= j < |r.core.outbox| && j != i ::
       r.core.outbox[j].requestId != r.core.outbox[i].requestId && r.toks[j] != r.toks[i])
  }

  // ---------------------------------------------------------------------------------------------
  // Proofs.
  lemma CheckedClaimAllowed(pre: F.Charge, t: F.Transition)
    requires F.Authorizes(pre, t)
    ensures MintAllowed(CheckedClaim(pre, t)) && Ours(CheckedClaim(pre, t))
  {
    assert F.Request(t.request.requestId, t.intent.amount, t.intent.reason) == t.request;
    assert F.Transition(t.request, t.post, t.intent) == t;
  }

  // A2 in terms of the proved checker: Check issues a token exactly when F.Authorizes holds, and the claim
  // built from the issued token is CheckedClaim.
  method CheckDecidesMint(pre: F.Charge, preStateHash: string, t: F.Transition)
      returns (mint: bool, ghost c: Claim)
    ensures mint <==> F.Authorizes(pre, t)
    ensures mint ==> c == CheckedClaim(pre, t) && MintAllowed(c) && Ours(c)
  {
    var verdict, plan := F.Check(pre, preStateHash, t);
    mint := verdict.Issue?;
    c := CheckedClaim(pre, t);
    if mint {
      var tk := verdict.token;
      assert c == ClaimOf(SinkToken(PINNED_SPEC, PINNED_CHK, pre, tk.requestId, tk.post, tk.intent, ""));
      CheckedClaimAllowed(pre, t);
    }
  }

  lemma PrefixHyps(init: State, acts: seq<Act>)
    requires |acts| > 0
    requires A1_IdealMacAtEachDelivery(init, acts) && A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts)
    ensures var p := acts[..|acts| - 1];
      A1_IdealMacAtEachDelivery(init, p) && A2_MintOnlyOnCheck(p) && A5_VerifierMatchesAtEachDelivery(p)
  {
    var p := acts[..|acts| - 1];
    forall k | 0 <= k < |p|
      ensures p[k] == acts[k] && p[..k] == acts[..k]
    {
    }
  }

  lemma ExecInv(init: State, acts: seq<Act>)
    requires A1_IdealMacAtEachDelivery(init, acts) && A2_MintOnlyOnCheck(acts) && A5_VerifierMatchesAtEachDelivery(acts)
    ensures Rel(Exec(init, acts).core, Exec(init, acts).s, Exec(init, acts).toks)
    ensures Inv(init, Exec(init, acts).s)
    ensures |Exec(init, acts).toks| > 0 ==> IdealMac(Exec(init, acts).s)
    decreases |acts|
  {
    if |acts| == 0 {
      InitInv(init);
      InitRel(init);
    } else {
      var n := |acts|;
      var p := acts[..n - 1];
      PrefixHyps(init, acts);
      ExecInv(init, p);
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
      case Deliver(tok, sigOk) =>
        assert acts[n - 1].Deliver?;
        assert acts[..n - 1] == p;
        assert IdealMac(r.s);
        assert A5_VerifierMatches(tok, sigOk);
        StepPreservesInv(init, r.core, r.s, r.toks, tok, sigOk);
    }
  }

  lemma ExecCommitWitness(init: State, acts: seq<Act>)
    ensures forall i | 0 <= i < |Exec(init, acts).toks| :: HasCommitWitness(init, acts, i)
    decreases |acts|
  {
    if |acts| > 0 {
      var n := |acts|;
      var p := acts[..n - 1];
      ExecCommitWitness(init, p);
      var r := Exec(init, p);
      var r' := Exec(init, acts);
      assert r' == Next(r, acts[n - 1]);
      assert |r.toks| <= |r'.toks| && r'.toks[..|r.toks|] == r.toks;
      forall i | 0 <= i < |r'.toks|
        ensures HasCommitWitness(init, acts, i)
      {
        if i < |r.toks| {
          assert HasCommitWitness(init, p, i);
          var k :| CommittedAt(init, p, k, i);
          assert acts[..k] == p[..k];
          assert acts[k] == p[k];
          assert r'.toks[i] == r.toks[i];
          assert CommittedAt(init, acts, k, i);
        } else {
          assert acts[n - 1].Deliver?;
          assert acts[..n - 1] == p;
          assert CommittedAt(init, acts, n - 1, i);
        }
      }
    }
  }

  lemma FlatPath(art: FlatFn, pre: F.Charge, req: F.Request, post: F.Charge, e: R.RefundIntent)
    requires A6_ArtifactComputesFlatContract(art)
    requires F.Authorizes(pre, F.Transition(req, post, e))
    ensures var o := art(FlatInputsOf(pre, e));
      L.Unflatten(o.0, o.1, o.2, o.3, o.4, o.5) ==
        (L.Authorized(e.amount, e.reason), [L.Intent(e.chargeId, e.requestId, e.amount, e.reason)])
  {
    var x := FlatInputsOf(pre, e);
    var o := art(x);
    assert FlatContract(x, o);
    U.EncodedEmpty(pre.chargeId);
    U.EncodedEmpty(e.requestId);
    U.SameReasons(e.reason);
    assert o.0;
    L.DecodeEncoded(e.reason);
    L.DecodeEncoded(pre.chargeId);
    L.DecodeEncoded(e.requestId);
  }

  lemma PerEntry(init: State, acts: seq<Act>, art: FlatFn, i: int)
    requires InitOk(init)
    requires A1_IdealMacAtEachDelivery(init, acts)
    requires A2_MintOnlyOnCheck(acts)
    requires A5_VerifierMatchesAtEachDelivery(acts)
    requires A6_ArtifactComputesFlatContract(art)
    requires 0 <= i < |Exec(init, acts).core.outbox|
    ensures ApprovedSpec(init, acts, i) && FlatResultAgrees(art, init, acts, i) && UniqueAuthorization(init, acts, i)
  {
    var r := Exec(init, acts);
    ExecInv(init, acts);
    ExecCommitWitness(init, acts);
    InvMeaning(init, r.s);
    assert |r.toks| == |r.s.log| == |r.core.outbox|;
    RefundSliceShape(init, r.core, r.s, r.toks);
    var tok := r.toks[i];
    assert r.s.log[i] == ClaimOf(tok);
    assert r.s.outbox[i] == r.s.log[i].eff;
    assert SpecRel(r.s.log[i].pre, r.s.log[i].req, r.s.log[i].post, r.s.log[i].eff);
    FlatPath(art, tok.pre, F.Request(tok.requestId, tok.intent.amount, tok.intent.reason), tok.post, tok.intent);
    assert r.s.log[i].reqId in r.s.settled;
    EncSetMember(r.core.settled, tok.requestId);
  }

  // =============================================================================================
  // THE COMPOSED THEOREM (Dafny model only).
  lemma SliceSafety(init: State, acts: seq<Act>, art: FlatFn)
    requires InitOk(init)
    requires A1_IdealMacAtEachDelivery(init, acts)
    requires A2_MintOnlyOnCheck(acts)
    requires A5_VerifierMatchesAtEachDelivery(acts)
    requires A6_ArtifactComputesFlatContract(art)
    ensures forall e | CommittedEffect(init, acts, e) ::
      exists i :: (0 <= i < |Exec(init, acts).core.outbox| && Exec(init, acts).core.outbox[i] == e &&
        ApprovedSpec(init, acts, i) && FlatResultAgrees(art, init, acts, i) && UniqueAuthorization(init, acts, i))
    ensures 0 <= Exec(init, acts).core.charge.remaining <= Exec(init, acts).core.charge.original == init.original
    ensures SumIntents(Exec(init, acts).core.outbox) == init.remaining - Exec(init, acts).core.charge.remaining
  {
    var r := Exec(init, acts);
    ExecInv(init, acts);
    InvMeaning(init, r.s);
    if |r.toks| > 0 {
      RefundSliceShape(init, r.core, r.s, r.toks);
    } else {
      assert r.core.outbox == [];
    }
    forall e | CommittedEffect(init, acts, e)
      ensures exists i :: (0 <= i < |r.core.outbox| && r.core.outbox[i] == e &&
        ApprovedSpec(init, acts, i) && FlatResultAgrees(art, init, acts, i) && UniqueAuthorization(init, acts, i))
    {
      var i :| 0 <= i < |r.core.outbox| && r.core.outbox[i] == e;
      PerEntry(init, acts, art, i);
    }
  }

  // ---------------------------------------------------------------------------------------------
  // What ApprovedSpec means for the approved Assess (R1-R5), in both refinements of RefundSpec.
  method ApprovedResultRefund(pre: F.Charge, e: R.RefundIntent) returns (d: R.Decision, p: seq<R.RefundIntent>)
    requires R.Eligible(F.ContextOf(pre, e.requestId), R.Candidate(e.amount, e.reason)) && e.chargeId == pre.chargeId
    ensures d == R.Authorized(e.amount, e.reason) && p == [e]
  {
    d, p := R.Assess(F.ContextOf(pre, e.requestId), R.Candidate(e.amount, e.reason));
  }

  method ApprovedResultLinked(pre: F.Charge, e: R.RefundIntent) returns (d: L.Decision, p: seq<L.RefundIntent>)
    requires R.Eligible(F.ContextOf(pre, e.requestId), R.Candidate(e.amount, e.reason)) && e.chargeId == pre.chargeId
    ensures d == L.Authorized(e.amount, e.reason) && p == [L.Intent(e.chargeId, e.requestId, e.amount, e.reason)]
  {
    var ctx := L.ChargeContext(pre.chargeId, e.requestId, pre.original, pre.remaining, pre.refundEnabled, true);
    assert L.Eligible(ctx, L.Candidate(e.amount, e.reason));
    d, p := L.Assess(ctx, L.Candidate(e.amount, e.reason));
  }

  // A flat function that meets A6 (used by the witness).
  function FlatSpecFn(x: FlatIn): L.FlatTuple
  {
    if x.chargeB != "" && x.requestB != "" && x.enabled && x.requestOpen &&
       0 <= x.original <= 9223372036854775807 && 0 <= x.remaining <= x.original &&
       x.candidate && 0 <= x.amount <= x.remaining &&
       (x.reasonB == "duplicate_charge" || x.reasonB == "service_not_delivered" || x.reasonB == "returned_item")
    then (true, x.amount, x.reasonB, x.chargeB, x.requestB, 1)
    else (false, 0, "", "", "", 0)
  }

  lemma FlatSpecFnMeetsA6()
    ensures A6_ArtifactComputesFlatContract(FlatSpecFn)
  {
  }
}

// Non-vacuity and refutations. VerifyTag is uninterpreted in SinkCore and cannot get a body here (refinement of
// SinkCore crashes the pinned Dafny). So each lemma below is CONDITIONAL on one reading of VerifyTag, named
// TagReading(tok): a tag verifies only for the claim of the one token `tok`. That such a reading is consistent is
// a fact about uninterpreted predicates (any predicate is a model); it is NOT a Dafny-checked fact.
module SliceWitness {
  import opened SinkCore
  import opened SliceTheorem

  const W_PRE: F.Charge := F.Charge("ch_1", 100, 60, true)
  const W_POST: F.Charge := F.Charge("ch_1", 100, 20, true)
  const W_INTENT: R.RefundIntent := R.Intent("ch_1", "rq_1", 40, "duplicate_charge")
  const W_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, W_PRE, "rq_1", W_POST, W_INTENT, "sig_w")
  // A zero-amount token: the post-state equals the pre-state.
  const W0_INTENT: R.RefundIntent := R.Intent("ch_1", "rq_0", 0, "duplicate_charge")
  const W0_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, W_PRE, "rq_0", W_PRE, W0_INTENT, "sig_0")
  // A token that Check never issues: 61 > remaining 60.
  const WB_INTENT: R.RefundIntent := R.Intent("ch_1", "rq_b", 61, "duplicate_charge")
  const WB_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, W_PRE, "rq_b", F.Charge("ch_1", 100, -1, true),
                                       WB_INTENT, "sig_b")

  ghost predicate TagReading(tok: SinkToken)
  {
    forall c: Claim, t: Tag :: VerifyTag(c, t) <==> (c == ClaimOf(tok) && t == tok.sig)
  }

  function ActsFor(tok: SinkToken): seq<Act>
  {
    [MintAct(ClaimOf(tok), tok.sig), Deliver(tok, true)]
  }

  function CheckedTransition(tok: SinkToken): F.Transition
  {
    F.Transition(F.Request(tok.requestId, tok.intent.amount, tok.intent.reason), tok.post, tok.intent)
  }

  function RejectAll(x: FlatIn): L.FlatTuple
  {
    (false, 0, "", "", "", 0)
  }

  // A two-action trace (mint the token's claim, deliver the token) under TagReading(tok).
  lemma WitnessFor(tok: SinkToken)
    requires TagReading(tok)
    requires tok.specId == PINNED_SPEC && tok.checkerId == PINNED_CHK
    ensures A1_IdealMacAtEachDelivery(tok.pre, ActsFor(tok))
    ensures A5_VerifierMatchesAtEachDelivery(ActsFor(tok))
    ensures Exec(tok.pre, ActsFor(tok)).core.outbox == [tok.intent]
    ensures Exec(tok.pre, ActsFor(tok)).toks == [tok]
    ensures CommittedEffect(tok.pre, ActsFor(tok), tok.intent)
    ensures F.Authorizes(tok.pre, CheckedTransition(tok)) ==> A2_MintOnlyOnCheck(ActsFor(tok))
  {
    var acts := ActsFor(tok);
    var init := tok.pre;
    if F.Authorizes(tok.pre, CheckedTransition(tok)) {
      assert ClaimOf(tok) == CheckedClaim(tok.pre, CheckedTransition(tok));
      forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c)
        ensures exists pre: F.Charge, t2: F.Transition :: F.Authorizes(pre, t2) && acts[k].c == CheckedClaim(pre, t2)
      {
        assert k == 0;
        assert F.Authorizes(tok.pre, CheckedTransition(tok)) && acts[k].c == CheckedClaim(tok.pre, CheckedTransition(tok));
      }
    }
    assert acts[..0] == [];
    assert acts[..1] == [acts[0]];
    assert acts[..2] == acts;
    var r0 := Exec(init, acts[..0]);
    assert r0 == RunSt(Core(init, {}, []), Sys(init, [], {}, [], {}), []);
    var r1 := Exec(init, acts[..1]);
    assert r1 == Next(r0, acts[0]);
    assert r1.s.minted == {(ClaimOf(tok), tok.sig)};
    assert IdealMac(r1.s);
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures IdealMac(Exec(init, acts[..k]).s) && A5_VerifierMatches(acts[k].tok, acts[k].sigOk)
    {
      assert k == 1;
    }
    var r2 := Exec(init, acts);
    assert r2 == Next(r1, acts[1]);
    assert r1.core == Core(init, {}, []);
    assert Step(r1.core, tok, true).out.Committed?;
  }

  // Non-vacuity: every hypothesis of SliceSafety holds and exactly one effect is committed.
  lemma Witness()
    requires TagReading(W_TOK)
    ensures InitOk(W_PRE)
    ensures A1_IdealMacAtEachDelivery(W_PRE, ActsFor(W_TOK))
    ensures A2_MintOnlyOnCheck(ActsFor(W_TOK))
    ensures A5_VerifierMatchesAtEachDelivery(ActsFor(W_TOK))
    ensures A6_ArtifactComputesFlatContract(FlatSpecFn)
    ensures Exec(W_PRE, ActsFor(W_TOK)).core.outbox == [W_INTENT]
    ensures CommittedEffect(W_PRE, ActsFor(W_TOK), W_INTENT)
  {
    assert F.Authorizes(W_PRE, CheckedTransition(W_TOK));
    WitnessFor(W_TOK);
    FlatSpecFnMeetsA6();
    SliceSafety(W_PRE, ActsFor(W_TOK), FlatSpecFn);
  }

  // Refutation of "every commit changes the store": all hypotheses hold, and the one committed token has
  // post-state == pre-state (zero amount).
  lemma ZeroAmountCommitKeepsStore()
    requires TagReading(W0_TOK)
    ensures InitOk(W_PRE)
    ensures A1_IdealMacAtEachDelivery(W_PRE, ActsFor(W0_TOK))
    ensures A2_MintOnlyOnCheck(ActsFor(W0_TOK))
    ensures A5_VerifierMatchesAtEachDelivery(ActsFor(W0_TOK))
    ensures A6_ArtifactComputesFlatContract(FlatSpecFn)
    ensures |Exec(W_PRE, ActsFor(W0_TOK)).toks| == 1
    ensures Exec(W_PRE, ActsFor(W0_TOK)).toks[0].post == Exec(W_PRE, ActsFor(W0_TOK)).toks[0].pre
    ensures Exec(W_PRE, ActsFor(W0_TOK)).core.charge == W_PRE
  {
    assert W_PRE.(remaining := W_PRE.remaining - 0) == W_PRE;
    assert F.Authorizes(W_PRE, CheckedTransition(W0_TOK));
    WitnessFor(W0_TOK);
    FlatSpecFnMeetsA6();
  }

  // Without A6 the flat-result conjunct is false for some artifact while A1, A2, A5 hold.
  lemma WrongArtifactBreaksFlatPath()
    requires TagReading(W_TOK)
    ensures A1_IdealMacAtEachDelivery(W_PRE, ActsFor(W_TOK))
    ensures A2_MintOnlyOnCheck(ActsFor(W_TOK))
    ensures A5_VerifierMatchesAtEachDelivery(ActsFor(W_TOK))
    ensures !A6_ArtifactComputesFlatContract(RejectAll)
    ensures !FlatResultAgrees(RejectAll, W_PRE, ActsFor(W_TOK), 0)
  {
    assert F.Authorizes(W_PRE, CheckedTransition(W_TOK));
    WitnessFor(W_TOK);
    var x := FlatInputsOf(W_PRE, W_INTENT);
    assert !FlatContract(x, RejectAll(x)) by {
      U.EncodedEmpty("ch_1");
      U.EncodedEmpty("rq_1");
      U.SameReasons("duplicate_charge");
    }
  }

  // Without A2 (a mint that Check never issues) the committed effect is NOT approved, while A1 and A5 hold.
  lemma UncheckedMintBreaksApprovedSpec()
    requires TagReading(WB_TOK)
    ensures A1_IdealMacAtEachDelivery(W_PRE, ActsFor(WB_TOK))
    ensures A5_VerifierMatchesAtEachDelivery(ActsFor(WB_TOK))
    ensures !A2_MintOnlyOnCheck(ActsFor(WB_TOK))
    ensures CommittedEffect(W_PRE, ActsFor(WB_TOK), WB_INTENT)
    ensures !ApprovedSpec(W_PRE, ActsFor(WB_TOK), 0)
  {
    WitnessFor(WB_TOK);
    var acts := ActsFor(WB_TOK);
    assert acts[0].MintAct? && Ours(acts[0].c);
    forall pre: F.Charge, t: F.Transition | acts[0].c == CheckedClaim(pre, t)
      ensures !F.Authorizes(pre, t)
    {
      assert pre == W_PRE && t.intent == WB_INTENT && t.request.requestId == "rq_b";
    }
  }
}
