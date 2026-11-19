// Night shift 2026-11-19, Orchestrator B, task b-v6bytes (G3). A DRAFT in an evidence folder. NOT gate evidence.
// M1-B stays OPEN. end_to_end=false. A Dafny-MODEL statement only. NOT a proof about sink.ts, a dispatcher,
// SQLite, a file system, Ed25519, SHA-256 or compiled code.
//
// G3: several charges with CHECKED creation (the route of b-top/src/KeyedHash.dfy: a direct re-proof over the keyed
// trace) over HashCore6.Step6. A store is a map from key to HashCore.Core. Actions: KMint6 (no effect on stores),
// KCreate6(key, init) (refused unless key == init.chargeId, key not present, 0 <= init.remaining <= init.original),
// KDel6(key, tok, sigOk) (Step6 on the routed store; a delivery to an absent key changes nothing).
// KeyedL0V6, NO hypothesis (arbitrary H, tokens, sigOk, keys, mints): for every key k in the reached store map:
//   - every effect in store k was committed by a delivery to k that Step6 committed (sigOk true), and it is
//     Approved (SliceSafetyBytesV3.Approved: F.Authorizes, R.Eligible with requestOpen = TRUE: CTX-SINK) on store
//     k's charge AT ITS COMMIT;
//   - 0 <= remaining <= original == original at creation; sum(outbox k) == remaining at creation - remaining;
//     so sum(outbox k) <= original(k);
//   - no two effects in all outboxes share (chargeId, requestId); every effect in store k has charge id k.
// The InitOk of each store is ENFORCED by the create check; it is not a hypothesis.
// OUTSIDE THE MODEL (as in KeyedHash): O1 no delete/re-create of a key; O2 the initial charge at creation is
// authentic; O3 no rollback of a store.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
include "SliceSafetyBytesV6.dfy"

module KeyedV6 {
  import opened HashCore
  import opened HashCore6
  import opened SliceSafetyBytesV3
  import opened SliceSafetyBytesV6

  type Store = map<string, Core>
  datatype KAct6 = KMint6(pre: F.Charge, msg: Bytes, tag: Tag) | KCreate6(key: string, init: F.Charge)
                 | KDel6(key: string, tok: HashToken, sigOk: bool)

  predicate CreateOk(st: Store, key: string, init: F.Charge)
  {
    key == init.chargeId && key !in st && 0 <= init.remaining <= init.original
  }

  function KStep6(H: HashFn, st: Store, a: KAct6): Store
  {
    match a
    case KMint6(_, _, _) => st
    case KCreate6(key, init) => if CreateOk(st, key, init) then st[key := Core(init, {}, [])] else st
    case KDel6(key, tok, s) => if key in st then st[key := Step6(H, st[key], tok, s).core] else st
  }

  function KExec6(H: HashFn, acts: seq<KAct6>): Store
    decreases |acts|
  {
    if |acts| == 0 then map[] else KStep6(H, KExec6(H, acts[..|acts| - 1]), acts[|acts| - 1])
  }

  lemma KExec6Step(H: HashFn, acts: seq<KAct6>, n: int)
    requires 0 <= n < |acts|
    ensures KExec6(H, acts[..n + 1]) == KStep6(H, KExec6(H, acts[..n]), acts[n])
  {
    assert acts[..n + 1][..n] == acts[..n];
    assert acts[..n + 1][n] == acts[n];
  }

  // ---- uniqueness (NO hypothesis) ----
  ghost predicate WellKeyed(st: Store)
  {
    forall k | k in st :: st[k].charge.chargeId == k && GoodV3(st[k])
  }

  lemma KStep6KeepsWellKeyed(H: HashFn, st: Store, a: KAct6)
    requires WellKeyed(st)
    ensures WellKeyed(KStep6(H, st, a))
  {
    match a
    case KMint6(_, _, _) =>
    case KCreate6(key, init) =>
    case KDel6(key, tok, s) =>
      if key in st {
        Step6KeepsGoodV3(H, st[key], tok, s);
      }
  }

