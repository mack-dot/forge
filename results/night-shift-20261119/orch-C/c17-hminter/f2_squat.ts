// F2: request-id squat at the minter WITHOUT any commit. Attacker: a minter caller without the key, who knows only the
// victim's (charge id, request id). It does NOT know the real pre-state: it sends an invented valid pre-state
// (original 5, remaining 5) and amount 0. The sink never sees that token. Then the victim's real request (C, R) on
// the real S0 is sent. Mode "on".
// Exit 1 = the victim's real request is refused by the minter (squat succeeded); 0 = issued and committed.
// Usage: f2_squat.ts <work dir> [fake|zero]   fake: invented pre-state; zero: real S0, amount 0, never committed
import { join } from "node:path";
import { Raw, done, fresh, guard, mint, newSink, propose, st } from "./lib";
const [work, mode = "fake"] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const m = await new Raw(["on"]).start();
  const s0 = st("ch_V", "1000", "1000"); const sink = newSink(m, join(work, "s.sqlite"), s0); sink.init(s0);
  const fakePre = mode === "fake" ? st("ch_V", "5", "5") : s0;
  const squat = await mint(m, fakePre, propose(fakePre, "rq_victim", "0"));
  const r: any = { mode, squatIssued: squat.ok, squatOnSink: squat.ok && mode === "fake" ? sink.commit(squat.text) : "not submitted" };
  // in "fake" mode the squat token is stale at the sink (never commits); in "zero" mode it is NOT submitted
  const victim = await mint(m, s0, propose(s0, "rq_victim", "700"));
  r.victim = victim.ok ? sink.commit(victim.text).status : "MINTER REFUSED: " + victim.reason;
  r.settledRows = sink.settled().length;
  const ctl = await mint(m, s0, propose(s0, "rq_victim_2", "700"));
  r.controlNewId = ctl.ok ? sink.commit(ctl.text).status : "refused: " + ctl.reason;
  sink.close(); m.stop();
  done(!victim.ok, r);
})());
