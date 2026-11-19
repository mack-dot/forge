// Night shift 2026-11-19, Orchestrator B, task h-minter. A DRAFT on the branch only. NOT gate evidence.
// The issuer's memory rule, proved at the source level (Dafny 4.11.0).
//
// RULE (replaces the old rule "one signed transition per PRE-STATE HASH", minter.ts single-use, U428):
//   key = (charge id of the pre-state, request id of the transition).
//   - the proved IssueBytes2.IssueTokenBytes refuses           -> RefusedByCore, memory unchanged;
//   - the key is new                                           -> Issued(bytes), memory gets key -> bytes;
//   - the key holds exactly these bytes (an identical retry)   -> Replayed(the stored bytes), memory unchanged;
//   - the key holds other bytes (same request, other candidate) -> RefusedOtherCandidate, memory unchanged.
// A DIFFERENT request id on the SAME pre-state is NOT blocked. Zero-amount tokens and tokens that are never
// committed therefore never freeze a charge. The sink decides which token commits.
//
// What this file proves (MACHINE-CHECKED only after a run of the lock script; see the evidence directory):
//   P1 (one byte string per key): RunSeq - over ANY finite call sequence, two signing outcomes with the same key
//      return the same bytes; and a key that is in the start memory only ever returns its stored bytes.
//   P2 (retry): Retry - an identical second call after a signing call is Replayed with byte-identical output.
//   P3 (other candidate): OtherCandidate - same key, different token body: refused, memory unchanged.
//   P4 (no freeze): NoFreeze - a new key with an authorized, well-formed candidate is always Issued.
//      Witnesses: ZeroZeroPositive (two zero-amount requests, then a positive one, on ONE pre-state: all issue);
//      Abandoned (a token that is never committed, then another request on the same pre-state: both issue).
//   P5 (safety, inherited): every signing outcome is authorized by RefundFinality and has a well-formed body.
//   OLD RULE CONTROL: OldIssue models the old minter rule; OldFreeze proves the red-team finding C-ATT-03
//      (a zero-amount token, then an authorized well-formed request with a new id on that pre-state: refused).
// NOT proved: minter.ts (decode, SHA-256 glue G-H, sign, the token text), Dafny's JavaScript back end, Node,
// persistence of the memory (it is process memory: it is lost at restart), the sink.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "IssueBytes2.dfy"

module IssueOnce {
  import F = RefundFinality
  import R = Refund
  import SM = SerModel
  import IB = IssueBytes2

  type Bytes = seq<IB.uint8>
  datatype Key = Key(chargeId: string, requestId: string)
  type Memory = map<Key, Bytes>

  datatype Outcome = Issued(bytes: Bytes) | Replayed(bytes: Bytes) | RefusedByCore | RefusedOtherCandidate
  {
    predicate Signs() { Issued? || Replayed? }
  }

  function KeyOf(pre: F.Charge, t: F.Transition): Key { Key(pre.chargeId, t.request.requestId) }

  // The bytes that IssueTokenBytes returns for these arguments when it issues (as integers).
  opaque ghost function Expected(t: F.Transition, sh: string, ch: string, h: string): seq<int>
  {
    SM.Utf8(SM.SerBody(IB.BodyFor(sh, ch, h, t)))
  }
  // Exactly the condition under which IssueTokenBytes issues.
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

  // Memory only grows; a stored key never changes its bytes.
  ghost predicate Extends(m: Memory, m2: Memory)
  {
    forall k | k in m :: k in m2 && m2[k] == m[k]
  }

