// a1: the owner's sequence. Sink commits refund 1 (600 of 1000); dispatcher emits it; the attacker (database
// file writer, no key) rolls the database file back to genesis; an honest host mints refund 2 (600) against the
// sink's (rolled-back) state; the sink commits it; dispatcher flush. DEFECT if the external effects sum > 1000.
// mode = running (raw overwrite of the file while the sink is open) | restart (sink closed, file restored, new sink).
// Also: variant "resync" (refund 3 of 400 after refund 2) and variant "newledger" (a new dispatcher instance with a
// fresh ledger path: documented as "a lost ledger sends everything again").
// Exit: 1 = more than the charge was paid (defect present); 0 = safe; 3 = harness error.
import { copyFileSync } from "node:fs";
import { join } from "node:path";
import { setup, Sink, S0 } from "./common";
const [work, mode, variant] = process.argv.slice(2);
(async () => {
  const h = await setup(work);
  const log: any = { mode, variant };
  let sink = new Sink(h.db, h.cfg); sink.init(S0);
  const genesis = join(work, "genesis.copy"); copyFileSync(h.db, genesis);       // attacker's snapshot
  log.c1 = sink.commit(await h.mint(S0, "r1", "600"));
  log.f1 = h.flush();
  // attacker: roll the file back to genesis
  if (mode === "restart") { sink.close(); copyFileSync(genesis, h.db); sink = new Sink(h.db, h.cfg); }
  else copyFileSync(genesis, h.db);                                                // same inode, contents replaced
  const pre2 = sink.storedBlob() === undefined ? null : JSON.parse(sink.storedBlob());
  log.stateSeenByHost = pre2;
  log.c2 = sink.commit(await h.mint(pre2, "r2", "600"));
  log.reaudits = sink.reaudits;
  log.f2 = h.flush();
  if (variant === "resync") { const p = JSON.parse(sink.stateBlob()); log.c3 = sink.commit(await h.mint(p, "r3", "400")); log.f3 = h.flush(); }
  if (variant === "newledger") { log.f2new = h.flush(join(work, "ledger-new.jsonl")); }
  log.offlineAudit = sink.audit();
  log.paid = h.paid(); log.effects = h.effects.map((e: any) => e.requestId);
  sink.close(); h.stop();
  console.log(JSON.stringify(log));
  process.exit(log.paid > 1000 ? 1 : 0);
})().catch(e => { console.error(String(e && e.stack)); process.exit(3); });
