// d-v3sink (night shift 2026-11-19, Orchestrator B). A DRAFT. NOT gate evidence. NOT about sink.ts.
// The shell-facing form of SinkCoreV3 (b-integrate; byte-equal copy in this folder). The token that the shell
// holds has ONLY a pre-state HASH, not the pre-state value. So the shell computes ONE boolean preOk (stored hash
// equals the token's hash), as it computes sigOk. StepP takes preOk in place of the value compare.
// StepP has the request-id check and the charge-id check of SinkCoreV3.Step. The charge-id check compares the
// STORED charge's id (core.charge) with intent.chargeId, and post.chargeId with intent.chargeId.
// StepPAgrees: StepP with preOk := (core.charge == pre) IS SinkCoreV3.Step on the full token. Every proved
// property of Step transfers under the named input assumption
//   A4' PreOkMatches: preOk == (core.charge == pre), for the pre-state value `pre` that the signer hashed.
// StepPKeepsGoodV3 needs NO assumption: for ANY preOk and ANY sigOk, GoodV3 is kept and the stored chargeId
// never changes. AuditStart is the executable start-up audit of SinkCoreV3 (AuditStart <==> GoodStart).
include "SinkCoreV3.dfy"

module ShellCoreV3 {
  import C = SinkCoreV3
  import F = RefundFinality
  import R = Refund

  datatype ShellToken = ShellToken(specId: int, checkerId: int, requestId: string,
                                   post: F.Charge, intent: R.RefundIntent, sig: string)

  function Full(t: ShellToken, pre: F.Charge): C.SinkToken
  {
    C.SinkToken(t.specId, t.checkerId, pre, t.requestId, t.post, t.intent, t.sig)
  }

  // The charge-id check on values the shell has: the stored charge and the token.
  predicate ChargeOkP(stored: F.Charge, t: ShellToken)
  {
    stored.chargeId == t.intent.chargeId && t.post.chargeId == t.intent.chargeId
  }

  function StepP(core: C.Core, t: ShellToken, sigOk: bool, preOk: bool): C.StepResult
  {
    if t.specId != C.PINNED_SPEC || t.checkerId != C.PINNED_CHK then C.StepResult(core, C.Rejected(C.IdsNotPinned))
    else if !sigOk then C.StepResult(core, C.Rejected(C.SignatureInvalid))
    else if t.intent.requestId != t.requestId then C.StepResult(core, C.Rejected(C.ReqIdMismatch))
    else if t.requestId in core.settled then C.StepResult(core, C.Rejected(C.RequestSettled))
    else if !preOk then C.StepResult(core, C.Rejected(C.PreStateMismatch))
    else if !ChargeOkP(core.charge, t) then C.StepResult(core, C.Rejected(C.ChargeIdMismatch))
    else C.StepResult(C.Core(t.post, core.settled + {t.requestId}, core.outbox + [t.intent]), C.Committed)
  }

  // The executable start-up audit (compiled; the shell calls it once on the loaded store).
  function AuditStart(core: C.Core): bool
  {
    C.AuditStart(core)
  }

  lemma AuditStartIsGoodStart(core: C.Core)
    ensures AuditStart(core) <==> C.GoodStart(core)
  {
    C.AuditStartIsGoodStart(core);
  }

  lemma StepPAgrees(core: C.Core, t: ShellToken, sigOk: bool, pre: F.Charge)
    ensures StepP(core, t, sigOk, core.charge == pre) == C.Step(core, Full(t, pre), sigOk)
  {
  }

  // The write set that the shell performs: exactly this, or nothing.
  lemma StepPShape(core: C.Core, t: ShellToken, sigOk: bool, preOk: bool)
    ensures StepP(core, t, sigOk, preOk).out.Committed? ==>
      StepP(core, t, sigOk, preOk).core == C.Core(t.post, core.settled + {t.requestId}, core.outbox + [t.intent])
    ensures !StepP(core, t, sigOk, preOk).out.Committed? ==> StepP(core, t, sigOk, preOk).core == core
  {
  }

  // Exact acceptance of StepP (rules out a reject-all and a commit-all StepP).
  lemma StepPExact(core: C.Core, t: ShellToken, sigOk: bool, preOk: bool)
    ensures StepP(core, t, sigOk, preOk).out.Committed? <==>
      (t.specId == C.PINNED_SPEC && t.checkerId == C.PINNED_CHK && sigOk && t.intent.requestId == t.requestId &&
       t.requestId !in core.settled && preOk && ChargeOkP(core.charge, t))
  {
  }

  // NO assumption (any preOk, any sigOk): GoodV3 is kept and the stored chargeId never changes.
  lemma StepPKeepsGoodV3(core: C.Core, t: ShellToken, sigOk: bool, preOk: bool)
    requires C.GoodV3(core)
    ensures C.GoodV3(StepP(core, t, sigOk, preOk).core)
    ensures StepP(core, t, sigOk, preOk).core.charge.chargeId == core.charge.chargeId
  {
    var pre := if preOk then core.charge else core.charge.(remaining := core.charge.remaining + 1);
    assert preOk == (core.charge == pre);
    StepPAgrees(core, t, sigOk, pre);
    C.StepKeepsGoodV3(core, Full(t, pre), sigOk);
  }

