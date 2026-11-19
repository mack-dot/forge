// Lead 7: database writer WITHOUT the key edits the outbox. Usage: l7_rowtype.ts <work> blob|nul|nulsettled|none
//  blob:       outbox.request_id of the committed r2 becomes a BLOB (same bytes). flush() filters the row out
//              (typeof !== "string") BEFORE any check: it is neither emitted nor refused, and is counted in alreadyDispatched.
//  nul:        a second outbox row 'r1\0x' (node reads 'r1') with r1's intent: is r1 emitted twice?
//  nulsettled: settled and outbox ids of r2 become 'r2\0x': lookup by the cut id misses; is it reported?
//  none:       control.
// Exit 1 = a committed refund is not emitted AND not in refused (silent), or an id is emitted twice. Exit 0 = safe.
import { DatabaseSync } from "node:sqlite";
import { startMinter, world } from "./common";
const [work, mode] = process.argv.slice(2);
(async () => {
  const { m, ids, mint } = await startMinter("off");
  const w = world(work, ids);
  console.log("r1", w.sink.commit(await mint(w.state(), "r1", "400")).status);
  console.log("r2", w.sink.commit(await mint(w.state(), "r2", "100")).status);
  const db = new DatabaseSync(w.db);
  if (mode === "blob") db.exec("UPDATE outbox SET request_id = CAST(request_id AS BLOB) WHERE request_id = 'r2'");
  if (mode === "nul") db.exec("INSERT INTO outbox(request_id, intent) SELECT 'r1' || char(0) || 'x', intent FROM outbox WHERE request_id = 'r1'");
  if (mode === "nulsettled") db.exec("UPDATE settled SET request_id = 'r2' || char(0) || 'x' WHERE request_id = 'r2'; UPDATE outbox SET request_id = 'r2' || char(0) || 'x' WHERE request_id = 'r2'");
  console.log("outbox", JSON.stringify(db.prepare("SELECT seq, typeof(request_id) t, hex(request_id) h FROM outbox").all()));
  db.close();
  const r = w.flush(); console.log("flush", JSON.stringify({ emitted: r.emitted.map((e: any) => e.requestId), refused: r.refused, already: r.alreadyDispatched }));
  m.stop(); w.sink.close();
  const out = w.effects.map((e: any) => e.requestId); const dup = out.filter((x: string, i: number) => out.indexOf(x) !== i);
  const silent = ["r1", "r2"].filter(id => !out.includes(id) && !r.refused.some((x: any) => x.requestId.startsWith(id)));
  console.log("silently missing:", JSON.stringify(silent), "duplicates:", JSON.stringify(dup));
  process.exit(silent.length || dup.length ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
