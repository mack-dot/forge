// x-bridge2 (night shift 2026-11-19, Orchestrator B). The single-input dual-check bridge, as a MODEL.
// MACHINE-CHECKED only about the decision FUNCTION Bridge2, with `check` (the compiled checker, possibly
// miscompiled) and `native` (launcher + strict parser + native program; None = no complete clean frame)
// as PARAMETERS. It says nothing about the binary, the compiler, the launcher, or the Python code.
// Byte-equal copies (see ../copies-sha256.txt): impl/RefundFinality.dfy, impl/Refund.dfy,
// spec/refund/RefundSpec.dfy. FlatIn and FlatContract below are text copies of SliceTheorem.dfy (Z9).
include "impl/RefundFinality.dfy"

module Bridge2Model {
  import F = RefundFinality
  import R = Refund

  datatype Option<T> = None | Some(value: T)

  // ---- the flat boundary (text copy of SliceTheorem.FlatIn / FlatContract; L.FlatTuple shape) ----
  datatype FlatIn = FlatIn(chargeB: string, requestB: string, original: int, remaining: int,
                           enabled: bool, requestOpen: bool, candidate: bool, amount: int, reasonB: string)
  type FlatTuple = (bool, int, string, string, string, int)

  predicate FlatContract(x: FlatIn, o: FlatTuple)
  {
    (o.0 <==>
      x.chargeB != "" && x.requestB != "" && x.enabled && x.requestOpen &&
      0 <= x.original <= 9223372036854775807 && 0 <= x.remaining <= x.original &&
      x.candidate && 0 <= x.amount <= x.remaining &&
      (x.reasonB == "duplicate_charge" || x.reasonB == "service_not_delivered" || x.reasonB == "returned_item")) &&
    (o.0 ==> o.1 == x.amount && o.2 == x.reasonB && o.3 == x.chargeB && o.4 == x.requestB && o.5 == 1) &&
    (!o.0 ==> o.1 == 0 && o.2 == "" && o.3 == "" && o.4 == "" && o.5 == 0)
  }

  // ---- the bridge's own environment: codec (UTF-8 in decide2.py), text range, pre-state digest ----
  datatype Env = Env(enc: string -> string, dec: string -> string, textOk: string -> bool, h: F.Charge -> string)

  // What the bridge needs of its codec: dec undoes enc; "" and the three reasons are fixed points.
  ghost predicate CodecOk(env: Env) {
    (forall s :: env.dec(env.enc(s)) == s) && env.enc("") == "" &&
    env.enc("duplicate_charge") == "duplicate_charge" &&
    env.enc("service_not_delivered") == "service_not_delivered" &&
    env.enc("returned_item") == "returned_item"
  }

  predicate InRange(env: Env, pre: F.Charge, t: F.Transition) {
    env.textOk(pre.chargeId) && env.textOk(t.request.requestId) && env.textOk(t.request.reason) &&
    0 <= pre.original <= 9223372036854775807 && 0 <= pre.remaining <= 9223372036854775807 &&
    0 <= t.request.amount <= 9223372036854775807
  }

  // (a) the fixed encoding: flat inputs from (pre, t.request) ONLY. t.post and t.intent are not sent.
  function Encode(env: Env, pre: F.Charge, q: F.Request): FlatIn {
    FlatIn(env.enc(pre.chargeId), env.enc(q.requestId), pre.original, pre.remaining, pre.refundEnabled,
           true, true, q.amount, env.enc(q.reason))
  }

  // (b) the expected native result once the checker issued: the authorized tuple for exactly x.
  function AuthTuple(x: FlatIn): FlatTuple { (true, x.amount, x.reasonB, x.chargeB, x.requestB, 1) }

  datatype Decision = Refuse(why: string) | Sign(token: F.Token)

  // The decision of decide2.py, in the same order. ONE candidate (pre, t) is the only input.
  function Bridge2(env: Env, pre: F.Charge, t: F.Transition,
                   check: (F.Charge, F.Transition) -> bool, native: FlatIn -> Option<FlatTuple>): Decision
  {
    if !InRange(env, pre, t) then Refuse("OUT_OF_RANGE")
    else
      var x := Encode(env, pre, t.request);
      var r := native(x);
      if r.None? then Refuse("NO_FRAME")
      else if r.value != AuthTuple(x) then Refuse("FRAME_NOT_AUTHORIZED_TUPLE")
      else
        var o := r.value;
        var post := pre.(remaining := pre.remaining - o.1);                      // recomputed
        var intent := R.Intent(pre.chargeId, env.dec(o.4), o.1, env.dec(o.2));    // recomputed
        if t.post != post then Refuse("POST_MISMATCH")
        else if t.intent != intent then Refuse("INTENT_MISMATCH")
        else Sign(F.Token(env.h(pre), env.dec(o.4), post, intent))
  }

