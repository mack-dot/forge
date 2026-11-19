// Night shift 2026-11-19, Orchestrator B, task h-minter2. A DRAFT on the branch only. NOT gate evidence.
// The issuer's memory rule, version 2, proved at the source level (Dafny 4.11.0). Replaces IssueOnce.Issue in
// minter.ts (IssueOnce.dfy stays as the record of rule 1).
//
// WHY (red team C-ATT-30): rule 1 trusted the CALLER's pre-state. A caller without the key could sign a zero-amount
// token for the victim's (charge id, request id) on an INVENTED pre-state; the token never commits, but the pair was
// then taken for ever. The governing context (owner decision B-10) is the approved policy plus the AUTHORITATIVE
// PERSISTED charge state. Rule 2 lets only a call on that state change the memory.
//
// RULE 2. The shell passes `a`, what it read from the sink's store for this request (read only):
//   a = Store(state, requestSettled): the store's current charge, and whether the request id is settled there;
//   a = NoStore: no store is configured (the issuer cannot know the authoritative state).
//   key = (charge id, request id)        in Store mode,
//   key = (charge id, request id, h)     in NoStore mode (h = the pre-state hash text that the body carries).
//   In this order:
//   the key holds Signed(exactly the bytes of this call) -> Replayed(bytes), memory unchanged (an identical retry,
//                                                     also after the store moved on: protocol.md:63-64);
//   Store mode, pre != state                      -> RefusedNotAuthoritative, memory unchanged;
//   Store mode, the request id is settled          -> RefusedCompleted, memory unchanged (closed by completion;
//                                                     durable: it is read from the store at each call);
//   the core (IssueBytes2.IssueTokenBytes) refuses -> RefusedByCore; a NEW key is recorded as Closed
//                                                     (protocol.md:61-62: rejection closes the attempt);
//   the key holds Closed                           -> RefusedClosed;
//   the key holds Signed(other bytes)              -> RefusedOtherCandidate (protocol.md:64-65: "Reusing the pair
//                                                     with different trusted context is rejected. A new attempt
//                                                     needs a new request ID.");
//   the key is new                                 -> Issued(bytes), memory gets key -> Signed(bytes).
//
// PROVED HERE (MACHINE-CHECKED only after a run of the lock script; see the evidence directory h-minter2):
//   Issue (step): the exact outcome and memory for each case; every signing outcome is authorized by RefundFinality,
//     has a well-formed body and returns exactly its canonical bytes; NEW bytes (Issued) only on the authoritative
//     state with an unsettled request id (Store mode); a Replayed outcome returns bytes already in the memory.
//   RunSeq (any finite call sequence): S1 one byte string per key; S2 every signing call is authorized, and every
//     Issued call in Store mode is on the authoritative state with an unsettled request id; S3 a key that the core
//     refused at first use never signs later; S4 a non-admitted call leaves the memory unchanged; L3 an admitted,
//     issuable call whose key is new at that point is Issued.
//   Live (liveness, per call): Store mode, authoritative pre-state, request id not settled, key new, authorized and
//     well-formed -> Issued. SquatsThenVictim: after ANY sequence of calls that are not on the authoritative state
//     (or that have another key), the victim's call is still Issued (C-ATT-30 cannot block it).
//   Witnesses (concrete runs, non-vacuity): WSquatStore, WSquatNoStore, WZeroZeroPositive, WRetry, WStaleRetry,
//     WRetryAfterMove, WClosed, WCompleted, WRunSeq, and the LIMIT WSquatRealState (a caller who sends the REAL state with the victim's id
//     first still takes the pair: red team C-ATT-08 class; no rule of the issuer alone can tell the callers apart).
// NOT proved: minter.ts (decode, SHA-256 glue G-H, the store read, sign, the token text), the store's contents
// (assumption STORE-READ: the file the issuer reads is the sink's store), Dafny's JavaScript back end, Node.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "../tree/impl/finality-core/IssueBytes2.dfy"

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

  // The memory after a call (one formula, used by the step and by the lemmas).
  ghost function After(m: Memory, k: Key, o: Outcome): Memory
  {
    if o.Issued? then m[k := Signed(o.bytes)]
    else if o.RefusedByCore? && k !in m then m[k := Closed]
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
  // Order: an identical retry is answered first (Replayed: the SAME bytes, memory unchanged; also after the store
  // moved on, so a client that lost the answer gets its token back: protocol.md:63-64 "An identical repeated request
  // returns its recorded decision"); then the authority checks; then the core; then the key.
  method Issue(m: Memory, a: Auth, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (m2: Memory, o: Outcome)
    ensures o.Signs() ==> F.Authorizes(pre, t) && SM.WfBody(IB.BodyFor(sh, ch, h, t))
    ensures o.Signs() ==> IB.ToInts(o.bytes) == Expected(t, sh, ch, h)
    ensures o.Issued? ==> Admitted(a, pre)
    ensures m2 == m && Extends(m, m2)
    ensures !o.Signs()
  {
    m2, o := m, RefusedByCore;  // MUTANT MU4: refuse everything
  }

  // =============================================================================================
  // RunSeq: properties over ANY finite call sequence (the auth value may change between calls: the store moves).
  datatype Call = Call(a: Auth, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
  function KeyOfCall(c: Call): Key { KeyFor(c.a, c.pre, c.t, c.h) }
  opaque ghost predicate SignsOk(c: Call, o: Outcome)
  {
    (o.Signs() ==> F.Authorizes(c.pre, c.t)) &&
    (o.Issued? && c.a.Store? ==> c.pre == c.a.state && !c.a.requestSettled)
  }
  // First-use core refusal: the call that recorded Closed.
  ghost predicate ClosedAt(calls: seq<Call>, outs: seq<Outcome>, ms: seq<Memory>, i: int)
    requires 0 <= i < |outs| <= |calls| && |ms| == |outs|
  {
    outs[i].RefusedByCore? && KeyOfCall(calls[i]) !in ms[i]
  }

  // What one Issue call guarantees, in the form the sequence proof needs.
  opaque ghost predicate StepFacts(m: Memory, m2: Memory, c: Call, o: Outcome)
  {
    Extends(m, m2) &&
    (o.Signs() ==> KeyOfCall(c) in m2 && m2[KeyOfCall(c)] == Signed(o.bytes)) &&
    (o.RefusedByCore? && KeyOfCall(c) !in m ==> KeyOfCall(c) in m2 && m2[KeyOfCall(c)] == Closed) &&
    (KeyOfCall(c) in m && m[KeyOfCall(c)].Closed? ==> !o.Signs()) &&
    (!Admitted(c.a, c.pre) ==> m2 == m) &&
    (Admitted(c.a, c.pre) && Issuable(c.pre, c.t, c.sh, c.ch, c.h) && KeyOfCall(c) !in m ==> o.Issued?) &&
    SignsOk(c, o)
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
    (forall i | 0 <= i < |outs| :: ClosedAt(calls, outs, ms, i) ==>
       KeyOfCall(calls[i]) in m && m[KeyOfCall(calls[i])] == Closed) &&
    (forall i, j | 0 <= i < j < |outs| ::
       ClosedAt(calls, outs, ms, i) && KeyOfCall(calls[j]) == KeyOfCall(calls[i]) ==> !outs[j].Signs()) &&
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
    forall i | 0 <= i < n + 1 && ClosedAt(calls, outs2, ms2, i)
      ensures KeyOfCall(calls[i]) in m2 && m2[KeyOfCall(calls[i])] == Closed
    {
      if i < n { assert outs2[i] == outs[i] && ms2[i] == ms[i]; assert ClosedAt(calls, outs, ms, i); }
    }
    forall i, j | 0 <= i < j < n + 1 && ClosedAt(calls, outs2, ms2, i) && KeyOfCall(calls[j]) == KeyOfCall(calls[i])
      ensures !outs2[j].Signs()
    {
      assert outs2[i] == outs[i] && ms2[i] == ms[i];
      assert ClosedAt(calls, outs, ms, i);
      if j < n { assert outs2[j] == outs[j]; }
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
    // S3: a key refused by the core at its first use never signs later.
    ensures forall i, j | 0 <= i < j < |calls| ::
              ClosedAt(calls, outs, ms, i) && KeyOfCall(calls[j]) == KeyOfCall(calls[i]) ==> !outs[j].Signs()
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
      var m2, o := Issue(m, c.a, c.pre, c.t, c.sh, c.ch, c.h);
      assert StepFacts(m, m2, c, o) by { reveal StepFacts(); reveal SignsOk(); }
      StepPreserves(m0, m, m2, calls, outs, ms, o);
      m, outs, ms := m2, outs + [o], ms + [m];
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

  // SquatsThenVictim: ANY sequence of harmless calls (C-ATT-30 squats on invented pre-states included), then the
  // victim's authorized, well-formed call whose key was new at the start: the victim is Issued.
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
    requires !Admitted(a, pre) && KeyFor(a, pre, t, h) !in m
    ensures m2 == m && !o.Signs()
    ensures a.Store? && a.state != pre ==> o.RefusedNotAuthoritative?
    ensures a.Store? && a.state == pre ==> o.RefusedCompleted?
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
    requires Admitted(a, pre) && !Issuable(pre, t, sh, ch, h) && KeyFor(a, pre, t, h) !in m
    ensures o.RefusedByCore? && m2 == m[KeyFor(a, pre, t, h) := Closed]
  {
    m2, o := Issue(m, a, pre, t, sh, ch, h);
  }

  // C-ATT-30, Store mode: a zero-amount squat on an INVENTED pre-state is refused and records nothing; the victim's
  // request on the real state is then Issued.
  method WSquatStore() returns (s: Outcome, v: Outcome)
    ensures s.RefusedNotAuthoritative? && v.Issued?
  {
    Hexes(); IssuableAt(W_PRE, "rq_v", 40, IB.HEXA);
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

  // Zero amounts stay legitimate: two zero-amount requests and a positive one on one state: all Issued.
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

  // Rejection closes the attempt (protocol.md:61-62): rq_c for 61 (> remaining 60) is refused by the core; then rq_c
  // for 40 (authorized) is RefusedClosed; a new request id for 40 is Issued (no freeze of the charge).
  method WClosed() returns (a: Outcome, b: Outcome, c: Outcome)
    ensures a.RefusedByCore? && b.RefusedClosed? && c.Issued?
  {
    Hexes(); IssuableAt(W_PRE, "rq_c", 40, IB.HEXA); IssuableAt(W_PRE, "rq_d", 40, IB.HEXA);
    assert !Issuable(W_PRE, IB.T(W_PRE, "rq_c", 61), SM.ZERO64, SM.ZERO64, IB.HEXA) by { reveal Issuable(); }
    var m: Memory := map[];
    var st := Store(W_PRE, false);
    m, a := CoreRefused(m, st, W_PRE, IB.T(W_PRE, "rq_c", 61), SM.ZERO64, SM.ZERO64, IB.HEXA);
    m, b := UsedKey(m, st, W_PRE, IB.T(W_PRE, "rq_c", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
    m, c := NewKey(m, st, W_PRE, IB.T(W_PRE, "rq_d", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // A client that lost its answer retries the identical request AFTER the store moved on (its token committed):
  // Replayed with the same bytes (the sink then answers "replayed"); a different candidate for that settled id on
  // the new state is RefusedCompleted.
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
    m2, o := NotAdmitted(map[], Store(W_PRE, true), W_PRE, IB.T(W_PRE, "rq_s", 0), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // LIMIT (red team C-ATT-08 class, owner question B-12(1)): a caller who knows the REAL state and the victim's
  // request id, and sends a zero-amount request first, takes the pair: the victim's request is then refused.
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

  // RunSeq is not vacuous: a two-call sequence where the second call signs.
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