  // =============================================================================================
  // THE ISSUER STEP. The shell (minter.ts) signs exactly o.bytes when o.Signs().
  method Issue(m: Memory, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (m2: Memory, o: Outcome)
    // P5 safety (inherited from IssueTokenBytes) and the exact signing condition.
    ensures o.Signs() <==> Issuable(pre, t, sh, ch, h) &&
                           (KeyOf(pre, t) !in m || IB.ToInts(m[KeyOf(pre, t)]) == Expected(t, sh, ch, h))
    ensures o.Signs() ==> F.Authorizes(pre, t) && SM.WfBody(IB.BodyFor(sh, ch, h, t))
    ensures o.Signs() ==> IB.ToInts(o.bytes) == SM.SignedBytes(IB.BodyFor(sh, ch, h, t))
    // The signed bytes are exactly the canonical body bytes for this checked transition.
    ensures o.Signs() ==> IB.ToInts(o.bytes) == Expected(t, sh, ch, h)
    // The four outcomes.
    ensures o.RefusedByCore? <==> !Issuable(pre, t, sh, ch, h)
    ensures o.Issued? <==> Issuable(pre, t, sh, ch, h) && KeyOf(pre, t) !in m
    ensures o.Replayed? ==> KeyOf(pre, t) in m && o.bytes == m[KeyOf(pre, t)]
    ensures o.RefusedOtherCandidate? <==> Issuable(pre, t, sh, ch, h) && KeyOf(pre, t) in m &&
                                          IB.ToInts(m[KeyOf(pre, t)]) != Expected(t, sh, ch, h)
    // Memory: only a new key is added; nothing else changes.
    ensures m2 == (if o.Issued? then m[KeyOf(pre, t) := o.bytes] else m)
    ensures Extends(m, m2)
    ensures o.Signs() ==> KeyOf(pre, t) in m2 && m2[KeyOf(pre, t)] == o.bytes
  {
    reveal Expected(); reveal Issuable();
    var r := IB.IssueTokenBytes(pre, t, sh, ch, h);
    var k := KeyOf(pre, t);
    if r.None? {
      m2, o := m, RefusedByCore;
      return;
    }
    if k in m {
      if m[k] == r.value {
        m2, o := m, Replayed(m[k]);
      } else {
        if IB.ToInts(m[k]) == IB.ToInts(r.value) { ToIntsInjective(m[k], r.value); }
        m2, o := m, RefusedOtherCandidate;
      }
      return;
    }
    m2, o := m[k := r.value], Issued(r.value);
  }

  // =============================================================================================
  // P1: over ANY call sequence, one byte string per key.
  datatype Call = Call(pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
  function KeyOfCall(c: Call): Key { KeyOf(c.pre, c.t) }

  opaque ghost predicate SignsAuthorized(c: Call, o: Outcome) { o.Signs() ==> F.Authorizes(c.pre, c.t) }
  ghost predicate Rec(m: Memory, calls: seq<Call>, outs: seq<Outcome>)
    requires |outs| <= |calls|
  {
    forall i | 0 <= i < |outs| :: outs[i].Signs() ==> KeyOfCall(calls[i]) in m && m[KeyOfCall(calls[i])] == outs[i].bytes
  }

  method RunSeq(m0: Memory, calls: seq<Call>) returns (m: Memory, outs: seq<Outcome>)
    ensures |outs| == |calls|
    ensures Extends(m0, m)
    ensures forall i, j | 0 <= i < |calls| && 0 <= j < |calls| ::
              KeyOfCall(calls[i]) == KeyOfCall(calls[j]) && outs[i].Signs() && outs[j].Signs() ==>
              outs[i].bytes == outs[j].bytes
    ensures forall i | 0 <= i < |calls| ::
              outs[i].Signs() && KeyOfCall(calls[i]) in m0 ==> outs[i].bytes == m0[KeyOfCall(calls[i])]
    ensures forall i | 0 <= i < |calls| :: SignsAuthorized(calls[i], outs[i])
  {
    m, outs := m0, [];
    var n := 0;
    while n < |calls|
      invariant 0 <= n <= |calls| && |outs| == n
      invariant Extends(m0, m)
      invariant Rec(m, calls, outs)
      invariant forall i | 0 <= i < n :: SignsAuthorized(calls[i], outs[i])
    {
      var c := calls[n];
      var m2, o := Issue(m, c.pre, c.t, c.sh, c.ch, c.h);
      assert SignsAuthorized(c, o) by { reveal SignsAuthorized(); }
      RecStep(m, m2, calls, outs, o);
      m, outs := m2, outs + [o];
      n := n + 1;
    }
  }

  lemma RecStep(m: Memory, m2: Memory, calls: seq<Call>, outs: seq<Outcome>, o: Outcome)
    requires |outs| < |calls| && Rec(m, calls, outs) && Extends(m, m2)
    requires o.Signs() ==> KeyOfCall(calls[|outs|]) in m2 && m2[KeyOfCall(calls[|outs|])] == o.bytes
    ensures Rec(m2, calls, outs + [o])
  {
    var outs2 := outs + [o];
    forall i | 0 <= i < |outs2| && outs2[i].Signs()
      ensures KeyOfCall(calls[i]) in m2 && m2[KeyOfCall(calls[i])] == outs2[i].bytes
    {
      if i < |outs| { assert outs2[i] == outs[i]; }
    }
  }

  // P2: an identical retry returns the identical bytes and changes nothing.
  method Retry(m: Memory, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (o1: Outcome, o2: Outcome, m1: Memory, m2: Memory)
    ensures o1.Signs() ==> o2.Replayed? && o2.bytes == o1.bytes && m2 == m1
  {
    m1, o1 := Issue(m, pre, t, sh, ch, h);
    m2, o2 := Issue(m1, pre, t, sh, ch, h);
  }

  // P3: the same key with a different token body is refused and changes nothing.
  method OtherCandidate(m: Memory, pre1: F.Charge, t1: F.Transition, pre2: F.Charge, t2: F.Transition,
                        sh: string, ch: string, h1: string, h2: string)
      returns (o1: Outcome, o2: Outcome, m1: Memory, m2: Memory)
    requires KeyOf(pre1, t1) == KeyOf(pre2, t2)
    requires IB.BodyFor(sh, ch, h1, t1) != IB.BodyFor(sh, ch, h2, t2)
    ensures KeyOf(pre1, t1) !in m && Issuable(pre1, t1, sh, ch, h1) ==> o1.Issued?
    ensures o1.Signs() ==> !o2.Signs() && m2 == m1
    ensures o1.Signs() && Issuable(pre2, t2, sh, ch, h2) ==> o2.RefusedOtherCandidate?
  {
    m1, o1 := Issue(m, pre1, t1, sh, ch, h1);
    m2, o2 := Issue(m1, pre2, t2, sh, ch, h2);
    if o1.Signs() && o2.Signs() {
      assert Expected(t1, sh, ch, h1) == Expected(t2, sh, ch, h2);
      reveal Expected();
      SM.SignedBytesInjective(IB.BodyFor(sh, ch, h1, t1), IB.BodyFor(sh, ch, h2, t2));
      assert false;
    }
  }

  // P4: NO FREEZE. A new key with an issuable candidate is always issued, whatever else is in memory
  // (zero-amount tokens, tokens that were never committed, tokens for the same pre-state).
  method NoFreeze(m: Memory, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (m2: Memory, o: Outcome)
    requires KeyOf(pre, t) !in m && Issuable(pre, t, sh, ch, h)
    ensures o.Issued? && IB.ToInts(o.bytes) == Expected(t, sh, ch, h)
    ensures m2 == m[KeyOf(pre, t) := o.bytes]
  {
    m2, o := Issue(m, pre, t, sh, ch, h);
  }

  // =============================================================================================
  // CONTROLS (non-vacuity). One pre-state W_PRE and ONE pre-state hash text for every call.
  const W_PRE: F.Charge := IB.W_PRE
  lemma IssuableT(rq: string, amount: int)
    requires rq != ""
    requires 2 * |rq| <= SM.MAX_TEXT && forall i | 0 <= i < |rq| :: rq[i] as int != 0
    requires 0 <= amount <= W_PRE.remaining
    ensures Issuable(W_PRE, IB.T(W_PRE, rq, amount), SM.ZERO64, SM.ZERO64, IB.HEXA)
  {
    reveal Issuable();
    WfT(rq, amount);
    AuthT(rq, amount);
  }
  lemma WfT(rq: string, amount: int)
    requires 2 * |rq| <= SM.MAX_TEXT && forall i | 0 <= i < |rq| :: rq[i] as int != 0
    requires 0 <= amount <= W_PRE.remaining
    ensures SM.WfBody(IB.BodyFor(SM.ZERO64, SM.ZERO64, IB.HEXA, IB.T(W_PRE, rq, amount)))
  {
    SM.TextSmall(rq); IB.Tx1(); IB.Tx3(); IB.HexWitness();
    IB.WfOfT(W_PRE, rq, amount, SM.ZERO64, SM.ZERO64, IB.HEXA);
  }
  lemma AuthT(rq: string, amount: int)
    requires rq != ""
    requires 0 <= amount <= W_PRE.remaining
    ensures F.Authorizes(W_PRE, IB.T(W_PRE, rq, amount))
  {
    assert IB.T(W_PRE, rq, amount).post == W_PRE.(remaining := W_PRE.remaining - amount);
  }

  // Two zero-amount requests and then a positive one, all on the same pre-state: all three are Issued.
  method ZeroZeroPositive() returns (a: Outcome, b: Outcome, c: Outcome)
    ensures a.Issued? && b.Issued? && c.Issued?
    ensures IB.T(W_PRE, "rz_1", 0).request.amount == 0 && IB.T(W_PRE, "rz_2", 0).request.amount == 0
    ensures IB.T(W_PRE, "rp_1", 40).request.amount == 40
  {
    IssuableT("rz_1", 0); IssuableT("rz_2", 0); IssuableT("rp_1", 40);
    var m: Memory := map[];
    m, a := NoFreeze(m, W_PRE, IB.T(W_PRE, "rz_1", 0), SM.ZERO64, SM.ZERO64, IB.HEXA);
    m, b := NoFreeze(m, W_PRE, IB.T(W_PRE, "rz_2", 0), SM.ZERO64, SM.ZERO64, IB.HEXA);
    m, c := NoFreeze(m, W_PRE, IB.T(W_PRE, "rp_1", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // A token that is never committed (abandoned), then another request on the same pre-state: Issued.
  // Then the abandoned request again: Replayed with the same bytes (the client's retry works).
  method Abandoned() returns (a: Outcome, b: Outcome, a2: Outcome)
    ensures a.Issued? && b.Issued? && a2.Replayed? && a2.bytes == a.bytes
  {
    IssuableT("ra_1", 40); IssuableT("rb_1", 50);
    var m: Memory := map[];
    var m1: Memory;
    m1, a := NoFreeze(m, W_PRE, IB.T(W_PRE, "ra_1", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
    var m2: Memory;
    m2, b := NoFreeze(m1, W_PRE, IB.T(W_PRE, "rb_1", 50), SM.ZERO64, SM.ZERO64, IB.HEXA);
    var m3: Memory;
    m3, a2 := Issue(m2, W_PRE, IB.T(W_PRE, "ra_1", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // The same request id with another amount after an issue: refused (P3 has a concrete instance).
  method SameRequestOtherAmount() returns (a: Outcome, b: Outcome)
    ensures a.Issued? && b.RefusedOtherCandidate?
  {
    IssuableT("rq_9", 40); IssuableT("rq_9", 41);
    var m: Memory := map[];
    assert IB.BodyFor(SM.ZERO64, SM.ZERO64, IB.HEXA, IB.T(W_PRE, "rq_9", 40)).intent.amount == 40;
    assert IB.BodyFor(SM.ZERO64, SM.ZERO64, IB.HEXA, IB.T(W_PRE, "rq_9", 41)).intent.amount == 41;
    var m1: Memory, m2: Memory;
    a, b, m1, m2 := OtherCandidate(m, W_PRE, IB.T(W_PRE, "rq_9", 40), W_PRE, IB.T(W_PRE, "rq_9", 41),
                                   SM.ZERO64, SM.ZERO64, IB.HEXA, IB.HEXA);
  }

  // An unauthorized candidate is refused by the core even with a new key (a reject-nothing rule fails here).
  method UnauthorizedRefused() returns (o: Outcome)
    ensures o.RefusedByCore?
  {
    var m: Memory := map[];
    var m2: Memory;
    m2, o := Issue(m, W_PRE, IB.T(W_PRE, "rq_x", 61), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // =============================================================================================
  // OLD RULE (minter.ts single-use, key = pre-state hash text) as a model, and its freeze.
  type OldMemory = map<string, Bytes>
  method OldIssue(m: OldMemory, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (m2: OldMemory, r: SM.Option<Bytes>)
    ensures r.Some? <==> Issuable(pre, t, sh, ch, h) && (h !in m || IB.ToInts(m[h]) == Expected(t, sh, ch, h))
    ensures r.Some? ==> IB.ToInts(r.value) == Expected(t, sh, ch, h) && m2 == m[h := r.value]
    ensures r.None? ==> m2 == m
  {
    reveal Expected(); reveal Issuable();
    var b := IB.IssueTokenBytes(pre, t, sh, ch, h);
    if b.None? { m2, r := m, SM.None; return; }
    if h in m && m[h] != b.value {
      if IB.ToInts(m[h]) == IB.ToInts(b.value) { ToIntsInjective(m[h], b.value); }
      m2, r := m, SM.None;
      return;
    }
    m2, r := m[h := b.value], b;
  }

  // C-ATT-03 as a theorem: under the OLD rule a zero-amount token for a pre-state refuses every later
  // authorized, well-formed request with a different body on that pre-state hash (e.g. a new request id).
  method OldFreeze() returns (r0: SM.Option<Bytes>, r1: SM.Option<Bytes>)
    ensures IB.T(W_PRE, "rz_1", 0).request.amount == 0 && r0.Some?
    ensures Issuable(W_PRE, IB.T(W_PRE, "rp_1", 40), SM.ZERO64, SM.ZERO64, IB.HEXA)  // legitimate request ...
    ensures r1.None?                                                                   // ... refused: the freeze
  {
    IssuableT("rz_1", 0); IssuableT("rp_1", 40);
    var m: OldMemory := map[];
    m, r0 := OldIssue(m, W_PRE, IB.T(W_PRE, "rz_1", 0), SM.ZERO64, SM.ZERO64, IB.HEXA);
    var b0 := IB.BodyFor(SM.ZERO64, SM.ZERO64, IB.HEXA, IB.T(W_PRE, "rz_1", 0));
    var b1 := IB.BodyFor(SM.ZERO64, SM.ZERO64, IB.HEXA, IB.T(W_PRE, "rp_1", 40));
    assert b0.requestId != b1.requestId;
    if SM.SignedBytes(b0) == SM.SignedBytes(b1) { SM.SignedBytesInjective(b0, b1); }
    assert Expected(IB.T(W_PRE, "rz_1", 0), SM.ZERO64, SM.ZERO64, IB.HEXA) != Expected(IB.T(W_PRE, "rp_1", 40), SM.ZERO64, SM.ZERO64, IB.HEXA) by {
      reveal Expected();
    }
    m, r1 := OldIssue(m, W_PRE, IB.T(W_PRE, "rp_1", 40), SM.ZERO64, SM.ZERO64, IB.HEXA);
  }

  // The general old-rule freeze: once h holds bytes, any issuable candidate with other bytes on h is refused.
  method OldFreezeGeneral(m: OldMemory, pre: F.Charge, t: F.Transition, sh: string, ch: string, h: string)
      returns (m2: OldMemory, r: SM.Option<Bytes>)
    requires h in m && IB.ToInts(m[h]) != Expected(t, sh, ch, h)
    ensures r.None? && m2 == m
  {
    m2, r := OldIssue(m, pre, t, sh, ch, h);
  }
}