  // The HOL-side statement, on the ONE input the bridge uses: a frame, if any, meets the flat contract.
  predicate NativeOkOn(native: FlatIn -> Option<FlatTuple>, x: FlatIn) {
    native(x).Some? ==> FlatContract(x, native(x).value)
  }

  // ---- codec facts ----
  lemma DecEnc(env: Env, s: string)
    requires CodecOk(env)
    ensures env.dec(env.enc(s)) == s
  {}

  lemma EmptyBack(env: Env, s: string)
    requires CodecOk(env)
    ensures env.enc(s) == "" <==> s == ""
  {
    if env.enc(s) == "" { DecEnc(env, s); DecEnc(env, ""); }
  }

  lemma ReasonBack(env: Env, s: string)
    requires CodecOk(env)
    ensures (env.enc(s) == "duplicate_charge" || env.enc(s) == "service_not_delivered" ||
             env.enc(s) == "returned_item") <==> R.AllowedReason(s)
  {
    DecEnc(env, s); DecEnc(env, "duplicate_charge"); DecEnc(env, "service_not_delivered");
    DecEnc(env, "returned_item");
  }

  // ---- (i) SOUND-NATIVE: whatever `check` is ----
  lemma SoundNative(env: Env, pre: F.Charge, t: F.Transition,
                    check: (F.Charge, F.Transition) -> bool, native: FlatIn -> Option<FlatTuple>)
    requires CodecOk(env)
    requires NativeOkOn(native, Encode(env, pre, t.request))
    requires Bridge2(env, pre, t, check, native).Sign?
    ensures F.Authorizes(pre, t)
    ensures Bridge2(env, pre, t, check, native).token ==
            F.Token(env.h(pre), t.request.requestId, t.post, t.intent)
  {
    var x := Encode(env, pre, t.request);
    assert native(x) == Some(AuthTuple(x));
    assert FlatContract(x, AuthTuple(x));
    DecEnc(env, t.request.requestId); DecEnc(env, t.request.reason);
    EmptyBack(env, pre.chargeId); EmptyBack(env, t.request.requestId); ReasonBack(env, t.request.reason);
  }

  // ---- (ii) SOUND-CHECK: whatever `native` is ----
  lemma SoundCheck(env: Env, pre: F.Charge, t: F.Transition,
                   check: (F.Charge, F.Transition) -> bool, native: FlatIn -> Option<FlatTuple>)
    requires CodecOk(env)
    requires check(pre, t) ==> F.Authorizes(pre, t)
    requires Bridge2(env, pre, t, check, native).Sign?
    ensures F.Authorizes(pre, t)
    ensures Bridge2(env, pre, t, check, native).token ==
            F.Token(env.h(pre), t.request.requestId, t.post, t.intent)
  {
    DecEnc(env, t.request.requestId);
  }

  // ---- (iii) COMPLETE: both right, authorized, in range ==> Sign (no reject-all) ----
  lemma Complete(env: Env, pre: F.Charge, t: F.Transition,
                 check: (F.Charge, F.Transition) -> bool, native: FlatIn -> Option<FlatTuple>)
    requires CodecOk(env) && InRange(env, pre, t)
    requires check(pre, t) <==> F.Authorizes(pre, t)
    requires native(Encode(env, pre, t.request)).Some? && NativeOkOn(native, Encode(env, pre, t.request))
    requires F.Authorizes(pre, t)
    ensures Bridge2(env, pre, t, check, native) == Sign(F.Token(env.h(pre), t.request.requestId, t.post, t.intent))
  {
    var x := Encode(env, pre, t.request);
    DecEnc(env, t.request.requestId); DecEnc(env, t.request.reason);
    EmptyBack(env, pre.chargeId); EmptyBack(env, t.request.requestId); ReasonBack(env, t.request.reason);
    assert native(x).value == AuthTuple(x);
  }

  // ---- concrete instances: identity codec (meets CodecOk), the specification native, a true checker ----
  function Id(s: string): string { s }
  function AnyText(s: string): bool { true }
  function H0(c: F.Charge): string { "h" }
  const IdEnv: Env := Env(Id, Id, AnyText, H0)

  function FlatSpec(x: FlatIn): FlatTuple {
    if x.chargeB != "" && x.requestB != "" && x.enabled && x.requestOpen &&
       0 <= x.original <= 9223372036854775807 && 0 <= x.remaining <= x.original &&
       x.candidate && 0 <= x.amount <= x.remaining &&
       (x.reasonB == "duplicate_charge" || x.reasonB == "service_not_delivered" || x.reasonB == "returned_item")
    then AuthTuple(x) else (false, 0, "", "", "", 0)
  }
  function SpecNative(x: FlatIn): Option<FlatTuple> { Some(FlatSpec(x)) }