  lemma KExec6WellKeyed(H: HashFn, acts: seq<KAct6>)
    ensures WellKeyed(KExec6(H, acts))
    decreases |acts|
  {
    if |acts| > 0 {
      KExec6WellKeyed(H, acts[..|acts| - 1]);
      KStep6KeepsWellKeyed(H, KExec6(H, acts[..|acts| - 1]), acts[|acts| - 1]);
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

  // ---- the commit log and the creation state ----
  ghost predicate CommitsAt6(H: HashFn, acts: seq<KAct6>, g: int)
  {
    0 <= g < |acts| && acts[g].KDel6? && acts[g].key in KExec6(H, acts[..g]) &&
    Step6(H, KExec6(H, acts[..g])[acts[g].key], acts[g].tok, acts[g].sigOk).out.Committed6?
  }
  ghost function Log6(H: HashFn, acts: seq<KAct6>, k: string, n: int): seq<int>
    requires 0 <= n <= |acts|
    decreases n
  {
    if n == 0 then []
    else Log6(H, acts, k, n - 1) + (if acts[n - 1].KDel6? && acts[n - 1].key == k && CommitsAt6(H, acts, n - 1) then [n - 1] else [])
  }
  ghost function InitOfK6(H: HashFn, acts: seq<KAct6>, k: string, n: int): F.Charge
    requires 0 <= n <= |acts|
    decreases n
  {
    if n == 0 then F.Charge(k, 0, 0, false)
    else if acts[n - 1].KCreate6? && acts[n - 1].key == k && CreateOk(KExec6(H, acts[..n - 1]), k, acts[n - 1].init)
    then acts[n - 1].init
    else InitOfK6(H, acts, k, n - 1)
  }

  // Entry: committed at g by a delivery to k with sigOk, and APPROVED on store k's charge at g.
  ghost predicate EntryK6(H: HashFn, acts: seq<KAct6>, k: string, g: int, e: R.RefundIntent)
  {
    CommitsAt6(H, acts, g) && acts[g].key == k && acts[g].sigOk && e == IntentOfSM(acts[g].tok.intent) &&
    Approved(KExec6(H, acts[..g])[k].charge, acts[g].tok, e)
  }

  ghost predicate MoneyK(init: F.Charge, c: Core)
  {
    0 <= c.charge.remaining <= c.charge.original && c.charge.original == init.original &&
    SumIntents(c.outbox) == init.remaining - c.charge.remaining
  }

  ghost predicate KeyInv6(H: HashFn, acts: seq<KAct6>, n: int, k: string)
    requires 0 <= n <= |acts|
  {
    var st := KExec6(H, acts[..n]);
    var L := Log6(H, acts, k, n);
    (k !in st ==> L == []) &&
    (k in st ==> (|L| == |st[k].outbox| && InitOfK6(H, acts, k, n).chargeId == k && InitOk(InitOfK6(H, acts, k, n)) &&
       MoneyK(InitOfK6(H, acts, k, n), st[k]) &&
       forall i | 0 <= i < |L| :: L[i] < n && EntryK6(H, acts, k, L[i], st[k].outbox[i])))
  }

  lemma KeyInv6NextCommit(H: HashFn, acts: seq<KAct6>, n: int, k: string)
    requires 0 <= n < |acts|
    requires KeyInv6(H, acts, n, k)
    requires acts[n].KDel6? && acts[n].key == k && CommitsAt6(H, acts, n)
    ensures KeyInv6(H, acts, n + 1, k)
  {
    KExec6Step(H, acts, n);
    var st := KExec6(H, acts[..n]);
    var st' := KExec6(H, acts[..n + 1]);
    var L := Log6(H, acts, k, n);
    var L' := Log6(H, acts, k, n + 1);
    var a := acts[n];
    var I := InitOfK6(H, acts, k, n);
    assert L' == L + [n];
    Step6Exact(H, st[k], a.tok, a.sigOk);
    ApprovedOfAuthorizes(st[k].charge, a.tok);
    var e := IntentOfSM(a.tok.intent);
    assert st'[k] == Step6(H, st[k], a.tok, a.sigOk).core;
    assert st'[k].outbox == st[k].outbox + [e];
    assert st'[k].charge == st[k].charge.(remaining := st[k].charge.remaining - e.amount);
    SumAppend(st[k].outbox, e);
    assert InitOfK6(H, acts, k, n + 1) == I;
    assert MoneyK(I, st'[k]);
    forall i | 0 <= i < |L'| ensures L'[i] < n + 1 && EntryK6(H, acts, k, L'[i], st'[k].outbox[i])
    {
      if i < |L| { assert L'[i] == L[i] && st'[k].outbox[i] == st[k].outbox[i]; }
      else { assert L'[i] == n && st'[k].outbox[i] == e; }
    }
  }

  lemma KeyInv6Next(H: HashFn, acts: seq<KAct6>, n: int, k: string)
    requires 0 <= n < |acts|
    requires KeyInv6(H, acts, n, k)
    ensures KeyInv6(H, acts, n + 1, k)
  {
    var a := acts[n];
    if a.KDel6? && a.key == k && CommitsAt6(H, acts, n) {
      KeyInv6NextCommit(H, acts, n, k);
    } else {
      KExec6Step(H, acts, n);
      var st := KExec6(H, acts[..n]);
      var st' := KExec6(H, acts[..n + 1]);
      var L := Log6(H, acts, k, n);
      assert Log6(H, acts, k, n + 1) == L;
      if a.KCreate6? && a.key == k && CreateOk(st, k, a.init) {
        assert L == [];
        assert InitOfK6(H, acts, k, n + 1) == a.init;
        assert st'[k] == Core(a.init, {}, []);
        assert SumIntents([]) == 0;
      } else if a.KDel6? && a.key == k && k in st {
        Rejected6ChangesNothing(H, st[k], a.tok, a.sigOk);
        assert st' == st;
        assert InitOfK6(H, acts, k, n + 1) == InitOfK6(H, acts, k, n);
      } else {
        assert k in st' <==> k in st;
        if k in st { assert st'[k] == st[k]; }
        assert InitOfK6(H, acts, k, n + 1) == InitOfK6(H, acts, k, n);
      }
    }
  }

  lemma KeyInv6Holds(H: HashFn, acts: seq<KAct6>, n: int, k: string)
    requires 0 <= n <= |acts|
    ensures KeyInv6(H, acts, n, k)
    decreases n
  {
    if n == 0 {
      assert acts[..0] == [];
    } else {
      KeyInv6Holds(H, acts, n - 1, k);
      KeyInv6Next(H, acts, n - 1, k);
    }
  }

  lemma SumNonNeg(o: seq<R.RefundIntent>)
    requires forall i | 0 <= i < |o| :: o[i].amount >= 0
    ensures SumIntents(o) >= 0
    decreases |o|
  {
    if |o| > 0 { SumNonNeg(o[..|o| - 1]); }
  }

  // KEYED L0 OVER Step6, NO hypothesis.
  lemma KeyedL0V6(H: HashFn, acts: seq<KAct6>, k: string)
    requires k in KExec6(H, acts)
    ensures var st := KExec6(H, acts); var I := InitOfK6(H, acts, k, |acts|);
      I.chargeId == k && InitOk(I) &&
      0 <= st[k].charge.remaining <= st[k].charge.original && st[k].charge.original == I.original &&
      SumIntents(st[k].outbox) == I.remaining - st[k].charge.remaining &&
      SumIntents(st[k].outbox) <= st[k].charge.original &&
      forall e | e in st[k].outbox :: exists g :: EntryK6(H, acts, k, g, e)
  {
    KeyInv6Holds(H, acts, |acts|, k);
    assert acts[..|acts|] == acts;
    var st := KExec6(H, acts);
    var L := Log6(H, acts, k, |acts|);
    forall e | e in st[k].outbox ensures exists g :: EntryK6(H, acts, k, g, e)
    {
      var i :| 0 <= i < |st[k].outbox| && st[k].outbox[i] == e;
      assert EntryK6(H, acts, k, L[i], e);
    }
  }

  lemma KeyedUniqueV6(H: HashFn, acts: seq<KAct6>)
    ensures WellKeyed(KExec6(H, acts))
    ensures forall k, i | k in KExec6(H, acts) && 0 <= i < |KExec6(H, acts)[k].outbox| :: KExec6(H, acts)[k].outbox[i].chargeId == k
    ensures forall k1, k2, i, j | k1 in KExec6(H, acts) && k2 in KExec6(H, acts) &&
        0 <= i < |KExec6(H, acts)[k1].outbox| && 0 <= j < |KExec6(H, acts)[k2].outbox| && (k1 != k2 || i != j) ::
      KExec6(H, acts)[k1].outbox[i].chargeId != KExec6(H, acts)[k2].outbox[j].chargeId ||
      KExec6(H, acts)[k1].outbox[i].requestId != KExec6(H, acts)[k2].outbox[j].requestId
  {
    KExec6WellKeyed(H, acts);
    GlobalDistinct(KExec6(H, acts));
  }

  // ---- non-vacuity: two charges; a zero and a positive commit on ch_1, a commit on ch_2; an unauthorized
  // delivery to ch_2 is rejected; a create with a bad init is refused. ----
  const DC: string := "duplicate_charge"
  const A1: F.Charge := F.Charge("ch_1", 100, 60, true)
  const A2: F.Charge := F.Charge("ch_2", 50, 50, true)
  function HK(c: F.Charge): string { "" }   // a constant hash: L0 needs no hash property

  function TkK(c: F.Charge, rid: string, amt: nat): HashToken
    requires 0 <= amt <= c.remaining && c.original >= 0
  {
    HashToken(PIN_SPEC, PIN_CHK, "", rid, StateOfN(c.(remaining := c.remaining - amt)), SM.Intent(c.chargeId, rid, amt, DC), [])
  }

  function KActs(): seq<KAct6>
  {
    [KCreate6("ch_1", A1), KCreate6("ch_2", A2), KCreate6("ch_3", F.Charge("ch_3", 10, 20, true)),
     KDel6("ch_1", TkK(A1, "rq_0", 0), true), KDel6("ch_1", TkK(A1, "rq_1", 40), true),
     KDel6("ch_2", TkK(A2, "rq_1", 50), true),
     KDel6("ch_2", TkK(A2, "rq_2", 50), true)]   // amount 50 > remaining 0 after the commit: rejected
  }

  function S2(): Store { map["ch_1" := Core(A1, {}, []), "ch_2" := Core(A2, {}, [])] }
  function C1(): Core { Core(A1, {"rq_0"}, [R.Intent("ch_1", "rq_0", 0, DC)]) }
  function C1b(): Core { Core(A1.(remaining := 20), {"rq_0", "rq_1"}, [R.Intent("ch_1", "rq_0", 0, DC), R.Intent("ch_1", "rq_1", 40, DC)]) }
  function C2(): Core { Core(A2.(remaining := 0), {"rq_1"}, [R.Intent("ch_2", "rq_1", 50, DC)]) }

  lemma Lits()
    ensures "rq_1" != "rq_0" && "rq_2" != "rq_1" && "ch_1" != "ch_2" && "ch_3" != "ch_1" && "ch_3" != "ch_2"
  {
    assert "rq_1"[3] != "rq_0"[3] && "rq_2"[3] != "rq_1"[3];
    assert "ch_1"[3] != "ch_2"[3] && "ch_3"[3] != "ch_1"[3] && "ch_3"[3] != "ch_2"[3];
  }

  lemma KW3() ensures KExec6(HK, KActs()[..3]) == S2()
  {
    var acts := KActs();
    Lits();
    assert acts[..0] == [];
    KExec6Step(HK, acts, 0); KExec6Step(HK, acts, 1); KExec6Step(HK, acts, 2);
  }
  lemma KW4() ensures KExec6(HK, KActs()[..4]) == S2()["ch_1" := C1()]
  {
    KW3(); KExec6Step(HK, KActs(), 3);
    var t := TkK(A1, "rq_0", 0);
    assert KActs()[3] == KDel6("ch_1", t, true);
    assert R.AllowedReason(DC);
    assert AuthorizesH(A1, t);
    AuthorizesHIs(A1, t);
    Step6Exact(HK, Core(A1, {}, []), t, true);
    assert Step6(HK, Core(A1, {}, []), t, true).core == Core(A1, {} + {"rq_0"}, [] + [R.Intent("ch_1", "rq_0", 0, DC)]);
    assert {} + {"rq_0"} == {"rq_0"};
    assert ChargeOfState(t.post) == A1;
    assert Step6(HK, Core(A1, {}, []), t, true).core == C1();
    assert "ch_1" in S2() && S2()["ch_1"] == Core(A1, {}, []);
    assert KStep6(HK, S2(), KActs()[3]) == S2()["ch_1" := Step6(HK, S2()["ch_1"], t, true).core];
  }
  lemma KW5() ensures KExec6(HK, KActs()[..5]) == S2()["ch_1" := C1b()]
  {
    KW4(); Lits(); KExec6Step(HK, KActs(), 4);
    var t := TkK(A1, "rq_1", 40);
    assert KActs()[4] == KDel6("ch_1", t, true);
    assert R.AllowedReason(DC);
    assert AuthorizesH(A1, t);
    AuthorizesHIs(A1, t);
    Step6Exact(HK, C1(), t, true);
    assert {"rq_0"} + {"rq_1"} == {"rq_0", "rq_1"};
    assert ChargeOfState(t.post) == A1.(remaining := 20);
    assert Step6(HK, C1(), t, true).core == C1b();
    var m := S2()["ch_1" := C1()];
    assert "ch_1" in m && m["ch_1"] == C1();
    assert KStep6(HK, m, KActs()[4]) == m["ch_1" := Step6(HK, C1(), t, true).core];
    assert m["ch_1" := C1b()] == S2()["ch_1" := C1b()];
  }
  lemma KW6() ensures KExec6(HK, KActs()[..6]) == S2()["ch_1" := C1b()]["ch_2" := C2()]
  {
    KW5(); Lits(); KExec6Step(HK, KActs(), 5);
    var t := TkK(A2, "rq_1", 50);
    assert KActs()[5] == KDel6("ch_2", t, true);
    assert R.AllowedReason(DC);
    assert AuthorizesH(A2, t);
    AuthorizesHIs(A2, t);
    Step6Exact(HK, Core(A2, {}, []), t, true);
    assert {} + {"rq_1"} == {"rq_1"};
    assert ChargeOfState(t.post) == A2.(remaining := 0);
    assert Step6(HK, Core(A2, {}, []), t, true).core == C2();
    var m := S2()["ch_1" := C1b()];
    assert "ch_2" in m && m["ch_2"] == Core(A2, {}, []);
    assert KStep6(HK, m, KActs()[5]) == m["ch_2" := Step6(HK, Core(A2, {}, []), t, true).core];
  }
  lemma KW7() ensures KExec6(HK, KActs()) == S2()["ch_1" := C1b()]["ch_2" := C2()]
  {
    KW6(); Lits(); KExec6Step(HK, KActs(), 6);
    assert KActs()[..7] == KActs();
    assert !F.Authorizes(C2().charge, TransH(TkK(A2, "rq_2", 50)));
    UnauthorizedNeverCommits(HK, C2(), TkK(A2, "rq_2", 50), true);
  }

  // NON-VACUITY: three commits (zero and positive on ch_1; ch_2); the bad create (ch_3: remaining > original) is
  // refused; the unauthorized second delivery to ch_2 is rejected; KeyedL0V6 applies to both keys.
  lemma KWitness()
    ensures var st := KExec6(HK, KActs());
      st.Keys == {"ch_1", "ch_2"} &&
      st["ch_1"].outbox == [R.Intent("ch_1", "rq_0", 0, DC), R.Intent("ch_1", "rq_1", 40, DC)] &&
      st["ch_1"].charge == A1.(remaining := 20) &&
      st["ch_2"].outbox == [R.Intent("ch_2", "rq_1", 50, DC)] && st["ch_2"].charge == A2.(remaining := 0)
    ensures forall e | e in KExec6(HK, KActs())["ch_1"].outbox :: exists g :: EntryK6(HK, KActs(), "ch_1", g, e)
    ensures forall e | e in KExec6(HK, KActs())["ch_2"].outbox :: exists g :: EntryK6(HK, KActs(), "ch_2", g, e)
  {
    KW7(); Lits();
    KeyedL0V6(HK, KActs(), "ch_1");
    KeyedL0V6(HK, KActs(), "ch_2");
  }
}
