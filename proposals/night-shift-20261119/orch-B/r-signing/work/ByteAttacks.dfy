// Night shift 2026-11-19, Orchestrator B, task r-signing. Attacks on the byte layer of SliceSafetyV2.
// Dafny model only. No assume, no axiom, no bodiless lemma.
//
// Real-world fact (ts/refund-finality/encoding.ts, signedBytes = canon(TokenBody)): the signed body holds
// preStateSha256 = SHA-256(canon(pre)), NOT the pre-state value. So the real Ser factors through a hash of pre.
// A hash from an infinite set of charges to 32 bytes is not injective (pigeonhole). Hence H3a_SerInjective
// (injective on ALL claims) is FALSE for the real serializer. Below: (1) any Ser that factors through a
// non-injective function of pre violates H3a; (2) with such a Ser and every OTHER byte hypothesis true, an
// UNAPPROVED effect commits (the conclusion ApprovedSpec of SliceSafetyV2Bytes fails); (3) H1B is satisfiable
// with a TOTAL byte verifier for every Ser (small witness).
include "SliceSafetyV2OnBytes.dfy"

module ByteAttacks {
  import opened SinkCore
  import opened SliceTheorem
  import opened SliceTheoremV2
  import opened SliceWitnessV2
  import SW = SliceWitness

  // (1) A Ser that sees pre only through h is not injective when h has a collision.
  lemma HashedPreSerNotInjective(ser: SerFn, h: F.Charge -> int, p1: F.Charge, p2: F.Charge, c: Claim)
    requires p1 != p2 && h(p1) == h(p2)
    requires forall c1: Claim, c2: Claim :: c1.(pre := c2.pre) == c2 && h(c1.pre) == h(c2.pre) ==> ser(c1) == ser(c2)
    ensures !H3a_SerInjective(ser)
  {
    var c1 := c.(pre := p1);
    var c2 := c.(pre := p2);
    assert c1.(pre := c2.pre) == c2;
    assert ser(c1) == ser(c2) && c1 != c2;
  }

  // (2) A pre-state collision: the stored charge P_COLL (remaining 30) has the same "hash" as V_TOK.pre
  // (remaining 60). The issuer signed the claim of V_TOK (refund 40 from 60, approved). The adversary presents
  // the same body with the colliding pre-state. Every byte hypothesis except H3a holds; A2 holds; the sink
  // commits; the committed effect is NOT approved (40 > 30) and the stored remaining becomes 20, not -10.
  const P_COLL: F.Charge := F.Charge("ch_1", 100, 30, true)
  const T_COLL: SinkToken := SinkToken(PINNED_SPEC, PINNED_CHK, P_COLL, "rq_1", SW.W_POST, SW.W_INTENT, "sig_rq_1")
  function CollActs(): seq<Act> { [MintAct(ClaimOf(V_TOK), V_TOK.sig), Deliver(T_COLL, true)] }
  function AcceptTag(m: Msg, t: Tag): bool { t == "sig_rq_1" }
  function RebuildBy(ser: SerFn): RebuildFn { (tok: SinkToken) => ser(ClaimOf(tok)) }

