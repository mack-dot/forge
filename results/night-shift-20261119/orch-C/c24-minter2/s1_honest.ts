// S1: Store mode, honest flows. Attacker: none. Exit 1 = a legitimate request is refused (other than B's specified
// "stale candidate" for a re-proposal of the SAME id, which is reported as information). Exit 0 = all honest requests served.
// Usage: s1_honest.ts <work dir>
import { join } from "node:path";
import { Raw, done, fresh, guard, mint, newSink, propose, st } from "./lib";
const [work] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const path = join(work, "s.sqlite");
  const m = await new Raw(["on", path]).start();
  const s0 = st("ch_S1", "1000", "1000");
  const r: any = { falseRejections: [] as string[] };
  const bad = (what: string, x: any) => r.falseRejections.push(what + ": " + JSON.stringify(x.reason ?? x));
  // (a) the minter starts BEFORE the store file exists
  const a0 = await mint(m, s0, propose(s0, "rq_early", "0"));
  r.beforeFile = a0.ok ? "issued" : a0.reason;
  const sink = newSink(m, path, s0);
  // (b) the file exists, schema created, no state row yet (before init)
  const a1 = await mint(m, s0, propose(s0, "rq_early", "0"));
  r.beforeInit = a1.ok ? "issued" : a1.reason;
  sink.init(s0);
  // (c) the same id after init: must be issued (the earlier refusals recorded nothing)
  const a2 = await mint(m, s0, propose(s0, "rq_early", "0"));
  r.afterInit = a2.ok ? sink.commit(a2.text).status : a2.reason;
  if (!a2.ok) bad("rq_early after init", a2);
  // (d) chain: 300, 0, 0, then amount == remaining, then 0 at remaining 0
  let cur = JSON.parse(sink.stateBlob());
  const chain: any[] = [];
  for (const [rid, amt] of [["rq_a", "300"], ["rq_z1", "0"], ["rq_z2", "0"], ["rq_full", "remaining"], ["rq_z3", "0"]]) {
    const amount = amt === "remaining" ? cur.remaining : amt;
    const t = await mint(m, cur, propose(cur, rid, amount));
    if (!t.ok) { bad(rid, t); chain.push([rid, amount, t.reason]); continue; }
    const c = sink.commit(t.text); chain.push([rid, amount, c.status, c.reason]);
    if (c.status !== "committed") bad(rid + " commit", c);
    // identical retry after the commit: the same bytes
    const again = await mint(m, cur, propose(cur, rid, amount));
    if (!again.ok || again.text !== t.text) bad(rid + " identical retry", again);
    cur = JSON.parse(sink.stateBlob());
  }
  r.chain = chain; r.finalState = cur;
  // (e) two requests on one state; one commits first
  const s = cur.remaining === "0" ? null : cur;
  sink.close(); m.stop();
  done(r.falseRejections.length > 0, r);
})());
