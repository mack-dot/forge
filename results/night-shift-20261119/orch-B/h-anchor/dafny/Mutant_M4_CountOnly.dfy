// h-anchor (night shift 2026-11-19, Orchestrator B, phase 2): the row-log head and an external anchor.
// Self-contained model. No assume, no axiom, no bodiless lemma, no extern.
// Named hypotheses:
//   NC(H, U)        trace-local no-collision: H is injective on the finite set U of hash inputs that occur
//                   in the chains under discussion. NOT global injectivity.
//   ENC-INJ         the canonical encoding of a hash input is injective and separates the genesis input from
//                   a link input. MODELLED by the datatype Msg (distinct constructors, structural equality).
//   ANCHOR-MONOTONE the anchor's record (dispatcher head, done set; or witness log) is never rolled back.
//                   MODELLED by the dispatcher state being threaded through Run; the control
//                   RecordRollbackResends shows what happens without it.
module Anchor {
  datatype Config = Config(ids: int, issuerKey: int)            // pinned ids and issuer public key
  datatype Init = Init(chargeId: int, original: int, remaining: int)
  datatype Row = Row(rid: int, amount: int)                     // committed token text + outbox intent, abstracted
  datatype Store = Store(cfg: Config, init: Init, rows: seq<Row>)
  datatype Msg = Genesis(gcfg: Config, ginit: Init) | Link(prev: int, row: Row)
  datatype Head = Head(n: nat, h: int)

  // h_0 = H(Genesis(cfg, init)); h_{i+1} = H(Link(h_i, row_{i+1})).
  ghost function Chain(H: Msg -> int, cfg: Config, init: Init, rows: seq<Row>): int
    decreases |rows|, 1
  { H(Top(H, cfg, init, rows)) }
  ghost function Top(H: Msg -> int, cfg: Config, init: Init, rows: seq<Row>): Msg
    decreases |rows|, 0
  { if |rows| == 0 then Genesis(cfg, init) else Link(Chain(H, cfg, init, rows[..|rows|-1]), rows[|rows|-1]) }
  ghost function Inputs(H: Msg -> int, cfg: Config, init: Init, rows: seq<Row>): set<Msg>
    decreases |rows|
  { if |rows| == 0 then {Top(H, cfg, init, rows)} else Inputs(H, cfg, init, rows[..|rows|-1]) + {Top(H, cfg, init, rows)} }
  ghost function HeadOf(H: Msg -> int, s: Store): Head { Head(|s.rows|, Chain(H, s.cfg, s.init, s.rows)) }
  ghost function InputsOf(H: Msg -> int, s: Store): set<Msg> { Inputs(H, s.cfg, s.init, s.rows) }
  ghost predicate NC(H: Msg -> int, U: set<Msg>) { forall m1, m2 :: m1 in U && m2 in U && H(m1) == H(m2) ==> m1 == m2 }

  lemma TopIn(H: Msg -> int, cfg: Config, init: Init, rows: seq<Row>)
    ensures Top(H, cfg, init, rows) in Inputs(H, cfg, init, rows)
  {}
  lemma InputsPrefix(H: Msg -> int, cfg: Config, init: Init, rows: seq<Row>, k: nat)
    requires k <= |rows|
    ensures Inputs(H, cfg, init, rows[..k]) <= Inputs(H, cfg, init, rows)
    decreases |rows| - k
  {
    if k < |rows| {
      var p := rows[..|rows|-1];
      assert p[..k] == rows[..k];
      InputsPrefix(H, cfg, init, p, k);
    } else { assert rows[..k] == rows; }
  }

