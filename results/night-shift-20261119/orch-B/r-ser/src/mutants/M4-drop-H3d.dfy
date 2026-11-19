// Night shift 2026-11-19, Orchestrator B, task b-ser. A DRAFT in an evidence folder. NOT gate evidence.
// M1-B stays OPEN. A Dafny-MODEL statement only (no claim about sink.ts, minter.ts, Ed25519, SHA-256, Node).
//
// It repairs the byte layer of SliceSafetyV2 (b-signing/SliceSafetyV2.dfy, items H3a/H3b) after review
// r-signing (ByteAttacks.PreStateCollisionBreaksApprovedSpec: H3a over ALL claims is false for the real
// serializer, because the signed body holds a HASH of the pre-state and the two pinned ids as hex texts).
//  - RealSer: the concrete serializer of SerModel.dfy (mirror of encoding.ts) applied to the body that a
//    claim reads as. The pre-state enters only as H(pre); the ids only as IdHex(id).
//  - H3a is now a LEMMA (ClaimInjectiveInRun), on parseable claims, under a TRACE-LOCAL hash hypothesis A4.
//  - A4_NoCollisionInRun: no minted claim and no delivered token in THIS trace have different pre-states (or
//    ids) with the same hash text. Realizable; computational (SHA-256 collision resistance); not global.
//  - SliceSafetyV2BytesRepaired: V2 conclusions from A2, H3b, H3c, H1B, B5, A4, the parse hypotheses, A6b.
//  - Controls: drop A4 => the reviewer's collision commits an unapproved effect (CollisionControl).
//  - Witness (conditional on the reading H3c of the uninterpreted VerifyTag, as in SliceWitnessV2): a total
//    byte verifier; a zero-amount and a positive effect commit; a forged tag is rejected.
//  - IssueBytes: a method that calls F.Check and returns RealSer(CheckedClaim(pre, t)) only on Issue.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "../SerModel.dfy"
include "../../b-signing/SliceSafetyV2OnBytes.dfy"

module RepairedBytes {
  import opened SinkCore
  import opened SliceTheorem
  import opened SliceTheoremV2
  import opened SliceTheoremV2B
  import SW = SliceWitness
  import SM = SerModel

  type HashFn = F.Charge -> string
  type IdFn = int -> string

  // ---- the body that a claim reads as (minter.ts:53-56 builds the same fields from Check's token) ----
  function Nat(x: int): nat { if x >= 0 then x else 0 }
  function StateOf(c: F.Charge): SM.ChargeState
  {
    SM.ChargeState(c.chargeId, Nat(c.original), Nat(c.remaining), c.refundEnabled)
  }
  function IntentOf(i: R.RefundIntent): SM.Intent
  {
    SM.Intent(i.chargeId, i.requestId, Nat(i.amount), i.reason)
  }
  function BodyOfClaim(H: HashFn, idHex: IdFn, c: Claim): SM.TokenBody
  {
    SM.TokenBody(SM.DOMAIN, idHex(c.specId), idHex(c.checkerId), H(c.pre), c.req.requestId, StateOf(c.post), IntentOf(c.eff))
  }
  function ToMsg(u: seq<int>): Msg
  {
    seq(|u|, i requires 0 <= i < |u| => (u[i] % 256) as bv8)
  }
  // The concrete serializer: UTF-8 bytes of canon(body) (encoding.ts:81).
  opaque function RealSerOf(H: HashFn, idHex: IdFn, c: Claim): Msg { ToMsg(SM.Utf8(SM.SerBody(BodyOfClaim(H, idHex, c)))) }
  lemma RealSerOfDef(H: HashFn, idHex: IdFn, c: Claim)
    ensures RealSerOf(H, idHex, c) == ToMsg(SM.Utf8(SM.SerBody(BodyOfClaim(H, idHex, c))))
  { reveal RealSerOf(); }
  lemma RealSerOfSameBody(H: HashFn, idHex: IdFn, c1: Claim, c2: Claim)
    requires BodyOfClaim(H, idHex, c1) == BodyOfClaim(H, idHex, c2)
    ensures RealSerOf(H, idHex, c1) == RealSerOf(H, idHex, c2)
  { reveal RealSerOf(); }
  function RealSer(H: HashFn, idHex: IdFn): SerFn { (c: Claim) => RealSerOf(H, idHex, c) }

