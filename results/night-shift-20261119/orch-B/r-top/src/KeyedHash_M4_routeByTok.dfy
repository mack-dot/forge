// Night shift 2026-11-19, Orchestrator B, task b-top (T3). A DRAFT in an evidence folder. NOT gate evidence.
// M1-B stays OPEN. end_to_end=false. A Dafny-MODEL statement only. NOT a proof about sink.ts, a dispatcher,
// SQLite, a file system, Ed25519, SHA-256 or compiled code.
//
// T3: several charges with CHECKED creation over the HASH core (HashCore.Step, b-ser2 copy).
// A store is a map from key to HashCore.Core. Actions: KMint(pre, msg, tag), KCreate(key, init) (refused unless
// key == init.chargeId, key not present, 0 <= init.remaining <= init.original), KDel(key, tok, sigOk) (HashCore.Step
// on the routed store; a delivery to an absent key changes nothing).
// Route: a DIRECT re-proof over the keyed trace (not the projection route). The per-commit argument is the one of
// SliceSafetyBytesV3.CommitApproved; the hypotheses are stated ONCE over the global keyed trace.
//  (a) KeyedL0Hash, NO hypothesis: WellKeyed invariant; a delivery changes only its routed store (KStepFrame); every
//      effect in store k has charge id k; no two effects in all outboxes share (charge id, request id).
//  (b) KeyedTopHash: under InitOk-at-creation (enforced by the create check), A2pK (or A2qK), H1BK, B5K, A4K: per key
//      k, every effect in k's outbox is Approved from k's STORED charge at its commit, its bytes were minted before,
//      0 <= remaining <= original == original at creation, and sum(outbox) == remaining at creation - remaining.
// OUTSIDE THE MODEL (assumptions the r-restart review found; NOT discharged here):
//   O1 no delete and no re-create of a key (the model has no delete action; a re-create of a present key is refused);
//   O2 the initial charge at creation is authentic (ANY caller may create any key == chargeId with any sane init);
//   O3 no rollback of a store (the store map only moves by KStep; a restore of old content is not an action).
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "IssuerLink.dfy"

module KeyedHash {
  import opened HashCore
  import opened SliceSafetyBytesV3
  import IL = IssuerLink

  type Store = map<string, Core>
  datatype KAct = KMint(pre: F.Charge, msg: Bytes, tag: Tag) | KCreate(key: string, init: F.Charge)
                | KDel(key: string, tok: HashToken, sigOk: bool)

  predicate CreateOk(st: Store, key: string, init: F.Charge)
  {
    key == init.chargeId && key !in st && 0 <= init.remaining <= init.original
  }

  function KStep(H: HashFn, st: Store, a: KAct): Store
  {
    match a
    case KMint(_, _, _) => st
    case KCreate(key, init) => if CreateOk(st, key, init) then st[key := Core(init, {}, [])] else st
    case KDel(key, tok, s) => if tok.intent.chargeId in st then st[tok.intent.chargeId := Step(H, st[tok.intent.chargeId], tok, s).core] else st
  }

  function KExec(H: HashFn, acts: seq<KAct>): Store
    decreases |acts|
  {
    if |acts| == 0 then map[] else KStep(H, KExec(H, acts[..|acts| - 1]), acts[|acts| - 1])
  }

  lemma KExecStep(H: HashFn, acts: seq<KAct>, n: int)
    requires 0 <= n < |acts|
    ensures KExec(H, acts[..n + 1]) == KStep(H, KExec(H, acts[..n]), acts[n])
  {
    assert acts[..n + 1][..n] == acts[..n];
    assert acts[..n + 1][n] == acts[n];
  }

  // ---- (a) NO hypothesis ----
  ghost predicate WellKeyed(st: Store)
  {
    forall k | k in st :: st[k].charge.chargeId == k && GoodV3(st[k])
  }

  // A delivery (and every other action) changes at most its routed store; it never removes a key.
  lemma KStepFrame(H: HashFn, st: Store, a: KAct)
    ensures st.Keys <= KStep(H, st, a).Keys
    ensures a.KDel? ==> KStep(H, st, a).Keys == st.Keys
    ensures a.KDel? ==> forall k | k in st && k != a.key :: KStep(H, st, a)[k] == st[k]
    ensures a.KMint? ==> KStep(H, st, a) == st
    ensures a.KCreate? ==> forall k | k in st :: KStep(H, st, a)[k] == st[k]
  {}

  lemma KStepKeepsWellKeyed(H: HashFn, st: Store, a: KAct)
    requires WellKeyed(st)
    ensures WellKeyed(KStep(H, st, a))
  {
    match a
    case KMint(_, _, _) =>
    case KCreate(key, init) =>
    case KDel(key, tok, s) =>
      if key in st {
        StepKeepsGoodV3(H, st[key], tok, s);
      }
  }

  lemma KExecWellKeyed(H: HashFn, acts: seq<KAct>)
    ensures WellKeyed(KExec(H, acts))
    decreases |acts|
  {
    if |acts| > 0 {
      KExecWellKeyed(H, acts[..|acts| - 1]);
      KStepKeepsWellKeyed(H, KExec(H, acts[..|acts| - 1]), acts[|acts| - 1]);
    }
  }