  // Core of T1: equal count and equal chain hash bind config, initial charge and every row, in order.
  lemma ChainBind(H: Msg -> int, c1: Config, i1: Init, r1: seq<Row>, c2: Config, i2: Init, r2: seq<Row>)
    requires |r1| == |r2|
    requires Chain(H, c1, i1, r1) == Chain(H, c2, i2, r2)
    requires NC(H, Inputs(H, c1, i1, r1) + Inputs(H, c2, i2, r2))
    ensures c1 == c2 && i1 == i2 && r1 == r2
    decreases |r1|
  {
    TopIn(H, c1, i1, r1); TopIn(H, c2, i2, r2);
    if |r1| > 0 {
      var p1, p2 := r1[..|r1|-1], r2[..|r2|-1];
      InputsPrefix(H, c1, i1, r1, |r1|-1); InputsPrefix(H, c2, i2, r2, |r2|-1);
      ChainBind(H, c1, i1, p1, c2, i2, p2);
      assert r1 == p1 + [r1[|r1|-1]] && r2 == p2 + [r2[|r2|-1]];
    }
  }
  // Under NC and ENC-INJ the count is redundant for binding (the genesis input never equals a link input).
  lemma ChainBindAnyLength(H: Msg -> int, c1: Config, i1: Init, r1: seq<Row>, c2: Config, i2: Init, r2: seq<Row>)
    requires Chain(H, c1, i1, r1) == Chain(H, c2, i2, r2)
    requires NC(H, Inputs(H, c1, i1, r1) + Inputs(H, c2, i2, r2))
    ensures |r1| == |r2| && c1 == c2 && i1 == i2 && r1 == r2
    decreases |r1|
  {
    TopIn(H, c1, i1, r1); TopIn(H, c2, i2, r2);
    if |r1| > 0 && |r2| > 0 {
      var p1, p2 := r1[..|r1|-1], r2[..|r2|-1];
      InputsPrefix(H, c1, i1, r1, |r1|-1); InputsPrefix(H, c2, i2, r2, |r2|-1);
      ChainBindAnyLength(H, c1, i1, p1, c2, i2, p2);
      assert r1 == p1 + [r1[|r1|-1]] && r2 == p2 + [r2[|r2|-1]];
    }
  }

  // T1 (binding).
  lemma T1_Binding(H: Msg -> int, s1: Store, s2: Store)
    requires HeadOf(H, s1) == HeadOf(H, s2)
    requires NC(H, InputsOf(H, s1) + InputsOf(H, s2))
    ensures s1 == s2
  { ChainBind(H, s1.cfg, s1.init, s1.rows, s2.cfg, s2.init, s2.rows); }

  // ---------- T2: the start check against the anchored head ----------
  // A store passes the start check against the published head L if its first L.n rows give L.h.
  // (Rows after L.n are the unpublished tail; they are not dispatchable until published.)
  ghost predicate Anchored(H: Msg -> int, L: Head, s: Store)
  { |s.rows| >= L.n }  // MUTANT M4: count-only anchor (monotone counter without the hash)

  lemma T2_StartDetects(H: Msg -> int, T: Store, s: Store)
    requires Anchored(H, HeadOf(H, T), s)
    requires NC(H, InputsOf(H, T) + Inputs(H, s.cfg, s.init, s.rows[..|T.rows|]))
    ensures s.cfg == T.cfg && s.init == T.init && s.rows[..|T.rows|] == T.rows
  { ChainBind(H, T.cfg, T.init, T.rows, s.cfg, s.init, s.rows[..|T.rows|]); }

  lemma T2_EqualHeadIsTrueHistory(H: Msg -> int, T: Store, s: Store)
    requires HeadOf(H, s) == HeadOf(H, T)
    requires NC(H, InputsOf(H, T) + InputsOf(H, s))
    ensures s == T
  { T1_Binding(H, s, T); }

  // Needs NO hash hypothesis: the count alone refuses a rollback to a proper prefix.
  lemma T2_RollbackToPrefixDetected(H: Msg -> int, T: Store, k: nat)
    requires k < |T.rows|
    ensures !Anchored(H, HeadOf(H, T), Store(T.cfg, T.init, T.rows[..k]))
  {}
  // Needs NO hash hypothesis: a deleted published row (zero amount or not) shortens the log.
  lemma T2_RowDeletionDetected(H: Msg -> int, T: Store, i: nat)
    requires i < |T.rows|
    ensures !Anchored(H, HeadOf(H, T), Store(T.cfg, T.init, T.rows[..i] + T.rows[i+1..]))
  {}
  // Reorder, swap, or any other change of the published rows (same count).
  lemma T2_ReorderDetected(H: Msg -> int, T: Store, s: Store)
    requires |s.rows| == |T.rows| && s.rows != T.rows
    requires NC(H, InputsOf(H, T) + InputsOf(H, s))
    ensures !Anchored(H, HeadOf(H, T), s)
  {
    if Anchored(H, HeadOf(H, T), s) { assert s.rows[..|T.rows|] == s.rows; T2_StartDetects(H, T, s); }
  }
  // Forged initial charge (the initial charge is inside h_0).
  lemma T2_ForgedInitDetected(H: Msg -> int, T: Store, s: Store)
    requires |s.rows| >= |T.rows| && s.init != T.init
    requires NC(H, InputsOf(H, T) + Inputs(H, s.cfg, s.init, s.rows[..|T.rows|]))
    ensures !Anchored(H, HeadOf(H, T), s)
  { if Anchored(H, HeadOf(H, T), s) { T2_StartDetects(H, T, s); } }

