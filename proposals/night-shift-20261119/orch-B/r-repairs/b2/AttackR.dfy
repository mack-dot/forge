// r-repairs (night shift 2026-11-19): adversarial lemmas over the UNCHANGED Bridge2.dfy copy.
include "Bridge2.dfy"

module AttackR {
  import opened Bridge2Model
  import F = RefundFinality
  import R = Refund

  // P1: SoundCheck does NOT need CodecOk (the codec is on the native side only).
  lemma SoundCheckNoCodec(env: Env, pre: F.Charge, t: F.Transition,
                          check: (F.Charge, F.Transition) -> bool, native: FlatIn -> Option<FlatTuple>)
    requires check(pre, t) ==> F.Authorizes(pre, t)
    requires Bridge2(env, pre, t, check, native).Sign?
    ensures F.Authorizes(pre, t)
    ensures Bridge2(env, pre, t, check, native).token == F.Token(env.h(pre), t.request.requestId, t.post, t.intent)
  {}

  // P2: CodecOk is necessary for SoundNative. A collapsing encoder (two request ids -> one flat input),
  // an accept-all checker and the CORRECT specification native: signs a transition that is not authorized.
  function Collapse(s: string): string { if s == "req_B" then "req_A" else s }
  const BadEnv: Env := Env(Collapse, Id, AnyText, H0)

  lemma SharedEncoderSignsWrongRequest()
    ensures var pre := F.Charge("ch_1", 100, 60, true);
            var t := F.Transition(F.Request("req_B", 40, "returned_item"), pre.(remaining := 20),
                                  R.Intent("ch_1", "req_A", 40, "returned_item"));
            !CodecOk(BadEnv) &&
            NativeOkOn(SpecNative, Encode(BadEnv, pre, t.request)) &&
            Bridge2(BadEnv, pre, t, CheckAcceptsAll, SpecNative).Sign? &&
            Bridge2(BadEnv, pre, t, CheckAcceptsAll, SpecNative).token.requestId == "req_A" &&
            !F.Authorizes(pre, t) &&
            Bridge2(BadEnv, pre, t, TrueCheck, SpecNative).Refuse?
  {
    assert Collapse("req_B") == "req_A";
    assert Id(Collapse("req_B")) != "req_B";
  }

  // P3: an encoder that maps a forbidden reason onto an allowed one (single native-side codec fault +
  // accept-all checker).
  function ReasonFold(s: string): string { if s == "Returned_Item" then "returned_item" else s }
  const FoldEnv: Env := Env(ReasonFold, Id, AnyText, H0)
  lemma CaseFoldedReasonSigns()
    ensures var pre := F.Charge("ch_1", 100, 60, true);
            var t := F.Transition(F.Request("req_1", 40, "Returned_Item"), pre.(remaining := 20),
                                  R.Intent("ch_1", "req_1", 40, "returned_item"));
            Bridge2(FoldEnv, pre, t, CheckAcceptsAll, SpecNative).Sign? && !F.Authorizes(pre, t)
  {
    assert !R.AllowedReason("Returned_Item");
  }

  // P4: both wrong (accept-all checker, authorize-all native outside NativeOkOn) signs.
  function AllNative(x: FlatIn): Option<FlatTuple> { Some(AuthTuple(x)) }
  lemma BothWrongSigns()
    ensures var pre := F.Charge("ch_1", 100, 30, true);
            var t := Tr(pre, "req_1", 40, "returned_item", -10);
            Bridge2(IdEnv, pre, t, CheckAcceptsAll, AllNative).Sign? && !F.Authorizes(pre, t) &&
            !NativeOkOn(AllNative, Encode(IdEnv, pre, t.request))
  {}

  // P5: an invalid pre-state (remaining > original; negative remaining) is refused with the spec native.
  lemma InvalidPreRefused()
    ensures var pre := F.Charge("ch_1", 50, 60, true);
            Bridge2(IdEnv, pre, Tr(pre, "req_1", 10, "returned_item", 50), CheckAcceptsAll, SpecNative).Refuse?
    ensures var pre := F.Charge("ch_1", 50, -5, true);
            Bridge2(IdEnv, pre, Tr(pre, "req_1", 0, "returned_item", -5), CheckAcceptsAll, SpecNative).Refuse?
  {}

  // P6: a refusing native (None) satisfies NativeOkOn trivially and Bridge2 refuses.
  function NoneNative(x: FlatIn): Option<FlatTuple> { None }
  lemma NoneRefuses(pre: F.Charge, t: F.Transition, check: (F.Charge, F.Transition) -> bool)
    ensures NativeOkOn(NoneNative, Encode(IdEnv, pre, t.request))
    ensures Bridge2(IdEnv, pre, t, check, NoneNative).Refuse?
  {}
}
