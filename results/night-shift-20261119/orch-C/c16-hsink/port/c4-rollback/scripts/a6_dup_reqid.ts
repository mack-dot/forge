// a6: two effects for ONE request id in the v6 sink, with a store that passes the start-up audit afterwards.
// Attacker: database file writer (SQLite with writable_schema), no key, no config. Plus an honest host retry: the
// host asks the minter again for request r1 against the CURRENT state (e.g. the first answer was lost), which the
// design allows (the proposer has no authority; "request open" = "not settled in the sink").
// Mechanism: the schema check does not compare rootpage and nothing runs integrity_check; the attacker points
// sqlite_autoindex_settled_1 and sqlite_autoindex_outbox_1 at crafted index b-trees in which r1's key is 'r1x'.
// Then the commit's lookup "WHERE request_id = ?" misses r1, both UNIQUE constraints miss it, and the start-up
// audit's COUNT(DISTINCT request_id) (answered from the same index) still equals the row count.
// mode = restart (attacker edits while the sink is stopped) | running (edits while the sink is open).
// Exit 1 = defect present: the sink commits a second effect for r1 AND a later restart serves. 0 = safe. 3 = error.
import { DatabaseSync } from "node:sqlite";
import { setup, Sink, S0 } from "./common";
const [work, mode] = process.argv.slice(2);
function corrupt(path: string) {
  const a = new DatabaseSync(path);
  a.exec(`CREATE TABLE d1(seq INTEGER PRIMARY KEY, request_id TEXT NOT NULL UNIQUE);
          INSERT INTO d1 SELECT seq, CASE WHEN request_id = 'r1' THEN 'r1x' ELSE request_id END FROM settled;
          CREATE TABLE d2(seq INTEGER PRIMARY KEY, request_id TEXT NOT NULL UNIQUE);
          INSERT INTO d2 SELECT seq, CASE WHEN request_id = 'r1' THEN 'r1x' ELSE request_id END FROM outbox;`);
  const r1 = (a.prepare("SELECT rootpage FROM sqlite_schema WHERE name = 'sqlite_autoindex_d1_1'").get() as any).rootpage;
  const r2 = (a.prepare("SELECT rootpage FROM sqlite_schema WHERE name = 'sqlite_autoindex_d2_1'").get() as any).rootpage;
  const sv = (a.prepare("PRAGMA schema_version").get() as any).schema_version;
  a.exec("PRAGMA writable_schema = ON");
  a.prepare("UPDATE sqlite_schema SET rootpage = ? WHERE name = 'sqlite_autoindex_settled_1'").run(r1);
  a.prepare("UPDATE sqlite_schema SET rootpage = ? WHERE name = 'sqlite_autoindex_outbox_1'").run(r2);
  a.exec("DELETE FROM sqlite_schema WHERE tbl_name IN ('d1', 'd2')");
  a.exec(`PRAGMA schema_version = ${sv + 1}`);
  a.exec("PRAGMA writable_schema = OFF");
  a.close();
}
(async () => {
  const h = await setup(work);
  const log: any = { mode };
  let sink = new Sink(h.db, h.cfg); sink.init(S0);
  log.c1 = sink.commit(await h.mint(S0, "r1", "100"));
  log.c2 = sink.commit(await h.mint(JSON.parse(sink.stateBlob()), "r2", "200"));
  log.c1replay_before = sink.commit(await h.mint(JSON.parse(sink.stateBlob()), "r1", "100"));   // control: refused
  if (mode === "running") corrupt(h.db);
  else { sink.close(); corrupt(h.db); try { sink = new Sink(h.db, h.cfg); log.start1 = "serves"; } catch (e) { log.start1 = String((e as Error).message); console.log(JSON.stringify(log)); h.stop(); process.exit(0); } }
  // honest host retry of r1 against the current state
  log.c1again = sink.commit(await h.mint(JSON.parse(sink.stateBlob()), "r1", "100"));
  log.reaudits = sink.reaudits;
  log.outboxR1 = sink.outbox().filter((o: any) => o.request_id === "r1").length;
  log.state = JSON.parse(sink.stateBlob()).remaining;
  log.offlineAudit = sink.audit();
  sink.close();
  try { new Sink(h.db, h.cfg).close(); log.restart = "serves"; } catch (e) { log.restart = String((e as Error).message); }
  const f = h.flush(); log.f = { emitted: f.emitted.map((e: any) => e.requestId), refused: f.refused.map((r: any) => r.requestId + ": " + r.reason) };
  log.paid = h.paid();
  h.stop();
  console.log(JSON.stringify(log));
  process.exit(log.c1again.status === "committed" && log.outboxR1 === 2 && log.restart === "serves" ? 1 : 0);
})().catch(e => { console.error(String(e && e.stack)); process.exit(3); });