  // ---------- T3: the anchored dispatcher ----------
  // n, h, done are its durable record (ANCHOR-MONOTONE). sent is a model-only log of effects.
  datatype Disp = Disp(n: nat, h: int, done: set<int>, sent: seq<Row>)
  ghost function D0(H: Msg -> int, cfg0: Config, init0: Init): Disp { Disp(0, Chain(H, cfg0, init0, []), {}, []) }
  ghost predicate DAccepts(H: Msg -> int, d: Disp, s: Store)
  { |s.rows| > d.n && Chain(H, s.cfg, s.init, s.rows[..d.n]) == d.h && s.rows[d.n].rid !in d.done }
  ghost function DStep(H: Msg -> int, d: Disp, s: Store): Disp
  {
    if DAccepts(H, d, s)
    then Disp(d.n + 1, Chain(H, s.cfg, s.init, s.rows[..d.n+1]), d.done + {s.rows[d.n].rid}, d.sent + [s.rows[d.n]])
    else d
  }
  ghost function Run(H: Msg -> int, d: Disp, ps: seq<Store>): Disp
    decreases |ps|
  { if |ps| == 0 then d else Run(H, DStep(H, d, ps[0]), ps[1..]) }
  ghost function AllInputs(H: Msg -> int, ps: seq<Store>): set<Msg>
    decreases |ps|
  { if |ps| == 0 then {} else InputsOf(H, ps[0]) + AllInputs(H, ps[1..]) }
  ghost function Rids(rows: seq<Row>): set<int> { set i | 0 <= i < |rows| :: rows[i].rid }
  ghost predicate DistinctRids(rows: seq<Row>) { forall i, j :: 0 <= i < j < |rows| ==> rows[i].rid != rows[j].rid }
  ghost predicate DCore(H: Msg -> int, cfg0: Config, init0: Init, d: Disp)
  { d.n == |d.sent| && d.h == Chain(H, cfg0, init0, d.sent) && d.done == Rids(d.sent) && DistinctRids(d.sent) }
  ghost predicate DInv(H: Msg -> int, cfg0: Config, init0: Init, d: Disp, U: set<Msg>)
  { DCore(H, cfg0, init0, d) && Inputs(H, cfg0, init0, d.sent) <= U }

  lemma RidsSnoc(rows: seq<Row>, r: Row)
    ensures Rids(rows + [r]) == Rids(rows) + {r.rid}
  {
    var a := rows + [r];
    forall x | x in Rids(a) ensures x in Rids(rows) + {r.rid} {
      var i :| 0 <= i < |a| && a[i].rid == x;
      if i < |rows| { assert rows[i] == a[i]; }
    }
    forall x | x in Rids(rows) ensures x in Rids(a) { var i :| 0 <= i < |rows| && rows[i].rid == x; assert a[i] == rows[i]; }
    assert a[|rows|] == r;
  }

