// r-v5 (night shift 2026-11-19, Orchestrator B). ADVERSARIAL review of ShellCoreV5.AuditV5. A TEST of the model.
// Finding Z: AuditV5 pins the CHARGE chain only. A zero-amount row does not change the charge, so its PRESENCE and
// its ORDER among rows with the same pre-state are not pinned. A database writer WITHOUT the signing key can delete a
// zero-amount row (settled + outbox) from the MIDDLE of the log, or swap two zero-amount rows. The result is NOT a
// prefix of any honest history (so it is outside the stated whole-database rollback limit), and it passes AuditV5
// with A-DB2. The deleted request id is then free: the same signed token commits AGAIN through StepQ, and the
// store after that commit also passes AuditV5. The zero-amount intent is emitted twice over the life of the store.
// No assume, no axiom, no bodiless lemma, no {:verify false}, no expect, no extern.
include "ShellCoreV5.dfy"

module AttackV5 {
  import opened ShellCoreV5
  import V4 = ShellCoreV4
  import V3 = ShellCoreV3
  import C = SinkCoreV3
  import F = RefundFinality
  import R = Refund

  function T1(): V3.ShellToken { Tk("rq_1", Ch(1000), 100) }
  function Z1(): V3.ShellToken { Tk("rq_z1", Ch(900), 0) }
  function Z2(): V3.ShellToken { Tk("rq_z2", Ch(900), 0) }
  function RT(t: V3.ShellToken): Row { RowT(t, true, true) }

  // The honest history H = [rq_1 (100), rq_z1 (0), rq_z2 (0)] and the hostile store D = [rq_1, rq_z2].
  function H(): seq<Row> { [RT(T1()), RT(Z1()), RT(Z2())] }
  function D(): seq<Row> { [RT(T1()), RT(Z2())] }

  lemma Fold3(initId: string, st: AState, a: Row, b: Row, c: Row)
    ensures Fold(initId, st, [a, b, c]) == AuditStep(initId, AuditStep(initId, AuditStep(initId, st, a), b), c)
  {
    assert [a, b, c] == [a, b] + [c];
    FoldSnoc(initId, st, [a, b], c);
    Fold2(initId, st, a, b);
  }

  lemma HonestHPasses()
    ensures AuditV5(Ch(1000), Ch(900), H(), 3, 3, 3)
  {
    Fold3("ch_1", AInit(Ch(1000)), RT(T1()), RT(Z1()), RT(Z2()));
  }

  // (1) The middle deletion passes the audit, and A-DB2 holds (2 distinct ids).
  lemma MiddleZeroDeletionPasses()
    ensures AuditV5(Ch(1000), Ch(900), D(), 2, 2, 2)
    ensures |IdSet(D())| == 2
    ensures StoredCore(Ch(900), D()) == Replay(Ch(1000), D())
  {
    var d := D();
    Fold2("ch_1", AInit(Ch(1000)), d[0], d[1]);
    assert d[..1] == [d[0]];
    assert [d[0]][..0] == [];
    assert IdSet([d[0]]) == {"rq_1"};
    assert "rq_1"[3] != "rq_z2"[3];
    assert IdSet(d) == IdSet(d[..1]) + {"rq_z2"};
    AuditV5SoundRelativeToSuppliedInitial(Ch(1000), Ch(900), d, 2, 2, 2);
  }

  // (2) D is not a prefix of H: the stated rollback limit (a prefix) does not cover it.
  lemma DNotAPrefixOfH()
    ensures forall k | 0 <= k <= |H()| :: D() != H()[..k]
  {
    assert H()[..2][1] == RT(Z1());
    assert Z1().requestId != Z2().requestId by { assert "rq_z1"[4] != "rq_z2"[4]; }
  }

