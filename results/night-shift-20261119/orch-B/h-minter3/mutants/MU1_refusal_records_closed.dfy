// h-minter3 MUTANT MU1_refusal_records_closed of IssueAuth.dfy (must FAIL).
// Night shift 2026-11-19, Orchestrator B, tasks h-minter2 and h-minter3. A DRAFT on the branch only. NOT gate evidence.
// The issuer's memory rule, version 2 under owner decision D-2 (a refusal records nothing), proved at the source level (Dafny 4.11.0). Replaces
// IssueOnce.Issue in minter.ts (IssueOnce.dfy stays as the record of rule 1).
//
// WHY (red team C-ATT-30): rule 1 trusted the CALLER's pre-state. A caller without the key could sign a zero-amount
// token for the victim's (charge id, request id) on an INVENTED pre-state; the token never commits, but the pair was
// then taken for ever. The governing context (owner decision B-10) is the approved policy plus the AUTHORITATIVE
// PERSISTED charge state. Rule 2 lets only a call on that state change the memory.
//
// OWNER DECISION D-2 (2026-11-19, answers B-19): "A minter refusal closes ONLY that attempt, NOT the whole request
// ID (closing C-ATT-38). Only an accepted/minted token (and sink commit) closes the request ID, preserving <= 1 valid
// token and <= 1 effect per request ID." So a refusal records NOTHING. A request id closes only by a minted token (the
// memory holds Signed(bytes) for its key) or by the sink's commit (Store mode: a.requestSettled).
// The earlier rule (h-minter2: a core refusal closed the key) stays only as a MODEL: OldAfter and the lemma
// OldRuleFreeze show the red team's spray (C-ATT-38) against it. It is not compiled into the step.
// Invariants (Store mode; the no-store mode keys on the pre-state hash and is a TEST mode only, see below):
//   I1 at most one valid token per (charge id, request id): RunSeq ensures I1 (one byte string per pair among Issued
//      and Replayed outcomes; so any other candidate for a minted pair is refused, and an identical request gets the
//      identical bytes: WRetry, WStaleRetry).
//   I2 a refusal records nothing that affects any later request: Issue ensures (!o.Issued? ==> m2 == m); RunSeq ensures
//      I2; SprayHarmless (after ANY sequence of calls by anyone that were not Issued on the victim's key, the victim's
//      honest authorized call on the authoritative state is Issued).
//   I3 a settled request id stays closed: Issue ensures (o.Issued? ==> Admitted), RunSeq ensures I3 (no call with a
//      settled request id is Issued; only the identical bytes already minted can be Replayed).
//   COMPOSED CLAIM (not proved here): at most one EFFECT per request id = I1 + the sink rule (the sink's settled table
//   has request_id UNIQUE and commits a token only on its stored pre-state; sink.ts and core/store.ts). Tested end to
//   end in m3_one_effect_per_request_id.ts.
// LOST against the letter of protocol.md:61-62 and 64-65 (owner-approved by D-2): after a rejection the same request
// id can still be signed; an identical repeat of a refused request is decided again, not answered from a record (the
// core refusal is a function of the call alone, RefusedByCore <==> !Issuable, so it gives the same answer).
// The no-store mode: key = (charge id, request id, pre-state hash). Two tokens can exist for one request id on two
// pre-states: it does NOT give I1. minter.ts runs it only as a test mode (a warning on stderr, "singleUse":"none" in the
// ready line); the closed launch (minter-launch.sh) refuses it.
//
// RULE 2. The shell passes `a`, what it read from the sink's store for this request (read only):
//   a = Store(state, requestSettled): the store's current charge, and whether the request id is settled there;
//   a = NoStore: no store is configured (the issuer cannot know the authoritative state).
//   key = (charge id, request id)        in Store mode,
//   key = (charge id, request id, h)     in NoStore mode (h = the pre-state hash text that the body carries).
//   In this order (h-minter3: the core check comes FIRST, so the text "core: Refuse" depends on the call alone and not
//   on the stored state; red team C-ATT-38 used the earlier order as a state oracle):
//   the core (IssueBytes2.IssueTokenBytes) refuses -> RefusedByCore, memory unchanged (D-2);
//   the key holds Signed(exactly the bytes of this call) -> Replayed(bytes), memory unchanged (an identical retry,
//                                                     also after the store moved on: protocol.md:63-64);
//   Store mode, the request id is settled          -> RefusedCompleted, memory unchanged (closed by completion);
//   the key holds Closed                           -> RefusedClosed (only a memory passed in can hold Closed:
//                                                     this rule never records it);
//   the key holds Signed(other bytes)              -> RefusedOtherCandidate (protocol.md:64-65);
//   Store mode, pre != state                       -> RefusedNotAuthoritative, memory unchanged;
//   the key is new (and the call is admitted)      -> Issued(bytes), memory gets key -> Signed(bytes).
//
// WHAT THE PROOF COVERS AND WHAT IT DOES NOT (review r-issueauth). The theorems are about the method Issue and about
// sequences of Issue calls. The authoritative state, the settled flag (both inside `a`) and the pre-state hash text h
// are FREE PARAMETERS of Issue: the model does not know which file is the sink's store, whether `a` is what that file
// holds now, or whether h is SHA-256 of canon(pre). Those bindings are TypeScript glue in minter.ts, under named
// assumptions: STORE-READ (the path is the sink's store and minter.ts reads it correctly at each request) and G-H (h is
// the lowercase hex SHA-256 of canon(pre), computed once in minter.ts). The reviewer's probes ProbeFreeAuth (an invented
// state passed as `a` is Issued) and ProbeHashFree (two hash texts for one pre-state; the first takes the key) still
// verify against this file: no cheap strengthening was found (no uninterpreted hash exists in SerModel or IssueBytes2;
// a bodiless function would be an audit finding; a hash-function parameter binds h only inside one RunSeq and needs a
// rewrite of this method). The memory that minter.ts passes in is also a free parameter (C-ATT-40: in mode "off" with
// a store, minter.ts seeds it with the body of the settled token for this request id; safety does not depend on it:
// every signing outcome is authorized for THIS call and returns exactly its canonical bytes, whatever the memory holds).
//
// PROVED HERE (MACHINE-CHECKED only after a run of the lock script; see the evidence directory h-minter3):
//   Issue (step): the exact outcome and memory for each case; every signing outcome is authorized by
//     RefundFinality, has a well-formed body and returns exactly its canonical bytes; NEW bytes (Issued) only on the
//     authoritative state with an unsettled request id (Store mode); a Replayed outcome returns bytes already in the
//     memory; every outcome other than Issued leaves the memory unchanged.
//   RunSeq (any finite call sequence): S1 one byte string per key; I1; I2; I3; S2 every signing call is authorized,
//     and every Issued call in Store mode is on the authoritative state with an unsettled request id; S4 a
//     non-admitted call leaves the memory unchanged; L3 an admitted, issuable call whose key is new is Issued.
//   Live, SquatsThenVictim (C-ATT-30), SprayHarmless (C-ATT-38), OldRuleFreeze (the old rule's spray), witnesses.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "<REPO>/results/night-shift-20261119/orch-B/h-minter3/tree/impl/finality-core/IssueBytes2.dfy"