  // A token for another charge (intent or post) never commits, for any preOk and sigOk.
  lemma ForeignChargeNeverCommitsP(core: C.Core, t: ShellToken, sigOk: bool, preOk: bool)
    requires t.intent.chargeId != core.charge.chargeId || t.post.chargeId != core.charge.chargeId
    ensures !StepP(core, t, sigOk, preOk).out.Committed? && StepP(core, t, sigOk, preOk).core == core
  {
  }

  // The refinement of SinkCoreV3 (A5 only) carries over to StepP under A4'.
  lemma StepPRefinesModelStep(core: C.Core, s: C.System, toks: seq<C.SinkToken>, t: ShellToken,
                              sigOk: bool, preOk: bool, pre: F.Charge)
    requires C.A5_VerifierMatches(Full(t, pre), sigOk)
    requires preOk == (core.charge == pre)                     // A4'
    requires C.Rel(core, s, toks)
    ensures C.Rel(StepP(core, t, sigOk, preOk).core, C.ModelStep(s, Full(t, pre)),
                  C.NextToks(toks, Full(t, pre), StepP(core, t, sigOk, preOk).out))
  {
    StepPAgrees(core, t, sigOk, pre);
    C.StepRefinesModelStep(core, s, toks, Full(t, pre), sigOk);
  }

  // Non-vacuity: an honest step commits, then a zero-amount step for the same charge commits; a foreign-charge
  // step is rejected; AuditStart accepts the fresh store and the store after the two commits.
  lemma Witness()
    ensures var c := F.Charge("ch_1", 1000, 1000, true);
            var t1 := ShellToken(C.PINNED_SPEC, C.PINNED_CHK, "rq_1", F.Charge("ch_1", 1000, 900, true),
                                 R.Intent("ch_1", "rq_1", 100, "returned_item"), "");
            var t2 := ShellToken(C.PINNED_SPEC, C.PINNED_CHK, "rq_2", F.Charge("ch_1", 1000, 900, true),
                                 R.Intent("ch_1", "rq_2", 0, "returned_item"), "");
            var tf := ShellToken(C.PINNED_SPEC, C.PINNED_CHK, "rq_3", F.Charge("ch_1", 1000, 800, true),
                                 R.Intent("ch_9", "rq_3", 100, "returned_item"), "");
            var r1 := StepP(C.Core(c, {}, []), t1, true, true);
            var r2 := StepP(r1.core, t2, true, true);
            var r3 := StepP(r2.core, tf, true, true);
            AuditStart(C.Core(c, {}, [])) && r1.out.Committed? && r2.out.Committed? &&
            r3.out == C.Rejected(C.ChargeIdMismatch) && r3.core == r2.core && AuditStart(r2.core)
  {
    var c := F.Charge("ch_1", 1000, 1000, true);
    var t1 := ShellToken(C.PINNED_SPEC, C.PINNED_CHK, "rq_1", F.Charge("ch_1", 1000, 900, true),
                         R.Intent("ch_1", "rq_1", 100, "returned_item"), "");
    var t2 := ShellToken(C.PINNED_SPEC, C.PINNED_CHK, "rq_2", F.Charge("ch_1", 1000, 900, true),
                         R.Intent("ch_1", "rq_2", 0, "returned_item"), "");
    var r2 := StepP(StepP(C.Core(c, {}, []), t1, true, true).core, t2, true, true);
    assert "rq_1"[3] != "rq_2"[3];
    assert r2.core.outbox == [t1.intent, t2.intent];
    assert r2.core.settled == {"rq_1", "rq_2"};
  }

  // AuditStart refuses a store with an outbox row whose request id is not settled, and one with a foreign charge id.
  lemma AuditStartRefuses()
    ensures !AuditStart(C.Core(F.Charge("ch_1", 100, 90, true), {"rq_body"}, [R.Intent("ch_1", "rq_v", 10, "duplicate_charge")]))
    ensures !AuditStart(C.Core(F.Charge("ch_1", 100, 90, true), {"rq_1"}, [R.Intent("ch_2", "rq_1", 10, "duplicate_charge")]))
  {
    var c1 := C.Core(F.Charge("ch_1", 100, 90, true), {"rq_body"}, [R.Intent("ch_1", "rq_v", 10, "duplicate_charge")]);
    assert "rq_v"[3] != "rq_body"[3];
    assert c1.outbox[0].requestId !in c1.settled;
    var c2 := C.Core(F.Charge("ch_1", 100, 90, true), {"rq_1"}, [R.Intent("ch_2", "rq_1", 10, "duplicate_charge")]);
    assert "ch_2"[3] != "ch_1"[3];
    assert c2.outbox[0].chargeId != c2.charge.chargeId;
  }
}
