// Provider-anchor regression: the same request id with OTHER parameters, after a PARTIAL restore (database and ledger, NOT the
// dispatch witness) from a backup taken after r1. The issuer (memory lost at restart) signs r2 with amount 500 on the stale
// pre-state. At 370ff65c the dispatch witness stops the dispatcher first ("CONTROL DOES NOT BITE" for mode c, anchor none);
// the full-restore form is p_full_param_rebind.ts. Usage and exit codes: p_lib.ts.
import { argv, attackVerdict, guard, moneyCheck, setupFail, world } from "./p_lib";
guard(() => {
  const { root, mode, anchor } = argv();
  const S0 = { chargeId: "ch_pp", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, anchor, S0);
  const r1 = w.refund("r1", "400"); const f1 = w.flush();
  w.backup();
  const r2 = w.refund("r2", "400"); const r3 = w.refund("r3", "100"); const f2 = w.flush();
  const setup = r1.status === "committed" && r2.status === "committed" && r3.status === "committed" && f1.error === "" && f2.emitted.length === 2;
  if (!setup) setupFail({ r1, r2, r3, f1, f2 });
  w.restore("both"); w.atAttack();
  const r2b = w.refund("r2", "500");
  const after = [w.flush(), w.flush()];
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  attackVerdict(mode, anchor, m.noDouble && m.withinCharge, w.events, { test: "p_param_rebind", r2b: r2b.status, after, money: m });
});