  // ---- parseable claims: what isTokenBody (encoding.ts:64-68) lets through, read as a claim ----
  predicate MoneyOk(x: int) { 0 <= x < SM.MONEY_BOUND }
  opaque predicate ParseableClaim(c: Claim)
  {
    c.reqId == Enc(c.req.requestId) && c.req == F.Request(c.req.requestId, c.eff.amount, c.eff.reason) &&
    MoneyOk(c.post.original) && MoneyOk(c.post.remaining) && MoneyOk(c.eff.amount) &&
    SM.Text(c.req.requestId) && SM.Text(c.post.chargeId) && SM.Text(c.eff.chargeId) &&
    SM.Text(c.eff.requestId) && SM.Text(c.eff.reason)
  }
  opaque predicate ParseableTok(tok: SinkToken)
  {
    MoneyOk(tok.post.original) && MoneyOk(tok.post.remaining) && MoneyOk(tok.intent.amount) &&
    SM.Text(tok.requestId) && SM.Text(tok.post.chargeId) && SM.Text(tok.intent.chargeId) &&
    SM.Text(tok.intent.requestId) && SM.Text(tok.intent.reason)
  }
  lemma ParseableTokClaim(tok: SinkToken)
    requires ParseableTok(tok)
    ensures ParseableClaim(ClaimOf(tok))
  { reveal ParseableTok(), ParseableClaim(); }

  // ---- the named hypotheses that replace H3a ----
  // H3d (replaces the shape part of H3a): every minted claim is the reading of a body that isTokenBody accepts.
  // Code support (unproved glue): minter.ts:81 isTransition and minter.ts:61 isTokenBody before signing.
  ghost predicate H3d_MintsParseable(acts: seq<Act>)
  {
    forall j | 0 <= j < |acts| && acts[j].MintAct? :: ParseableClaim(acts[j].c)
  }
  // B6: every delivered token is the reading of a body that the sink parsed (sink.ts:81-83 refuses others
  // before any signature check or store access).
  ghost predicate B6_DeliveriesParseable(acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? :: ParseableTok(acts[k].tok)
  }
  // A4 (trace-local, computational): no minted claim and delivered token of THIS trace have different
  // pre-states with the same hash text, or different ids with the same id text.
  ghost predicate A4_NoCollisionInRun(H: HashFn, idHex: IdFn, acts: seq<Act>)
  {
    forall j, k | 0 <= j < |acts| && 0 <= k < |acts| && acts[j].MintAct? && acts[k].Deliver? ::
      (H(acts[j].c.pre) == H(acts[k].tok.pre) ==> acts[j].c.pre == acts[k].tok.pre) &&
      (idHex(acts[j].c.specId) == idHex(acts[k].tok.specId) ==> acts[j].c.specId == acts[k].tok.specId) &&
      (idHex(acts[j].c.checkerId) == idHex(acts[k].tok.checkerId) ==> acts[j].c.checkerId == acts[k].tok.checkerId)
  }
  // A4b (NOT used by any proof here; named for the sink.ts <-> SinkCore.Step relation): the stored state at a
  // delivery and the token's pre-state do not collide. sink.ts:102 compares HASHES; Step compares VALUES.
  ghost predicate A4b_NoStoredStateCollision(H: HashFn, init: State, acts: seq<Act>)
  {
    forall k | 0 <= k < |acts| && acts[k].Deliver? ::
      H(Exec(init, acts[..k]).core.charge) == H(acts[k].tok.pre) ==> Exec(init, acts[..k]).core.charge == acts[k].tok.pre
  }