  // (3) The deleted token commits AGAIN through the proved step (it is not settled in D; its pre-state is the
  // stored charge), and the store after that commit also passes AuditV5. Over the life of the store, the intent of
  // rq_z1 is emitted twice (once in H's outbox, once more after the re-commit).
  lemma DeletedZeroRecommits()
    ensures "rq_z1" !in IdSet(D())
    ensures V4.StepQ(Ch(900), Z1(), true, true, "rq_z1" in IdSet(D())) == V4.Commit(Ch(900), "rq_z1", Z1().intent)
    ensures AuditV5(Ch(1000), Ch(900), D() + [RT(Z1())], 3, 3, 3)
    ensures Z1().intent in Intents(H()) && Z1().intent in Intents(D() + [RT(Z1())])
  {
    MiddleZeroDeletionPasses();
    var d := D();
    assert d[..1] == [d[0]];
    assert [d[0]][..0] == [];
    assert IdSet(d) == {"rq_1", "rq_z2"};
    assert "rq_z1"[4] != "rq_z2"[4];
    assert "rq_z1"[3] != "rq_1"[3];
    assert D() + [RT(Z1())] == [RT(T1()), RT(Z2()), RT(Z1())];
    Fold3("ch_1", AInit(Ch(1000)), RT(T1()), RT(Z2()), RT(Z1()));
    var h := H();
    assert Intents(h) == Intents(h[..2]) + [h[2].outIntent];
    assert h[..2][..1] == [h[0]];
    assert [h[0]][..0] == [];
    assert Intents(h[..2]) == Intents(h[..2][..1]) + [h[1].outIntent];
    var e := D() + [RT(Z1())];
    assert Intents(e) == Intents(e[..2]) + [e[2].outIntent];
  }

  // (4) The order of two zero-amount rows with the same pre-state is not pinned: the swapped store also passes.
  lemma SwappedZeroRowsPass()
    ensures AuditV5(Ch(1000), Ch(900), [RT(T1()), RT(Z2()), RT(Z1())], 3, 3, 3)
  {
    Fold3("ch_1", AInit(Ch(1000)), RT(T1()), RT(Z2()), RT(Z1()));
  }

  // (5) A zero-amount row BEFORE a non-zero row can also be deleted: [z0 (0 from 1000), rq_1 (100 from 1000)]
  // becomes [rq_1]; it passes and is not a prefix. The authorization record of z0 disappears (its outbox row too).
  lemma LeadingZeroDeletionPasses()
    ensures AuditV5(Ch(1000), Ch(900), [RT(T1())], 1, 1, 1)
    ensures AuditV5(Ch(1000), Ch(900), [RT(Tk("rq_z0", Ch(1000), 0)), RT(T1())], 2, 2, 2)
    ensures [RT(Tk("rq_z0", Ch(1000), 0)), RT(T1())][..1] != [RT(T1())]
  {
    var a := RT(T1());
    var z := RT(Tk("rq_z0", Ch(1000), 0));
    assert [a] == [] + [a];
    FoldSnoc("ch_1", AInit(Ch(1000)), [], a);
    var s1 := AuditStep("ch_1", AInit(Ch(1000)), a);
    assert s1.cur == Ch(900) && s1.ok;
    Fold2("ch_1", AInit(Ch(1000)), z, a);
    var s0 := AuditStep("ch_1", AInit(Ch(1000)), z);
    assert s0.cur == Ch(1000) && s0.ok;
    assert z.tok.requestId != a.tok.requestId by { assert "rq_z0"[3] != "rq_1"[3]; }
    assert [z, a][..1] == [z];
  }

  // Control: a NON-zero row cannot be deleted from the middle: [rq_1 (100), rq_2 (100 from 900)] minus rq_1 is
  // refused for every stored charge that the audit could compare against (the remaining chain breaks).
  lemma NonZeroDeletionRefused(stored: F.Charge, s: bool, p: bool, n1: int, n2: int, n3: int)
    ensures !AuditV5(Ch(1000), stored, [RowT(Tk("rq_2", Ch(900), 100), s, p)], n1, n2, n3)
  {
    assert [RowT(Tk("rq_2", Ch(900), 100), s, p)] == [] + [RowT(Tk("rq_2", Ch(900), 100), s, p)];
    FoldSnoc("ch_1", AInit(Ch(1000)), [], RowT(Tk("rq_2", Ch(900), 100), s, p));
  }
}
