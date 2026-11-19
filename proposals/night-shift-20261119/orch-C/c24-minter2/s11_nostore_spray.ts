// S11: NoStore mode (three minter arguments), mode "on". A caller WITHOUT the key who knows the charge id, the
// victim's request id and the ORIGINAL amount, but NOT the current state, sends one core-refused request (unapproved
// reason) with the victim's id for EVERY possible remaining value 0..original (original+1 requests, no feedback needed).
// Each closes the key (charge id, request id, hash of that guessed pre-state). The real state is among them.
// Exit 1 = the victim's honest request on the real state (and on a later state) is refused. Exit 0 = issued.
// Usage: s11_nostore_spray.ts <work dir>
import { join } from "node:path";
import { Raw, done, fresh, guard, mint, newSink, propose, st } from "./lib";
const [work] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const m = await new Raw(["on"]).start();
  const s0 = st("ch_S11", "1000", "1000");
  const sink = newSink(m, join(work, "s.sqlite"), s0); sink.init(s0);
  let cur = s0;
  for (const [rid, a] of [["rq_h1", "137"], ["rq_h2", "226"]]) { const t = await mint(m, cur, propose(cur, rid, a)); sink.commit(t.text); cur = JSON.parse(sink.stateBlob()); }
  const victim = "rq_victim", t0 = Date.now(); let closed = 0;
  for (let rem = 0; rem <= 1000; rem++) {
    const g = st("ch_S11", "1000", String(rem));
    const a = await mint(m, g, propose(g, victim, "0", "attacker_text"));
    if (!a.ok && a.reason === "core: Refuse") closed++;
  }
  const attackMs = Date.now() - t0;
  const v = await mint(m, cur, propose(cur, victim, "250"));
  const r: any = { closedKeys: closed, attackMs, victimOnRealState: v.ok ? "issued" : "refused: " + v.reason };
  // a later state (after another honest refund): still closed?
  const t3 = await mint(m, cur, propose(cur, "rq_h3", "100")); sink.commit(t3.text); const s3 = JSON.parse(sink.stateBlob());
  const v2 = await mint(m, s3, propose(s3, victim, "250"));
  r.victimOnLaterState = v2.ok ? "issued" : "refused: " + v2.reason;
  sink.close(); m.stop();
  done(!v.ok, r);
})());
