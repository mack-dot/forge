// S8: Store mode; request-id squat by a caller WITHOUT the key who knows the charge id, the victim's request id and
// the charge's ORIGINAL amount, but NOT the stored state. It uses the minter as an oracle: every wrong guess of
// `remaining` is answered "pre-state is not the authoritative stored state" and is not recorded; the first right guess
// carries an unapproved reason, so the core refuses and the pair is CLOSED (no token exists, no sink row).
// Exit 1 = the victim's honest request is refused afterwards. Exit 0 = it is issued and commits.
// Usage: s8_squat_search.ts <work dir> [close|zero]
import { join } from "node:path";
import { Raw, done, fresh, guard, mint, newSink, propose, st } from "./lib";
const [work, how = "close"] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const path = join(work, "s.sqlite");
  const m = await new Raw(["on", path]).start();
  const s0 = st("ch_S8", "1000", "1000");
  const sink = newSink(m, path, s0); sink.init(s0);
  // honest history the attacker does not see: two refunds
  let cur = s0;
  for (const [rid, a] of [["rq_h1", "137"], ["rq_h2", "226"]]) { const t = await mint(m, cur, propose(cur, rid, a)); sink.commit(t.text); cur = JSON.parse(sink.stateBlob()); }
  const victim = "rq_victim", t0 = Date.now();
  let probes = 0, hit: any = null;
  for (let rem = 1000; rem >= 0 && hit === null; rem--) {
    const g = st("ch_S8", "1000", String(rem)); probes++;
    const a = how === "zero" ? await mint(m, g, propose(g, victim, "0")) : await mint(m, g, propose(g, victim, "1", "attacker_text"));
    if (a.ok || a.reason !== "pre-state is not the authoritative stored state") hit = { rem, answer: a.ok ? "SIGNED" : a.reason };
  }
  const attackMs = Date.now() - t0;
  const v = await mint(m, cur, propose(cur, victim, "250"));
  const r = { how, probes, attackMs, hit, sinkRowsAfterAttack: sink.settled().length, victim: v.ok ? "issued -> " + sink.commit(v.text).status : "refused: " + v.reason };
  sink.close(); m.stop();
  done(!v.ok, r);
})());
