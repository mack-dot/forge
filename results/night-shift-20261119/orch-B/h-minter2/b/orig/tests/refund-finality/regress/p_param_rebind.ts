// Provider-anchor regression: the same request id with OTHER parameters. The operator restores the database and the
// ledger from a backup taken after r1; the host sends r2 again, but the issuer (memory lost at restart) signs r2 with
// amount 500 on the stale pre-state. The store commits it; the dispatcher emits r2 with amount 500.
// PROVIDER-PARAM-BINDING must refuse it (the key r2 was used with amount 400). SAFE: no request id moves money twice
// and money moved <= the charge. Usage and exit codes: p_lib.ts.
import { argv, guard, moneyCheck, verdict, world } from "./p_lib";
guard(() => {
  const { root, mode } = argv();
  const S0 = { chargeId: "ch_pp", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, S0);
  const r1 = w.refund("r1", "400"); const f1 = w.flush();
  w.backup();
  const r2 = w.refund("r2", "400"); const r3 = w.refund("r3", "100"); const f2 = w.flush();
  w.restore("both"); w.atAttack();
  const r2b = w.refund("r2", "500");
  const after = [w.flush(), w.flush()];
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  const setup = r1.status === "committed" && r2.status === "committed" && r3.status === "committed" && f1.error === "" && f2.emitted.length === 2 && r2b.status === "committed";
  if (!setup) { console.error(JSON.stringify({ r1, r2, r3, f1, f2, r2b })); process.exit(3); }
  verdict(m.noDouble && m.withinCharge, { mode, r2b: r2b.status, after, money: m });
});
