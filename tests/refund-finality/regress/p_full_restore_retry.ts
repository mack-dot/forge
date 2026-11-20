// FULL-RESTORE regression (C-ATT-19 "full restore", h-provider2): r1 400 committed and dispatched; SNAPSHOT of every local
// file; r2 400 and r3 100 committed and dispatched; the COMPLETE snapshot is restored (store, ledger, witness, adapter
// journal all at "after r1"); the host retries r2 and r3 with the SAME tokens; three dispatcher runs. Expected without an
// anchor: the restored sink commits r2 and r3 again and the dispatcher emits them again. Usage and exit codes: p_lib.ts.
import { argv, attackVerdict, guard, moneyCheck, setupFail, world } from "./p_lib";
guard(() => {
  const { root, mode, anchor } = argv();
  const S0 = { chargeId: "ch_fr", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, anchor, S0);
  const r1 = w.refund("r1", "400"); const f1 = w.flush();
  const snap = w.snapshotAll();
  const r2 = w.refund("r2", "400"); const r3 = w.refund("r3", "100"); const f2 = w.flush();
  const setup = r1.status === "committed" && r2.status === "committed" && r3.status === "committed" && f1.emitted.join() === "r1" && f2.emitted.join() === "r2,r3";
  if (!setup) setupFail({ r1, r2, r3, f1, f2 });
  const restored = w.restoreAll(); w.atAttack();
  const retry = [w.commitText(r2.text), w.commitText(r3.text)];
  const after = [w.flush(), w.flush(), w.flush()];
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  attackVerdict(mode, anchor, m.noDouble && m.withinCharge, w.events, { test: "p_full_restore_retry", snapshot: snap, restored, sinkAfterRestore: w.sinkRefusal() || "started", retry, after, money: m });
});
