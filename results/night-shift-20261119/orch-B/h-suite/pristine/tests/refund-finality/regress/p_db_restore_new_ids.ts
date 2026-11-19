// Provider-anchor regression, the OVERPAY ROUTE of a database restore: the operator restores the database and the ledger
// from a backup taken after r1 (remaining 600 in the restored store; 900 was really refunded: r1 400, r2 400, r3 100).
// New refund requests with NEW request ids arrive; the issuer signs them on the STALE pre-state the store supplies
// (r4 600 = the stale remaining). No key repeats, so PROVIDER-IDEMPOTENT-KEY cannot help: only PROVIDER-CEILING can.
// SAFE: no request id moves money twice and money moved <= the charge. Usage and exit codes: p_lib.ts.
import { argv, guard, moneyCheck, verdict, world } from "./p_lib";
guard(() => {
  const { root, mode } = argv();
  const S0 = { chargeId: "ch_pn", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, S0);
  const r1 = w.refund("r1", "400"); const f1 = w.flush();
  w.backup();
  const r2 = w.refund("r2", "400"); const r3 = w.refund("r3", "100"); const f2 = w.flush();
  w.restore("both"); w.atAttack();
  const stale = w.state().remaining;
  const r4 = w.refund("r4", "600");
  const after = [w.flush(), w.flush()];
  const localRemaining = w.state().remaining;
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  const setup = r1.status === "committed" && r2.status === "committed" && r3.status === "committed" && f1.error === "" && f2.emitted.length === 2 &&
    stale === "600" && r4.status === "committed";
  if (!setup) { console.error(JSON.stringify({ r1, r2, r3, f1, f2, stale, r4 })); process.exit(3); }
  verdict(m.noDouble && m.withinCharge, { mode, staleRemaining: stale, r4: r4.status, after, localRemainingAfter: localRemaining, money: m });
});
