// Regression (issuer-side idempotency per request). The issuer never signs two DIFFERENT transitions for one
// (charge id, request id). rq_x is minted for 100 on S0 (not committed); rq_y commits; then rq_x is asked for 30 on
// the NEW pre-state S1: refused. Control: a fresh id on S1 issues and commits. FAILS on the earlier issuer rule
// (its key is the pre-state hash, so another pre-state was signed again) and with no rule ("off").
// Usage and exit codes: m_lib.ts.
import { argv, guard, verdict, world } from "./m_lib";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_md", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const first = await w.mint(S0, "rq_x", "100");
  const y = await w.mint(S0, "rq_y", "200"); const cy = w.commit(y);
  const second = await w.mint(y.post, "rq_x", "30");
  const fresh = await w.mint(y.post, "rq_z", "30"); const cf = w.commit(fresh);
  w.stop();
  // On the earlier rule rq_y is refused (frozen pre-state); then y.post is not the stored state; we report it as is.
  verdict(first.ok && cy === "committed" && !second.ok && cf === "committed",
    { first: first.ok, otherRequest: cy, sameIdOtherCandidate: second.ok ? "SIGNED" : "refused: " + second.reason, freshId: cf });
})());
