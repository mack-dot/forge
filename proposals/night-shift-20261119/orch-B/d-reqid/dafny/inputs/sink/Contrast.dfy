// d-reqid (night shift 2026-11-19, Orchestrator B). A DRAFT. No assume, no axiom, no bodiless lemma.
// The CONTRAST: the UNPATCHED SinkCore.Step (byte-equal copy) commits the gap trace of report G4.
// Both deliveries have sigOk = true and pinned ids: a trusted but faulty signer (or a stolen key) can
// sign both tokens. The real issuer cannot sign the first one (proved Check: token.requestId ==
// request.requestId, and Authorizes forces intent.requestId == request.requestId).
include "SinkCore.dfy"
include "SinkCoreReqId.dfy"

module ReqIdGapContrast {
  import S = SinkCore
  import P = SinkCoreReqId
  import F = RefundFinality
  import R = Refund

  function C0(): F.Charge { F.Charge("ch_1", 100, 100, true) }

  // Unpatched core, minimal counterexample: two deliveries, both commit; the outbox holds two intents
  // with the SAME intent.requestId; after the first step its outbox request id is NOT in settled.
  lemma UnpatchedGap()
    ensures var bad := S.SinkToken(S.PINNED_SPEC, S.PINNED_CHK, C0(), "rq_body", C0().(remaining := 90),
                                   R.Intent("ch_1", "rq_victim", 10, "duplicate_charge"), "sigA");
            var honest := S.SinkToken(S.PINNED_SPEC, S.PINNED_CHK, C0().(remaining := 90), "rq_victim",
                                      C0().(remaining := 80), R.Intent("ch_1", "rq_victim", 10, "duplicate_charge"), "sigB");
            var r1 := S.Step(S.Core(C0(), {}, []), bad, true);
            var r2 := S.Step(r1.core, honest, true);
            r1.out.Committed? && r2.out.Committed? &&
            |r2.core.outbox| == 2 &&
            r2.core.outbox[0].requestId == r2.core.outbox[1].requestId == "rq_victim" &&
            r1.core.outbox[0].requestId !in r1.core.settled &&
            r2.core.charge.remaining == 80
  {
  }

  // The same two tokens against the PATCHED core: the first is rejected and changes nothing; the honest
  // token then fails only on the pre-state (it was minted for remaining 90). A fresh honest token on
  // the true pre-state commits once (P.PatchedRefusesGapTrace).
  lemma PatchedOnGapTrace()
    ensures var bad := P.SinkToken(P.PINNED_SPEC, P.PINNED_CHK, C0(), "rq_body", C0().(remaining := 90),
                                   R.Intent("ch_1", "rq_victim", 10, "duplicate_charge"), "sigA");
            var r1 := P.Step(P.Core(C0(), {}, []), bad, true);
            r1.out == P.Rejected(P.ReqIdMismatch) && r1.core == P.Core(C0(), {}, [])
  {
  }

  // The unpatched core breaks the Good invariant of the patched theorem on that trace.
  lemma UnpatchedBreaksGood()
    ensures var bad := S.SinkToken(S.PINNED_SPEC, S.PINNED_CHK, C0(), "rq_body", C0().(remaining := 90),
                                   R.Intent("ch_1", "rq_victim", 10, "duplicate_charge"), "sigA");
            var r1 := S.Step(S.Core(C0(), {}, []), bad, true);
            !(forall i | 0 <= i < |r1.core.outbox| :: r1.core.outbox[i].requestId in r1.core.settled)
  {
    var bad := S.SinkToken(S.PINNED_SPEC, S.PINNED_CHK, C0(), "rq_body", C0().(remaining := 90),
                           R.Intent("ch_1", "rq_victim", 10, "duplicate_charge"), "sigA");
    var r1 := S.Step(S.Core(C0(), {}, []), bad, true);
    assert r1.core.outbox[0].requestId == "rq_victim" && r1.core.settled == {"rq_body"};
  }
}