  lemma DStepInv(H: Msg -> int, cfg0: Config, init0: Init, d: Disp, s: Store, U: set<Msg>)
    requires DInv(H, cfg0, init0, d, U) && InputsOf(H, s) <= U && NC(H, U)
    ensures DInv(H, cfg0, init0, DStep(H, d, s), U)
    ensures d.sent <= DStep(H, d, s).sent
    ensures DAccepts(H, d, s) ==> s.cfg == cfg0 && s.init == init0 && s.rows[..d.n] == d.sent
  {
    if DAccepts(H, d, s) {
      InputsPrefix(H, s.cfg, s.init, s.rows, d.n);
      ChainBind(H, cfg0, init0, d.sent, s.cfg, s.init, s.rows[..d.n]);
      var r := s.rows[d.n];
      assert s.rows[..d.n+1] == d.sent + [r];
      InputsPrefix(H, s.cfg, s.init, s.rows, d.n + 1);
      RidsSnoc(d.sent, r);
    }
  }

  lemma RunInv(H: Msg -> int, cfg0: Config, init0: Init, d: Disp, ps: seq<Store>, U: set<Msg>)
    requires DInv(H, cfg0, init0, d, U) && AllInputs(H, ps) <= U && NC(H, U)
    ensures DInv(H, cfg0, init0, Run(H, d, ps), U)
    ensures d.sent <= Run(H, d, ps).sent
    decreases |ps|
  {
    if |ps| > 0 {
      DStepInv(H, cfg0, init0, d, ps[0], U);
      RunInv(H, cfg0, init0, DStep(H, d, ps[0]), ps[1..], U);
    }
  }

  // T3: over ANY sequence of presented sink stores (honest, rolled back, re-extended, forged), the
  // dispatched effects form one chain from h_0 = H(Genesis(cfg0, init0)), each request id at most once,
  // and the record only grows. Hypotheses: NC on the inputs that occur in the trace; ANCHOR-MONOTONE (the
  // record d is threaded, never reset).
  lemma T3_DispatchTrace(H: Msg -> int, cfg0: Config, init0: Init, ps: seq<Store>)
    requires NC(H, Inputs(H, cfg0, init0, []) + AllInputs(H, ps))
    ensures DCore(H, cfg0, init0, Run(H, D0(H, cfg0, init0), ps))
  {
    var U := Inputs(H, cfg0, init0, []) + AllInputs(H, ps);
    assert Rids([]) == {};
    RunInv(H, cfg0, init0, D0(H, cfg0, init0), ps, U);
  }

  // ---------- T4: freshness ----------
  // A sink that restarted from a stale snapshot and committed rows that differ from the dispatched
  // history (or uses another config or initial charge) is refused.
  lemma T4_StaleRefused(H: Msg -> int, cfg0: Config, init0: Init, d: Disp, s: Store, U: set<Msg>)
    requires DInv(H, cfg0, init0, d, U) && InputsOf(H, s) <= U && NC(H, U)
    requires |s.rows| > d.n
    requires s.rows[..d.n] != d.sent || s.cfg != cfg0 || s.init != init0
    ensures !DAccepts(H, d, s)
  { DStepInv(H, cfg0, init0, d, s, U); }
  // A stale sink that only re-commits dropped (already dispatched) rows causes no effect at all.
  lemma T4_StaleReplayNoEffect(H: Msg -> int, d: Disp, s: Store)
    requires |s.rows| <= d.n
    ensures DStep(H, d, s) == d
  {}
  // Completeness: an honest extension is accepted (no hash hypothesis needed).
  ghost predicate HonestExt(cfg0: Config, init0: Init, d: Disp, s: Store)
  { s.cfg == cfg0 && s.init == init0 && |s.rows| > d.n && s.rows[..d.n] == d.sent && DistinctRids(s.rows) }
  lemma T4_HonestAccepted(H: Msg -> int, cfg0: Config, init0: Init, d: Disp, s: Store)
    requires DCore(H, cfg0, init0, d) && HonestExt(cfg0, init0, d, s)
    ensures DAccepts(H, d, s)
    ensures DCore(H, cfg0, init0, DStep(H, d, s)) && DStep(H, d, s).sent == s.rows[..d.n+1]
  {
    var r := s.rows[d.n];
    if r.rid in d.done { var i :| 0 <= i < |d.sent| && d.sent[i].rid == r.rid; assert s.rows[i] == d.sent[i]; assert false; }
    assert s.rows[..d.n+1] == d.sent + [r];
    RidsSnoc(d.sent, r);
  }
  ghost function Repeat(s: Store, k: nat): seq<Store> { seq(k, _ => s) }
  lemma T4_HonestDrain(H: Msg -> int, cfg0: Config, init0: Init, d: Disp, s: Store)
    requires DCore(H, cfg0, init0, d) && s.cfg == cfg0 && s.init == init0
    requires d.n <= |s.rows| && s.rows[..d.n] == d.sent && DistinctRids(s.rows)
    ensures DCore(H, cfg0, init0, Run(H, d, Repeat(s, |s.rows| - d.n)))
    ensures Run(H, d, Repeat(s, |s.rows| - d.n)).sent == s.rows
    decreases |s.rows| - d.n
  {
    var ps := Repeat(s, |s.rows| - d.n);
    if d.n == |s.rows| { assert s.rows[..d.n] == s.rows; }
    else {
      T4_HonestAccepted(H, cfg0, init0, d, s);
      var d1 := DStep(H, d, s);
      assert ps[1..] == Repeat(s, |s.rows| - d1.n);
      T4_HonestDrain(H, cfg0, init0, d1, s);
    }
  }

