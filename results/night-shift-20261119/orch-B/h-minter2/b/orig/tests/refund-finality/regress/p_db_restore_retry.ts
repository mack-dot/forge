// Provider-anchor regression for C-ATT-19 mode "dir": the operator restores the database AND the co-located ledger from a
// backup taken after r1. The host then retries r2 and r3 with the SAME tokens (an honest retry); the restored sink commits
// them again; the dispatcher emits them again. SAFE: no request id moves money twice and money moved <= the charge.
// Usage and exit codes: p_lib.ts.
import { argv, guard, moneyCheck, verdict, world } from "./p_lib";
guard(() => {
  const { root, mode } = argv();
  const S0 = { chargeId: "ch_pd", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, S0);
  const r1 = w.refund("r1", "400"); const f1 = w.flush();
  w.backup();
  const r2 = w.refund("r2", "400"); const r3 = w.refund("r3", "100"); const f2 = w.flush();
  w.restore("both"); w.atAttack();
  const retry = [w.commitText(r2.text), w.commitText(r3.text)];
  const after = [w.flush(), w.flush(), w.flush()];
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  const setup = r1.status === "committed" && r2.status === "committed" && r3.status === "committed" && f1.error === "" && f2.emitted.length === 2 &&
    retry[0] === "committed" && retry[1] === "committed";
  if (!setup) { console.error(JSON.stringify({ r1, r2, r3, f1, f2, retry })); process.exit(3); }
  verdict(m.noDouble && m.withinCharge, { mode, retry, after, money: m });
});