module IssueAuth {
  import F = RefundFinality
  import R = Refund
  import SM = SerModel
  import IB = IssueBytes2

  type Bytes = seq<IB.uint8>
  // scoped = false: Store mode, scope = "". scoped = true: NoStore mode, scope = the pre-state hash text.
  datatype Key = Key(chargeId: string, requestId: string, scoped: bool, scope: string)
  datatype Rec = Signed(bytes: Bytes) | Closed
  type Memory = map<Key, Rec>
  datatype Auth = NoStore | Store(state: F.Charge, requestSettled: bool)

  datatype Outcome = Issued(bytes: Bytes) | Replayed(bytes: Bytes) | RefusedByCore | RefusedOtherCandidate
                   | RefusedClosed | RefusedNotAuthoritative | RefusedCompleted
  {
    predicate Signs() { Issued? || Replayed? }
  }

  function KeyFor(a: Auth, pre: F.Charge, t: F.Transition, h: string): Key
  {
    if a.Store? then Key(pre.chargeId, t.request.requestId, false, "")
    else Key(pre.chargeId, t.request.requestId, true, h)
  }
  // A call may touch the memory only when it is admitted.
  predicate Admitted(a: Auth, pre: F.Charge) { a.Store? ==> a.state == pre && !a.requestSettled }
  predicate Settled(a: Auth) { a.Store? && a.requestSettled }