  // ---------- Controls ----------
  // C1 (no external anchor: the record lives in the rolled-back database and is reset with it):
  // the same row is accepted again from the reset record. A second effect for the same request id.
  lemma C1_RecordRollbackResends(H: Msg -> int, cfg0: Config, init0: Init, r: Row)
    ensures var s := Store(cfg0, init0, [r]);
            var d1 := DStep(H, D0(H, cfg0, init0), s);
            DAccepts(H, D0(H, cfg0, init0), s) && d1.sent == [r] &&
            DStep(H, D0(H, cfg0, init0), s).sent + DStep(H, D0(H, cfg0, init0), s).sent == [r, r]
  { var s := Store(cfg0, init0, [r]); assert s.rows[..0] == []; }

  // Count-only anchor (a monotone counter without the hash): it accepts a fork that out-runs the count.
  ghost predicate CountOnlyAccepts(L: Head, s: Store) { |s.rows| > L.n }

  // A concrete hash for the witnesses. It has collisions in general; NC is shown only on the trace.
  function H0(m: Msg): int {
    match m
    case Genesis(c, i) => 2 * (c.ids + 10 * c.issuerKey + 1000 * i.chargeId + 7 * i.original + 13 * i.remaining)
    case Link(p, r) => 2 * (3 * p + 101 * r.rid + 7 * r.amount) + 1
  }
  const cfg0 := Config(7, 42)
  const init0 := Init(1, 100, 100)
  const r1 := Row(1, 10)
  const r2 := Row(2, 0)     // zero-amount refund
  const r3 := Row(3, 0)     // zero-amount refund
  const r4 := Row(4, 10)    // a different token minted from a rolled-back pre-state
  const r5 := Row(5, 5)
  const S := Store(cfg0, init0, [r1, r2, r3])

  lemma Snoc(H: Msg -> int, cfg: Config, init: Init, rows: seq<Row>, r: Row)
    ensures Chain(H, cfg, init, rows + [r]) == H(Link(Chain(H, cfg, init, rows), r))
    ensures Inputs(H, cfg, init, rows + [r]) == Inputs(H, cfg, init, rows) + {Link(Chain(H, cfg, init, rows), r)}
  { assert (rows + [r])[..|rows|] == rows; }

  lemma Expand3(i: Init, a: Row, b: Row, c: Row)
    ensures Chain(H0, cfg0, i, []) == H0(Genesis(cfg0, i))
    ensures Chain(H0, cfg0, i, [a]) == H0(Link(H0(Genesis(cfg0, i)), a))
    ensures Chain(H0, cfg0, i, [a, b]) == H0(Link(Chain(H0, cfg0, i, [a]), b))
    ensures Chain(H0, cfg0, i, [a, b, c]) == H0(Link(Chain(H0, cfg0, i, [a, b]), c))
    ensures Inputs(H0, cfg0, i, [a, b, c]) == {Genesis(cfg0, i), Link(H0(Genesis(cfg0, i)), a),
              Link(Chain(H0, cfg0, i, [a]), b), Link(Chain(H0, cfg0, i, [a, b]), c)}
  {
    Snoc(H0, cfg0, i, [], a); assert [] + [a] == [a];
    Snoc(H0, cfg0, i, [a], b); assert [a] + [b] == [a, b];
    Snoc(H0, cfg0, i, [a, b], c); assert [a, b] + [c] == [a, b, c];
  }

