// Night shift 2026-11-19, Orchestrator B, task r-integrate (adversarial review of b-integrate). A DRAFT in an
// evidence folder. NOT gate evidence. Dafny-model statements about SinkCoreV3 (b-integrate, copied to ../src,
// SHA-256 1a65fab2...). No assume, no axiom, no bodiless lemma.
include "../src/SinkCoreV3.dfy"

module AttackCore {
  import opened SinkCoreV3

  // ---- R1 (completeness of the new checks): an HONEST token passes both new checks. ----
  // An honest token is one whose claim is CheckedClaim-shaped for an authorized transition (what A2 gives).
  // Then Match holds and ChargeOk holds against ANY stored charge with the pre-state's charge id.
  // Zero amount is not special-cased: Authorizes allows amount 0.
  lemma HonestTokenPassesNewChecks(tok: SinkToken, pre: F.Charge, t: F.Transition, stored: F.Charge)
    requires F.Authorizes(pre, t)
    requires ClaimOf(tok) == Claim(PINNED_SPEC, PINNED_CHK, pre, Enc(t.request.requestId),
                                   F.Request(t.request.requestId, t.intent.amount, t.intent.reason), t.post, t.intent)
    requires stored.chargeId == pre.chargeId
    ensures Match(tok) && ChargeOk(stored, tok)
    ensures tok.pre == pre && tok.post == t.post && tok.intent == t.intent
  {
    EncInjective(tok.requestId, t.request.requestId);
  }

  // V2 acceptance (SinkCore of b-signing: no request-id check, no charge-id check).
  predicate V2Accepts(core: Core, tok: SinkToken, sigOk: bool)
  {
    tok.specId == PINNED_SPEC && tok.checkerId == PINNED_CHK && sigOk &&
    tok.requestId !in core.settled && core.charge == tok.pre
  }

  // Core-level completeness: V3 commits every honest token that V2 commits, with the same new core.
  lemma V3LosesNoHonestCommit(core: Core, tok: SinkToken, sigOk: bool, pre: F.Charge, t: F.Transition)
    requires F.Authorizes(pre, t)
    requires ClaimOf(tok) == Claim(PINNED_SPEC, PINNED_CHK, pre, Enc(t.request.requestId),
                                   F.Request(t.request.requestId, t.intent.amount, t.intent.reason), t.post, t.intent)
    requires V2Accepts(core, tok, sigOk)
    ensures Step(core, tok, sigOk).out.Committed?
    ensures Step(core, tok, sigOk).core == Core(tok.post, core.settled + {tok.requestId}, core.outbox + [tok.intent])
  {
    HonestTokenPassesNewChecks(tok, pre, t, core.charge);
  }

  // The bad direction of the refinement is FALSE: the model's Commit may accept where the core refuses (a stutter).
  // A token with a request-id mismatch: SinkAccepts holds (tag verifies), the core rejects, ModelStep stutters.
  // This direction only REFUSES more; it never commits more (StepRefinesModelStep is an iff on core commits).
  lemma StutterHidesNoCoreCommit(core: Core, s: System, toks: seq<SinkToken>, tok: SinkToken, sigOk: bool)
    requires A5_VerifierMatches(tok, sigOk) && Rel(core, s, toks)
    ensures Step(core, tok, sigOk).out.Committed? ==>
      SinkAccepts(s, ClaimOf(tok), tok.sig) && ModelStep(s, tok) == Commit(s, ClaimOf(tok), tok.sig) &&
      ModelStep(s, tok).log == s.log + [ClaimOf(tok)]
    ensures !Step(core, tok, sigOk).out.Committed? ==> ModelStep(s, tok).log == s.log
  {
    StepRefinesModelStep(core, s, toks, tok, sigOk);
  }

  // ---- R2: outbox entries are distinct as VALUES (index-level statement; no hidden duplicate). ----
  lemma GoodV3NoEqualValues(c: Core)
    requires GoodV3(c)
    ensures forall i, j | 0 <= i < |c.outbox| && 0 <= j < |c.outbox| && i != j :: c.outbox[i] != c.outbox[j]
  {
    forall i, j | 0 <= i < |c.outbox| && 0 <= j < |c.outbox| && i != j
      ensures c.outbox[i] != c.outbox[j]
    {
      if i < j {
        assert c.outbox[i].requestId != c.outbox[j].requestId;
      } else {
        assert c.outbox[j].requestId != c.outbox[i].requestId;
      }
    }
  }

  // ---- R3 (closure): every core that V3 reaches from an empty store passes AuditStart. ----
  lemma ReachableAuditStartTrue(init: F.Charge, ds: seq<Delivery>)
    ensures AuditStart(Run(Core(init, {}, []), ds))
  {
    FromInitGood(init, ds);
    AuditStartIsGoodStart(Run(Core(init, {}, []), ds));
  }

  // And from any GoodStart core.
  lemma GoodStartClosed(c: Core, ds: seq<Delivery>)
    requires AuditStart(c)
    ensures AuditStart(Run(c, ds))
  {
    AuditStartIsGoodStart(c);
    RunKeepsGoodV3(c, ds);
    AuditStartIsGoodStart(Run(c, ds));
  }

