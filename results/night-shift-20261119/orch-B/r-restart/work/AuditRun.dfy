// r-restart: compile RestartV3.AuditFull / AuditFullSpec to JavaScript and run them on concrete ledgers.
include "Restart.dfy"

module AuditRun {
  import opened SinkCoreV3
  import opened RestartV3

  method {:print} Main()
  {
    var wpre := F.Charge("ch_1", 100, 60, true);
    var wpost := F.Charge("ch_1", 100, 20, true);
    var i0 := R.Intent("ch_1", "rq_0", 0, "duplicate_charge");
    var i1 := R.Intent("ch_1", "rq_1", 40, "duplicate_charge");
    var t0 := SinkToken(PINNED_SPEC, PINNED_CHK, wpre, "rq_0", wpre, i0, "sig_rq_0");
    var t1 := SinkToken(PINNED_SPEC, PINNED_CHK, wpre, "rq_1", wpost, i1, "sig_rq_1");
    var honest := Core(wpost, {"rq_0", "rq_1"}, [i0, i1]);
    var L := [Delivery(t0, true), Delivery(t1, true)];
    print "honest AuditFull=", AuditFull(wpre, honest, L), " AuditFullSpec=", AuditFullSpec(wpre, honest, L), "\n";
    // the reviewer's bad core with the forged row
    var c100 := F.Charge("ch_1", 100, 100, true);
    print "bad AuditFull=", AuditFull(c100, BadCore(), [Delivery(ForgedRow(), true)]),
          " AuditFullSpec=", AuditFullSpec(c100, BadCore(), [Delivery(ForgedRow(), true)]), "\n";
    // forged init
    var fi := F.Charge("ch_1", 1000, 1000, true);
    var ft := SinkToken(PINNED_SPEC, PINNED_CHK, fi, "rq_f", fi.(remaining := 500), R.Intent("ch_1", "rq_f", 500, "duplicate_charge"), "forged");
    var fc := Core(fi.(remaining := 500), {"rq_f"}, [ft.intent]);
    print "forged-init AuditFullSpec=", AuditFullSpec(fi, fc, [Delivery(ft, true)]),
          " true-init AuditFullSpec=", AuditFullSpec(c100, fc, [Delivery(ft, true)]), "\n";
    // rollback: honest prefix
    print "rollback AuditFullSpec=", AuditFullSpec(wpre, Core(wpre, {"rq_0"}, [i0]), [Delivery(t0, true)]), "\n";
    // reordered rows of the honest ledger
    print "reordered AuditFull=", AuditFull(wpre, honest, [Delivery(t1, true), Delivery(t0, true)]), "\n";
    // zero-amount only
    print "zero AuditFullSpec=", AuditFullSpec(wpre, Core(wpre, {"rq_0"}, [i0]), [Delivery(t0, true)]), "\n";
  }
}