  lemma SpecNativeOk(x: FlatIn)
    ensures NativeOkOn(SpecNative, x) && SpecNative(x).Some?
  {}

  // A compiled restatement of F.Authorizes (the true checker).
  predicate TrueCheck(pre: F.Charge, t: F.Transition) {
    R.Eligible(F.ContextOf(pre, t.request.requestId), R.Candidate(t.request.amount, t.request.reason)) &&
    t.post == pre.(remaining := pre.remaining - t.request.amount) &&
    t.intent == R.Intent(pre.chargeId, t.request.requestId, t.request.amount, t.request.reason)
  }
  lemma TrueCheckIsAuthorizes(pre: F.Charge, t: F.Transition)
    ensures TrueCheck(pre, t) <==> F.Authorizes(pre, t)
  {}

  lemma IdEnvOk() ensures CodecOk(IdEnv) {}

  const MAXM: int := 9223372036854775807
  function Tr(pre: F.Charge, q: string, a: int, why: string, postRem: int): F.Transition {
    F.Transition(F.Request(q, a, why), pre.(remaining := postRem), R.Intent(pre.chargeId, q, a, why))
  }

  // Non-vacuity: honest authorize, zero amount, max amount sign; honest reject refuses.
  lemma Witnesses()
    ensures var pre := F.Charge("ch_1", 100, 60, true);
            Bridge2(IdEnv, pre, Tr(pre, "req_1", 40, "returned_item", 20), TrueCheck, SpecNative).Sign?
    ensures var pre := F.Charge("ch_1", 100, 60, true);
            Bridge2(IdEnv, pre, Tr(pre, "req_0", 0, "duplicate_charge", 60), TrueCheck, SpecNative).Sign?
    ensures var pre := F.Charge("c", MAXM, MAXM, true);
            Bridge2(IdEnv, pre, Tr(pre, "r", MAXM, "returned_item", 0), TrueCheck, SpecNative).Sign?
    ensures var pre := F.Charge("ch_1", 100, 60, false);
            Bridge2(IdEnv, pre, Tr(pre, "req_1", 40, "returned_item", 20), TrueCheck, SpecNative).Refuse?
  {}

  // ---- (iv) the OLD bridge shape: six fields from the token, inputs x passed SEPARATELY ----
  function OldFields(env: Env, t: F.Transition): FlatTuple {
    (true, t.intent.amount, env.enc(t.intent.reason), env.enc(t.intent.chargeId), env.enc(t.request.requestId), 1)
  }
  function OldBridge(env: Env, pre: F.Charge, t: F.Transition, check: (F.Charge, F.Transition) -> bool,
                     x: FlatIn, native: FlatIn -> Option<FlatTuple>): Decision {
    if !check(pre, t) then Refuse("DAFNY_REFUSE")
    else if native(x) != Some(OldFields(env, t)) then Refuse("MISMATCH")
    else Sign(F.Token(env.h(pre), t.request.requestId, t.post, t.intent))
  }

  // Miscompiled checkers (models): one ignores the post-state; one accepts everything.
  predicate CheckIgnoresPost(pre: F.Charge, t: F.Transition) {
    R.Eligible(F.ContextOf(pre, t.request.requestId), R.Candidate(t.request.amount, t.request.reason)) &&
    t.intent == R.Intent(pre.chargeId, t.request.requestId, t.request.amount, t.request.reason)
  }
  predicate CheckAcceptsAll(pre: F.Charge, t: F.Transition) { true }

  // Reviewer H: wrong post-state (59 instead of 20), miscompiled check, CORRECT native, same inputs.
  lemma AttackPostState()
    ensures var pre := F.Charge("ch_1", 100, 60, true);
            var t := Tr(pre, "req_1", 40, "returned_item", 59);
            !F.Authorizes(pre, t) &&
            OldBridge(IdEnv, pre, t, CheckIgnoresPost, Encode(IdEnv, pre, t.request), SpecNative).Sign? &&
            Bridge2(IdEnv, pre, t, CheckIgnoresPost, SpecNative) == Refuse("POST_MISMATCH")
  {}

  // Reviewer M: native inputs from another pre-state (remaining 50) while pre has remaining 30 < 40;
  // miscompiled check accepts all; CORRECT native.
  lemma AttackSeparateInputs()
    ensures var pre := F.Charge("ch_1", 100, 30, true);
            var other := F.Charge("ch_1", 100, 50, true);
            var t := Tr(pre, "req_1", 40, "returned_item", -10);
            !F.Authorizes(pre, t) &&
            OldBridge(IdEnv, pre, t, CheckAcceptsAll, Encode(IdEnv, other, t.request), SpecNative).Sign? &&
            Bridge2(IdEnv, pre, t, CheckAcceptsAll, SpecNative) == Refuse("FRAME_NOT_AUTHORIZED_TUPLE")
  {}
}
