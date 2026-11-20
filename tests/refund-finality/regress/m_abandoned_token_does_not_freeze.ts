// Regression C-ATT-03 (abandoned token). A token is minted and NEVER committed (the client crashed). Another request
// on the same pre-state then issues and commits. FAILS on the earlier issuer rule (key = pre-state hash).
// Usage and exit codes: m_lib.ts.
import { argv, guard, verdict, world } from "./m_lib";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_ma", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const abandoned = await w.mint(S0, "rq_lost", "250");          // never committed
  const b = await w.mint(S0, "rq_next", "100"); const cb = w.commit(b);
  w.stop();
  verdict(abandoned.ok && cb === "committed", { abandonedMinted: abandoned.ok, next: cb });
})());
