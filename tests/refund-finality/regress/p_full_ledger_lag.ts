// FULL-RESTORE regression (C-ATT-19 "full restore", h-provider2): the backup is taken while the ledger LAGS the database:
// r1 400 committed and dispatched; r2 400 and r3 100 committed but not yet dispatched; SNAPSHOT of every local file (sink
// store, ledger, dispatch witness, adapter journal; list in p_lib.ts). Then the honest run dispatches r2 and r3. Then the
// COMPLETE snapshot is restored (one consistent older state: the store holds r1..r3, the ledger and the witness claim r1
// only) and the dispatcher runs three times. Expected without an anchor: r2 and r3 are emitted again. The outside head
// does NOT see this (the store head is still the committed head); the ledger floor does. Usage and exit codes: p_lib.ts.
import { argv, attackVerdict, guard, moneyCheck, setupFail, world } from "./p_lib";
guard(() => {
  const { root, mode, anchor } = argv();
  const S0 = { chargeId: "ch_fl", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, anchor, S0);
  const r1 = w.refund("r1", "400"); const f1 = w.flush();
  const r2 = w.refund("r2", "400"); const r3 = w.refund("r3", "100");
  const snap = w.snapshotAll();
  const f2 = w.flush();
  const setup = r1.status === "committed" && r2.status === "committed" && r3.status === "committed" && f1.emitted.join() === "r1" && f2.emitted.join() === "r2,r3";
  if (!setup) setupFail({ r1, r2, r3, f1, f2 });
  const restored = w.restoreAll(); w.atAttack();
  const after = [w.flush(), w.flush(), w.flush()];
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  attackVerdict(mode, anchor, m.noDouble && m.withinCharge, w.events, { test: "p_full_ledger_lag", snapshot: snap, restored, sinkAfterRestore: w.sinkRefusal() || "started", after, money: m });
});
