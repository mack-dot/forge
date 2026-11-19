// Provider-anchor regression for C-ATT-19 (results/night-shift-20261119/orch-C/c8-dispatcher/scripts/l3_ledger_restore.ts,
// mode "ledger"), PARTIAL restore: an operator restores ONLY the dispatcher ledger from a backup taken after r1. The database
// and the dispatch witness stay current. At e65f9ec8 the dispatcher emitted r2 and r3 AGAIN. At 370ff65c the dispatch witness
// (n = 3) stops the run first. So mode c with anchor none is "CONTROL DOES NOT BITE" (exit 2) on this tree: the full-restore
// form of this attack is p_full_ledger_lag.ts. Up to three dispatcher runs after the restore. Usage and exit codes: p_lib.ts.
import { argv, attackVerdict, guard, moneyCheck, setupFail, world } from "./p_lib";
guard(() => {
  const { root, mode, anchor } = argv();
  const S0 = { chargeId: "ch_pl", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, anchor, S0);
  const r1 = w.refund("r1", "400"); const f1 = w.flush();
  w.backup();
  const r2 = w.refund("r2", "400"); const r3 = w.refund("r3", "100"); const f2 = w.flush();
  const setup = r1.status === "committed" && r2.status === "committed" && r3.status === "committed" && f1.error === "" && f2.error === "" && f2.emitted.length === 2;
  if (!setup) setupFail({ r1, r2, r3, f1, f2 });
  w.restore("ledger"); w.atAttack();
  const after = [w.flush(), w.flush(), w.flush()];
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  attackVerdict(mode, anchor, m.noDouble && m.withinCharge, w.events, { test: "p_ledger_restore", after, money: m });
});
