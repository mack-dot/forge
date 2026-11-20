// Provider-anchor regression, the OVERPAY ROUTE of a PARTIAL database restore: the operator restores the database and the
// ledger (NOT the dispatch witness) from a backup taken after r1 (remaining 600 in the restored store; 900 was really
// refunded: r1 400, r2 400, r3 100). A new request r4 (a NEW request id) is signed on the STALE pre-state (r4 600 = the
// stale remaining). No key repeats, so PROVIDER-IDEMPOTENT-KEY cannot help. At 370ff65c the dispatch witness stops the
// dispatcher first ("CONTROL DOES NOT BITE" for mode c, anchor none); the full-restore form is p_full_restore_new_ids.ts.
// Usage and exit codes: p_lib.ts.
import { argv, attackVerdict, guard, moneyCheck, setupFail, world } from "./p_lib";
guard(() => {
  const { root, mode, anchor } = argv();
  const S0 = { chargeId: "ch_pn", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, anchor, S0);
  const r1 = w.refund("r1", "400"); const f1 = w.flush();
  w.backup();
  const r2 = w.refund("r2", "400"); const r3 = w.refund("r3", "100"); const f2 = w.flush();
  const setup = r1.status === "committed" && r2.status === "committed" && r3.status === "committed" && f1.error === "" && f2.emitted.length === 2;
  if (!setup) setupFail({ r1, r2, r3, f1, f2 });
  w.restore("both"); w.atAttack();
  const stale = w.state()?.remaining ?? "(no sink)";
  const r4 = stale === "(no sink)" ? { status: "no sink (start refused)" } : w.refund("r4", stale);
  const after = [w.flush(), w.flush()];
  const localRemaining = w.state()?.remaining ?? "(no sink)";
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  attackVerdict(mode, anchor, m.noDouble && m.withinCharge, w.events, { test: "p_db_restore_new_ids", staleRemaining: stale, r4: r4.status, after, localRemainingAfter: localRemaining, money: m });
});