  lemma GlobalDistinct(st: Store)
    requires WellKeyed(st)
    ensures forall k, i | k in st && 0 <= i < |st[k].outbox| :: st[k].outbox[i].chargeId == k
    ensures forall k1, k2, i, j | k1 in st && k2 in st &&
        0 <= i < |st[k1].outbox| && 0 <= j < |st[k2].outbox| && (k1 != k2 || i != j) ::
      st[k1].outbox[i].chargeId != st[k2].outbox[j].chargeId || st[k1].outbox[i].requestId != st[k2].outbox[j].requestId
  {
    forall k1, k2, i, j | k1 in st && k2 in st &&
        0 <= i < |st[k1].outbox| && 0 <= j < |st[k2].outbox| && (k1 != k2 || i != j)
      ensures st[k1].outbox[i].chargeId != st[k2].outbox[j].chargeId || st[k1].outbox[i].requestId != st[k2].outbox[j].requestId
    {
      if k1 == k2 {
        if i < j { assert st[k1].outbox[i].requestId != st[k1].outbox[j].requestId; }
        else { assert st[k1].outbox[j].requestId != st[k1].outbox[i].requestId; }
      }
    }
  }

  // KEYED L0 (NO hypothesis): every run of arbitrary mints, creates and deliveries with arbitrary keys, tokens,
  // sigOk and hash function, from the empty map.
  lemma KeyedL0Hash(H: HashFn, acts: seq<KAct>)
    ensures WellKeyed(KExec(H, acts))
    ensures forall k, i | k in KExec(H, acts) && 0 <= i < |KExec(H, acts)[k].outbox| :: KExec(H, acts)[k].outbox[i].chargeId == k
    ensures forall k1, k2, i, j | k1 in KExec(H, acts) && k2 in KExec(H, acts) &&
        0 <= i < |KExec(H, acts)[k1].outbox| && 0 <= j < |KExec(H, acts)[k2].outbox| && (k1 != k2 || i != j) ::
      KExec(H, acts)[k1].outbox[i].chargeId != KExec(H, acts)[k2].outbox[j].chargeId ||
      KExec(H, acts)[k1].outbox[i].requestId != KExec(H, acts)[k2].outbox[j].requestId
  {
    KExecWellKeyed(H, acts);
    GlobalDistinct(KExec(H, acts));
  }

  // ---- the commit log and the creation state ----
  ghost predicate CommitsAt(H: HashFn, acts: seq<KAct>, g: int)
  {
    0 <= g < |acts| && acts[g].KDel? && acts[g].key in KExec(H, acts[..g]) &&
    Step(H, KExec(H, acts[..g])[acts[g].key], acts[g].tok, acts[g].sigOk).out.Committed?
  }
  // The action indexes (< n) of the commits routed to k.
  ghost function Log(H: HashFn, acts: seq<KAct>, k: string, n: int): seq<int>
    requires 0 <= n <= |acts|
    decreases n
  {
    if n == 0 then []
    else Log(H, acts, k, n - 1) + (if acts[n - 1].KDel? && acts[n - 1].key == k && CommitsAt(H, acts, n - 1) then [n - 1] else [])
  }
  // The initial charge with which k was created in acts[..n] (a dummy before creation).
  ghost function InitOfK(H: HashFn, acts: seq<KAct>, k: string, n: int): F.Charge
    requires 0 <= n <= |acts|
    decreases n
  {
    if n == 0 then F.Charge(k, 0, 0, false)
    else if acts[n - 1].KCreate? && acts[n - 1].key == k && CreateOk(KExec(H, acts[..n - 1]), k, acts[n - 1].init)
    then acts[n - 1].init
    else InitOfK(H, acts, k, n - 1)
  }

  ghost predicate EntryK0(H: HashFn, acts: seq<KAct>, k: string, g: int, e: R.RefundIntent)
  {
    CommitsAt(H, acts, g) && acts[g].key == k && acts[g].sigOk && e == IntentOfSM(acts[g].tok.intent)
  }

  ghost predicate KeyInv0(H: HashFn, acts: seq<KAct>, n: int, k: string)
    requires 0 <= n <= |acts|
  {
    var st := KExec(H, acts[..n]);
    var L := Log(H, acts, k, n);
    (k !in st ==> L == []) &&
    (k in st ==> (|L| == |st[k].outbox| && InitOfK(H, acts, k, n).chargeId == k && InitOk(InitOfK(H, acts, k, n)) &&
       forall i | 0 <= i < |L| :: L[i] < n && EntryK0(H, acts, k, L[i], st[k].outbox[i])))
  }

