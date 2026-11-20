// Regression (retry safety). Part A (CONTROL; it also passes on the earlier issuer): the same request twice gives a
// byte-identical token; it commits once; the second commit is "replayed". Part B (the regression): a crashed client
// retries request rq_a AFTER another client minted rq_b on the same pre-state; both mints answer, the retry is
// byte-identical, and rq_b commits. FAILS on the earlier issuer rule (rq_b was refused: key = pre-state hash).
// Usage and exit codes: m_lib.ts.
import { argv, guard, verdict, world } from "./m_lib";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_mr", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  // Part A
  const a1 = await w.mint(S0, "rq_r1", "100"), a2 = await w.mint(S0, "rq_r1", "100");
  const sameA = a1.ok && a2.ok && a1.text === a2.text;
  const ca1 = w.commit(a1), ca2 = w.commit(a2);
  // Part B, on the new stored state
  const S1 = a1.post;
  const x1 = await w.mint(S1, "rq_a", "50");                     // client A crashes before it commits
  const y = await w.mint(S1, "rq_b", "70");                      // client B
  const x2 = await w.mint(S1, "rq_a", "50");                     // client A retries
  const sameB = x1.ok && x2.ok && x1.text === x2.text;
  const cy = w.commit(y);
  w.stop();
  verdict(sameA && ca1 === "committed" && ca2 === "replayed" && y.ok && sameB && cy === "committed",
    { partA: { identical: sameA, first: ca1, second: ca2 }, partB: { retryIdentical: sameB, other: y.ok ? cy : "mint refused: " + y.reason } });
})());
