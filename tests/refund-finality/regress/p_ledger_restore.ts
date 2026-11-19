// Provider-anchor regression for C-ATT-19 (results/night-shift-20261119/orch-C/c8-dispatcher/scripts/l3_ledger_restore.ts,
// mode "ledger"): an operator restores ONLY the dispatcher ledger from a backup taken after r1. The database stays current.
// The dispatcher at e65f9ec8 emits r2 and r3 AGAIN (its rowHead check passes: the store still extends the old ledger).
// The emit is the provider adapter (key = request id). Up to three dispatcher runs after the restore (a host that retries a
// stopped run). SAFE: no request id moves money twice and money moved <= the charge. Usage and exit codes: p_lib.ts.
import { argv, guard, moneyCheck, verdict, world } from "./p_lib";
guard(() => {
  const { root, mode } = argv();
  const S0 = { chargeId: "ch_pl", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, S0);
  const r1 = w.refund("r1", "400"); const f1 = w.flush();
  w.backup();
  const r2 = w.refund("r2", "400"); const r3 = w.refund("r3", "100"); const f2 = w.flush();
  w.restore("ledger"); w.atAttack();
  const after = [w.flush(), w.flush(), w.flush()];
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  const setup = r1.status === "committed" && r2.status === "committed" && r3.status === "committed" && f1.error === "" && f2.error === "" && f2.emitted.length === 2;
  if (!setup) { console.error(JSON.stringify({ r1, r2, r3, f1, f2 })); process.exit(3); }
  verdict(m.noDouble && m.withinCharge, { mode, after, money: m });
});