  opaque ghost function Expected(t: F.Transition, sh: string, ch: string, h: string): seq<int>
  {
    SM.Utf8(SM.SerBody(IB.BodyFor(sh, ch, h, t)))
  }
  opaque ghost predicate Issuable(pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
  {
    F.Authorizes(pre, t) && SM.WfBody(IB.BodyFor(sh, ch, h, t))
  }

  lemma ToIntsInjective(a: Bytes, b: Bytes)
    requires IB.ToInts(a) == IB.ToInts(b)
    ensures a == b
  {
    assert |a| == |IB.ToInts(a)| == |IB.ToInts(b)| == |b|;
    forall i | 0 <= i < |a| ensures a[i] == b[i] {
      assert IB.ToInts(a)[i] == IB.ToInts(b)[i];
    }
  }

  ghost predicate Extends(m: Memory, m2: Memory)
  {
    forall k | k in m :: k in m2 && m2[k] == m[k]
  }

  // The memory after a call (one formula, used by the step and by the lemmas): only a minted token changes it (D-2).
  ghost function After(m: Memory, k: Key, o: Outcome): Memory
  {
    if o.Issued? then m[k := Signed(o.bytes)] else m
  }
  // The EARLIER rule (h-minter2), as a model only: an admitted call that the core refused on a new key closed the key.
  function OldAfter(adm: bool, m: Memory, k: Key, o: Outcome): Memory
  {
    if o.Issued? then m[k := Signed(o.bytes)]
    else if adm && o.RefusedByCore? && k !in m then m[k := Closed]
    else m
  }

  // An identical retry: the key holds Signed(exactly the bytes of this call).
  ghost predicate IsReplay(m: Memory, a: Auth, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
  {
    Issuable(pre, t, sh, ch, h) && KeyFor(a, pre, t, h) in m && m[KeyFor(a, pre, t, h)].Signed? &&
    IB.ToInts(m[KeyFor(a, pre, t, h)].bytes) == Expected(t, sh, ch, h)
  }

  // =============================================================================================
  // THE ISSUER STEP. The shell (minter.ts) signs exactly o.bytes when o.Signs().
  method Issue(m: Memory, a: Auth, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (m2: Memory, o: Outcome)
    // Outcome for each case.
    ensures o.RefusedByCore? <==> !Issuable(pre, t, sh, ch, h)
    ensures o.Replayed? <==> IsReplay(m, a, pre, t, sh, ch, h)
    ensures o.Replayed? ==> o.bytes == m[KeyFor(a, pre, t, h)].bytes
    ensures o.RefusedCompleted? <==> Issuable(pre, t, sh, ch, h) && !IsReplay(m, a, pre, t, sh, ch, h) && Settled(a)
    ensures o.RefusedClosed? <==> Issuable(pre, t, sh, ch, h) && !Settled(a) &&
                                  KeyFor(a, pre, t, h) in m && m[KeyFor(a, pre, t, h)].Closed?
    ensures o.RefusedOtherCandidate? <==> Issuable(pre, t, sh, ch, h) && !Settled(a) &&
                                          KeyFor(a, pre, t, h) in m && m[KeyFor(a, pre, t, h)].Signed? &&
                                          IB.ToInts(m[KeyFor(a, pre, t, h)].bytes) != Expected(t, sh, ch, h)
    ensures o.RefusedNotAuthoritative? <==> Issuable(pre, t, sh, ch, h) && !Settled(a) && KeyFor(a, pre, t, h) !in m &&
                                            a.Store? && a.state != pre
    ensures o.Issued? <==> Admitted(a, pre) && Issuable(pre, t, sh, ch, h) && KeyFor(a, pre, t, h) !in m
    ensures !Admitted(a, pre) ==> m2 == m && (o.Signs() ==> o.Replayed?)
    // Safety of a signing outcome.
    ensures o.Signs() ==> F.Authorizes(pre, t) && SM.WfBody(IB.BodyFor(sh, ch, h, t))
    ensures o.Signs() ==> IB.ToInts(o.bytes) == Expected(t, sh, ch, h)
    ensures o.Signs() ==> IB.ToInts(o.bytes) == SM.SignedBytes(IB.BodyFor(sh, ch, h, t))
    // NEW bytes are signed only on the authoritative state with an unsettled request id.
    ensures o.Issued? ==> Admitted(a, pre)
    // A key that holds Closed never signs.
    ensures KeyFor(a, pre, t, h) in m && m[KeyFor(a, pre, t, h)].Closed? ==> !o.Signs()
    // Memory.
    ensures m2 == After(m, KeyFor(a, pre, t, h), o)
  {
    reveal Expected(); reveal Issuable();
    var k := KeyFor(a, pre, t, h);
    var r := IB.IssueTokenBytes(pre, t, sh, ch, h);
    if r.None? {
      o := RefusedByCore;
      m2 := if Admitted(a, pre) && k !in m then m[k := Closed] else m;
      return;
    }
    if k in m && m[k].Signed? {
      if IB.ToInts(m[k].bytes) == IB.ToInts(r.value) { ToIntsInjective(m[k].bytes, r.value); }
      if m[k].bytes == r.value {
        m2, o := m, Replayed(m[k].bytes);
        return;
      }
    }
    if a.Store? && a.requestSettled {
      m2, o := m, RefusedCompleted;
      return;
    }
    if k in m {
      if m[k].Closed? {
        m2, o := m, RefusedClosed;
      } else {
        m2, o := m, RefusedOtherCandidate;
      }
      return;
    }
    if a.Store? && a.state != pre {
      m2, o := m, RefusedNotAuthoritative;
      return;
    }
    m2, o := m[k := Signed(r.value)], Issued(r.value);
  }

  // Memory facts that follow from After (small lemmas: they keep the step method's contract short).
  lemma AfterExtends(m: Memory, k: Key, o: Outcome)
    requires o.Issued? ==> k !in m
    ensures Extends(m, After(m, k, o))
  {}
  // I2 for one step: every outcome other than Issued leaves the memory as it was.
  lemma RefusalRecordsNothing(m: Memory, k: Key, o: Outcome)
    requires !o.Issued?
    ensures After(m, k, o) == m
  {}

  // =============================================================================================
  // RunSeq: properties over ANY finite call sequence (the auth value may change between calls: the store moves).
  datatype Call = Call(a: Auth, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
  function KeyOfCall(c: Call): Key { KeyFor(c.a, c.pre, c.t, c.h) }
  opaque ghost predicate SignsOk(c: Call, o: Outcome)
  {
    (o.Signs() ==> F.Authorizes(c.pre, c.t)) &&
    (o.Issued? && c.a.Store? ==> c.pre == c.a.state && !c.a.requestSettled)
  }
  // What one Issue call guarantees, in the form the sequence proof needs.
  opaque ghost predicate StepFacts(m: Memory, m2: Memory, c: Call, o: Outcome)
  {
    Extends(m, m2) &&
    (o.Signs() ==> KeyOfCall(c) in m2 && m2[KeyOfCall(c)] == Signed(o.bytes)) &&
    (!o.Issued? ==> m2 == m) &&
    (KeyOfCall(c) in m && m[KeyOfCall(c)].Closed? ==> !o.Signs()) &&
    (!Admitted(c.a, c.pre) ==> m2 == m) &&
    (Admitted(c.a, c.pre) && Issuable(c.pre, c.t, c.sh, c.ch, c.h) && KeyOfCall(c) !in m ==> o.Issued?) &&
    SignsOk(c, o)
  }
  // One Issue call, with its facts in the StepFacts form (keeps RunSeq's loop body small).
  method Step(m: Memory, c: Call) returns (m2: Memory, o: Outcome)
    ensures StepFacts(m, m2, c, o)
    ensures !o.Issued? ==> m2 == m
    ensures o.Issued? ==> m2 == m[KeyOfCall(c) := Signed(o.bytes)]
    ensures o.RefusedByCore? <==> !Issuable(c.pre, c.t, c.sh, c.ch, c.h)
  {
    m2, o := Issue(m, c.a, c.pre, c.t, c.sh, c.ch, c.h);
    AfterExtends(m, KeyOfCall(c), o);
    if !o.Issued? { RefusalRecordsNothing(m, KeyOfCall(c), o); }
    reveal StepFacts(); reveal SignsOk();
  }
  // The loop invariant of RunSeq after n calls.
  ghost predicate Inv(m0: Memory, m: Memory, calls: seq<Call>, outs: seq<Outcome>, ms: seq<Memory>)
  {
    |outs| <= |calls| && |ms| == |outs| &&
    (|outs| > 0 ==> ms[0] == m0) && (|outs| == 0 ==> m == m0) &&
    Extends(m0, m) &&
    (forall i | 0 <= i < |outs| :: outs[i].Signs() ==>
       KeyOfCall(calls[i]) in m && m[KeyOfCall(calls[i])] == Signed(outs[i].bytes)) &&
    (forall i | 0 <= i < |outs| :: SignsOk(calls[i], outs[i])) &&
    (forall i | 0 <= i < |outs| - 1 :: !outs[i].Issued? ==> ms[i + 1] == ms[i]) &&
    (|outs| > 0 && !outs[|outs| - 1].Issued? ==> m == ms[|outs| - 1]) &&
    (forall i | 0 <= i < |outs| - 1 :: !Admitted(calls[i].a, calls[i].pre) ==> ms[i + 1] == ms[i]) &&
    (|outs| > 0 && !Admitted(calls[|outs| - 1].a, calls[|outs| - 1].pre) ==> m == ms[|outs| - 1]) &&
    (forall i | 0 <= i < |outs| ::
       (Admitted(calls[i].a, calls[i].pre) && Issuable(calls[i].pre, calls[i].t, calls[i].sh, calls[i].ch, calls[i].h) &&
        KeyOfCall(calls[i]) !in ms[i]) ==> outs[i].Issued?)
  }
  lemma ExtendsTrans(a: Memory, b: Memory, c: Memory)
    requires Extends(a, b) && Extends(b, c)
    ensures Extends(a, c)
  {}
  lemma StepPreserves(m0: Memory, m: Memory, m2: Memory, calls: seq<Call>, outs: seq<Outcome>, ms: seq<Memory>, o: Outcome)
    requires Inv(m0, m, calls, outs, ms) && |outs| < |calls|
    requires StepFacts(m, m2, calls[|outs|], o)
    ensures Inv(m0, m2, calls, outs + [o], ms + [m])
  {
    reveal StepFacts();
    var n := |outs|;
    var c := calls[n];
    var outs2, ms2 := outs + [o], ms + [m];
    ExtendsTrans(m0, m, m2);
    forall i | 0 <= i < n + 1 && outs2[i].Signs()
      ensures KeyOfCall(calls[i]) in m2 && m2[KeyOfCall(calls[i])] == Signed(outs2[i].bytes)
    {
      if i < n { assert outs2[i] == outs[i]; }
    }
    forall i | 0 <= i < n + 1
      ensures SignsOk(calls[i], outs2[i])
    {
      if i < n { assert outs2[i] == outs[i]; }
    }
    forall i | 0 <= i < n + 1 - 1 && !outs2[i].Issued?
      ensures ms2[i + 1] == ms2[i]
    {
      assert outs2[i] == outs[i];
      if i + 1 < n { assert ms2[i + 1] == ms[i + 1] && ms2[i] == ms[i]; }
    }
    forall i | 0 <= i < n + 1 - 1 && !Admitted(calls[i].a, calls[i].pre)
      ensures ms2[i + 1] == ms2[i]
    {
      if i + 1 < n { assert ms2[i + 1] == ms[i + 1] && ms2[i] == ms[i]; }
    }
    forall i | 0 <= i < n + 1 &&
        (Admitted(calls[i].a, calls[i].pre) && Issuable(calls[i].pre, calls[i].t, calls[i].sh, calls[i].ch, calls[i].h) &&
         KeyOfCall(calls[i]) !in ms2[i])
      ensures outs2[i].Issued?
    {
      if i < n { assert outs2[i] == outs[i] && ms2[i] == ms[i]; }
    }
  }

  method RunSeq(m0: Memory, calls: seq<Call>) returns (m: Memory, outs: seq<Outcome>, ghost ms: seq<Memory>)
    ensures |outs| == |calls| && |ms| == |calls|
    ensures Extends(m0, m)
    // S1: one byte string per key.
    ensures forall i, j | 0 <= i < |calls| && 0 <= j < |calls| ::
              KeyOfCall(calls[i]) == KeyOfCall(calls[j]) && outs[i].Signs() && outs[j].Signs() ==>
              outs[i].bytes == outs[j].bytes
    // S2: authority.
    ensures forall i | 0 <= i < |calls| :: SignsOk(calls[i], outs[i])
    // I1 (Store mode): at most one byte string per (charge id, request id) among Issued and Replayed outcomes.
    ensures forall i, j | 0 <= i < |calls| && 0 <= j < |calls| ::
              calls[i].a.Store? && calls[j].a.Store? && calls[i].pre.chargeId == calls[j].pre.chargeId &&
              calls[i].t.request.requestId == calls[j].t.request.requestId && outs[i].Signs() && outs[j].Signs() ==>
              outs[i].bytes == outs[j].bytes
    // I2: a call that is not Issued (every refusal) leaves the memory as it was.
    ensures forall i | 0 <= i < |calls| - 1 :: !outs[i].Issued? ==> ms[i + 1] == ms[i]
    ensures |calls| > 0 && !outs[|calls| - 1].Issued? ==> m == ms[|calls| - 1]
    // I3: a call whose request id is settled in the store is never Issued.
    ensures forall i | 0 <= i < |calls| :: Settled(calls[i].a) ==> !outs[i].Issued?
    // S4: a call that is not admitted leaves the memory as it was.
    ensures forall i | 0 <= i < |calls| - 1 :: !Admitted(calls[i].a, calls[i].pre) ==> ms[i + 1] == ms[i]
    ensures |calls| > 0 ==> ms[0] == m0
    // L3: a call that is admitted, issuable and whose key is new at that point is Issued.
    ensures forall i | 0 <= i < |calls| ::
              (Admitted(calls[i].a, calls[i].pre) && Issuable(calls[i].pre, calls[i].t, calls[i].sh, calls[i].ch, calls[i].h) &&
               KeyOfCall(calls[i]) !in ms[i]) ==> outs[i].Issued?
  {
    m, outs, ms := m0, [], [];
    while |outs| < |calls|
      invariant Inv(m0, m, calls, outs, ms)
      decreases |calls| - |outs|
    {
      var c := calls[|outs|];
      var m2, o := Step(m, c);
      StepPreserves(m0, m, m2, calls, outs, ms, o);
      m, outs, ms := m2, outs + [o], ms + [m];
    }
    reveal SignsOk();
    forall i, j | 0 <= i < |calls| && 0 <= j < |calls| &&
        calls[i].a.Store? && calls[j].a.Store? && calls[i].pre.chargeId == calls[j].pre.chargeId &&
        calls[i].t.request.requestId == calls[j].t.request.requestId && outs[i].Signs() && outs[j].Signs()
      ensures outs[i].bytes == outs[j].bytes
    {
      assert KeyOfCall(calls[i]) == KeyOfCall(calls[j]);
    }
  }

  // =============================================================================================
  // LIVENESS.
  // Live: an authorized, well-formed request on the authoritative pre-state, request id not settled, key new: Issued.
  method Live(m: Memory, state: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (m2: Memory, o: Outcome)
    requires KeyFor(Store(state, false), state, t, h) !in m && Issuable(state, t, sh, ch, h)
    ensures o.Issued? && IB.ToInts(o.bytes) == Expected(t, sh, ch, h)
  {
    m2, o := Issue(m, Store(state, false), state, t, sh, ch, h);
  }

  // A call that cannot block the victim v: not admitted, or another key.
  ghost predicate Harmless(s: Call, v: Call)
  {
    !Admitted(s.a, s.pre) || KeyOfCall(s) != KeyOfCall(v)
  }
  // In Store mode, every call on a pre-state that is not the store's state is harmless (whatever its key).
  lemma WrongStateHarmless(s: Call, v: Call)
    requires s.a.Store? && s.a.state != s.pre
    ensures Harmless(s, v)
  {}
  // In NoStore mode, a call whose pre-state hash text differs from the victim's has another key.
  lemma OtherHashHarmless(s: Call, v: Call)
    requires s.a.NoStore? && v.a.NoStore? && s.h != v.h
    ensures Harmless(s, v)
  {}

  // SquatsThenVictim: ANY sequence of harmless calls (C-ATT-30 squats on invented pre-states
  // included), then the victim's authorized, well-formed call whose key was new at the start: the victim is Issued.
  method SquatsThenVictim(m0: Memory, squats: seq<Call>, v: Call) returns (outs: seq<Outcome>, ov: Outcome)
    requires Admitted(v.a, v.pre) && Issuable(v.pre, v.t, v.sh, v.ch, v.h)
    requires KeyOfCall(v) !in m0
    requires forall i | 0 <= i < |squats| :: Harmless(squats[i], v)
    ensures ov.Issued? && IB.ToInts(ov.bytes) == Expected(v.t, v.sh, v.ch, v.h)
  {
    var m := m0;
    outs := [];
    var n := 0;
    while n < |squats|
      invariant 0 <= n <= |squats|
      invariant KeyOfCall(v) !in m
    {
      var s := squats[n];
      var m2, o := Issue(m, s.a, s.pre, s.t, s.sh, s.ch, s.h);
      m := m2;
      outs := outs + [o];
      n := n + 1;
    }
    var m3;
    m3, ov := Issue(m, v.a, v.pre, v.t, v.sh, v.ch, v.h);
  }

  // SprayHarmless (I2; red team C-ATT-38; owner decision D-2): ANY sequence of calls by others (on any
  // pre-state, with any key, the victim's key included), then the victim's honest call (authorized, well-formed, on the
  // authoritative state, request id not settled, key new at the start). If no call of the sequence was Issued on the
  // victim's key (that is: the others were refused, or signed under other keys), the victim is Issued.
  // The excluded case (a call Issued on the victim's key before the victim) is the squat on the real state (C-ATT-08
  // class, WSquatRealState): it needs an AUTHORIZED call; no refusal can block the victim.
  method SprayHarmless(m0: Memory, spray: seq<Call>, v: Call) returns (outs: seq<Outcome>, ov: Outcome)
    requires Admitted(v.a, v.pre) && Issuable(v.pre, v.t, v.sh, v.ch, v.h)
    requires KeyOfCall(v) !in m0
    ensures |outs| == |spray|
    ensures forall i | 0 <= i < |spray| :: outs[i].RefusedByCore? <==> !Issuable(spray[i].pre, spray[i].t, spray[i].sh, spray[i].ch, spray[i].h)
    ensures (forall i | 0 <= i < |spray| :: !outs[i].Issued? || KeyOfCall(spray[i]) != KeyOfCall(v)) ==>
              ov.Issued? && IB.ToInts(ov.bytes) == Expected(v.t, v.sh, v.ch, v.h)
  {
    var m := m0;
    outs := [];
    while |outs| < |spray|
      invariant |outs| <= |spray|
      invariant forall i | 0 <= i < |outs| ::
                  outs[i].RefusedByCore? <==> !Issuable(spray[i].pre, spray[i].t, spray[i].sh, spray[i].ch, spray[i].h)
      invariant (forall i | 0 <= i < |outs| :: !outs[i].Issued? || KeyOfCall(spray[i]) != KeyOfCall(v)) ==>
                  KeyOfCall(v) !in m
    {
      var s := spray[|outs|];
      var m2, o := Step(m, s);
      m := m2;
      outs := outs + [o];
    }
    var m3;
    m3, ov := Issue(m, v.a, v.pre, v.t, v.sh, v.ch, v.h);
  }

  // =============================================================================================
  // WITNESSES (non-vacuity). W_PRE = Charge("ch_1", 100, 60, true) of IssueBytes2.
  const W_PRE: F.Charge := IB.W_PRE
  const W_FAKE: F.Charge := F.Charge("ch_1", 5, 5, true)                 // an invented pre-state, same charge id
  const W_NEXT: F.Charge := F.Charge("ch_1", 100, 50, true)              // the state after a refund of 10
  const HEXB: string := seq(64, _ => 'b')

  lemma HexB() ensures SM.Hex64(HEXB) {}
  // The witness pre-states: charge id "ch_1", refunds enabled, 0 <= remaining <= original <= 100.
  ghost predicate WState(pre: F.Charge)
  {
    pre.chargeId == "ch_1" && pre.refundEnabled && 0 <= pre.remaining <= pre.original <= 100
  }
  lemma AuthAt(pre: F.Charge, rq: string, amount: int)
    requires WState(pre) && rq != "" && 0 <= amount <= pre.remaining
    ensures F.Authorizes(pre, IB.T(pre, rq, amount))
  {
    assert IB.T(pre, rq, amount).post == pre.(remaining := pre.remaining - amount);
  }
  lemma WfAt(pre: F.Charge, rq: string, amount: int, h: string)
    requires WState(pre) && SM.Hex64(h) && 0 <= amount <= pre.remaining
    requires 2 * |rq| <= SM.MAX_TEXT && forall i | 0 <= i < |rq| :: rq[i] as int != 0
    ensures SM.WfBody(IB.BodyFor(SM.ZERO64, SM.ZERO64, h, IB.T(pre, rq, amount)))
  {
    SM.TextSmall(rq); IB.Tx1(); IB.Tx3(); IB.HexWitness();
    IB.WfOfT(pre, rq, amount, SM.ZERO64, SM.ZERO64, h);
  }
  lemma IssuableAt(pre: F.Charge, rq: string, amount: int, h: string)
    requires WState(pre) && SM.Hex64(h)
    requires rq != "" && 2 * |rq| <= SM.MAX_TEXT && forall i | 0 <= i < |rq| :: rq[i] as int != 0
    requires 0 <= amount <= pre.remaining
    ensures Issuable(pre, IB.T(pre, rq, amount), SM.ZERO64, SM.ZERO64, h)
  {
    reveal Issuable();
    AuthAt(pre, rq, amount);
    WfAt(pre, rq, amount, h);
  }
  lemma Hexes() ensures SM.Hex64(IB.HEXA) && SM.Hex64(HEXB) { IB.HexWitness(); }

  // Small wrappers of Issue (they only restate cases of its postcondition; they keep the witnesses cheap).
  method NewKey(m: Memory, a: Auth, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (m2: Memory, o: Outcome)
    requires Admitted(a, pre) && Issuable(pre, t, sh, ch, h) && KeyFor(a, pre, t, h) !in m
    ensures o.Issued? && IB.ToInts(o.bytes) == Expected(t, sh, ch, h) && m2 == m[KeyFor(a, pre, t, h) := Signed(o.bytes)]
  {
    m2, o := Issue(m, a, pre, t, sh, ch, h);
  }
  method NotAdmitted(m: Memory, a: Auth, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (m2: Memory, o: Outcome)
    requires !Admitted(a, pre) && Issuable(pre, t, sh, ch, h) && KeyFor(a, pre, t, h) !in m
    ensures m2 == m && !o.Signs()
    ensures a.Store? && !a.requestSettled && a.state != pre ==> o.RefusedNotAuthoritative?
    ensures a.Store? && a.requestSettled ==> o.RefusedCompleted?
  {
    m2, o := Issue(m, a, pre, t, sh, ch, h);
  }
  method UsedKey(m: Memory, a: Auth, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (m2: Memory, o: Outcome)
    requires Admitted(a, pre) && Issuable(pre, t, sh, ch, h) && KeyFor(a, pre, t, h) in m
    ensures m2 == m
    ensures m[KeyFor(a, pre, t, h)].Closed? ==> o.RefusedClosed?
    ensures m[KeyFor(a, pre, t, h)].Signed? && IB.ToInts(m[KeyFor(a, pre, t, h)].bytes) != Expected(t, sh, ch, h) ==>
              o.RefusedOtherCandidate?
    ensures m[KeyFor(a, pre, t, h)].Signed? && IB.ToInts(m[KeyFor(a, pre, t, h)].bytes) == Expected(t, sh, ch, h) ==>
              o.Replayed? && o.bytes == m[KeyFor(a, pre, t, h)].bytes
  {
    reveal Expected();
    m2, o := Issue(m, a, pre, t, sh, ch, h);
    if o.Replayed? { assert o.bytes == m[KeyFor(a, pre, t, h)].bytes; }
    if m[KeyFor(a, pre, t, h)].Signed? && IB.ToInts(m[KeyFor(a, pre, t, h)].bytes) == Expected(t, sh, ch, h) {
      assert IB.ToInts(m[KeyFor(a, pre, t, h)].bytes) == Expected(t, sh, ch, h);
      assert o.Signs();
    }
  }
  method Replay(m: Memory, a: Auth, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (m2: Memory, o: Outcome)
    requires IsReplay(m, a, pre, t, sh, ch, h)
    ensures o.Replayed? && o.bytes == m[KeyFor(a, pre, t, h)].bytes && m2 == m
  {
    m2, o := Issue(m, a, pre, t, sh, ch, h);
  }
  method CoreRefused(m: Memory, a: Auth, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (m2: Memory, o: Outcome)
    requires !Issuable(pre, t, sh, ch, h)
    ensures o.RefusedByCore? && m2 == m
  {
    m2, o := Issue(m, a, pre, t, sh, ch, h);
  }

  // C-ATT-30, Store mode: a zero-amount squat on an INVENTED pre-state is refused and records nothing; the victim's
  // request on the real state is then Issued.
  method WSquatStore() returns (s: Outcome, v: Outcome)
    ensures s.RefusedNotAuthoritative? && v.Issued?
  {
    Hexes(); IssuableAt(W_PRE, "rq_v", 40, IB.HEXA); IssuableAt(W_FAKE, "rq_v", 0, HEXB);
    var m: Memory := map[];
    var a := Store(W_PRE, false);
    m, s := NotAdmitted(m, a, W_FAKE, IB.T(W_FAKE, "rq_v", 0), SM.ZERO64, SM.ZERO64, HEXB);
    m, v := NewKey(m, a, W_PRE, IB.T(W_PRE, "rq_v", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // C-ATT-30, NoStore mode: the squat on the invented pre-state IS signed (no store to compare with), but under
  // another key (its own pre-state hash); the victim is then Issued.
  method WSquatNoStore() returns (s: Outcome, v: Outcome)
    ensures s.Issued? && v.Issued?
  {
    Hexes(); IssuableAt(W_FAKE, "rq_v", 0, HEXB); IssuableAt(W_PRE, "rq_v", 40, IB.HEXA);
    var m: Memory := map[];
    m, s := NewKey(m, NoStore, W_FAKE, IB.T(W_FAKE, "rq_v", 0), SM.ZERO64, SM.ZERO64, HEXB);
    assert IB.HEXA != HEXB by { assert IB.HEXA[0] != HEXB[0]; }
    m, v := NewKey(m, NoStore, W_PRE, IB.T(W_PRE, "rq_v", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // Zero amounts stay legitimate : two zero-amount requests and a positive one on one state: Issued.
  method WZeroZeroPositive() returns (a: Outcome, b: Outcome, c: Outcome)
    ensures a.Issued? && b.Issued? && c.Issued?
    ensures IB.T(W_PRE, "rz_1", 0).request.amount == 0 && IB.T(W_PRE, "rz_2", 0).request.amount == 0
  {
    Hexes();
    IssuableAt(W_PRE, "rz_1", 0, IB.HEXA); IssuableAt(W_PRE, "rz_2", 0, IB.HEXA); IssuableAt(W_PRE, "rp_1", 40, IB.HEXA);
    var m: Memory := map[];
    var st := Store(W_PRE, false);
    m, a := NewKey(m, st, W_PRE, IB.T(W_PRE, "rz_1", 0), SM.ZERO64, SM.ZERO64, IB.HEXA);
    m, b := NewKey(m, st, W_PRE, IB.T(W_PRE, "rz_2", 0), SM.ZERO64, SM.ZERO64, IB.HEXA);
    m, c := NewKey(m, st, W_PRE, IB.T(W_PRE, "rp_1", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // An identical retry returns the identical bytes (Store mode and NoStore mode).
  method WRetry() returns (a: Outcome, a2: Outcome, b: Outcome, b2: Outcome)
    ensures a.Issued? && a2.Replayed? && a2.bytes == a.bytes
    ensures b.Issued? && b2.Replayed? && b2.bytes == b.bytes
  {
    Hexes(); IssuableAt(W_PRE, "rq_r", 0, IB.HEXA);
    var t := IB.T(W_PRE, "rq_r", 0);
    var m: Memory := map[];
    m, a := NewKey(m, Store(W_PRE, false), W_PRE, t, SM.ZERO64, SM.ZERO64, IB.HEXA);
    m, a2 := UsedKey(m, Store(W_PRE, false), W_PRE, t, SM.ZERO64, SM.ZERO64, IB.HEXA);
    var n: Memory := map[];
    n, b := NewKey(n, NoStore, W_PRE, t, SM.ZERO64, SM.ZERO64, IB.HEXA);
    n, b2 := UsedKey(n, NoStore, W_PRE, t, SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // C-ATT-29 as SPECIFIED behaviour (protocol.md:64-65), Store mode: rq_1 is signed on W_PRE; the store moves to
  // W_NEXT; the same rq_1 on W_NEXT (authorized and well-formed there) is RefusedOtherCandidate; a NEW request id on
  // W_NEXT is Issued.
  method WStaleRetry() returns (a: Outcome, b: Outcome, c: Outcome)
    ensures a.Issued? && b.RefusedOtherCandidate? && c.Issued?
  {
    Hexes();
    IssuableAt(W_PRE, "rq_1", 40, IB.HEXA); IssuableAt(W_NEXT, "rq_1", 40, HEXB); IssuableAt(W_NEXT, "rq_1b", 40, HEXB);
    var b0 := IB.BodyFor(SM.ZERO64, SM.ZERO64, IB.HEXA, IB.T(W_PRE, "rq_1", 40));
    var b1 := IB.BodyFor(SM.ZERO64, SM.ZERO64, HEXB, IB.T(W_NEXT, "rq_1", 40));
    assert b0.preStateSha256 != b1.preStateSha256 by { assert IB.HEXA[0] != HEXB[0]; }
    if SM.SignedBytes(b0) == SM.SignedBytes(b1) { SM.SignedBytesInjective(b0, b1); }
    assert Expected(IB.T(W_PRE, "rq_1", 40), SM.ZERO64, SM.ZERO64, IB.HEXA) !=
           Expected(IB.T(W_NEXT, "rq_1", 40), SM.ZERO64, SM.ZERO64, HEXB) by { reveal Expected(); }
    var m: Memory := map[];
    m, a := NewKey(m, Store(W_PRE, false), W_PRE, IB.T(W_PRE, "rq_1", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
    m, b := UsedKey(m, Store(W_NEXT, false), W_NEXT, IB.T(W_NEXT, "rq_1", 40), SM.ZERO64, SM.ZERO64, HEXB);
    m, c := NewKey(m, Store(W_NEXT, false), W_NEXT, IB.T(W_NEXT, "rq_1b", 40), SM.ZERO64, SM.ZERO64, HEXB);
  }

  // D-2: rq_c for 61 (> remaining 60) is refused and records nothing; rq_c for 40 is then Issued (what is LOST
  // against the letter of 61-62: the request id stays usable after a rejection).
  method WRefusalThenSameId() returns (a: Outcome, b: Outcome, m: Memory)
    ensures a.RefusedByCore? && b.Issued? && m.Keys == {KeyFor(Store(W_PRE, false), W_PRE, IB.T(W_PRE, "rq_c", 40), IB.HEXA)}
  {
    Hexes(); IssuableAt(W_PRE, "rq_c", 40, IB.HEXA);
    assert !Issuable(W_PRE, IB.T(W_PRE, "rq_c", 61), SM.ZERO64, SM.ZERO64, IB.HEXA) by { reveal Issuable(); }
    m := map[];
    var st := Store(W_PRE, false);
    m, a := CoreRefused(m, st, W_PRE, IB.T(W_PRE, "rq_c", 61), SM.ZERO64, SM.ZERO64, IB.HEXA);
    assert m == map[];
    m, b := NewKey(m, st, W_PRE, IB.T(W_PRE, "rq_c", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // OldRuleFreeze: the EARLIER rule (OldAfter) against the red team's spray C-ATT-38. A caller without the key sends,
  // with the victim's request id, one unauthorized request (amount 61) on an invented state and one on the real state.
  // Under the old rule the guess on the real state is admitted and refused by the core, so it records Closed; the
  // victim's honest request is then RefusedClosed. (Under the rule of this file, WSpray: the victim is Issued.)
  method OldRuleFreeze() returns (s1: Outcome, s2: Outcome, v: Outcome)
    ensures s1.RefusedByCore? && s2.RefusedByCore? && v.RefusedClosed?
  {
    Hexes(); IssuableAt(W_PRE, "rq_v", 40, IB.HEXA);
    assert !Issuable(W_FAKE, IB.T(W_FAKE, "rq_v", 61), SM.ZERO64, SM.ZERO64, HEXB) by { reveal Issuable(); }
    assert !Issuable(W_PRE, IB.T(W_PRE, "rq_v", 61), SM.ZERO64, SM.ZERO64, IB.HEXA) by { reveal Issuable(); }
    var st := Store(W_PRE, false);
    var k := KeyFor(st, W_PRE, IB.T(W_PRE, "rq_v", 40), IB.HEXA);
    var m: Memory := map[];
    var m1;
    m1, s1 := CoreRefused(m, st, W_FAKE, IB.T(W_FAKE, "rq_v", 61), SM.ZERO64, SM.ZERO64, HEXB);
    m := OldAfter(Admitted(st, W_FAKE), m, KeyFor(st, W_FAKE, IB.T(W_FAKE, "rq_v", 61), HEXB), s1);
    m1, s2 := CoreRefused(m, st, W_PRE, IB.T(W_PRE, "rq_v", 61), SM.ZERO64, SM.ZERO64, IB.HEXA);
    m := OldAfter(Admitted(st, W_PRE), m, KeyFor(st, W_PRE, IB.T(W_PRE, "rq_v", 61), IB.HEXA), s2);
    assert m == map[k := Closed];
    m, v := UsedKey(m, st, W_PRE, IB.T(W_PRE, "rq_v", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // The same spray under the rule of this file (D-2), through SprayHarmless: the victim is Issued.
  method WSpray() returns (outs: seq<Outcome>, v: Outcome)
    ensures |outs| == 2 && outs[0].RefusedByCore? && outs[1].RefusedByCore? && v.Issued?
  {
    Hexes(); IssuableAt(W_PRE, "rq_v", 40, IB.HEXA);
    assert !Issuable(W_FAKE, IB.T(W_FAKE, "rq_v", 61), SM.ZERO64, SM.ZERO64, HEXB) by { reveal Issuable(); }
    assert !Issuable(W_PRE, IB.T(W_PRE, "rq_v", 61), SM.ZERO64, SM.ZERO64, IB.HEXA) by { reveal Issuable(); }
    var st := Store(W_PRE, false);
    var spray := [Call(st, W_FAKE, IB.T(W_FAKE, "rq_v", 61), SM.ZERO64, SM.ZERO64, HEXB),
                  Call(st, W_PRE, IB.T(W_PRE, "rq_v", 61), SM.ZERO64, SM.ZERO64, IB.HEXA)];
    var vc := Call(st, W_PRE, IB.T(W_PRE, "rq_v", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
    outs, v := SprayHarmless(map[], spray, vc);
  }

  // A client that lost its answer retries the identical request AFTER the store moved on (its token committed):
  // Replayed with the same bytes (the sink then answers "replayed"); a different candidate for that settled id on
  // the new state is RefusedCompleted. (minter.ts in mode "off" seeds the memory from the settled row: C-ATT-40.)
  method WRetryAfterMove() returns (a: Outcome, a2: Outcome, b: Outcome)
    ensures a.Issued? && a2.Replayed? && a2.bytes == a.bytes && b.RefusedCompleted?
  {
    Hexes(); IssuableAt(W_PRE, "rq_m", 10, IB.HEXA);
    var t := IB.T(W_PRE, "rq_m", 10);
    var m: Memory := map[];
    m, a := NewKey(m, Store(W_PRE, false), W_PRE, t, SM.ZERO64, SM.ZERO64, IB.HEXA);
    reveal Expected();
    m, a2 := Replay(m, Store(W_NEXT, true), W_PRE, t, SM.ZERO64, SM.ZERO64, IB.HEXA);
    IssuableAt(W_NEXT, "rq_m", 5, HEXB);
    var t2 := IB.T(W_NEXT, "rq_m", 5);
    var b0 := IB.BodyFor(SM.ZERO64, SM.ZERO64, IB.HEXA, t);
    var b1 := IB.BodyFor(SM.ZERO64, SM.ZERO64, HEXB, t2);
    assert b0.intent.amount != b1.intent.amount;
    if SM.SignedBytes(b0) == SM.SignedBytes(b1) { SM.SignedBytesInjective(b0, b1); }
    m, b := Issue(m, Store(W_NEXT, true), W_NEXT, t2, SM.ZERO64, SM.ZERO64, HEXB);
  }

  // Completion closes the attempt: a request id that the store has settled is refused, memory unchanged.
  method WCompleted() returns (o: Outcome, m2: Memory)
    ensures o.RefusedCompleted? && m2 == map[]
  {
    Hexes(); IssuableAt(W_PRE, "rq_s", 0, IB.HEXA);
    m2, o := NotAdmitted(map[], Store(W_PRE, true), W_PRE, IB.T(W_PRE, "rq_s", 0), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // LIMIT (red team C-ATT-08 class, owner question B-12(1)): a caller who knows the REAL state and the
  // victim's request id, and sends a zero-amount request first, takes the pair: the victim's request is then refused.
  method WSquatRealState() returns (s: Outcome, v: Outcome)
    ensures s.Issued? && v.RefusedOtherCandidate?
  {
    Hexes(); IssuableAt(W_PRE, "rq_v", 0, IB.HEXA); IssuableAt(W_PRE, "rq_v", 40, IB.HEXA);
    var b0 := IB.BodyFor(SM.ZERO64, SM.ZERO64, IB.HEXA, IB.T(W_PRE, "rq_v", 0));
    var b1 := IB.BodyFor(SM.ZERO64, SM.ZERO64, IB.HEXA, IB.T(W_PRE, "rq_v", 40));
    assert b0.intent.amount != b1.intent.amount;
    if SM.SignedBytes(b0) == SM.SignedBytes(b1) { SM.SignedBytesInjective(b0, b1); }
    assert Expected(IB.T(W_PRE, "rq_v", 0), SM.ZERO64, SM.ZERO64, IB.HEXA) !=
           Expected(IB.T(W_PRE, "rq_v", 40), SM.ZERO64, SM.ZERO64, IB.HEXA) by { reveal Expected(); }
    var m: Memory := map[];
    var st := Store(W_PRE, false);
    m, s := NewKey(m, st, W_PRE, IB.T(W_PRE, "rq_v", 0), SM.ZERO64, SM.ZERO64, IB.HEXA);
    m, v := UsedKey(m, st, W_PRE, IB.T(W_PRE, "rq_v", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // RunSeq is not vacuous : a two-call sequence where the second call signs.
  method WRunSeq() returns (outs: seq<Outcome>)
    ensures |outs| == 2 && outs[1].Issued?
  {
    Hexes(); IssuableAt(W_PRE, "rq_w", 40, IB.HEXA);
    var calls := [Call(Store(W_PRE, false), W_FAKE, IB.T(W_FAKE, "rq_w", 0), SM.ZERO64, SM.ZERO64, HEXB),
                  Call(Store(W_PRE, false), W_PRE, IB.T(W_PRE, "rq_w", 40), SM.ZERO64, SM.ZERO64, IB.HEXA)];
    var m: Memory; ghost var ms: seq<Memory>;
    m, outs, ms := RunSeq(map[], calls);
    assert !Admitted(calls[0].a, calls[0].pre);
    assert ms[1] == map[];
  }
}