  lemma PreStateCollisionBreaksApprovedSpec(ser: SerFn)
    requires ser(ClaimOf(T_COLL)) == ser(ClaimOf(V_TOK))   // the collision (SHA-256 of two pre-states)
    ensures !H3a_SerInjective(ser)
    ensures InitOk(P_COLL)
    ensures A2_MintOnlyOnCheck(CollActs())
    ensures H3b_SinkRebuildsSignedBytes(ser, RebuildBy(ser), CollActs())
    ensures H1B_ByteUnforgeability(ser, AcceptTag, RebuildBy(ser), CollActs())
    ensures B5_ByteVerifierMatchesAtEachDelivery(AcceptTag, RebuildBy(ser), CollActs())
    ensures Exec(P_COLL, CollActs()).core.outbox == [SW.W_INTENT]
    ensures CommittedEffect(P_COLL, CollActs(), SW.W_INTENT)
    ensures forall i :: !ApprovedSpec(P_COLL, CollActs(), i)
    ensures Exec(P_COLL, CollActs()).core.charge.remaining == 20 && P_COLL.remaining - SW.W_INTENT.amount == -10
  {
    var acts := CollActs();
    var init := P_COLL;
    assert ClaimOf(T_COLL) != ClaimOf(V_TOK) by { assert ClaimOf(T_COLL).pre != ClaimOf(V_TOK).pre; }
    assert F.Authorizes(SW.W_PRE, SW.CheckedTransition(V_TOK));
    assert ClaimOf(V_TOK) == CheckedClaim(V_TOK.pre, SW.CheckedTransition(V_TOK));
    forall k | 0 <= k < |acts| && acts[k].MintAct? && Ours(acts[k].c)
      ensures exists pre: F.Charge, t2: F.Transition :: F.Authorizes(pre, t2) && acts[k].c == CheckedClaim(pre, t2)
    {
      assert k == 0;
      assert F.Authorizes(V_TOK.pre, SW.CheckedTransition(V_TOK)) && acts[k].c == CheckedClaim(V_TOK.pre, SW.CheckedTransition(V_TOK));
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures BytesSignedBefore(ser, acts, k, RebuildBy(ser)(acts[k].tok))
    {
      assert k == 1;
      assert acts[0].MintAct? && ser(acts[0].c) == RebuildBy(ser)(acts[1].tok);
    }
    forall k | 0 <= k < |acts| && acts[k].Deliver?
      ensures acts[k].sigOk == AcceptTag(RebuildBy(ser)(acts[k].tok), acts[k].tok.sig)
    {
      assert k == 1;
    }
    ExecStep(init, acts, 0);
    ExecStep(init, acts, 1);
    assert acts[..0] == [];
    assert acts[..2] == acts;
    var r0 := Exec(init, acts[..0]);
    assert r0 == RunSt(Core(init, {}, []), Sys(init, [], {}, [], {}), []);
    var r1 := Exec(init, acts[..1]);
    assert r1.core == Core(init, {}, []) && r1.toks == [];
    assert Step(r1.core, T_COLL, true).out.Committed?;
    var r := Exec(init, acts);
    assert r.toks == [T_COLL] && r.core.outbox == [SW.W_INTENT] && r.core.charge == SW.W_POST;
    forall i
      ensures !ApprovedSpec(init, acts, i)
    {
      if 0 <= i < |r.toks| {
        assert i == 0;
        assert !R.Eligible(F.ContextOf(P_COLL, "rq_1"), R.Candidate(40, "duplicate_charge"));
      }
    }
  }

  // (3) H1B is satisfiable with a TOTAL byte verifier, for EVERY Ser: every message has exactly one verifying
  // tag (SB(m)); the trace mints c and presents it; a forged delivery with a wrong tag is also present.
  function SB(m: Msg): Tag { seq(|m|, i requires 0 <= i < |m| => (m[i] as int) as char) + "#" }
  function TotalVB(m: Msg, t: Tag): bool { t == SB(m) }
  ghost predicate HasByteTag(m: Msg) { exists t: Tag :: TotalVB(m, t) }

  lemma H1BWithTotalVerifier(ser: SerFn, tok: SinkToken, bad: SinkToken)
    requires tok.sig == SB(ser(ClaimOf(tok)))
    requires bad.sig != SB(ser(ClaimOf(bad)))
    ensures forall m: Msg :: HasByteTag(m)
    ensures var acts := [MintAct(ClaimOf(tok), tok.sig), Deliver(tok, true), Deliver(bad, false)];
      H3b_SinkRebuildsSignedBytes(ser, RebuildBy(ser), acts) &&
      H1B_ByteUnforgeability(ser, TotalVB, RebuildBy(ser), acts) &&
      B5_ByteVerifierMatchesAtEachDelivery(TotalVB, RebuildBy(ser), acts)
  {
    forall m: Msg
      ensures HasByteTag(m)
    {
      assert TotalVB(m, SB(m));
    }
    var acts := [MintAct(ClaimOf(tok), tok.sig), Deliver(tok, true), Deliver(bad, false)];
    forall k | 0 <= k < |acts| && acts[k].Deliver? && TotalVB(RebuildBy(ser)(acts[k].tok), acts[k].tok.sig)
      ensures BytesSignedBefore(ser, acts, k, RebuildBy(ser)(acts[k].tok))
    {
      assert k == 1;
      assert acts[0].MintAct? && ser(acts[0].c) == RebuildBy(ser)(acts[1].tok);
    }
  }
}
