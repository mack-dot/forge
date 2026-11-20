// Regression C-ATT-20 (a BLOB-typed outbox request_id was skipped silently). A file writer WITHOUT the key, who can
// bypass the store's safeguards (drop the append-only trigger, ignore CHECK constraints, put the trigger back with the
// same text), turns the committed r2's outbox request_id into a BLOB with the same bytes. Nothing is dispatched yet.
// SAFE: the run either stops with an error (alarm), or reports every committed id (r1, r2) EXACTLY (emitted, or refused
// under its own id); nothing is counted as already dispatched; nothing is emitted twice. FAILS on the unfixed
// dispatcher (r2 is refused under the text "114,50", i.e. under no committed id). Usage and exit codes: d_lib.ts.
import { DatabaseSync } from "node:sqlite";
import { argv, dups, guard, verdict, world } from "./d_lib";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_d20", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "400"); w.commit(t1.text);
  const t2 = await w.mint(t1.post, "r2", "100"); w.commit(t2.text);
  w.closeSink();
  const db = new DatabaseSync(w.db);
  const trig = (db.prepare("SELECT sql FROM sqlite_master WHERE type = 'trigger' AND name = 'h_outbox_bu'").get() as { sql?: string } | undefined)?.sql;
  db.exec("PRAGMA ignore_check_constraints = ON");
  if (trig) db.exec("DROP TRIGGER h_outbox_bu");
  db.exec("UPDATE outbox SET request_id = CAST(request_id AS BLOB) WHERE request_id = 'r2'");
  if (trig) db.exec(trig);
  const rows = db.prepare("SELECT seq, typeof(request_id) AS t, hex(request_id) AS h FROM outbox").all();
  db.close();
  let r: any = null, stopped = "";
  try { r = w.flush(); } catch (e) { stopped = (e as Error).message; }
  w.stop();
  const ids = w.effects.map(e => e.requestId);
  const exact = (id: string) => ids.includes(id) || (r !== null && r.refused.some((x: any) => x.requestId === id));
  const pass = dups(ids).length === 0 && (stopped !== "" || (exact("r1") && exact("r2") && r.alreadyDispatched === 0));
  verdict(pass, { outbox: rows, emitted: ids, refused: r?.refused?.map((x: any) => x.requestId + ": " + String(x.reason).slice(0, 90)), already: r?.alreadyDispatched, stopped: stopped.slice(0, 200) });
})());