  lemma KeyInv0Next(H: HashFn, acts: seq<KAct>, n: int, k: string)
    requires 0 <= n < |acts|
    requires KeyInv0(H, acts, n, k)
    ensures KeyInv0(H, acts, n + 1, k)
  {
    KExecStep(H, acts, n);
    var st := KExec(H, acts[..n]);
    var st' := KExec(H, acts[..n + 1]);
    var L := Log(H, acts, k, n);
    var L' := Log(H, acts, k, n + 1);
    var a := acts[n];
    if a.KDel? && a.key == k && CommitsAt(H, acts, n) {
      assert L' == L + [n];
      StepExact(H, st[k], a.tok, a.sigOk);
      assert st'[k].outbox == st[k].outbox + [IntentOfSM(a.tok.intent)];
      assert InitOfK(H, acts, k, n + 1) == InitOfK(H, acts, k, n);
      forall i | 0 <= i < |L'| ensures L'[i] < n + 1 && EntryK0(H, acts, k, L'[i], st'[k].outbox[i])
      {
        if i < |L| { assert L'[i] == L[i] && st'[k].outbox[i] == st[k].outbox[i]; }
      }
    } else {
      assert L' == L;
      if a.KCreate? && a.key == k && CreateOk(st, k, a.init) {
        assert L == [];
      } else if a.KDel? && a.key == k && k in st {
        RejectedChangesNothing(H, st[k], a.tok, a.sigOk);
        assert st' == st;
      } else {
        assert k in st' <==> k in st;
        if k in st { assert st'[k] == st[k]; }
        assert InitOfK(H, acts, k, n + 1) == InitOfK(H, acts, k, n);
      }
    }
  }

  lemma KeyInv0Holds(H: HashFn, acts: seq<KAct>, n: int, k: string)
    requires 0 <= n <= |acts|
    ensures KeyInv0(H, acts, n, k)
    decreases n
  {
    if n == 0 {
      assert acts[..0] == [];
    } else {
      KeyInv0Holds(H, acts, n - 1, k);
      KeyInv0Next(H, acts, n - 1, k);
    }
  }

  // ---- the global hypotheses over the keyed trace ----
  ghost predicate MintedBeforeK(acts: seq<KAct>, g: int, m: Bytes)
  {
    exists j :: 0 <= j < g && j < |acts| && acts[j].KMint? && acts[j].msg == m
  }
  // A2pK (organisational + proved code): every mint of pinned-id bytes is an IssueBytes output for its pre.
  opaque ghost predicate A2pK(H: HashFn, acts: seq<KAct>)
  {
    forall j | 0 <= j < |acts| && acts[j].KMint? && OurBytes(acts[j].msg) ::
      exists t: F.Transition :: IssuedFrom(H, acts[j].pre, t, acts[j].msg)
  }
  // A2qK: the same with the d-minter method IssueTokenBytes (T2).
  opaque ghost predicate A2qK(H: HashFn, acts: seq<KAct>)
  {
    forall j | 0 <= j < |acts| && acts[j].KMint? && OurBytes(acts[j].msg) ::
      exists t: F.Transition, sh: string, ch: string :: IL.IssueTokenBytesOut(acts[j].pre, t, sh, ch, H(acts[j].pre), acts[j].msg)
  }
  // H1BK (cryptographic, EUF-CMA read per trace; the key is GLOBAL: one issuer for all charges).
  opaque ghost predicate H1BK(vb: ByteVerifier, acts: seq<KAct>)
  {
    forall g | 0 <= g < |acts| && acts[g].KDel? && vb(BytesOf(acts[g].tok), acts[g].tok.sig) ::
      MintedBeforeK(acts, g, BytesOf(acts[g].tok))
  }
  // B5K (glue): the sink's boolean is the byte verifier, at every delivery, for every store.
  opaque ghost predicate B5K(vb: ByteVerifier, acts: seq<KAct>)
  {
    forall g | 0 <= g < |acts| && acts[g].KDel? :: acts[g].sigOk == vb(BytesOf(acts[g].tok), acts[g].tok.sig)
  }
  // A4K (cryptographic, collision resistance read per trace, per store): for a mint before a delivery routed to a
  // present key, the hash of that key's STORED charge equals the hash of the mint's pre only if they are equal.
  opaque ghost predicate A4K(H: HashFn, acts: seq<KAct>)
  {
    forall j, g | 0 <= j < g < |acts| && acts[j].KMint? && acts[g].KDel? && acts[g].key in KExec(H, acts[..g]) ::
      H(KExec(H, acts[..g])[acts[g].key].charge) == H(acts[j].pre) ==> KExec(H, acts[..g])[acts[g].key].charge == acts[j].pre
  }

  lemma A2qKImpliesA2pK(H: HashFn, acts: seq<KAct>)
    requires A2qK(H, acts)
    ensures A2pK(H, acts)
  {
    reveal A2qK(), A2pK();
    forall j | 0 <= j < |acts| && acts[j].KMint? && OurBytes(acts[j].msg)
      ensures exists t: F.Transition :: IssuedFrom(H, acts[j].pre, t, acts[j].msg)
    {
      var t: F.Transition, sh: string, ch: string :| IL.IssueTokenBytesOut(acts[j].pre, t, sh, ch, H(acts[j].pre), acts[j].msg);
      IL.OutIsIssuedFrom(H, acts[j].pre, t, sh, ch, acts[j].msg);
    }
  }

  // One commit (the argument of SliceSafetyBytesV3.CommitApproved, over the keyed trace).
  lemma CommitApprovedK(H: HashFn, acts: seq<KAct>, vb: ByteVerifier, g: int)
    requires CommitsAt(H, acts, g)
    requires A2pK(H, acts) && H1BK(vb, acts) && B5K(vb, acts) && A4K(H, acts)
    ensures var c := KExec(H, acts[..g])[acts[g].key].charge;
      Approved(c, acts[g].tok, IntentOfSM(acts[g].tok.intent)) &&
      MintedBeforeK(acts, g, BytesOf(acts[g].tok)) &&
      ChargeOfState(acts[g].tok.post) == c.(remaining := c.remaining - acts[g].tok.intent.amount) &&
      0 <= acts[g].tok.intent.amount <= c.remaining
  {
    reveal A2pK(), H1BK(), B5K(), A4K();
    var core := KExec(H, acts[..g])[acts[g].key];
    var tok := acts[g].tok;
    StepExact(H, core, tok, acts[g].sigOk);
    assert vb(BytesOf(tok), tok.sig);
    assert MintedBeforeK(acts, g, BytesOf(tok));
    var j :| 0 <= j < g && j < |acts| && acts[j].KMint? && acts[j].msg == BytesOf(tok);
    assert OurBytes(acts[j].msg) by {
      assert SM.SignedBytes(BodyOf(tok)) == acts[j].msg && BodyOf(tok).specLockSha256 == PIN_SPEC &&
             BodyOf(tok).checkerSha256 == PIN_CHK;
    }
    var t :| IssuedFrom(H, acts[j].pre, t, acts[j].msg);
    IssuedTokenFields(H, acts[j].pre, t, tok);
    assert H(core.charge) == H(acts[j].pre);
    assert core.charge == acts[j].pre;
    AuthorizedMoneyNonNeg(acts[j].pre, t);
    var e := IntentOfSM(tok.intent);
    assert e == t.intent;
    assert F.Request(e.requestId, e.amount, e.reason) == t.request;
    assert F.Transition(F.Request(e.requestId, e.amount, e.reason), ChargeOfState(tok.post), e) == t;
  }

  ghost predicate EntryTop(H: HashFn, acts: seq<KAct>, k: string, g: int, e: R.RefundIntent)
  {
    EntryK0(H, acts, k, g, e) &&
    Approved(KExec(H, acts[..g])[k].charge, acts[g].tok, e) && MintedBeforeK(acts, g, BytesOf(acts[g].tok))
  }

  ghost predicate KeyInv2(H: HashFn, acts: seq<KAct>, n: int, k: string)
    requires 0 <= n <= |acts|
  {
    var st := KExec(H, acts[..n]);
    var L := Log(H, acts, k, n);
    var I := InitOfK(H, acts, k, n);
    k in st ==> (
      0 <= st[k].charge.remaining <= st[k].charge.original && st[k].charge.original == I.original &&
      SumIntents(st[k].outbox) == I.remaining - st[k].charge.remaining &&
      |L| == |st[k].outbox| &&
      forall i | 0 <= i < |L| :: L[i] < n && EntryTop(H, acts, k, L[i], st[k].outbox[i]))
  }

  lemma KeyInv2NextCommit(H: HashFn, acts: seq<KAct>, vb: ByteVerifier, n: int, k: string)
    requires 0 <= n < |acts|
    requires A2pK(H, acts) && H1BK(vb, acts) && B5K(vb, acts) && A4K(H, acts)
    requires KeyInv2(H, acts, n, k)
    requires acts[n].KDel? && acts[n].key == k && CommitsAt(H, acts, n)
    ensures KeyInv2(H, acts, n + 1, k)
  {
    KExecStep(H, acts, n);
    var st := KExec(H, acts[..n]);
    var st' := KExec(H, acts[..n + 1]);
    var L := Log(H, acts, k, n);
    var L' := Log(H, acts, k, n + 1);
    var a := acts[n];
    assert L' == L + [n];
    CommitApprovedK(H, acts, vb, n);
    StepExact(H, st[k], a.tok, a.sigOk);
    var e := IntentOfSM(a.tok.intent);
    assert st'[k] == Core(ChargeOfState(a.tok.post), st[k].settled + {a.tok.requestId}, st[k].outbox + [e]);
    SumAppend(st[k].outbox, e);
    assert InitOfK(H, acts, k, n + 1) == InitOfK(H, acts, k, n);
    assert EntryTop(H, acts, k, n, e);
    forall i | 0 <= i < |L'|
      ensures L'[i] < n + 1 && EntryTop(H, acts, k, L'[i], st'[k].outbox[i])
    {
      if i < |L| { assert L'[i] == L[i] && st'[k].outbox[i] == st[k].outbox[i]; }
      else { assert L'[i] == n && st'[k].outbox[i] == e; }
    }
  }

  lemma KeyInv2NextOther(H: HashFn, acts: seq<KAct>, n: int, k: string)
    requires 0 <= n < |acts|
    requires KeyInv2(H, acts, n, k)
    requires !(acts[n].KDel? && acts[n].key == k && CommitsAt(H, acts, n))
    ensures KeyInv2(H, acts, n + 1, k)
  {
    KeyInv0Holds(H, acts, n, k);
    KExecStep(H, acts, n);
    var st := KExec(H, acts[..n]);
    var st' := KExec(H, acts[..n + 1]);
    var L := Log(H, acts, k, n);
    var L' := Log(H, acts, k, n + 1);
    var a := acts[n];
    assert L' == L;
    if a.KCreate? && a.key == k && CreateOk(st, k, a.init) {
      assert L == [];
      assert st'[k] == Core(a.init, {}, []);
      assert InitOfK(H, acts, k, n + 1) == a.init;
    } else if a.KDel? && a.key == k && k in st {
      RejectedChangesNothing(H, st[k], a.tok, a.sigOk);
      assert st' == st;
      assert InitOfK(H, acts, k, n + 1) == InitOfK(H, acts, k, n);
    } else {
      assert k in st' <==> k in st;
      if k in st { assert st'[k] == st[k]; }
      assert InitOfK(H, acts, k, n + 1) == InitOfK(H, acts, k, n);
    }
  }

  lemma KeyInv2Next(H: HashFn, acts: seq<KAct>, vb: ByteVerifier, n: int, k: string)
    requires 0 <= n < |acts|
    requires A2pK(H, acts) && H1BK(vb, acts) && B5K(vb, acts) && A4K(H, acts)
    requires KeyInv2(H, acts, n, k)
    ensures KeyInv2(H, acts, n + 1, k)
  {
    if acts[n].KDel? && acts[n].key == k && CommitsAt(H, acts, n) {
      KeyInv2NextCommit(H, acts, vb, n, k);
    } else {
      KeyInv2NextOther(H, acts, n, k);
    }
  }

  lemma KeyInv2Holds(H: HashFn, acts: seq<KAct>, vb: ByteVerifier, n: int, k: string)
    requires 0 <= n <= |acts|
    requires A2pK(H, acts) && H1BK(vb, acts) && B5K(vb, acts) && A4K(H, acts)
    ensures KeyInv2(H, acts, n, k)
    decreases n
  {
    if n == 0 {
      assert acts[..0] == [];
    } else {
      KeyInv2Holds(H, acts, vb, n - 1, k);
      KeyInv2Next(H, acts, vb, n - 1, k);
    }
  }

  lemma SumNonNeg(o: seq<R.RefundIntent>)
    requires forall i | 0 <= i < |o| :: o[i].amount >= 0
    ensures SumIntents(o) >= 0
    decreases |o|
  {
    if |o| > 0 { SumNonNeg(o[..|o| - 1]); }
  }

  // KEYED TOP over the hash core (A2pK form).
  lemma KeyedTopHashP(H: HashFn, acts: seq<KAct>, vb: ByteVerifier, k: string)
    requires A2pK(H, acts) && H1BK(vb, acts) && B5K(vb, acts) && A4K(H, acts)
    requires k in KExec(H, acts)
    ensures var st := KExec(H, acts); var I := InitOfK(H, acts, k, |acts|); var L := Log(H, acts, k, |acts|);
      I.chargeId == k && InitOk(I) &&
      st[k].charge.chargeId == k && GoodV3(st[k]) &&
      0 <= st[k].charge.remaining <= st[k].charge.original && st[k].charge.original == I.original &&
      SumIntents(st[k].outbox) == I.remaining - st[k].charge.remaining &&
      0 <= SumIntents(st[k].outbox) <= I.original &&
      |L| == |st[k].outbox| &&
      forall i | 0 <= i < |st[k].outbox| :: EntryTop(H, acts, k, L[i], st[k].outbox[i])
  {
    var n := |acts|;
    assert acts[..n] == acts;
    KeyInv0Holds(H, acts, n, k);
    KeyInv2Holds(H, acts, vb, n, k);
    KExecWellKeyed(H, acts);
    var st := KExec(H, acts);
    var L := Log(H, acts, k, n);
    forall i | 0 <= i < |st[k].outbox| ensures st[k].outbox[i].amount >= 0
    {
      assert EntryK0(H, acts, k, L[i], st[k].outbox[i]);
      DecodedMoneyNonNeg(acts[L[i]].tok);
    }
    SumNonNeg(st[k].outbox);
  }

  // All keys at once (the per-entry part of KeyedTopHashP).
  lemma TopAllKeys(H: HashFn, acts: seq<KAct>, vb: ByteVerifier)
    requires A2pK(H, acts) && H1BK(vb, acts) && B5K(vb, acts) && A4K(H, acts)
    ensures forall k | k in KExec(H, acts) :: (|Log(H, acts, k, |acts|)| == |KExec(H, acts)[k].outbox| &&
      forall i | 0 <= i < |KExec(H, acts)[k].outbox| ::
        EntryTop(H, acts, k, Log(H, acts, k, |acts|)[i], KExec(H, acts)[k].outbox[i]))
  {
    forall k | k in KExec(H, acts)
      ensures |Log(H, acts, k, |acts|)| == |KExec(H, acts)[k].outbox| && forall i | 0 <= i < |KExec(H, acts)[k].outbox| ::
        EntryTop(H, acts, k, Log(H, acts, k, |acts|)[i], KExec(H, acts)[k].outbox[i])
    {
      KeyedTopHashP(H, acts, vb, k);
    }
  }

  // KEYED TOP over the hash core with the d-minter issuer hypothesis A2qK (T2 + T3).
  lemma KeyedTopHash(H: HashFn, acts: seq<KAct>, vb: ByteVerifier, k: string)
    requires A2qK(H, acts) && H1BK(vb, acts) && B5K(vb, acts) && A4K(H, acts)
    requires k in KExec(H, acts)
    ensures var st := KExec(H, acts); var I := InitOfK(H, acts, k, |acts|); var L := Log(H, acts, k, |acts|);
      I.chargeId == k && InitOk(I) &&
      st[k].charge.chargeId == k && GoodV3(st[k]) &&
      0 <= st[k].charge.remaining <= st[k].charge.original && st[k].charge.original == I.original &&
      SumIntents(st[k].outbox) == I.remaining - st[k].charge.remaining &&
      0 <= SumIntents(st[k].outbox) <= I.original &&
      |L| == |st[k].outbox| &&
      forall i | 0 <= i < |st[k].outbox| :: EntryTop(H, acts, k, L[i], st[k].outbox[i])
  {
    A2qKImpliesA2pK(H, acts);
    KeyedTopHashP(H, acts, vb, k);
  }
}

// =================================================================================================================
// T3 witness and controls.
module KeyedHashControls {
  import opened HashCore
  import opened SliceSafetyBytesV3
  import opened KeyedHash
  import C = ControlsBytesV3
  import IL = IssuerLink
  import ILC = IssuerLinkControls
  import ShortTexts

  const DC: string := C.DC
  const B1: F.Charge := F.Charge("ch_2", 100, 40, true)
  const IB1: R.RefundIntent := R.Intent("ch_2", "rq_1", 10, DC)
  const TB: F.Transition := F.Transition(F.Request("rq_1", 10, DC), B1, IB1)
  const MB: Bytes := IssueOut(C.HW, C.C2_PRE, TB)
  const TKB: HashToken := C.TokOf(C.HW, C.C2_PRE, TB)

  lemma Lits()
    ensures "ch_1" != "ch_2" && "rq_0" != "rq_1"
  {
    assert "ch_1"[3] != "ch_2"[3];
    assert "rq_0"[3] != "rq_1"[3];
  }

  lemma AuthB()
    ensures F.Authorizes(C.C2_PRE, TB) && MoneyNonNeg(TB)
    ensures ChargeOfState(TKB.post) == B1 && IntentOfSM(TKB.intent) == IB1
  {
    assert C.C2_PRE.(remaining := C.C2_PRE.remaining - 10) == B1;
  }

  // The keyed witness: two charges; rq_0 (amount 0) and rq_1 commit in ch_1; rq_1 commits in ch_2 as well; the ch_1
  // token TK1 delivered to ch_2's store is rejected; a re-create of ch_1 is refused.
  opaque function KW(): (r: seq<KAct>)
    ensures |r| == 10
  {
    [KCreate("ch_1", C.W_PRE), KCreate("ch_2", C.C2_PRE),
     KMint(C.W_PRE, C.M0, C.SB(C.M0)), KDel("ch_1", C.TK0, true),
     KMint(C.W_PRE, C.M1, C.SB(C.M1)), KDel("ch_1", C.TK1, true),
     KMint(C.C2_PRE, MB, C.SB(MB)), KDel("ch_2", C.TK1, true), KDel("ch_2", TKB, true),
     KCreate("ch_1", C.W_PRE)]
  }

  function S1(): Store { map["ch_1" := Core(C.W_PRE, {}, [])] }
  function S2(): Store { S1()["ch_2" := Core(C.C2_PRE, {}, [])] }
  function S4(): Store { S2()["ch_1" := Core(C.W_PRE, {"rq_0"}, [C.I0])] }
  function S6(): Store { S4()["ch_1" := Core(C.W_POST, {"rq_0", "rq_1"}, [C.I0, C.I1])] }
  function S9(): Store { S6()["ch_2" := Core(B1, {"rq_1"}, [IB1])] }

  lemma StepsB()
    ensures Step(C.HW, Core(C.C2_PRE, {}, []), C.TK1, true).out == Rejected(PreStateMismatch)
    ensures Step(C.HW, Core(C.C2_PRE, {}, []), TKB, true) == StepResult(Core(B1, {"rq_1"}, [IB1]), Committed)
  {
    C.Authorized(); C.HexDistinct(); AuthB();
    assert {} + {"rq_1"} == {"rq_1"};
    assert [] + [IB1] == [IB1];
  }

  lemma KW3()
    ensures KExec(C.HW, KW()[..1]) == S1() && KExec(C.HW, KW()[..2]) == S2() && KExec(C.HW, KW()[..3]) == S2()
  {
    reveal KW();
    var A := KW();
    assert A[..0] == [];
    KExecStep(C.HW, A, 0);
    KExecStep(C.HW, A, 1);
    Lits();
    KExecStep(C.HW, A, 2);
  }
  lemma KW6()
    ensures KExec(C.HW, KW()[..4]) == S4() && KExec(C.HW, KW()[..5]) == S4() && KExec(C.HW, KW()[..6]) == S6()
  {
    reveal KW();
    var A := KW();
    KW3();
    C.WitSteps();
    KExecStep(C.HW, A, 3);
    KExecStep(C.HW, A, 4);
    KExecStep(C.HW, A, 5);
  }
  lemma KW10()
    ensures KExec(C.HW, KW()[..7]) == S6() && KExec(C.HW, KW()[..8]) == S6() && KExec(C.HW, KW()[..9]) == S9()
    ensures KExec(C.HW, KW()) == S9()
  {
    reveal KW();
    var A := KW();
    KW6();
    StepsB();
    Lits();
    KExecStep(C.HW, A, 6);
    KExecStep(C.HW, A, 7);
    assert S6()["ch_2"] == Core(C.C2_PRE, {}, []);
    KExecStep(C.HW, A, 8);
    KExecStep(C.HW, A, 9);
    assert A[..10] == A;
  }

  lemma KWA2p()
    ensures A2pK(C.HW, KW())
  {
    reveal KW();
    reveal A2pK();
    var A := KW();
    C.Authorized(); AuthB();
    assert IssuedFrom(C.HW, C.W_PRE, C.T0, C.M0) && IssuedFrom(C.HW, C.W_PRE, C.T1, C.M1) && IssuedFrom(C.HW, C.C2_PRE, TB, MB);
    forall j | 0 <= j < |A| && A[j].KMint? && OurBytes(A[j].msg)
      ensures exists t: F.Transition :: IssuedFrom(C.HW, A[j].pre, t, A[j].msg)
    {
      if j == 2 { assert IssuedFrom(C.HW, A[j].pre, C.T0, A[j].msg); }
      else if j == 4 { assert IssuedFrom(C.HW, A[j].pre, C.T1, A[j].msg); }
      else { assert j == 6; assert IssuedFrom(C.HW, A[j].pre, TB, A[j].msg); }
    }
  }

  lemma KWSig()
    ensures H1BK(C.TotalVB, KW()) && B5K(C.TotalVB, KW())
  {
    reveal KW();
    reveal H1BK(), B5K();
    var A := KW();
    C.Authorized(); AuthB();
    C.TokOfBytes(C.HW, C.W_PRE, C.T0); C.TokOfBytes(C.HW, C.W_PRE, C.T1); C.TokOfBytes(C.HW, C.C2_PRE, TB);
    forall g | 0 <= g < |A| && A[g].KDel?
      ensures A[g].sigOk == C.TotalVB(BytesOf(A[g].tok), A[g].tok.sig)
    {
      assert g == 3 || g == 5 || g == 7 || g == 8;
    }
    forall g | 0 <= g < |A| && A[g].KDel? && C.TotalVB(BytesOf(A[g].tok), A[g].tok.sig)
      ensures MintedBeforeK(A, g, BytesOf(A[g].tok))
    {
      if g == 3 { assert A[2].KMint? && A[2].msg == BytesOf(A[g].tok); }
      else if g == 5 || g == 7 { assert A[4].KMint? && A[4].msg == BytesOf(A[g].tok); }
      else { assert g == 8; assert A[6].KMint? && A[6].msg == BytesOf(A[g].tok); }
    }
  }

  // A4K holds for EVERY stored state here: HW is injective on the hash values of the minted pre-states.
  lemma HWInverse(c: F.Charge)
    ensures C.HW(c) == C.HW(C.W_PRE) ==> c == C.W_PRE
    ensures C.HW(c) == C.HW(C.C2_PRE) ==> c == C.C2_PRE
  {
    C.HexDistinct();
  }
  lemma KWA4()
    ensures A4K(C.HW, KW())
  {
    reveal KW();
    reveal A4K();
    var A := KW();
    forall j, g | 0 <= j < g < |A| && A[j].KMint? && A[g].KDel? && A[g].key in KExec(C.HW, A[..g])
      ensures C.HW(KExec(C.HW, A[..g])[A[g].key].charge) == C.HW(A[j].pre) ==> KExec(C.HW, A[..g])[A[g].key].charge == A[j].pre
    {
      assert A[j].pre == C.W_PRE || A[j].pre == C.C2_PRE;
      HWInverse(KExec(C.HW, A[..g])[A[g].key].charge);
    }
  }

  lemma KWShape()
    ensures KExec(C.HW, KW()).Keys == {"ch_1", "ch_2"}
    ensures KExec(C.HW, KW())["ch_1"].outbox == [C.I0, C.I1] && C.I0.amount == 0 && C.I1.requestId == "rq_1"
    ensures KExec(C.HW, KW())["ch_2"].outbox == [IB1] && IB1.requestId == "rq_1"
    ensures KExec(C.HW, KW()[..10]) == KExec(C.HW, KW()[..9])
  {
    reveal KW();
    KW10();
    assert KW()[..10] == KW();
  }
  lemma KWReject()
    ensures KW()[7] == KDel("ch_2", C.TK1, true) && !CommitsAt(C.HW, KW(), 7)
  {
    reveal KW();
    KW10(); StepsB();
    assert KExec(C.HW, KW()[..7])["ch_2"] == Core(C.C2_PRE, {}, []);
  }
  lemma KWTop()
    requires A2pK(C.HW, KW()) && H1BK(C.TotalVB, KW()) && B5K(C.TotalVB, KW()) && A4K(C.HW, KW())
    ensures forall k | k in KExec(C.HW, KW()) :: (|Log(C.HW, KW(), k, |KW()|)| == |KExec(C.HW, KW())[k].outbox| &&
      forall i | 0 <= i < |KExec(C.HW, KW())[k].outbox| ::
        EntryTop(C.HW, KW(), k, Log(C.HW, KW(), k, |KW()|)[i], KExec(C.HW, KW())[k].outbox[i]))
  {
    TopAllKeys(C.HW, KW(), C.TotalVB);
  }

  // NON-VACUITY: all hypotheses hold; both stores commit; zero amount commits; rq_1 commits once in EACH store;
  // TK1 (a ch_1 token) delivered to ch_2's store is rejected; the re-create of ch_1 is refused; KeyedTopHashP applies.
  lemma KeyedWitness()
    ensures A2pK(C.HW, KW()) && H1BK(C.TotalVB, KW()) && B5K(C.TotalVB, KW()) && A4K(C.HW, KW())
    ensures KExec(C.HW, KW()).Keys == {"ch_1", "ch_2"}
    ensures KExec(C.HW, KW())["ch_1"].outbox == [C.I0, C.I1] && C.I0.amount == 0 && C.I1.requestId == "rq_1"
    ensures KExec(C.HW, KW())["ch_2"].outbox == [IB1] && IB1.requestId == "rq_1"
    ensures KW()[7] == KDel("ch_2", C.TK1, true) && !CommitsAt(C.HW, KW(), 7)
    ensures KExec(C.HW, KW()[..10]) == KExec(C.HW, KW()[..9])
    ensures forall k | k in KExec(C.HW, KW()) :: (|Log(C.HW, KW(), k, |KW()|)| == |KExec(C.HW, KW())[k].outbox| &&
      forall i | 0 <= i < |KExec(C.HW, KW())[k].outbox| ::
        EntryTop(C.HW, KW(), k, Log(C.HW, KW(), k, |KW()|)[i], KExec(C.HW, KW())[k].outbox[i]))
  {
    KWA2p(); KWSig(); KWA4();
    KWShape(); KWReject();
    KWTop();
  }

  // The witness also meets A2qK (the d-minter issuer form, T2): every mint is an IssueTokenBytes output.
  lemma WfTKB() ensures SM.WfBody(BodyOf(TKB))
  {
    C.WfCommon(); ShortTexts.Texts(); AuthB();
    var b := BodyOf(TKB);
    assert b == SM.TokenBody(SM.DOMAIN, PIN_SPEC, PIN_CHK, C.HX2, "rq_1", SM.ChargeState("ch_2", 100, 40, true), SM.Intent("ch_2", "rq_1", 10, DC));
    assert SM.Money(100) && SM.Money(40) && SM.Money(10);
    assert SM.IsState(b.post);
    assert SM.IsIntent(b.intent);
  }
  lemma OutB() ensures IL.IssueTokenBytesOut(C.C2_PRE, TB, PIN_SPEC, PIN_CHK, C.HW(C.C2_PRE), MB)
  {
    AuthB(); WfTKB();
    assert BodyOf(TKB) == IssueBody(C.HW, C.C2_PRE, TB);
    ILC.OutOfIssued(C.HW, C.C2_PRE, TB, MB);
  }
  lemma KWA2q()
    ensures A2qK(C.HW, KW())
  {
    reveal KW();
    reveal A2qK();
    var A := KW();
    ILC.Out0(); ILC.Out1(); OutB();
    forall j | 0 <= j < |A| && A[j].KMint? && OurBytes(A[j].msg)
      ensures exists t: F.Transition, sh: string, ch: string ::
        IL.IssueTokenBytesOut(A[j].pre, t, sh, ch, C.HW(A[j].pre), A[j].msg)
    {
      if j == 2 { assert A[j].pre == C.W_PRE && A[j].msg == C.M0; }
      else if j == 4 { assert A[j].pre == C.W_PRE && A[j].msg == C.M1; }
      else { assert j == 6; assert A[j].pre == C.C2_PRE && A[j].msg == MB; }
    }
  }
  lemma KeyedWitnessA2q()
    ensures A2qK(C.HW, KW()) && H1BK(C.TotalVB, KW()) && B5K(C.TotalVB, KW()) && A4K(C.HW, KW())
    ensures "ch_1" in KExec(C.HW, KW()) && "ch_2" in KExec(C.HW, KW())
  {
    KWA2q(); KWSig(); KWA4(); KWShape();
    KeyedTopHash(C.HW, KW(), C.TotalVB, "ch_1");
    KeyedTopHash(C.HW, KW(), C.TotalVB, "ch_2");
  }

  // Generic: a token whose intent names another charge never commits in a well-keyed store (NO hypothesis).
  lemma MisroutedNeverCommits(H: HashFn, st: Store, key: string, tok: HashToken, sigOk: bool)
    requires WellKeyed(st) && key in st && tok.intent.chargeId != key
    ensures KStep(H, st, KDel(key, tok, sigOk)) == st
  {
    ForeignChargeNeverCommits(H, st[key], tok, sigOk);
    assert st[key := st[key]] == st;
  }

  // ---- CONTROL 1: creation without the key check (key == chargeId dropped) reaches a double refund. ----
  function UStep(H: HashFn, st: Store, a: KAct): Store
  {
    match a
    case KMint(_, _, _) => st
    case KCreate(key, init) => if key !in st && 0 <= init.remaining <= init.original then st[key := Core(init, {}, [])] else st
    case KDel(key, tok, s) => if key in st then st[key := Step(H, st[key], tok, s).core] else st
  }
  function DupActs(): seq<KAct>
  {
    [KCreate("db_a", C.W_PRE), KCreate("db_b", C.W_PRE), KMint(C.W_PRE, C.M1, C.SB(C.M1)),
     KDel("db_a", C.TK1, true), KDel("db_b", C.TK1, true)]
  }
  lemma UncheckedCreateDoubleRefund()
    ensures var u := UStep(C.HW, UStep(C.HW, UStep(C.HW, UStep(C.HW, UStep(C.HW, map[], DupActs()[0]), DupActs()[1]),
                                                   DupActs()[2]), DupActs()[3]), DupActs()[4]);
      "db_a" in u && "db_b" in u && "db_a" != "db_b" && u["db_a"].outbox == [C.I1] && u["db_b"].outbox == [C.I1] &&
      C.I1.chargeId == "ch_1" && C.I1.amount + C.I1.amount > C.W_PRE.remaining
    ensures IssuedFrom(C.HW, C.W_PRE, C.T1, C.M1) && C.TotalVB(BytesOf(C.TK1), C.TK1.sig)
    ensures KExec(C.HW, DupActs()) == map[]
  {
    C.Authorized(); C.WitSteps();
    C.TokOfBytes(C.HW, C.W_PRE, C.T1);
    assert "db_a"[3] != "db_b"[3];
    assert Step(C.HW, Core(C.W_PRE, {}, []), C.TK1, true) == StepResult(Core(C.W_POST, {"rq_1"}, [C.I1]), Committed) by {
      assert {} + {"rq_1"} == {"rq_1"};
      assert [] + [C.I1] == [C.I1];
    }
    var A := DupActs();
    assert A[..0] == [];
    KExecStep(C.HW, A, 0); KExecStep(C.HW, A, 1); KExecStep(C.HW, A, 2); KExecStep(C.HW, A, 3); KExecStep(C.HW, A, 4);
    assert A[..5] == A;
  }

  // ---- CONTROL 2: a reject-all delivery step. Every outbox stays empty on EVERY trace, so it cannot meet the
  // KeyedWitness conclusion (ch_1's outbox == [I0, I1]). ----
  function RAStep(st: Store, a: KAct): Store
  {
    match a
    case KMint(_, _, _) => st
    case KCreate(key, init) => if CreateOk(st, key, init) then st[key := Core(init, {}, [])] else st
    case KDel(_, _, _) => st
  }
  function RAExec(acts: seq<KAct>): Store
    decreases |acts|
  {
    if |acts| == 0 then map[] else RAStep(RAExec(acts[..|acts| - 1]), acts[|acts| - 1])
  }
  lemma RejectAllEmpty(acts: seq<KAct>)
    ensures forall k | k in RAExec(acts) :: RAExec(acts)[k].outbox == []
    decreases |acts|
  {
    if |acts| > 0 { RejectAllEmpty(acts[..|acts| - 1]); }
  }
  lemma RejectAllFailsWitness()
    ensures "ch_1" in KExec(C.HW, KW()) && |KExec(C.HW, KW())["ch_1"].outbox| == 2
    ensures forall k | k in RAExec(KW()) :: RAExec(KW())[k].outbox == []
  {
    RejectAllEmpty(KW());
    KWShape();
  }

  // ---- CONTROL 3: a commit-all delivery step (no check). The ch_1 token TK1 enters ch_2's store: an effect with
  // charge id ch_1 in store ch_2, which KeyedL0Hash excludes for the real step. ----
  function CAStep(st: Store, a: KAct): Store
  {
    match a
    case KMint(_, _, _) => st
    case KCreate(key, init) => if CreateOk(st, key, init) then st[key := Core(init, {}, [])] else st
    case KDel(key, tok, s) =>
      if key in st then st[key := Core(ChargeOfState(tok.post), st[key].settled + {tok.requestId},
                                       st[key].outbox + [IntentOfSM(tok.intent)])]
      else st
  }
  lemma CommitAllBreaksL0()
    ensures var st := CAStep(S6(), KDel("ch_2", C.TK1, true));
      "ch_2" in st && |st["ch_2"].outbox| == 1 && st["ch_2"].outbox[0].chargeId == "ch_1" && "ch_1" != "ch_2"
    ensures KStep(C.HW, S6(), KDel("ch_2", C.TK1, true)) == S6()
  {
    Lits();
    C.Authorized();
    assert IntentOfSM(C.TK1.intent) == C.I1;
    StepsB();
    assert S6()["ch_2"] == Core(C.C2_PRE, {}, []);
    assert S6()["ch_2" := S6()["ch_2"]] == S6();
  }
}