  lemma ChainS()
    ensures Chain(H0, cfg0, init0, []) == 6854
    ensures Chain(H0, cfg0, init0, [r1]) == 41467
    ensures Chain(H0, cfg0, init0, [r1, r2]) == 249207
    ensures Chain(H0, cfg0, init0, [r1, r2, r3]) == 1495849
    ensures InputsOf(H0, S) == {Genesis(cfg0, init0), Link(6854, r1), Link(41467, r2), Link(249207, r3)}
  { Expand3(init0, r1, r2, r3); }

  // Non-vacuity: NC holds on the honest trace; the history (with two zero-amount rows) is published,
  // passes the start check, and is dispatched completely (three effects, two of them zero).
  lemma W_NonVacuity()
    ensures NC(H0, InputsOf(H0, S))
    ensures NC(H0, Inputs(H0, cfg0, init0, []) + AllInputs(H0, Repeat(S, 3)))
    ensures Anchored(H0, HeadOf(H0, S), S)
    ensures Run(H0, D0(H0, cfg0, init0), Repeat(S, 3)).sent == [r1, r2, r3]
    ensures DCore(H0, cfg0, init0, Run(H0, D0(H0, cfg0, init0), Repeat(S, 3)))
  {
    ChainS();
    assert S.rows[..3] == S.rows;
    var ps := Repeat(S, 3);
    AllInputsRepeat(H0, S, 3);
    var d0 := D0(H0, cfg0, init0);
    assert Rids([]) == {};
    assert S.rows[..0] == [];
    T4_HonestDrain(H0, cfg0, init0, d0, S);
  }

  lemma AllInputsRepeat(H: Msg -> int, s: Store, k: nat)
    requires k > 0
    ensures AllInputs(H, Repeat(s, k)) == InputsOf(H, s)
  {
    var ps := Repeat(s, k);
    if k > 1 { assert ps[1..] == Repeat(s, k - 1); AllInputsRepeat(H, s, k - 1); }
    else { assert ps[1..] == []; }
  }
  ghost function D3(): Disp { Run(H0, D0(H0, cfg0, init0), Repeat(S, 3)) }
  lemma D3Facts()
    ensures D3().n == 3 && D3().h == 1495849 && D3().sent == [r1, r2, r3]
  { W_NonVacuity(); ChainS(); }

  // The four attacks against the published head (start check) and against the dispatcher after the
  // three effects (D3). Each attack store has a fourth row so that it has a row to dispatch.
  // Rollback to a prefix, then re-commit of the dropped tokens: same store as S, no new effect.
  lemma W_Attack_RollbackRecommit()
    ensures !Anchored(H0, HeadOf(H0, S), Store(cfg0, init0, [r1]))
    ensures DStep(H0, D3(), Store(cfg0, init0, [r1, r2, r3])) == D3()
  { D3Facts(); }
  // Rollback to a prefix, then a different token r4 from the rolled-back pre-state.
  lemma W_Attack_RollbackDiverge()
    ensures !DAccepts(H0, D3(), Store(cfg0, init0, [r1, r4, r5, Row(6, 0)]))
  { D3Facts(); ChainS(); Expand3(init0, r1, r4, r5); assert [r1, r4, r5, Row(6, 0)][..3] == [r1, r4, r5]; }
  // Middle zero-amount row deleted.
  lemma W_Attack_ZeroDeletion()
    ensures !Anchored(H0, HeadOf(H0, S), Store(cfg0, init0, [r1, r3]))
    ensures !DAccepts(H0, D3(), Store(cfg0, init0, [r1, r3, r5, Row(6, 0)]))
  { D3Facts(); ChainS(); Expand3(init0, r1, r3, r5); assert [r1, r3, r5, Row(6, 0)][..3] == [r1, r3, r5]; }
  // Swapped zero-amount rows.
  lemma W_Attack_ZeroSwap()
    ensures !Anchored(H0, HeadOf(H0, S), Store(cfg0, init0, [r1, r3, r2]))
    ensures !DAccepts(H0, D3(), Store(cfg0, init0, [r1, r3, r2, r5]))
  {
    D3Facts(); ChainS(); Expand3(init0, r1, r3, r2);
    assert [r1, r3, r2, r5][..3] == [r1, r3, r2]; assert [r1, r3, r2][..3] == [r1, r3, r2];
  }
  // Forged initial charge (remaining 1000 instead of 100), same rows.
  lemma W_Attack_ForgedInit()
    ensures !Anchored(H0, HeadOf(H0, S), Store(cfg0, Init(1, 100, 1000), [r1, r2, r3]))
    ensures !DAccepts(H0, D3(), Store(cfg0, Init(1, 100, 1000), [r1, r2, r3, r5]))
  {
    D3Facts(); ChainS(); Expand3(Init(1, 100, 1000), r1, r2, r3);
    assert [r1, r2, r3, r5][..3] == [r1, r2, r3]; assert [r1, r2, r3][..3] == [r1, r2, r3];
  }

