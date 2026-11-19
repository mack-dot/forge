// a2: after a rollback the sink keeps acknowledging honest refunds that the dispatcher can NEVER emit, and no
// component of the sink notices. Attacker: database file writer, no key, no config. Sequence: r1 600 committed and
// emitted; file rolled back to genesis (running sink, raw overwrite, same inode); honest r2 700, r3 100, r4 200
// against the sink's state; flush after each. The dispatcher head stays at remaining 400; the sink's chain is at
// 300 and below: remaining only decreases, so no later sink token can continue the dispatcher's chain.
// Arg singleUse = on|off (minter single-use rule; in memory only).
// Exit 1 = defect present: >=1 refund acknowledged "committed" by a serving (not halted) sink with an empty offline
// audit, and never emitted (refused by "does not continue the dispatched chain"). 0 = safe. 3 = harness error.
import { copyFileSync } from "node:fs";
import { join } from "node:path";
import { setup, Sink, S0 } from "./common";
const [work, singleUse] = process.argv.slice(2);
(async () => {
  const h = await setup(work, singleUse === "on" ? "on" : "off");
  const log: any = { singleUse };
  const sink = new Sink(h.db, h.cfg); sink.init(S0);
  const genesis = join(work, "genesis.copy"); copyFileSync(h.db, genesis);
  log.c1 = sink.commit(await h.mint(S0, "r1", "600")); log.f1 = h.flush().emitted.length;
  copyFileSync(genesis, h.db);
  const acked: string[] = [];
  log.steps = [];
  for (const [rid, amt] of [["r2", "700"], ["r3", "100"], ["r4", "200"]]) {
    const pre = JSON.parse(sink.stateBlob());
    let c: any;
    try { c = sink.commit(await h.mint(pre, rid, amt)); } catch (e) { c = { status: "mint-refused", reason: String((e as Error).message) }; }
    if (c.status === "committed") acked.push(rid);
    const f = h.flush();
    log.steps.push({ rid, amt, pre: pre.remaining, commit: c, emitted: f.emitted.map((e: any) => e.requestId), refused: f.refused.map((r: any) => r.requestId + ": " + r.reason) });
  }
  const audit = sink.audit();
  const notEmitted = acked.filter(r => !h.effects.some((e: any) => e.requestId === r));
  log.acked = acked; log.notEmitted = notEmitted; log.offlineAudit = audit; log.reaudits = sink.reaudits; log.paid = h.paid();
  sink.close();
  // restart: does the start-up audit see anything?
  try { new Sink(h.db, h.cfg).close(); log.restart = "serves"; } catch (e) { log.restart = String((e as Error).message); }
  h.stop();
  console.log(JSON.stringify(log));
  process.exit(notEmitted.length > 0 && audit.length === 0 && log.restart === "serves" ? 1 : 0);
})().catch(e => { console.error(String(e && e.stack)); process.exit(3); });