  // =============================================================================================
  // H3a as a LEMMA: on parseable claims, equal signed bytes give equal claims, given no hash collision.
  lemma Utf8CharRange(c: char)
    ensures forall i | 0 <= i < |SM.Utf8Char(c)| :: 0 <= SM.Utf8Char(c)[i] < 256
  {
    var v := c as int;
    assert v <= 0x10FFFF;
  }
  lemma Utf8Range(s: string)
    ensures forall i | 0 <= i < |SM.Utf8(s)| :: 0 <= SM.Utf8(s)[i] < 256
    decreases |s|
  {
    if |s| > 0 {
      Utf8CharRange(s[0]);
      Utf8Range(s[1..]);
      var a := SM.Utf8Char(s[0]);
      var b := SM.Utf8(s[1..]);
      assert SM.Utf8(s) == a + b;
      forall i | 0 <= i < |a + b| ensures 0 <= (a + b)[i] < 256 {
        if i < |a| { assert (a + b)[i] == a[i]; } else { assert (a + b)[i] == b[i - |a|]; }
      }
    }
  }
  lemma Bv8RT(x: int)
    requires 0 <= x < 256
    ensures ((x % 256) as bv8) as int == x
  {}
  lemma ToMsgAt(u: seq<int>, i: int)
    requires 0 <= i < |u|
    ensures |ToMsg(u)| == |u| && ToMsg(u)[i] == (u[i] % 256) as bv8
  {}
  lemma ToMsgInjective(u1: seq<int>, u2: seq<int>)
    requires forall i | 0 <= i < |u1| :: 0 <= u1[i] < 256
    requires forall i | 0 <= i < |u2| :: 0 <= u2[i] < 256
    requires ToMsg(u1) == ToMsg(u2)
    ensures u1 == u2
  {
    assert |u1| == |ToMsg(u1)| == |u2|;
    forall i | 0 <= i < |u1| ensures u1[i] == u2[i] {
      ToMsgAt(u1, i);
      ToMsgAt(u2, i);
      Bv8RT(u1[i]);
      Bv8RT(u2[i]);
    }
  }
  lemma RealSerBodyInjective(H: HashFn, idHex: IdFn, c1: Claim, c2: Claim)
    requires RealSerOf(H, idHex, c1) == RealSerOf(H, idHex, c2)
    ensures BodyOfClaim(H, idHex, c1) == BodyOfClaim(H, idHex, c2)
  {
    var s1 := SM.SerBody(BodyOfClaim(H, idHex, c1));
    var s2 := SM.SerBody(BodyOfClaim(H, idHex, c2));
    RealSerOfDef(H, idHex, c1);
    RealSerOfDef(H, idHex, c2);
    Utf8Range(s1);
    Utf8Range(s2);
    ToMsgInjective(SM.Utf8(s1), SM.Utf8(s2));
    SM.Utf8Injective(s1, s2);
    SM.SerBodyInjective(BodyOfClaim(H, idHex, c1), BodyOfClaim(H, idHex, c2));
  }
  lemma ClaimInjective(H: HashFn, idHex: IdFn, c1: Claim, c2: Claim)
    requires ParseableClaim(c1) && ParseableClaim(c2)
    requires H(c1.pre) == H(c2.pre) ==> c1.pre == c2.pre
    requires idHex(c1.specId) == idHex(c2.specId) ==> c1.specId == c2.specId
    requires idHex(c1.checkerId) == idHex(c2.checkerId) ==> c1.checkerId == c2.checkerId
    requires RealSerOf(H, idHex, c1) == RealSerOf(H, idHex, c2)
    ensures c1 == c2
  {
    reveal ParseableClaim();
    RealSerBodyInjective(H, idHex, c1, c2);
    var b1 := BodyOfClaim(H, idHex, c1);
    var b2 := BodyOfClaim(H, idHex, c2);
    assert b1.post == b2.post && b1.intent == b2.intent && b1.requestId == b2.requestId;
    assert c1.post == c2.post;
    assert c1.eff == c2.eff;
    assert c1.req == c2.req;
  }

  lemma BytesToClaimsRepaired(H: HashFn, idHex: IdFn, vb: ByteVerifier, rebuild: RebuildFn, acts: seq<Act>)
    requires H3b_SinkRebuildsSignedBytes(RealSer(H, idHex), rebuild, acts)
    requires H1B_ByteUnforgeability(RealSer(H, idHex), vb, rebuild, acts)
    requires H3d_MintsParseable(acts) && B6_DeliveriesParseable(acts)
    requires A4_NoCollisionInRun(H, idHex, acts)
    ensures ClaimSignedWhenBytesVerify(vb, rebuild, acts)
  {
    var ser := RealSer(H, idHex);
    forall k | 0 <= k < |acts| && acts[k].Deliver? && vb(rebuild(acts[k].tok), acts[k].tok.sig)
      ensures SignedBefore(acts, k, ClaimOf(acts[k].tok))
    {
      var j :| 0 <= j < k && j < |acts| && acts[j].MintAct? && ser(acts[j].c) == rebuild(acts[k].tok);
      ParseableTokClaim(acts[k].tok);
      assert RealSerOf(H, idHex, acts[j].c) == RealSerOf(H, idHex, ClaimOf(acts[k].tok));
      ClaimInjective(H, idHex, acts[j].c, ClaimOf(acts[k].tok));
    }
  }

