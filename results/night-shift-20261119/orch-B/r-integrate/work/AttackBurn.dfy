// r-integrate: the request-id burn of CommittedAttackBurnsRequestId uses an AUTHORIZED claim. So H1 + A2 do not
// exclude it when the issuer signs two authorized claims for one request id (a U428-type issuer behaviour).
// A DRAFT. NOT gate evidence. No assume, no axiom, no bodiless lemma.
include "../src/SinkCoreV3.dfy"

module AttackBurn {
  import opened SinkCoreV3

  lemma TwoAuthorizedClaimsOneRequestId()
    ensures var c0 := F.Charge("ch_1", 100, 100, true);
            var tz := F.Transition(F.Request("rq_v", 0, "returned_item"), c0, R.Intent("ch_1", "rq_v", 0, "returned_item"));
            var th := F.Transition(F.Request("rq_v", 10, "duplicate_charge"), c0.(remaining := 90),
                                   R.Intent("ch_1", "rq_v", 10, "duplicate_charge"));
            var atk := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_v", tz.post, tz.intent, "x");
            var hon := SinkToken(PINNED_SPEC, PINNED_CHK, c0, "rq_v", th.post, th.intent, "y");
            var r1 := Step(Core(c0, {}, []), atk, true);
            F.Authorizes(c0, tz) && F.Authorizes(c0, th) &&
            r1.out.Committed? && Step(r1.core, hon, true).out == Rejected(RequestSettled)
  {
    assert "returned_item" in {"duplicate_charge", "service_not_delivered", "returned_item"};
    assert "duplicate_charge" in {"duplicate_charge", "service_not_delivered", "returned_item"};
  }
}