  // The general theorem applies to the swap attack: NC holds on its trace, so T2_ReorderDetected refuses it.
  lemma W_SwapByTheorem()
    ensures NC(H0, InputsOf(H0, S) + InputsOf(H0, Store(cfg0, init0, [r1, r3, r2])))
    ensures !Anchored(H0, HeadOf(H0, S), Store(cfg0, init0, [r1, r3, r2]))
  {
    ChainS();
    var sw := Store(cfg0, init0, [r1, r3, r2]);
    Expand3(init0, r1, r3, r2);
    assert InputsOf(H0, S) + InputsOf(H0, sw) ==
      {Genesis(cfg0, init0), Link(6854, r1), Link(41467, r2), Link(249207, r3), Link(41467, r3), Link(249409, r2)};
    T2_ReorderDetected(H0, S, sw);
  }

  // C2 (dispatcher check dropped): the reviewer's rollback (sink rewound to the empty prefix, then a
  // different token r4 from the same pre-state, then r5) gets r5 dispatched after r1, and the record is
  // no longer one chain from h_0 (DCore fails). The anchored dispatcher refuses the same store.
  ghost predicate DAcceptsNoCheck(d: Disp, s: Store) { |s.rows| > d.n && s.rows[d.n].rid !in d.done }
  ghost function DStepNoCheck(H: Msg -> int, d: Disp, s: Store): Disp
  {
    if DAcceptsNoCheck(d, s)
    then Disp(d.n + 1, Chain(H, s.cfg, s.init, s.rows[..d.n+1]), d.done + {s.rows[d.n].rid}, d.sent + [s.rows[d.n]])
    else d
  }
  lemma C2_NoCheckForks()
    ensures var d1 := DStep(H0, D0(H0, cfg0, init0), Store(cfg0, init0, [r1]));
            var fork := Store(cfg0, init0, [r4, r5]);
            d1.sent == [r1] && DAcceptsNoCheck(d1, fork) &&
            DStepNoCheck(H0, d1, fork).sent == [r1, r5] &&
            !DCore(H0, cfg0, init0, DStepNoCheck(H0, d1, fork)) &&
            !DAccepts(H0, d1, fork)
  {
    ChainS();
    Expand3(init0, r4, r5, r5); Expand3(init0, r1, r5, r5);
    assert [r1][..0] == [] && [r1][..1] == [r1];
    assert [r4, r5][..1] == [r4] && [r4, r5][..2] == [r4, r5];
  }

  // Count-only anchor control: a rolled-back store that out-runs the count passes the counter and fails
  // the real anchor check.
  lemma C3_CountOnlyAcceptsFork()
    ensures var fork := Store(cfg0, init0, [r1, r4, r5, Row(6, 0)]);
            CountOnlyAccepts(HeadOf(H0, S), fork) && !Anchored(H0, HeadOf(H0, S), fork)
  {
    ChainS();
    Expand3(init0, r1, r4, r5);
    assert [r1, r4, r5, Row(6, 0)][..3] == [r1, r4, r5];
  }
}