  lemma RepairedGiveClaimAuthenticity(H: HashFn, idHex: IdFn, vb: ByteVerifier, rebuild: RebuildFn, acts: seq<Act>)
    requires H3b_SinkRebuildsSignedBytes(RealSer(H, idHex), rebuild, acts)
    requires H3c_VerifyTagIsByteVerifier(RealSer(H, idHex), vb)
    requires H1B_ByteUnforgeability(RealSer(H, idHex), vb, rebuild, acts)
    requires B5_ByteVerifierMatchesAtEachDelivery(vb, rebuild, acts)
    requires H3d_MintsParseable(acts) && B6_DeliveriesParseable(acts)
    requires A4_NoCollisionInRun(H, idHex, acts)
    ensures H1_SignatureAuthenticity(acts)
    ensures A5_VerifierMatchesAtEachDelivery(acts)
  {
    BytesToClaimsRepaired(H, idHex, vb, rebuild, acts);
    var ser := RealSer(H, idHex);
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures VerifyTag(ClaimOf(acts[k].tok), acts[k].tok.sig) <==> vb(rebuild(acts[k].tok), acts[k].tok.sig)
    {
      assert rebuild(acts[k].tok) == ser(ClaimOf(acts[k].tok));
    }
  }

  // THE REPAIRED COMPOSED THEOREM. H3a is gone (it is the lemma ClaimInjective); A4 is trace-local.
  lemma SliceSafetyV2BytesRepaired(init: State, acts: seq<Act>, art: FlatFn,
                                   H: HashFn, idHex: IdFn, vb: ByteVerifier, rebuild: RebuildFn)
    requires InitOk(init)
    requires A2_MintOnlyOnCheck(acts)
    requires H3b_SinkRebuildsSignedBytes(RealSer(H, idHex), rebuild, acts)
    requires H3c_VerifyTagIsByteVerifier(RealSer(H, idHex), vb)
    requires H1B_ByteUnforgeability(RealSer(H, idHex), vb, rebuild, acts)
    requires B5_ByteVerifierMatchesAtEachDelivery(vb, rebuild, acts)
    requires B6_DeliveriesParseable(acts)
    requires A4_NoCollisionInRun(H, idHex, acts)
    requires A6b_ArtifactComputesFlatContractOnBytes(art)
    ensures forall e | CommittedEffect(init, acts, e) ::
      exists i :: (0 <= i < |Exec(init, acts).core.outbox| && Exec(init, acts).core.outbox[i] == e &&
        ApprovedSpec(init, acts, i) && FlatResultAgrees(art, init, acts, i) && UniqueAuthorizationV2(init, acts, i))
    ensures 0 <= Exec(init, acts).core.charge.remaining <= Exec(init, acts).core.charge.original == init.original
    ensures SumIntents(Exec(init, acts).core.outbox) == init.remaining - Exec(init, acts).core.charge.remaining
  {
    RepairedGiveClaimAuthenticity(H, idHex, vb, rebuild, acts);
    SliceSafetyV2OnByteStrings(init, acts, art);
  }

