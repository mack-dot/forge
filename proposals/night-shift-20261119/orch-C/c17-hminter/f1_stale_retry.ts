// F1: honest concurrency. R1 and R2 minted on S0; R2 commits; R1 is refused by the sink as stale; the host re-proposes
// the SAME request id R1 on the new state S1. Mode "on". Attacker: none.
// Exit 1 = the minter refuses R1 on S1 (the request id is frozen for the life of the minter process).
// Exit 0 = R1 on S1 is issued and commits. Also prints the control: a NEW request id on S1 commits.
// Usage: f1_stale_retry.ts <work dir> [stale|amount]
import { join } from "node:path";
import { Raw, done, fresh, guard, mint, newSink, propose, st } from "./lib";
const [work, mode = "stale"] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const m = await new Raw(["on"]).start();
  const s0 = st("ch_F1", "1000", "1000"); const sink = newSink(m, join(work, "s.sqlite"), s0); sink.init(s0);
  const r: any = { mode };
  if (mode === "stale") {
    const t1 = await mint(m, s0, propose(s0, "rq_1", "300")), t2 = await mint(m, s0, propose(s0, "rq_2", "200"));
    r.commit2 = sink.commit(t2.text).status; r.commit1 = sink.commit(t1.text);
    const s1 = JSON.parse(sink.stateBlob());
    const again = await mint(m, s1, propose(s1, "rq_1", "300"));
    r.reproposeR1onS1 = again.ok ? sink.commit(again.text) : "MINTER REFUSED: " + again.reason;
    const ctl = await mint(m, s1, propose(s1, "rq_1b", "300"));
    r.controlNewId = ctl.ok ? sink.commit(ctl.text).status : "refused: " + ctl.reason;
    sink.close(); m.stop();
    done(!again.ok, r);
  } else {
    // the host minted rq_1 with a wrong amount (300), did not submit it, and asks again with the corrected 250
    await mint(m, s0, propose(s0, "rq_1", "300"));
    const fix = await mint(m, s0, propose(s0, "rq_1", "250"));
    r.corrected = fix.ok ? sink.commit(fix.text).status : "MINTER REFUSED: " + fix.reason;
    sink.close(); m.stop();
    done(!fix.ok, r);
  }
})());
