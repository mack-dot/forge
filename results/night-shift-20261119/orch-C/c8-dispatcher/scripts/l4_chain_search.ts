// Lead 4: exhaustive search over short HONEST histories (no attacker) against the real Sink and Dispatcher.
// Ops: N = mint 100 on the current state and commit; Z = mint 0 on the current state and commit;
//      S = mint 100 on the current state, hold the token; T = mint 0 on the current state, hold it;
//      C = commit the oldest held token (may be refused as stale: that is correct); D = dispatcher run.
// Every history ends with D, a sink restart and a second D. Lengths 1..4 over 6 ops = 1554 histories.
// Checks: emitted sequence == outbox in seq order; no duplicate; total <= 1000; nothing refused; every committed
// refund emitted; the restart passes; no throw. Exit 1 = some history breaks a check. Usage: l4_chain_search.ts <work>
import { join } from "node:path";
import { rmSync } from "node:fs";
import { startMinter, world, sum, Sink } from "./common";
const [work] = process.argv.slice(2);
const OPS = ["N", "Z", "S", "T", "C", "D"];
(async () => {
  const { m, ids, mint } = await startMinter("off");
  const hist: string[][] = [];
  for (let L = 1; L <= 4; L++) { const rec = (p: string[]) => { if (p.length === L) { hist.push(p); return; } for (const o of OPS) rec([...p, o]); }; rec([]); }
  let bad = 0, n = 0, zeroCommits = 0, staleRefusals = 0;
  for (const h of hist) {
    n++; const dir = join(work, "h"); const w = world(dir, ids); let k = 0; const held: string[] = []; const committed: string[] = []; const errs: string[] = [];
    try {
      for (const o of [...h, "D"]) {
        const rid = "q" + (k++);
        if (o === "N" || o === "Z") { const r = w.sink.commit(await mint(w.state(), rid, o === "N" ? "100" : "0")); if (r.status !== "committed") errs.push(o + " " + r.status + " " + r.reason); else { committed.push(rid); if (o === "Z") zeroCommits++; } }
        else if (o === "S" || o === "T") held.push(await mint(w.state(), rid, o === "S" ? "100" : "0"));
        else if (o === "C") { const t = held.shift(); if (t) { const r = w.sink.commit(t); const id = JSON.parse(t).body.requestId; if (r.status === "committed") committed.push(id); else if (/pre-state/.test(r.reason ?? "")) staleRefusals++; else errs.push("C " + r.status + " " + r.reason); } }
        else { const r = w.flush(); if (r.refused.length) errs.push("refused " + JSON.stringify(r.refused)); }
      }
      w.sink.close(); const s2 = new Sink(w.db, w.cfg); s2.close();
      const r = w.flush(); if (r.refused.length || r.emitted.length) errs.push("after restart " + JSON.stringify(r));
      const out = w.effects.map((e: any) => e.requestId);
      if (JSON.stringify(out) !== JSON.stringify(committed)) errs.push("emitted " + out + " committed " + committed);
      if (sum(w.effects) > 1000) errs.push("total " + sum(w.effects));
    } catch (e) { errs.push("threw " + (e as Error).message); try { w.sink.close(); } catch { /* closed */ } }
    if (errs.length) { bad++; if (bad <= 10) console.log("BAD", h.join(""), errs.join(" | ")); }
  }
  rmSync(join(work, "h"), { recursive: true, force: true }); m.stop();
  console.log(JSON.stringify({ histories: n, bad, zeroCommits, staleRefusals }));
  process.exit(bad ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