  // =============================================================================================
  // CONTROL (drop A4): the reviewer's collision with the CONCRETE serializer. HC maps the two pre-states
  // W_PRE (remaining 60) and P_COLL (remaining 30) to one text. Everything but A4 holds; the trace commits an
  // effect that is not approved (40 > 30). (Proof pattern copied from r-signing ByteAttacks.)
  const P_COLL: F.Charge := F.Charge("ch_1", 100, 30, true)
  const V_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, SW.W_PRE, "rq_1", SW.W_POST, SW.W_INTENT, "sig_rq_1")
  const T_COLL: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, P_COLL, "rq_1", SW.W_POST, SW.W_INTENT, "sig_rq_1")
  function HC(c: F.Charge): string { "h" }
  function IdC(i: int): string { if i == PINNED_SPEC then "s" else if i == PINNED_CHK then "k" else "o" }
  function CollActs(): seq<Act> { [MintAct(ClaimOf(V_TOK), V_TOK.sig), Deliver(T_COLL, true)] }
  function AcceptTag(m: Msg, t: Tag): bool { t == "sig_rq_1" }
  function RebuildC(tok: SinkToken): Msg { RealSerOf(HC, IdC, ClaimOf(tok)) }

  lemma T1() ensures SM.Text("ch_1") { SM.TextSmall("ch_1"); }
  lemma T2() ensures SM.Text("rq_1") { SM.TextSmall("rq_1"); }
  lemma T3() ensures SM.Text("duplicate_charge") { SM.TextSmall("duplicate_charge"); }
  lemma T4() ensures SM.Text("rq_0") { SM.TextSmall("rq_0"); }
  lemma T5() ensures SM.Text("rq_b") { SM.TextSmall("rq_b"); }
  lemma TextShort()
    ensures SM.Text("ch_1") && SM.Text("rq_1") && SM.Text("duplicate_charge") && SM.Text("rq_0") && SM.Text("rq_b")
  {
    T1(); T2(); T3(); T4(); T5();
  }

  lemma CollBytes()
    ensures RealSerOf(HC, IdC, ClaimOf(T_COLL)) == RealSerOf(HC, IdC, ClaimOf(V_TOK))
  {
    assert BodyOfClaim(HC, IdC, ClaimOf(T_COLL)) == BodyOfClaim(HC, IdC, ClaimOf(V_TOK));
    RealSerOfSameBody(HC, IdC, ClaimOf(T_COLL), ClaimOf(V_TOK));
  }
  lemma CollNotA4()
    ensures !A4_NoCollisionInRun(HC, IdC, CollActs())
  {
    var acts := CollActs();
    assert acts[0].MintAct? && acts[1].Deliver? && HC(acts[0].c.pre) == HC(acts[1].tok.pre) && acts[0].c.pre != acts[1].tok.pre;
  }
  lemma CollA2()
    ensures InitOk(P_COLL) && A2_MintOnlyOnCheck(CollActs())
  {
    var acts := CollActs();
    assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(V_TOK));
    assert ClaimOf(V_TOK) == CheckedClaim(V_TOK.pre, SW.CheckedTransition(V_TOK));
    forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c)
      ensures exists pre: F.Charge, t2: F.Transition :: F.Authorizes(pre, t2) && acts[k].c == CheckedClaim(pre, t2)
    {
      assert k == 0;
      assert F.Authorizes(V_TOK.pre, SW.CheckedTransition(V_TOK)) && acts[k].c == CheckedClaim(V_TOK.pre, SW.CheckedTransition(V_TOK));
    }
  }
  lemma PT_V() ensures ParseableTok(V_TOK) { reveal ParseableTok(); TextShort(); }
  lemma PT_COLL() ensures ParseableTok(T_COLL) { reveal ParseableTok(); TextShort(); }
  lemma CollParse()
    ensures H3d_MintsParseable(CollActs()) && B6_DeliveriesParseable(CollActs())
  {
    var acts := CollActs();
    PT_V(); PT_COLL();
    ParseableTokClaim(V_TOK);
    forall j | 0 <= j < |acts| && acts[j].MintAct? ensures ParseableClaim(acts[j].c) { assert j == 0; }
    forall k | 0 <= k < |acts| && acts[k].Deliver? ensures ParseableTok(acts[k].tok) { assert k == 1; }
  }
  lemma CollBytesHyps()
    ensures H3b_SinkRebuildsSignedBytes(RealSer(HC, IdC), RebuildC, CollActs())
    ensures H1B_ByteUnforgeability(RealSer(HC, IdC), AcceptTag, RebuildC, CollActs())
    ensures B5_ByteVerifierMatchesAtEachDelivery(AcceptTag, RebuildC, CollActs())
  {
    var acts := CollActs();
    var ser := RealSer(HC, IdC);
    CollBytes();
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures BytesSignedBefore(ser, acts, k, RebuildC(acts[k].tok))
    {
      assert k == 1;
      assert acts[0].MintAct? && ser(acts[0].c) == RebuildC(acts[1].tok);
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures acts[k].sigOk == AcceptTag(RebuildC(acts[k].tok), acts[k].tok.sig)
    {
      assert k == 1;
    }
  }
  lemma CollTrace()
    ensures CommittedEffect(P_COLL, CollActs(), SW.W_INTENT)
    ensures forall i :: !ApprovedSpec(P_COLL, CollActs(), i)
  {
    var acts := CollActs();
    var init := P_COLL;
    SW_ExecStep(init, acts, 0);
    SW_ExecStep(init, acts, 1);
    assert acts[..0] == [];
    assert acts[..2] == acts;
    var r1 := Exec(init, acts[..1]);
    assert r1.core == Core(init, {}, []) && r1.toks == [];
    assert Step(r1.core, T_COLL, true).out.Committed?;
    var r := Exec(init, acts);
    assert r.toks == [T_COLL] && r.core.outbox == [SW.W_INTENT];
    forall i
      ensures !ApprovedSpec(init, acts, i)
    {
      if 0 <= i < |r.toks| {
        assert i == 0;
        assert !R.Eligible(F.ContextOf(P_COLL, "rq_1"), R.Candidate(40, "duplicate_charge"));
      }
    }
  }
  lemma CollisionControl()
    ensures RealSerOf(HC, IdC, ClaimOf(T_COLL)) == RealSerOf(HC, IdC, ClaimOf(V_TOK))
    ensures !A4_NoCollisionInRun(HC, IdC, CollActs())
    ensures InitOk(P_COLL) && A2_MintOnlyOnCheck(CollActs())
    ensures H3d_MintsParseable(CollActs()) && B6_DeliveriesParseable(CollActs())
    ensures H3b_SinkRebuildsSignedBytes(RealSer(HC, IdC), RebuildC, CollActs())
    ensures H1B_ByteUnforgeability(RealSer(HC, IdC), AcceptTag, RebuildC, CollActs())
    ensures B5_ByteVerifierMatchesAtEachDelivery(AcceptTag, RebuildC, CollActs())
    ensures CommittedEffect(P_COLL, CollActs(), SW.W_INTENT)
    ensures forall i :: !ApprovedSpec(P_COLL, CollActs(), i)
  {
    CollBytes(); CollNotA4(); CollA2(); CollParse(); CollBytesHyps(); CollTrace();
  }

  lemma SW_ExecStep(init: State, acts: seq<Act>, k: int)
    requires 0 <= k < |acts|
    ensures Exec(init, acts[..k + 1]) == Next(Exec(init, acts[..k]), acts[k])
  {
    assert acts[..k + 1][..k] == acts[..k];
    assert acts[..k + 1][k] == acts[k];
  }

  // =============================================================================================
  // NON-VACUITY WITNESS with the concrete serializer and a TOTAL byte verifier (each message has exactly one
  // verifying tag, SB(m)). Conditional on the reading H3c of the uninterpreted VerifyTag (the same method as
  // SliceWitnessV2.SigReading): VerifyTag is bodiless, so no concrete statement about it can be proved.
  function SB(m: Msg): Tag { seq(|m|, i requires 0 <= i < |m| => (m[i] as int) as char) + "#" }
  function TotalVB(m: Msg, t: Tag): bool { t == SB(m) }
  function HW(c: F.Charge): string { if c == SW.W_PRE then "p" else "q" }
  function RebuildW(tok: SinkToken): Msg { RealSerOf(HW, IdC, ClaimOf(tok)) }
  opaque function TagW(tok: SinkToken): Tag { SB(RealSerOf(HW, IdC, ClaimOf(tok))) }
  lemma TagWDef(tok: SinkToken) ensures TagW(tok) == SB(RebuildW(tok)) { reveal TagW(); }

  const Z_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, SW.W_PRE, "rq_0", SW.W_PRE, SW.W0_INTENT, "")
  const P_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, SW.W_PRE, "rq_1", SW.W_POST, SW.W_INTENT, "")
  // A forged token: parseable and Check-approvable, never minted; its tag is not SB of anything (no '#').
  const F_TOK: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, SW.W_POST, "rq_b", F.Charge("ch_1", 100, 10, true),
                                      R.Intent("ch_1", "rq_b", 10, "duplicate_charge"), "forged")
  function WActs(): seq<Act>
  {
    [MintAct(ClaimOf(Z_TOK), TagW(Z_TOK)), Deliver(Z_TOK.(sig := TagW(Z_TOK)), true),
     MintAct(ClaimOf(P_TOK), TagW(P_TOK)), Deliver(P_TOK.(sig := TagW(P_TOK)), true),
     Deliver(F_TOK, false)]
  }

  lemma ForgedTagRejected(m: Msg)
    ensures !TotalVB(m, "forged")
  {
    var s := SB(m);
    assert s[|s| - 1] == '#';
  }

  lemma WitnessTrace()
    ensures Exec(SW.W_PRE, WActs()).core.outbox == [SW.W0_INTENT, SW.W_INTENT]
    ensures Exec(SW.W_PRE, WActs()).core.charge == SW.W_POST
    ensures Step(Exec(SW.W_PRE, WActs()[..4]).core, F_TOK, false).out == Rejected(SignatureInvalid)
  {
    var acts := WActs();
    var init := SW.W_PRE;
    SW_ExecStep(init, acts, 0);
    SW_ExecStep(init, acts, 1);
    SW_ExecStep(init, acts, 2);
    SW_ExecStep(init, acts, 3);
    SW_ExecStep(init, acts, 4);
    assert acts[..0] == [];
    assert acts[..5] == acts;
    var r1 := Exec(init, acts[..1]);
    assert r1.core == Core(init, {}, []);
    var r2 := Exec(init, acts[..2]);
    assert SW.W_PRE.(remaining := SW.W_PRE.remaining - 0) == SW.W_PRE;
    assert r2.core == Core(init, {"rq_0"}, [SW.W0_INTENT]);
    var r3 := Exec(init, acts[..3]);
    assert r3.core == r2.core;
    var r4 := Exec(init, acts[..4]);
    assert "rq_1" !in {"rq_0"};
    assert r4.core == Core(SW.W_POST, {"rq_0", "rq_1"}, [SW.W0_INTENT, SW.W_INTENT]);
    var r5 := Exec(init, acts[..5]);
    assert r5.core == r4.core;
  }

  lemma WitA2()
    ensures A2_MintOnlyOnCheck(WActs())
  {
    var acts := WActs();
    assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(Z_TOK)) by {
      assert SW.W_PRE.(remaining := SW.W_PRE.remaining - 0) == SW.W_PRE;
    }
    assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(P_TOK));
    assert ClaimOf(Z_TOK) == CheckedClaim(Z_TOK.pre, SW.CheckedTransition(Z_TOK));
    assert ClaimOf(P_TOK) == CheckedClaim(P_TOK.pre, SW.CheckedTransition(P_TOK));
    forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c)
      ensures exists pre: F.Charge, t2: F.Transition :: F.Authorizes(pre, t2) && acts[k].c == CheckedClaim(pre, t2)
    {
      if k == 0 {
        assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(Z_TOK)) && acts[k].c == CheckedClaim(Z_TOK.pre, SW.CheckedTransition(Z_TOK));
      } else {
        assert k == 2;
        assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(P_TOK)) && acts[k].c == CheckedClaim(P_TOK.pre, SW.CheckedTransition(P_TOK));
      }
    }
  }
  lemma WitBytes()
    ensures H3b_SinkRebuildsSignedBytes(RealSer(HW, IdC), RebuildW, WActs())
    ensures H1B_ByteUnforgeability(RealSer(HW, IdC), TotalVB, RebuildW, WActs())
    ensures B5_ByteVerifierMatchesAtEachDelivery(TotalVB, RebuildW, WActs())
  {
    var acts := WActs();
    var ser := RealSer(HW, IdC);
    assert ClaimOf(acts[1].tok) == ClaimOf(Z_TOK) && ClaimOf(acts[3].tok) == ClaimOf(P_TOK);
    TagWDef(Z_TOK); TagWDef(P_TOK);
    assert RebuildW(acts[1].tok) == RebuildW(Z_TOK) && RebuildW(acts[3].tok) == RebuildW(P_TOK);
    ForgedTagRejected(RebuildW(F_TOK));
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures acts[k].sigOk == TotalVB(RebuildW(acts[k].tok), acts[k].tok.sig)
    {
      assert k == 1 || k == 3 || k == 4;
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver? && TotalVB(RebuildW(acts[k].tok), acts[k].tok.sig)
      ensures BytesSignedBefore(ser, acts, k, RebuildW(acts[k].tok))
    {
      if k == 1 {
        assert acts[0].MintAct? && ser(acts[0].c) == RebuildW(acts[k].tok);
      } else {
        assert k == 3;
        assert acts[2].MintAct? && ser(acts[2].c) == RebuildW(acts[k].tok);
      }
    }
  }
  lemma PT_Z() ensures ParseableTok(Z_TOK) { reveal ParseableTok(); TextShort(); }
  lemma PT_P() ensures ParseableTok(P_TOK) { reveal ParseableTok(); TextShort(); }
  lemma PT_F() ensures ParseableTok(F_TOK) { reveal ParseableTok(); TextShort(); }
  lemma ParseableIgnoresSig(tok: SinkToken, sg: Tag)
    requires ParseableTok(tok)
    ensures ParseableTok(tok.(sig := sg)) && ClaimOf(tok.(sig := sg)) == ClaimOf(tok)
  { reveal ParseableTok(); }
  lemma WitMintsParse()
    ensures H3d_MintsParseable(WActs())
  {
    var acts := WActs();
    PT_Z(); PT_P();
    ParseableTokClaim(Z_TOK); ParseableTokClaim(P_TOK);
    assert acts[0].c == ClaimOf(Z_TOK) && acts[2].c == ClaimOf(P_TOK);
    forall j | 0 <= j < |acts| && acts[j].MintAct? ensures ParseableClaim(acts[j].c) { assert j == 0 || j == 2; }
  }
  lemma WitDelivParse()
    ensures B6_DeliveriesParseable(WActs())
  {
    var acts := WActs();
    PT_Z(); PT_P(); PT_F();
    ParseableIgnoresSig(Z_TOK, TagW(Z_TOK));
    ParseableIgnoresSig(P_TOK, TagW(P_TOK));
    assert acts[1].tok == Z_TOK.(sig := TagW(Z_TOK)) && acts[3].tok == P_TOK.(sig := TagW(P_TOK)) && acts[4].tok == F_TOK;
    forall k | 0 <= k < |acts| && acts[k].Deliver? ensures ParseableTok(acts[k].tok) { assert k == 1 || k == 3 || k == 4; }
  }
  lemma WitParse()
    ensures H3d_MintsParseable(WActs()) && B6_DeliveriesParseable(WActs())
  {
    WitMintsParse(); WitDelivParse();
  }
  lemma WitA4()
    ensures A4_NoCollisionInRun(HW, IdC, WActs())
  {
    var acts := WActs();
    forall j, k | 0 <= j < |acts| && 0 <= k < |acts| && acts[j].MintAct? && acts[k].Deliver?
      ensures (HW(acts[j].c.pre) == HW(acts[k].tok.pre) ==> acts[j].c.pre == acts[k].tok.pre)
      ensures (IdC(acts[j].c.specId) == IdC(acts[k].tok.specId) ==> acts[j].c.specId == acts[k].tok.specId)
      ensures (IdC(acts[j].c.checkerId) == IdC(acts[k].tok.checkerId) ==> acts[j].c.checkerId == acts[k].tok.checkerId)
    {
      assert j == 0 || j == 2;
      assert k == 1 || k == 3 || k == 4;
      assert acts[j].c.pre == SW.W_PRE;
    }
  }
  lemma WitnessHyps()
    ensures A2_MintOnlyOnCheck(WActs())
    ensures H3b_SinkRebuildsSignedBytes(RealSer(HW, IdC), RebuildW, WActs())
    ensures H1B_ByteUnforgeability(RealSer(HW, IdC), TotalVB, RebuildW, WActs())
    ensures B5_ByteVerifierMatchesAtEachDelivery(TotalVB, RebuildW, WActs())
    ensures H3d_MintsParseable(WActs()) && B6_DeliveriesParseable(WActs())
    ensures A4_NoCollisionInRun(HW, IdC, WActs())
  {
    WitA2(); WitBytes(); WitParse(); WitA4();
  }

  lemma Witness(art: FlatFn)
    requires H3c_VerifyTagIsByteVerifier(RealSer(HW, IdC), TotalVB)    // the reading of VerifyTag
    requires A6b_ArtifactComputesFlatContractOnBytes(art)
    ensures forall m: Msg :: TotalVB(m, SB(m))                            // the byte verifier is total
    ensures Exec(SW.W_PRE, WActs()).core.outbox == [SW.W0_INTENT, SW.W_INTENT]   // amount 0 and 40 commit
    ensures Step(Exec(SW.W_PRE, WActs()[..4]).core, F_TOK, false).out == Rejected(SignatureInvalid)
    ensures forall e | CommittedEffect(SW.W_PRE, WActs(), e) ::
      exists i :: (0 <= i < |Exec(SW.W_PRE, WActs()).core.outbox| && Exec(SW.W_PRE, WActs()).core.outbox[i] == e &&
        ApprovedSpec(SW.W_PRE, WActs(), i))
  {
    WitnessTrace();
    WitnessHyps();
    assert InitOk(SW.W_PRE);
    SliceSafetyV2BytesRepaired(SW.W_PRE, WActs(), art, HW, IdC, TotalVB, RebuildW);
  }

  // =============================================================================================
  // G3: IssueBytes. The issuer signs only what this method returns. It calls the PROVED F.Check and returns
  // the concrete signed bytes of CheckedClaim(pre, t) on Issue, nothing on Refuse.
  method IssueBytes(pre: F.Charge, t: F.Transition, H: HashFn, idHex: IdFn) returns (out: SM.Option<Msg>)
    ensures out.Some? <==> F.Authorizes(pre, t)
    ensures out.Some? ==> out.value == RealSerOf(H, idHex, CheckedClaim(pre, t)) && Ours(CheckedClaim(pre, t)) &&
                          MoneyOk(CheckedClaim(pre, t).post.remaining) && MoneyOk(CheckedClaim(pre, t).eff.amount) &&
                          MoneyOk(CheckedClaim(pre, t).post.original)
  {
    var verdict, plan := F.Check(pre, H(pre), t);
    if verdict.Issue? {
      var tk := verdict.token;
      var body := SM.TokenBody(SM.DOMAIN, idHex(PINNED_SPEC), idHex(PINNED_CHK), tk.preStateHash, tk.requestId,
                               StateOf(tk.post), IntentOf(tk.intent));
      assert body == BodyOfClaim(H, idHex, CheckedClaim(pre, t));
      RealSerOfDef(H, idHex, CheckedClaim(pre, t));
      out := SM.Some(ToMsg(SM.Utf8(SM.SerBody(body))));
    } else {
      out := SM.None;
    }
  }
}