  // ---- R4 (DEFECT CLASS: GoodStart is NOT enough for money-type conclusions). ----
  // A start core that passes AuditStart (so GoodStart holds) but already holds an effect of 500 for a charge of
  // original 100, and remaining == original. AuditStart checks no amount, no chain, no signature.
  // Then one honest token (refund 100) still commits: total 600 > original 100.
  function BadButAudited(): Core
  {
    Core(F.Charge("ch_1", 100, 100, true), {"rq_a"}, [R.Intent("ch_1", "rq_a", 500, "duplicate_charge")])
  }

  lemma GoodStartDoesNotBoundMoney()
    ensures AuditStart(BadButAudited()) && GoodStart(BadButAudited())
    ensures var c := BadButAudited();
            var t := SinkToken(PINNED_SPEC, PINNED_CHK, c.charge, "rq_b", c.charge.(remaining := 0),
                               R.Intent("ch_1", "rq_b", 100, "duplicate_charge"), "sig");
            var r := Step(c, t, true);
            r.out.Committed? && SumIntents(r.core.outbox) == 600 && SumIntents(r.core.outbox) > c.charge.original &&
            SumIntents(r.core.outbox) != c.charge.original - r.core.charge.remaining
  {
    var c := BadButAudited();
    AuditStartIsGoodStart(c);
    var t := SinkToken(PINNED_SPEC, PINNED_CHK, c.charge, "rq_b", c.charge.(remaining := 0),
                       R.Intent("ch_1", "rq_b", 100, "duplicate_charge"), "sig");
    var r := Step(c, t, true);
    assert "rq_b"[3] != "rq_a"[3];
    assert r.core.outbox == [R.Intent("ch_1", "rq_a", 500, "duplicate_charge"), t.intent];
    assert r.core.outbox[..1] == [R.Intent("ch_1", "rq_a", 500, "duplicate_charge")];
    assert r.core.outbox[..1][..0] == [];
  }

  // The honest token of R4 is AUTHORIZED by the approved relation (so H1 + A2 + A5 cannot exclude it).
  lemma R4TokenIsHonest()
    ensures var c := BadButAudited();
            F.Authorizes(c.charge, F.Transition(F.Request("rq_b", 100, "duplicate_charge"), c.charge.(remaining := 0),
                                                R.Intent("ch_1", "rq_b", 100, "duplicate_charge")))
  {
    assert "duplicate_charge" in {"duplicate_charge", "service_not_delivered", "returned_item"};
  }

  // ---- R5 (zero amount) ----
  // Two zero-amount tokens with distinct request ids both commit; a zero-amount token for a foreign charge does not.
  lemma ZeroAmountCases()
    ensures var c0 := F.Charge("ch_1", 100, 100, true);
            var z1 := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_z1", c0, R.Intent("ch_1", "rq_z1", 0, "returned_item"), "a");
            var z2 := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_z2", c0, R.Intent("ch_1", "rq_z2", 0, "returned_item"), "b");
            var zf := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_z3", c0, R.Intent("ch_2", "rq_z3", 0, "returned_item"), "c");
            var r1 := Step(Core(c0, {}, []), z1, true);
            var r2 := Step(r1.core, z2, true);
            var r3 := Step(r2.core, zf, true);
            r1.out.Committed? && r2.out.Committed? && r3.out == Rejected(ChargeIdMismatch) &&
            r3.core.outbox == [z1.intent, z2.intent]
  {
    assert "rq_z2"[4] != "rq_z1"[4];
    assert "rq_z3"[4] != "rq_z1"[4] && "rq_z3"[4] != "rq_z2"[4];
  }

  // ---- R6 (liveness after an attack on the SAME request id) ----
  // Any rejected delivery leaves the core unchanged, so a token that would commit before still commits after.
  lemma RejectedAttackBurnsNothing(c: Core, attack: SinkToken, aSig: bool, honest: SinkToken)
    requires !Step(c, attack, aSig).out.Committed?
    ensures Step(Step(c, attack, aSig).core, honest, true) == Step(c, honest, true)
  {
  }

  // A COMMITTED attack (verifying tag, no signer assumption) for the honest request id burns it: the honest token
  // is then refused (RequestSettled). This is outside L0's promise; only H1 + A2 exclude such an attack token.
  lemma CommittedAttackBurnsRequestId()
    ensures var c0 := F.Charge("ch_1", 100, 100, true);
            var atk := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_v", c0, R.Intent("ch_1", "rq_v", 0, "returned_item"), "x");
            var hon := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_v", c0.(remaining := 90),
                                 R.Intent("ch_1", "rq_v", 10, "duplicate_charge"), "y");
            var r1 := Step(Core(c0, {}, []), atk, true);
            r1.out.Committed? && Step(r1.core, hon, true).out == Rejected(RequestSettled)
  {
  }
}
