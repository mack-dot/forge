// S2: Store mode, two honest requests minted on one state; one commits first. Attacker: none.
// Reports what the minter answers for a re-proposal of the SAME id and of a NEW id, and the number of minter calls
// until the second refund is committed. Exit 1 = the second refund is NOT reachable at all (with a new id).
// Exit 0 = reachable (the same-id refusal "stale candidate" is B's specified behaviour, printed as information).
// Mode "off": the identical retry after the commit (header line 31 says an identical request gets byte-identical bytes).
// Usage: s2_stale.ts <work dir> [on|off]
import { join } from "node:path";
import { Raw, done, fresh, guard, mint, newSink, propose, st } from "./lib";
const [work, mode = "on"] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const path = join(work, "s.sqlite");
  const m = await new Raw([mode, path]).start();
  const s0 = st("ch_S2", "1000", "1000");
  const sink = newSink(m, path, s0); sink.init(s0);
  const r: any = { mode }; let calls = 0;
  const t1 = await mint(m, s0, propose(s0, "rq_1", "300")); calls++;
  const t2 = await mint(m, s0, propose(s0, "rq_2", "200")); calls++;
  r.commit2 = sink.commit(t2.text).status; r.commit1 = sink.commit(t1.text).reason;
  // identical retry of rq_2 after its commit (lost answer): must be the same bytes
  const re2 = await mint(m, s0, propose(s0, "rq_2", "200"));
  r.identicalRetryAfterCommit = re2.ok ? (re2.text === t2.text ? "same bytes" : "OTHER bytes") : "refused: " + re2.reason;
  const s1 = JSON.parse(sink.stateBlob());
  const same = await mint(m, s1, propose(s1, "rq_1", "300")); calls++;
  r.sameIdOnS1 = same.ok ? "issued -> " + sink.commit(same.text).status : "refused: " + same.reason;
  let reached = same.ok;
  if (!reached) {
    const nu = await mint(m, s1, propose(s1, "rq_1b", "300")); calls++;
    r.newIdOnS1 = nu.ok ? "issued -> " + sink.commit(nu.text).status : "refused: " + nu.reason;
    reached = nu.ok;
  }
  r.minterCallsForTwoRefunds = calls;
  sink.close(); m.stop();
  if (mode === "off") done(r.identicalRetryAfterCommit !== "same bytes", r);
  done(!reached, r);
})());
