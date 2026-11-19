// r-repairs: attempts that MUST FAIL to verify (SoundNative for every check under CodecOk).
include "Bridge2.dfy"
module AttackFail {
  import opened Bridge2Model
  import F = RefundFinality
  import R = Refund
  // F1: request id in intent differs from the request; accept-all check; spec native; identity codec.
  lemma F1_IntentOtherRequestSigns()
    ensures var pre := F.Charge("ch_1", 100, 60, true);
            var t := F.Transition(F.Request("req_B", 40, "returned_item"), pre.(remaining := 20),
                                  R.Intent("ch_1", "req_A", 40, "returned_item"));
            Bridge2(IdEnv, pre, t, CheckAcceptsAll, SpecNative).Sign?
  {}
  // F2: general: some check, some native under NativeOkOn and CodecOk, signs while not authorized.
  lemma F2_NotAuthorizedSigns(env: Env, pre: F.Charge, t: F.Transition,
                              check: (F.Charge, F.Transition) -> bool, native: FlatIn -> Option<FlatTuple>)
    requires CodecOk(env) && NativeOkOn(native, Encode(env, pre, t.request))
    requires Bridge2(env, pre, t, check, native).Sign?
    ensures !F.Authorizes(pre, t)
  {}
  // F3: intent charge id other than pre.chargeId.
  lemma F3_OtherChargeSigns()
    ensures var pre := F.Charge("ch_1", 100, 60, true);
            var t := F.Transition(F.Request("req_1", 40, "returned_item"), pre.(remaining := 20),
                                  R.Intent("CH_1", "req_1", 40, "returned_item"));
            Bridge2(IdEnv, pre, t, CheckAcceptsAll, SpecNative).Sign?
  {}
}
