// Lead 3: an operator restores a backup. Usage: l3_ledger_restore.ts <work> ledger|dir|none
//  ledger: restore only the ledger file from a backup taken after r1 (database current). The next run emits r2, r3 AGAIN.
//  dir:    restore the whole folder (database + co-located ledger, the suite.ts convention) from the same backup;
//          the host retries r2, r3 with the SAME tokens (honest retry); the sink commits them again; the dispatcher emits them again.
//  none:   control: no restore.
// Exit 1 = a request id is emitted twice or the total is above 1000. Exit 0 = safe.
import { copyFileSync, mkdirSync, rmSync, existsSync } from "node:fs";
import { join } from "node:path";
import { startMinter, world, sum, Sink } from "./common";
const [work, mode] = process.argv.slice(2);
(async () => {
  const { m, ids, mint } = await startMinter("off");
  const w = world(work, ids);
  console.log("r1", w.sink.commit(await mint(w.state(), "r1", "400")).status);
  console.log("flush 1", JSON.stringify(w.flush()));
  w.sink.close();
  const bk = join(work, "backup"); mkdirSync(bk);
  for (const f of ["sink.sqlite", "dispatch-ledger.jsonl"]) copyFileSync(join(work, f), join(bk, f));
  let sink = new Sink(w.db, w.cfg);
  const t2 = await mint(JSON.parse(sink.stateBlob()), "r2", "400"); console.log("r2", sink.commit(t2).status);
  const t3 = await mint(JSON.parse(sink.stateBlob()), "r3", "100"); console.log("r3", sink.commit(t3).status);
  console.log("flush 2", JSON.stringify(w.flush()));
  sink.close();
  if (mode === "ledger") { copyFileSync(join(bk, "dispatch-ledger.jsonl"), w.ledger); console.log("restored the ledger only"); }
  if (mode === "dir") { for (const f of ["sink.sqlite", "dispatch-ledger.jsonl"]) { copyFileSync(join(bk, f), join(work, f)); }
    for (const x of ["-wal", "-shm", "-journal"]) if (existsSync(w.db + x)) rmSync(w.db + x); console.log("restored the folder"); }
  sink = new Sink(w.db, w.cfg); console.log("sink restart: start-up audit passed");
  if (mode === "dir") { console.log("retry r2", sink.commit(t2).status, "retry r3", sink.commit(t3).status); }
  console.log("flush 3", JSON.stringify(w.flush()));
  sink.close(); m.stop();
  const rid = w.effects.map((e: any) => e.requestId); const dup = rid.filter((x: string, i: number) => rid.indexOf(x) !== i);
  console.log("effects", rid.join(","), "total", sum(w.effects), "of 1000; duplicates", JSON.stringify(dup));
  process.exit(dup.length > 0 || sum(w.effects) > 1000 ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
