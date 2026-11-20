// Regression C-ATT-03 (zero amount, issuer side). Two zero-amount refunds with distinct request ids, then a positive
// refund, all for one charge: every mint issues and every token commits in the sink. FAILS on the earlier issuer rule
// "one signed transition per pre-state hash" (a zero-amount refund does not change the state, so it froze the charge).
// Usage and exit codes: m_lib.ts.
import { argv, guard, verdict, world } from "./m_lib";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_mz", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const z1 = await w.mint(S0, "rq_z1", "0"); const c1 = w.commit(z1);
  const z2 = await w.mint(z1.post, "rq_z2", "0"); const c2 = w.commit(z2);
  const p = await w.mint(z2.post, "rq_p1", "100"); const c3 = w.commit(p);
  w.stop();
  verdict(c1 === "committed" && c2 === "committed" && c3 === "committed", { zero1: c1, zero2: c2, positive: c3 });
})());
