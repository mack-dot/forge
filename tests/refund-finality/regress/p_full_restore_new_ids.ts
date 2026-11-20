// FULL-RESTORE regression, the OVERPAY ROUTE (h-provider2): r1 400 committed and dispatched; SNAPSHOT of every local file;
// r2 400 and r3 100 committed and dispatched (900 really refunded); the COMPLETE snapshot is restored (stale remaining
// 600). A NEW request id r4 for the stale remaining (600) is signed on the stale pre-state and committed; two dispatcher
// runs. No key repeats: PROVIDER-IDEMPOTENT-KEY cannot help. Expected without an anchor: 1500 moved on a 1000 charge in
// modes a, c, d-a; the provider ceiling refuses r4 in b and d-b. Usage and exit codes: p_lib.ts.
import { argv, attackVerdict, guard, moneyCheck, setupFail, world } from "./p_lib";
guard(() => {
  const { root, mode, anchor } = argv();
  const S0 = { chargeId: "ch_fn", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, anchor, S0);
  const r1 = w.refund("r1", "400"); const f1 = w.flush();
  const snap = w.snapshotAll();
  const r2 = w.refund("r2", "400"); const r3 = w.refund("r3", "100"); const f2 = w.flush();
  const setup = r1.status === "committed" && r2.status === "committed" && r3.status === "committed" && f1.emitted.join() === "r1" && f2.emitted.join() === "r2,r3";
  if (!setup) setupFail({ r1, r2, r3, f1, f2 });
  const restored = w.restoreAll(); w.atAttack();
  const stale = w.state()?.remaining ?? "(no sink)";
  const r4 = stale === "(no sink)" ? { status: "no sink (start refused)" } : w.refund("r4", stale);
  const after = [w.flush(), w.flush()];
  const localRemaining = w.state()?.remaining ?? "(no sink)";
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  attackVerdict(mode, anchor, m.noDouble && m.withinCharge, w.events, { test: "p_full_restore_new_ids", snapshot: snap, restored, sinkAfterRestore: w.sinkRefusal() || "started",
    staleRemaining: stale, r4: r4.status, after, localRemainingAfter: localRemaining, money: m });
});
