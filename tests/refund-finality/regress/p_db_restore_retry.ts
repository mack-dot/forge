// Provider-anchor regression for C-ATT-19 mode "dir", PARTIAL restore: the operator restores the database AND the co-located
// ledger (NOT the dispatch witness) from a backup taken after r1. The host then retries r2 and r3 with the SAME tokens (an
// honest retry); without an outside head the restored sink commits them again. At 370ff65c the dispatch witness (n = 3)
// stops the dispatcher, so mode c with anchor none is "CONTROL DOES NOT BITE" (exit 2): the full-restore form is
// p_full_restore_retry.ts. Usage and exit codes: p_lib.ts.
import { argv, attackVerdict, guard, moneyCheck, setupFail, world } from "./p_lib";
guard(() => {
  const { root, mode, anchor } = argv();
  const S0 = { chargeId: "ch_pd", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, anchor, S0);
  const r1 = w.refund("r1", "400"); const f1 = w.flush();
  w.backup();
  const r2 = w.refund("r2", "400"); const r3 = w.refund("r3", "100"); const f2 = w.flush();
  const setup = r1.status === "committed" && r2.status === "committed" && r3.status === "committed" && f1.error === "" && f2.emitted.length === 2;
  if (!setup) setupFail({ r1, r2, r3, f1, f2 });
  w.restore("both"); w.atAttack();
  const retry = [w.commitText(r2.text), w.commitText(r3.text)];
  const after = [w.flush(), w.flush(), w.flush()];
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  attackVerdict(mode, anchor, m.noDouble && m.withinCharge, w.events, { test: "p_db_restore_retry", retry, after, money: m });
});
