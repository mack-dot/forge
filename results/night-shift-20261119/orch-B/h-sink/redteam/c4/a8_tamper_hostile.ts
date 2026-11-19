// a8: a table of database-writer tampers (no key, no config) on an honest store [r1 100, z 0, r2 200], sink
// stopped. For each: does the v6 sink start; if it starts, does the next honest commit + dispatcher flush (fresh
// ledger, so the dispatcher has no memory) emit more than the charge or two effects for one request id; and does
// the offline audit() agree with the start-up audit.
// Exit 1 = some tamper that the start-up audit ACCEPTS leads to money > original or a duplicate request id at the
// dispatcher, or a listed "must refuse" tamper starts. 0 = safe. 3 = harness error.
import { copyFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { setup, Sink, Dispatcher, S0, E } from "./common";
const [work] = process.argv.slice(2);
const T: [string, boolean, string][] = [   // name, must refuse?, SQL
  ["state-only rollback to genesis", true, `UPDATE state SET blob = (SELECT initial_state FROM meta)`],
  ["settled tail truncated only", true, `DELETE FROM settled WHERE seq = (SELECT MAX(seq) FROM settled)`],
  ["outbox tail truncated only", true, `DELETE FROM outbox WHERE seq = (SELECT MAX(seq) FROM outbox)`],
  ["settled+outbox tail truncated, state kept", true, `DELETE FROM settled WHERE seq = (SELECT MAX(seq) FROM settled); DELETE FROM outbox WHERE seq = (SELECT MAX(seq) FROM outbox)`],
  ["sqlite_sequence zeroed", false, `UPDATE sqlite_sequence SET seq = 0`],
  ["all seq negated in reverse (order reversed)", true, `UPDATE settled SET seq = -seq; UPDATE outbox SET seq = -seq`],
  ["seq shifted to negative, order kept", false, `UPDATE settled SET seq = seq - 1000; UPDATE outbox SET seq = seq - 1000`],
  ["settled+outbox seq gaps", false, `UPDATE settled SET seq = seq * 10; UPDATE outbox SET seq = seq * 7`],
  ["request_id of r1 as BLOB in settled", true, `UPDATE settled SET request_id = CAST(request_id AS BLOB) WHERE request_id = 'r1'`],
  ["token of r1 as BLOB", true, `UPDATE settled SET token = CAST(token AS BLOB) WHERE request_id = 'r1'`],
  ["user_version and application_id", false, `PRAGMA user_version = 7; PRAGMA application_id = 99`],
  ["meta rows deleted (legacy path)", false, `DELETE FROM meta`],
  ["second state row (CHECK ignored)", false, `PRAGMA ignore_check_constraints = ON; INSERT INTO state(id, blob, seq, refunded) VALUES (2, (SELECT initial_state FROM meta), 0, 0)`],
  ["outbox r1 and r2 seq swapped", true, `UPDATE outbox SET seq = -1 WHERE request_id='r1'; UPDATE outbox SET seq = (SELECT seq FROM settled WHERE request_id='r1') WHERE request_id='r2'; UPDATE outbox SET seq = (SELECT seq FROM settled WHERE request_id='r2') WHERE seq = -1`],
  ["unknown meta key", true, `INSERT INTO meta VALUES (2, 'x', 'y', 'z', 'w', 'v')`],
  ["temp trigger (per connection)", false, `CREATE TEMP TRIGGER t AFTER INSERT ON main.settled BEGIN DELETE FROM main.outbox; END`],
];
(async () => {
  const h = await setup(work);
  const base = join(work, "base.sqlite");
  { const s = new Sink(base, h.cfg); s.init(S0);
    s.commit(await h.mint(S0, "r1", "100")); const p1 = JSON.parse(s.stateBlob());
    s.commit(await h.mint(p1, "z", "0")); s.commit(await h.mint(p1, "r2", "200")); s.close(); }
  const rows: any[] = []; let bad = false;
  for (let i = 0; i < T.length; i++) {
    const [name, mustRefuse, sql] = T[i];
    const db = join(work, `t${i}.sqlite`); copyFileSync(base, db);
    const a = new DatabaseSync(db); let applied = "ok";
    // h-sink HOSTILE variant: the writer first drops every trigger and ignores CHECKs, applies the tamper, restores the triggers.
    const trig = a.prepare("SELECT name, sql FROM sqlite_schema WHERE type = 'trigger'").all() as any[];
    try { a.exec("PRAGMA ignore_check_constraints = ON"); for (const t of trig) a.exec(`DROP TRIGGER ${t.name}`); a.exec(sql); } catch (e) { applied = String((e as Error).message); }
    try { for (const t of trig) a.exec(t.sql); } catch { /* restored partly */ } a.close();
    const row: any = { i, name, applied };
    try {
      const s = new Sink(db, h.cfg); row.start = "serves";
      row.offlineAudit = s.audit().length;
      const st = JSON.parse(s.stateBlob()); row.state = st.remaining;
      row.commit = s.commit(await h.mint(st, "r3", "50")).status;
      s.close();
      const eff: any[] = [];
      const f = new Dispatcher(db, join(work, `t${i}-ledger.jsonl`), h.dcfg, (e: any) => eff.push(e)).flush();
      const ids = eff.map(e => e.requestId); row.emitted = ids; row.refused = f.refused.length;
      row.paid = eff.reduce((x, e) => x + Number(JSON.parse(e.intent).amount), 0);
      if (row.paid > 1000 || new Set(ids).size !== ids.length) bad = true;
      if (mustRefuse) bad = true;
    } catch (e) { row.start = "refuses: " + String((e as Error).message).slice(0, 90); }
    rows.push(row);
  }
  h.stop();
  for (const r of rows) console.log(JSON.stringify(r));
  process.exit(bad ? 1 : 0);
})().catch(e => { console.error(String(e && e.stack)); process.exit(3); });
