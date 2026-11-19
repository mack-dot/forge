// r-harden probe P2: a raw SQL writer who KEEPS (or restores) the schema, against the hardened sink (branch 608b5165).
// usage (cwd = tree): node --import tsx p2_sql_writer.ts <treeRoot> <scratch dir>
// One short run. Test keys only (made here). Each attack runs on a fresh copy of one honest store.
// For each attack: did the raw write land? If it landed: does a RUNNING sink halt, does a RESTART refuse, does the
// dispatcher (fresh ledger, newLedgerH0) refuse? Class: (i) defeats a claim of HARDENING_NOTES; (ii) lands and is only
// caught by an outside anchor (stated limit); (iii) no effect / refused.
// Exit 1 if any attack is class (i). Exit 0 otherwise. Exit 3 if the harness broke.
import { generateKeyPairSync, sign } from "node:crypto";
import { copyFileSync, mkdirSync, rmSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { join, resolve } from "node:path";

const [TREE0, OUT0] = process.argv.slice(2);
const TREE = resolve(TREE0), OUT = resolve(OUT0);
rmSync(OUT, { recursive: true, force: true }); mkdirSync(OUT, { recursive: true });
/* eslint-disable @typescript-eslint/no-require-imports */
const E = require(join(TREE, "ts/refund-finality/encoding.ts"));
const HM = require(join(TREE, "ts/refund-finality/sink.ts"));
const { Dispatcher } = require(join(TREE, "ts/refund-finality/dispatcher.ts"));
/* eslint-enable @typescript-eslint/no-require-imports */
const { canon, signedBytes, stateSha256, sha256hex, DOMAIN } = E;
const { publicKey, privateKey } = generateKeyPairSync("ed25519"), attacker = generateKeyPairSync("ed25519");
const pem = publicKey.export({ type: "spki", format: "pem" }) as string;
const st = (remaining: string) => ({ chargeId: "ch_1", original: "1000", remaining, refundEnabled: true });
const S0 = st("1000");
const cfg: any = { publicKeyPem: pem, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: S0 };
const genesis = HM.genesisOf(canon(S0), cfg.specLockSha256, cfg.checkerSha256, pem);
function tokObj(pre: any, rid: string, amount: any, o: { key?: any; post?: any } = {}) {
  const post = o.post ?? { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
  const body = { domain: DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: stateSha256(pre),
    requestId: rid, post, intent: { chargeId: "ch_1", requestId: rid, amount, reason: "duplicate_charge" } };
  return { body, signature: sign(null, signedBytes(body), o.key ?? privateKey).toString("base64") };
}
const tok = (pre: any, rid: string, amount: any, o: any = {}) => canon(tokObj(pre, rid, amount, o));
const intentOf = (t: string) => canon(JSON.parse(t).body.intent);
const short = (e: unknown) => String((e as Error).message).replace(/\s+/g, " ").slice(0, 140);

// honest base: rq_1 100, rq_z1 0, rq_z2 0, rq_2 50 -> remaining 850
const BASE = join(OUT, "base.sqlite");
const T = { r1: tok(st("1000"), "rq_1", "100"), z1: tok(st("900"), "rq_z1", "0"), z2: tok(st("900"), "rq_z2", "0"), r2: tok(st("900"), "rq_2", "50") };
{ const s = new HM.Sink(BASE, cfg); s.init(S0); const r = [T.r1, T.z1, T.z2, T.r2].map(t => s.commit(t).status); s.close();
  if (r.some(x => x !== "committed")) throw new Error("honest base: " + r); }
const headBase = (() => { const s = new HM.Sink(BASE, cfg); const h = s.head(); s.close(); return h; })();
const NEXT = tok(st("850"), "rq_5", "10");
const fp = (p: string): string => { const db = new DatabaseSync(p, { readOnly: true });
  const q = (sql: string) => JSON.stringify(db.prepare(sql).all());
  const r = q("SELECT type, name, sql FROM sqlite_schema ORDER BY name") + q("SELECT * FROM meta") + q("SELECT * FROM state") +
    q("SELECT * FROM settled NOT INDEXED ORDER BY seq") + q("SELECT * FROM outbox NOT INDEXED ORDER BY seq"); db.close(); return r; };
const FP_BASE = fp(BASE);
const selfOfRow = (db: DatabaseSync, seq: number) => (db.prepare("SELECT self FROM outbox WHERE seq = ?").get(seq) as any).self as string;

type Row = { id: string; what: string; write: string; running: string; restart: string; restartAnchor: string; dispatcher: string; cls: string };
const rows: Row[] = [];
let n = 0;
function attack(id: string, what: string, f: (p: string) => void, expectLegit = false): void {
  const p = join(OUT, `${++n}-${id}.sqlite`); copyFileSync(BASE, p);
  const L = join(OUT, `${n}-ledger.jsonl`);
  const pre = new Dispatcher(p, L, { ...cfg, initialStateSha256: stateSha256(S0), newLedgerH0: genesis }, () => undefined).flush();
  if (pre.emitted.length !== 4) throw new Error("ledger set-up");
  const running = new HM.Sink(p, cfg);                 // a running sink, opened before the attack
  let write = "LANDED";
  try { f(p); } catch (e) { write = "REFUSED: " + short(e); }
  if (write === "LANDED" && fp(p) === FP_BASE) write = "NO EFFECT on the stored rows or schema";
  const rc = running.commit(NEXT); running.close();
  const runningS = rc.status + (rc.reason ? " (" + rc.reason.slice(0, 70) + ")" : "");
  const start = (c: any) => { try { const s = new HM.Sink(p, c); const h = s.head(); s.close(); return "STARTED count=" + h.count; } catch (e) { return "REFUSED"; } };
  // the restart is on a fresh copy taken after the attack and before the running sink's commit is irrelevant: recopy
  const restart = start(cfg), restartAnchor = start({ ...cfg, expectedHead: headBase });
  const effects: string[] = []; let disp = "";
  try {
    const fr = new Dispatcher(p, L, { ...cfg, initialStateSha256: stateSha256(S0), newLedgerH0: genesis }, (e: any) => effects.push(e.requestId)).flush();
    disp = `emitted=${fr.emitted.length} refused=${fr.refused.length} already=${fr.alreadyDispatched}`;
  } catch (e) { disp = "ALARM: " + short(e).slice(0, 60); }
  let cls = "iii";
  if (write === "LANDED" && !expectLegit) {
    // caught without an outside anchor: the running sink halts, a restart refuses, and the dispatcher (whose ledger already
    // holds the 4 honest rows) sends nothing new from the changed rows.
    const caughtNoAnchor = runningS.includes("halted") && restart === "REFUSED" && (disp.startsWith("ALARM") || disp.startsWith("emitted=0"));
    const caughtAnchor = restartAnchor === "REFUSED" && runningS.includes("halted") && (disp.startsWith("ALARM") || disp.startsWith("emitted=0"));
    cls = caughtNoAnchor ? "detected" : caughtAnchor ? "ii" : "i";
  }
  if (expectLegit) cls = write === "LANDED" ? "legit-append" : "legit-refused";
  rows.push({ id, what, write, running: runningS, restart, restartAnchor, dispatcher: disp, cls });
}
const exec = (p: string, sql: string[], params: any[][] = []) => {
  const db = new DatabaseSync(p);
  try { db.exec("BEGIN IMMEDIATE"); sql.forEach((s, i) => { if (/^\s*PRAGMA/.test(s)) db.exec(s); else db.prepare(s).run(...(params[i] ?? [])); }); db.exec("COMMIT"); }
  catch (e) { try { db.exec("ROLLBACK"); } catch { /* none */ } throw e; } finally { db.close(); }
};
const ins = "INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (?, ?, ?, ?, ?, ?)";
const legitParams = (db: DatabaseSync | null, p: string, t: string, rid: string, seq: number) => {
  const d = db ?? new DatabaseSync(p); const prev = selfOfRow(d, seq - 1); if (!db) d.close();
  return [seq, rid, t, sha256hex(t), prev, HM.linkOf(prev, t, intentOf(t))];
};

// ---- REPLACE / IGNORE conflict clauses (recursive_triggers OFF: REPLACE deletes fire no DELETE trigger)
const rq9 = tok(st("900"), "rq_9", "50");
attack("A01", "INSERT OR REPLACE INTO settled seq=4 (replace rq_2 by rq_9)", p => { const q = legitParams(null, p, rq9, "rq_9", 4); exec(p, [ins.replace("INSERT", "INSERT OR REPLACE")], [q]); });
attack("A02", "INSERT OR REPLACE INTO settled seq=5 with existing request_id rq_2 (signed)", p => { const t = tok(st("850"), "rq_2", "10"); exec(p, [ins.replace("INSERT", "INSERT OR REPLACE")], [legitParams(null, p, t, "rq_2", 5)]); });
attack("A03", "REPLACE INTO outbox seq=4 other intent", p => exec(p, ["REPLACE INTO outbox(seq, request_id, intent, prev, self) SELECT seq, 'rq_9', replace(intent, 'rq_2', 'rq_9'), prev, self FROM outbox WHERE seq = 4"]));
attack("A04", "REPLACE INTO state back to the initial row", p => exec(p, ["REPLACE INTO state(id, blob, seq, refunded) VALUES (1, ?, 0, 0)"], [[canon(S0)]]));
attack("A05", "UPDATE OR REPLACE settled SET request_id='rq_1' WHERE seq=4", p => exec(p, ["UPDATE OR REPLACE settled SET request_id = 'rq_1' WHERE seq = 4"]));
attack("A06", "UPDATE settled SET rowid = 10 WHERE seq = 4", p => exec(p, ["UPDATE settled SET rowid = 10 WHERE seq = 4"]));
attack("A07", "INSERT OR IGNORE INTO outbox a second row for rq_1", p => exec(p, ["INSERT OR IGNORE INTO outbox(seq, request_id, intent, prev, self) SELECT 5, request_id, intent, prev, self FROM outbox WHERE seq = 1"]));
attack("A08", "DELETE FROM settled WHERE seq=4 with recursive_triggers ON/OFF", p => exec(p, ["PRAGMA recursive_triggers = OFF", "DELETE FROM settled WHERE seq = 4"]));
// ---- pragmas
attack("B01", "ignore_check_constraints=ON + forged-signature next row", p => { const t = tok(st("850"), "rq_f", "10", { key: attacker.privateKey }); exec(p, ["PRAGMA ignore_check_constraints = ON", ins], [[], legitParams(null, p, t, "rq_f", 5)]); });
attack("B02", "plain INSERT of a forged-signature next row (triggers cannot verify a signature)", p => { const t = tok(st("850"), "rq_f", "10", { key: attacker.privateKey }); exec(p, [ins], [legitParams(null, p, t, "rq_f", 5)]); });
attack("B03", "trusted_schema=OFF, foreign_keys=OFF, then a valid signed next row (a second writer)", p => { const t = tok(st("850"), "rq_6", "10"); exec(p, ["PRAGMA trusted_schema = OFF", "PRAGMA foreign_keys = OFF", ins], [[], [], legitParams(null, p, t, "rq_6", 5)]); }, true);
attack("B04", "valid signed next row with a WRONG self (garbage chain link)", p => { const t = tok(st("850"), "rq_7", "10"); const q = legitParams(null, p, t, "rq_7", 5); q[5] = "f".repeat(64); exec(p, [ins], [q]); });
// ---- type and affinity tricks (SIGNED by the real test key: a buggy key holder)
const odd: [string, any][] = [["C01", 100], ["C02", "0100"], ["C03", "-0"], ["C04", "1e2"], ["C05", "9223372036854775808"], ["C06", " 10"], ["C07", "10.0"], ["C08", 10.5], ["C09", "١٠"]];
for (const [id, amt] of odd) {
  attack(id, "signed next row with amount " + JSON.stringify(amt), p => {
    const post = { ...st("850"), remaining: (typeof amt === "string" && /^[0-9]+$/.test(amt)) ? (850n - BigInt(amt)).toString() : "840" };
    const t = tok(st("850"), "rq_" + id, amt, { post }); exec(p, [ins], [legitParams(null, p, t, "rq_" + id, 5)]);
  });
}
attack("C10", "signed next row, amount > remaining and > original-refunded (900)", p => { const t = tok(st("850"), "rq_big", "900", { post: { ...st("850"), remaining: "0" } }); exec(p, [ins], [legitParams(null, p, t, "rq_big", 5)]); });
attack("C11", "signed next row, request_id column 'RQ_1' vs token 'rq_1' (case)", p => { const t = tok(st("850"), "RQ_1", "10"); const q = legitParams(null, p, t, "RQ_1", 5); q[1] = "rq_1"; exec(p, [ins], [q]); });
attack("C12", "signed next row, request_id 'RQ_1' (differs from rq_1 only by case) - a legitimate new id", p => { const t = tok(st("850"), "RQ_1", "10"); exec(p, [ins], [legitParams(null, p, t, "RQ_1", 5)]); }, true);
// ---- temp objects in the attacker's connection
attack("D01", "TEMP TABLE settled shadows main.settled in the attacker's connection", p => { const db = new DatabaseSync(p); db.exec("CREATE TEMP TABLE settled(seq, request_id, token, token_sha256, prev, self)"); db.prepare(ins).run(4, "rq_x", "{}", "0", "0", "0"); db.prepare("DELETE FROM settled").run(); db.close(); });
attack("D02", "TEMP TRIGGER on main.outbox AFTER INSERT deletes the new outbox row, then a valid commit", p => {
  const db = new DatabaseSync(p); db.exec("CREATE TEMP TRIGGER t1 AFTER INSERT ON main.outbox BEGIN DELETE FROM main.outbox WHERE seq = NEW.seq; END");
  const t = tok(st("850"), "rq_8", "10"); try { db.exec("BEGIN IMMEDIATE"); db.prepare(ins).run(...legitParams(db, p, t, "rq_8", 5)); db.exec("COMMIT"); } catch (e) { db.exec("ROLLBACK"); db.close(); throw e; } db.close(); });
attack("D03", "TEMP TRIGGER BEFORE INSERT ON main.settled RAISE(IGNORE) then INSERT OR REPLACE seq=4", p => {
  const db = new DatabaseSync(p); db.exec("CREATE TEMP TRIGGER t2 BEFORE INSERT ON main.settled BEGIN SELECT RAISE(IGNORE); END");
  db.prepare(ins.replace("INSERT", "INSERT OR REPLACE")).run(...legitParams(db, p, rq9, "rq_9", 4)); db.close(); });
attack("D04", "VACUUM INTO a copy (original untouched)", p => { const db = new DatabaseSync(p); db.exec(`VACUUM INTO '${p}.copy'`); db.close(); rmSync(p + ".copy", { force: true }); });
// ---- drop trigger / writable_schema, edit, restore the same text (SCHEMA-KEPT afterwards)
function dropEditRestore(p: string, names: string[], edit: (db: DatabaseSync) => void): void {
  const db = new DatabaseSync(p);
  const saved = names.map(nm => (db.prepare("SELECT sql FROM sqlite_schema WHERE type='trigger' AND name=?").get(nm) as any).sql as string);
  db.exec("BEGIN IMMEDIATE"); for (const nm of names) db.exec(`DROP TRIGGER ${nm}`); edit(db); for (const s of saved) db.exec(s); db.exec("COMMIT"); db.close();
}
attack("E01", "DROP 4 triggers; roll back the last commit (rq_2); restore the same trigger text", p => dropEditRestore(p, ["h_settled_bd", "h_outbox_bd", "h_state_bu"], db => {
  db.exec("DELETE FROM outbox WHERE seq = 4"); db.exec("DELETE FROM settled WHERE seq = 4");
  db.prepare("UPDATE state SET blob = ?, seq = 3, refunded = 100 WHERE id = 1").run(canon(st("900"))); }));
attack("E02", "DROP triggers; D14 swap of row 4 rq_2 (50) for an uncommitted signed rq_3 (50) on the same pre-state; chain recomputed", p => dropEditRestore(p, ["h_settled_bu", "h_outbox_bu"], db => {
  const t = tok(st("900"), "rq_3", "50"); const prev = selfOfRow(db, 3); const self = HM.linkOf(prev, t, intentOf(t));
  db.prepare("UPDATE settled SET request_id = 'rq_3', token = ?, token_sha256 = ?, self = ? WHERE seq = 4").run(t, sha256hex(t), self);
  db.prepare("UPDATE outbox SET request_id = 'rq_3', intent = ?, self = ? WHERE seq = 4").run(intentOf(t), self); }));
attack("E03", "writable_schema: neuter h_settled_bu text, reopen, edit row 4 reason, restore text", p => {
  let db = new DatabaseSync(p); db.exec("PRAGMA writable_schema = ON");
  const old = (db.prepare("SELECT sql FROM sqlite_schema WHERE name = 'h_settled_bu'").get() as any).sql as string;
  db.prepare("UPDATE sqlite_schema SET sql = ? WHERE name = 'h_settled_bu'").run("CREATE TRIGGER h_settled_bu BEFORE UPDATE ON settled WHEN 0 BEGIN SELECT 1; END"); db.close();
  db = new DatabaseSync(p); db.prepare("UPDATE settled SET token = replace(token, 'duplicate_charge', 'fraudulent') WHERE seq = 4").run(); db.close();
  db = new DatabaseSync(p); db.exec("PRAGMA writable_schema = ON"); db.prepare("UPDATE sqlite_schema SET sql = ? WHERE name = 'h_settled_bu'").run(old); db.close(); });
attack("E04", "journal_mode=WAL switched by a writer (file header only)", p => { const db = new DatabaseSync(p); db.exec("PRAGMA journal_mode = WAL"); db.close(); });

let fail = 0;
for (const r of rows) { console.log(JSON.stringify(r)); if (r.cls === "i") fail++; }
console.log(`attacks=${rows.length} class_i=${fail} landed=${rows.filter(r => r.write === "LANDED").length}`);
rmSync(OUT, { recursive: true, force: true });
console.log(fail ? "DEFEATED" : "SAFE");
process.exit(fail ? 1 : 0);
