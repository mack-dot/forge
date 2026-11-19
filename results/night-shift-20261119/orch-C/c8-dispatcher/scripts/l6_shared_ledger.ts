// Lead 6: two charges (ch_A, ch_B), one database each, both with request id r1, one dispatcher per charge, and ONE
// ledger file (the fixed name dispatch-ledger.jsonl of suite.ts in a shared folder). Usage: l6_shared_ledger.ts <work>
// Exit 1 = a wrong or missing-and-unreported effect, or a total above a charge's original. Exit 0 = safe (a stop is a liveness cost only).
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { startMinter, E, Sink, Dispatcher } from "./common";
const [work] = process.argv.slice(2);
(async () => {
  rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const { m, ids, mint } = await startMinter("off");
  const ledger = join(work, "dispatch-ledger.jsonl"); const effects: any[] = []; const out: string[] = [];
  for (const ch of ["ch_A", "ch_B"]) {
    const s0 = { chargeId: ch, original: "1000", remaining: "1000", refundEnabled: true };
    const db = join(work, ch + ".sqlite"); const sink = new Sink(db, { ...ids, initialState: s0 }); sink.init(s0);
    out.push(ch + " r1 " + sink.commit(await mint(s0, "r1", "400")).status); sink.close();
    try { const r = new Dispatcher(db, ledger, { ...ids, initialStateSha256: E.stateSha256(s0) }, (e: any) => effects.push(e)).flush();
      out.push(ch + " flush " + JSON.stringify({ emitted: r.emitted.length, refused: r.refused, already: r.alreadyDispatched })); }
    catch (e) { out.push(ch + " flush stopped: " + (e as Error).message); }
  }
  m.stop(); console.log(out.join("\n")); console.log("effects", effects.map(e => JSON.parse(e.intent).chargeId + ":" + e.requestId).join(","));
  const okA = effects.length === 1 && JSON.parse(effects[0].intent).chargeId === "ch_A";
  process.exit(okA ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
