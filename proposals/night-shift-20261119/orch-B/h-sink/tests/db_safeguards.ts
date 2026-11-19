// h-sink E1 (night shift 2026-11-19, Orchestrator B). Direct SQL-level tests of the hardened sink's database safeguards
// S1-S7: per safeguard a POSITIVE test (the sink's own commit path, zero amounts included) and NEGATIVE tests (a raw second
// connection tries the forbidden write; it must ABORT with the trigger's message). Where the same raw statement fits the
// v6 schema, it is also run against a v6 store: there it must NOT abort (the regression fails on the unfixed code).
// One short run. Test keys are made in this process. A TEST, not a proof.
// Usage (cwd = changed tree): node --import tsx db_safeguards.ts <tree> <v6 sink.ts> <out dir>
import { execFileSync } from "node:child_process";
import { generateKeyPairSync, sign } from "node:crypto";
import { copyFileSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";

const [TREE, V6PATH, OUT] = process.argv.slice(2);
rmSync(OUT, { recursive: true, force: true }); mkdirSync(OUT, { recursive: true });
// eslint-disable-next-line @typescript-eslint/no-require-imports
const E = require(TREE + "/ts/refund-finality/encoding.ts");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const HM = require(TREE + "/ts/refund-finality/sink.ts"); const H = HM.Sink;
// eslint-disable-next-line @typescript-eslint/no-require-imports
const V6 = require(V6PATH).Sink;
// eslint-disable-next-line @typescript-eslint/no-require-imports
const Dispatcher = require(TREE + "/ts/refund-finality/dispatcher.ts").Dispatcher;
const { canon, signedBytes, stateSha256, sha256hex, DOMAIN } = E;

const { publicKey, privateKey } = generateKeyPairSync("ed25519"), attacker = generateKeyPairSync("ed25519");
const pem = publicKey.export({ type: "spki", format: "pem" }) as string;
const st = (remaining: string, cid = "ch_1", original = "1000", refundEnabled = true) => ({ chargeId: cid, original, remaining, refundEnabled });
const S0 = st("1000");
const cfg: any = { publicKeyPem: pem, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: S0 };
type BodyOpt = { amount?: string; post?: any; intentCid?: string; intentRid?: string; key?: any };
function tokObj(pre: any, rid: string, amount: string, o: BodyOpt = {}) {
  const post = o.post ?? { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
  const body = { domain: DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: stateSha256(pre),
    requestId: rid, post, intent: { chargeId: o.intentCid ?? pre.chargeId, requestId: o.intentRid ?? rid, amount, reason: "duplicate_charge" } };
  return { body, signature: sign(null, signedBytes(body), o.key ?? privateKey).toString("base64") };
}
const tok = (pre: any, rid: string, amount: string, o: BodyOpt = {}) => canon(tokObj(pre, rid, amount, o));
const T = { r1: tok(st("1000"), "rq_1", "100"), z1: tok(st("900"), "rq_z1", "0"), z2: tok(st("900"), "rq_z2", "0"), r2: tok(st("900"), "rq_2", "50") };

const rows: any[] = [];
let bad = 0;
const rec = (safeguard: string, name: string, expect: string, got: string, pass: boolean) => {
  rows.push({ safeguard, name, expect, got, pass }); if (!pass) bad++;
  console.log(`${pass ? "PASS" : "FAIL"} ${safeguard.padEnd(3)} ${name} | expect: ${expect} | got: ${got}`);
};
const short = (e: unknown) => String((e as Error).message).slice(0, 150);
// The honest base store: rq_1 (100), rq_z1 (0), rq_z2 (0), rq_2 (50). State after: remaining 850.
let n = 0;
function honest(S: any, label: string): string {
  const p = `${OUT}/${++n}-${label}.sqlite`; const s = new S(p, cfg); s.init(S0);
  const out = [T.r1, T.z1, T.z2, T.r2].map(t => s.commit(t).status); s.close();
  if (out.some(x => x !== "committed")) throw new Error("honest base " + label + ": " + out);
  return p;
}
const raw = (p: string, f: (db: DatabaseSync) => void): string => {
  const db = new DatabaseSync(p);
  try { db.exec("BEGIN IMMEDIATE"); f(db); db.exec("COMMIT"); return "OK (no abort)"; }
  catch (e) { try { db.exec("ROLLBACK"); } catch { /* none */ } return "ABORT: " + short(e); }
  finally { db.close(); }
};
const restart = (S: any, p: string, c: any = cfg) => { try { const s = new S(p, c); const h = typeof s.head === "function" ? s.head() : undefined; s.close(); return "STARTED" + (h ? ` head=${h.count}` : ""); } catch (e) { return "REFUSED: " + short(e).replace(/^h1 sink refuses to serve: start-up audit \(schema, integrity, initial charge, AuditV5 replay, chain, anchor\) is false/, "") ; } };
const counts = (p: string) => { const db = new DatabaseSync(p); try { return JSON.stringify(db.prepare("SELECT (SELECT COUNT(*) FROM settled) s, (SELECT COUNT(*) FROM outbox) o, (SELECT blob FROM state) b").get()); } finally { db.close(); } };
// A raw next commit with the hardened column shape: correct seq and prev; self correct unless told otherwise.
function rawCommit(db: DatabaseSync, token: string, o: { rid?: string; prev?: string; self?: string; seq?: number; verb?: string } = {}) {
  const t = JSON.parse(token);
  const last = db.prepare("SELECT seq, self FROM outbox ORDER BY seq DESC LIMIT 1").get() as any;
  const g = (db.prepare("SELECT genesis FROM meta").get() as any).genesis;
  const seq = o.seq ?? (last ? last.seq + 1 : 1), prev = o.prev ?? (last ? last.self : g), rid = o.rid ?? t.body.requestId;
  const self = o.self ?? HM.linkOf(prev, token, canon(t.body.intent));
  db.prepare(`${o.verb ?? "INSERT"} INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (?, ?, ?, ?, ?, ?)`).run(seq, rid, token, sha256hex(token), prev, self);
}
const isAbort = (got: string, tag: string) => got.startsWith("ABORT") && got.includes(tag);
const neg = (sg: string, name: string, tag: string, f: (db: DatabaseSync) => void, v6f?: (db: DatabaseSync) => void) => {
  const p = honest(H, "h-" + sg); const before = counts(p); const got = raw(p, f); const after = counts(p);
  rec(sg, "NEG " + name, `ABORT containing "${tag}"; store unchanged`, got + (before === after ? "; unchanged" : "; CHANGED"), isAbort(got, tag) && before === after);
  if (v6f) { const q = honest(V6, "v6-" + sg); const g6 = raw(q, v6f); rec(sg, "v6-control " + name, "OK (no abort) on the v6 schema", g6, g6.startsWith("OK")); }
};
const zeroIntent = (rid: string) => canon({ chargeId: "ch_1", requestId: rid, amount: "0", reason: "duplicate_charge" });

// ---------------- POSITIVE: the sink's own commit path (all safeguards at once), zero amounts included.
{
  const p = `${OUT}/pos.sqlite`; const s = new H(p, cfg); s.init(S0);
  const out = [T.r1, T.z1, T.z2, T.r2].map(t => s.commit(t).status);
  const replay = s.commit(T.z1).status, h = s.head(), audit = s.audit(); s.close();
  const effects: string[] = [];
  const fl = new Dispatcher(p, `${OUT}/pos-ledger.jsonl`, { ...cfg, initialStateSha256: stateSha256(S0), newLedgerH0: HM.genesisOf(canon(S0), cfg.specLockSha256, cfg.checkerSha256, pem) }, (e: any) => effects.push(e.requestId)).flush();
  rec("ALL", "POS sink commits r1(100), z1(0), z2(0), r2(50); replay z1", "4 committed; replayed; head 4; audit 0 problems; dispatcher 4 effects; restart STARTED head=4",
    `${out.join(",")}; ${replay}; head ${h.count}; audit ${audit.length}; effects ${effects.length} refused ${fl.refused.length}; restart ${restart(H, p)}`,
    out.every(x => x === "committed") && replay === "replayed" && h.count === 4 && audit.length === 0 && effects.length === 4 && restart(H, p) === "STARTED head=4");
  const db = new DatabaseSync(p); const c = db.prepare("SELECT (SELECT COUNT(*) FROM settled) s, (SELECT COUNT(*) FROM outbox) o, (SELECT seq FROM state) sq, (SELECT refunded FROM state) rf, (SELECT json_extract(blob,'$.remaining') FROM state) rem").get() as any;
  const idx = db.prepare("SELECT name, \"unique\" AS u FROM pragma_index_list('outbox') UNION ALL SELECT name, \"unique\" FROM pragma_index_list('settled')").all() as any[]; db.close();
  rec("S1", "POS unique indexes on settled.request_id and outbox.request_id", "2 unique indexes", `${idx.filter(i => i.u === 1).length} unique: ${idx.map(i => i.name).join(",")}`, idx.filter(i => i.u === 1).length === 2);
  rec("S4", "POS state columns after 4 commits", "settled 4, outbox 4, seq 4, refunded 150, remaining 850", JSON.stringify(c), c.s === 4 && c.o === 4 && c.sq === 4 && c.rf === 150 && c.rem === "850");
  // Zero amount on a charge whose remaining is 0 (largest amount first).
  const M = "9223372036854775807", p2 = `${OUT}/pos-max.sqlite`, c2 = { ...cfg, initialState: st(M, "ch_1", M) }; const s2 = new H(p2, c2); s2.init(st(M, "ch_1", M));
  const a = s2.commit(tok(st(M, "ch_1", M), "rq_max", M)).status, b = s2.commit(tok(st("0", "ch_1", M), "rq_after", "0")).status, d = s2.commit(tok(st("0", "ch_1", M), "rq_one", "1")).status; s2.close();
  rec("S4", "POS amount 2^63-1 on a 2^63-1 charge, then 0, then 1", "committed, committed, rejected; restart STARTED", `${a}, ${b}, ${d}; restart ${restart(H, p2, c2)}`,
    a === "committed" && b === "committed" && d === "rejected" && restart(H, p2, c2).startsWith("STARTED"));
  // Non-BMP and escapes in ids (json_quote / json_extract text equality with canon).
  const cid = "ch_\u{1F600}\"\\\u0001 é\t/", rid = "rq_\u{10FFFF}\u{1F4A9}\\\"\u007f", c6 = { ...cfg, initialState: st("1000", cid) }, p3 = `${OUT}/pos-esc.sqlite`;
  const s3 = new H(p3, c6); s3.init(st("1000", cid)); const e1 = s3.commit(tok(st("1000", cid), rid, "100")); const e2 = s3.commit(tok(st("900", cid), rid + "\u{1F600}", "0")); s3.close();
  rec("S3", "POS escapes and non-BMP text in charge id and request id", "committed, committed; restart STARTED", `${e1.status}${e1.reason ? "(" + e1.reason + ")" : ""}, ${e2.status}${e2.reason ? "(" + e2.reason + ")" : ""}; restart ${restart(H, p3, c6)}`,
    e1.status === "committed" && e2.status === "committed" && restart(H, p3, c6).startsWith("STARTED"));
}

// ---------------- S1 request identity
neg("S1", "settled row that reuses request id rq_z1 (next seq, right prev)", "h-sink S1/S2/S3/S6", db => rawCommit(db, tok(st("850"), "rq_z1", "0")),
  db => db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES ('rq_z1_dup', 'x', 'y')").run());
neg("S1", "INSERT OR REPLACE of settled with an existing request id (REPLACE would delete without a delete trigger)", "h-sink S1/S2/S3/S6",
  db => rawCommit(db, tok(st("850"), "rq_z1", "0"), { verb: "INSERT OR REPLACE" }));
neg("S1", "settled request_id column is not the token's request id", "h-sink S1/S2/S3/S6", db => rawCommit(db, tok(st("850"), "rq_3", "0"), { rid: "rq_other" }));
neg("S1", "token whose intent request id is another id", "h-sink S1/S2/S3/S6", db => rawCommit(db, tok(st("850"), "rq_3", "0", { intentRid: "rq_victim" })));

// ---------------- S2 atomic effect commit
neg("S2", "outbox row without a settled row", "h-sink S1/S2/S4", db => {
  const last = db.prepare("SELECT self FROM outbox ORDER BY seq DESC LIMIT 1").get() as any;
  db.prepare("INSERT INTO outbox(seq, request_id, intent, prev, self) VALUES (5, 'rq_ghost', ?, ?, ?)").run(zeroIntent("rq_ghost"), last.self, "a".repeat(64)); },
  db => db.prepare("INSERT INTO outbox(request_id, intent) VALUES ('rq_ghost', ?)").run(zeroIntent("rq_ghost")));
neg("S2", "state update alone (a valid next state text, seq + 1)", "h-sink S2/S4",
  db => db.prepare("UPDATE state SET blob = ?, seq = seq + 1, refunded = refunded + 10 WHERE id = 1").run(canon(st("840"))),
  db => db.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(st("840"))));
neg("S2", "state update alone, seq unchanged (the v6 'raw UPDATE state' shape)", "h-sink S2/S4",
  db => db.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(st("840"))));
neg("S2", "INSERT OR REPLACE of the state row", "h-sink S2", db => db.prepare("INSERT OR REPLACE INTO state(id, blob, seq, refunded) VALUES (1, ?, 4, 150)").run(canon(st("840"))));
neg("S2", "outbox row inserted again for the last commit (seq 4, its own values)", "h-sink S1/S2/S4", db => {
  const o = db.prepare("SELECT * FROM outbox WHERE seq = 4").get() as any;
  db.prepare("INSERT OR REPLACE INTO outbox(seq, request_id, intent, prev, self) VALUES (?, ?, ?, ?, ?)").run(o.seq, o.request_id, o.intent, o.prev, o.self); });
{ // A raw writer who keeps the schema: ONE statement writes all three rows or none.
  const p = honest(H, "h-S2-one-statement"); const got = raw(p, db => rawCommit(db, tok(st("850"), "rq_3", "10", { key: attacker.privateKey })));
  rec("S2", "raw complete next commit (attacker key; one INSERT into settled)", "OK; settled 5, outbox 5, state remaining 840 together; restart REFUSED (signature)",
    `${got}; ${counts(p)}; restart ${restart(H, p)}`, got.startsWith("OK") && counts(p).includes('"s":5,"o":5') && counts(p).includes('840') && restart(H, p).startsWith("REFUSED"));
}

// ---------------- S3 charge binding
neg("S3", "UPDATE meta charge id", "h-sink S3: meta is immutable", db => db.exec("UPDATE meta SET charge_id = 'ch_2'"), db => db.exec("UPDATE meta SET v = 'x'"));
neg("S3", "DELETE meta", "h-sink S3: meta is immutable", db => db.exec("DELETE FROM meta"), db => db.exec("DELETE FROM meta"));
neg("S3", "second meta row", "h-sink S3: meta is written once", db => db.prepare("INSERT INTO meta(id, format, charge_id, initial_state, initial_state_sha256, genesis) VALUES (2, 'forge-sink-h1', 'ch_2', ?, ?, ?)").run(canon(st("1000", "ch_2")), "a".repeat(64), "b".repeat(64)));
neg("S3", "token intent for another charge id (zero amount)", "h-sink S1/S2/S3/S6", db => rawCommit(db, tok(st("850"), "rq_3", "0", { intentCid: "ch_2" })));
neg("S3", "token post state for another charge id", "h-sink S1/S2/S3/S6", db => rawCommit(db, tok(st("850"), "rq_3", "0", { post: st("850", "ch_2") })));

// ---------------- S4 cumulative refund limit and money text
neg("S4", "amount above remaining (850 -> 900)", "h-sink S1/S2/S4", db => rawCommit(db, tok(st("850"), "rq_3", "900", { post: st("0") })));
neg("S4", "amount with a leading zero ('010')", "h-sink S1/S2/S4", db => rawCommit(db, tok(st("850"), "rq_3", "010", { post: st("840") })));
neg("S4", "amount 2^63 (19 digits, above 9223372036854775807)", "h-sink S1/S2/S4", db => rawCommit(db, tok(st("850"), "rq_3", "9223372036854775808", { post: st("0") })));
neg("S4", "amount with a sign ('-10')", "h-sink S1/S2/S4", db => rawCommit(db, tok(st("850"), "rq_3", "-10", { post: st("860") })));
neg("S4", "post remaining not decreased (amount 10, remaining stays 850)", "h-sink S2/S4", db => rawCommit(db, tok(st("850"), "rq_3", "10", { post: st("850") })));
neg("S4", "post remaining reset upward (zero amount, remaining 1000)", "h-sink S2/S4", db => rawCommit(db, tok(st("850"), "rq_3", "0", { post: st("1000") })));
neg("S4", "post changes original (amount 10, original 2000)", "h-sink S2/S4", db => rawCommit(db, tok(st("850"), "rq_3", "10", { post: st("840", "ch_1", "2000") })));
neg("S4", "post switches refunds off (amount 0)", "h-sink S2/S4", db => rawCommit(db, tok(st("850"), "rq_3", "0", { post: st("850", "ch_1", "1000", false) })));
{ // S7 at the SQL level: meta with original above MaxMoney, in a fresh store with the hardened schema.
  const p = `${OUT}/s7-sql.sqlite`; const db = new DatabaseSync(p); db.exec(HM.SINK_DDL); db.close();
  const big = canon(st("9999999999999999999", "ch_1", "9999999999999999999"));
  const got = raw(p, db => db.prepare("INSERT INTO meta(id, format, charge_id, initial_state, initial_state_sha256, genesis) VALUES (1, 'forge-sink-h1', 'ch_1', ?, ?, ?)").run(big, sha256hex(big), "c".repeat(64)));
  rec("S7", "NEG raw meta insert: original 9999999999999999999 (above MaxMoney)", "ABORT h-sink S7", got, isAbort(got, "h-sink S7"));
  const gotOk = raw(p, db => db.prepare("INSERT INTO meta(id, format, charge_id, initial_state, initial_state_sha256, genesis) VALUES (1, 'forge-sink-h1', 'ch_1', ?, ?, ?)").run(canon(S0), sha256hex(canon(S0)), HM.genesisOf(canon(S0), cfg.specLockSha256, cfg.checkerSha256, pem)));
  rec("S7", "POS raw meta insert of a valid charge makes the state row (trigger)", "OK; state row = initial", `${gotOk}; ${counts(p)}`, gotOk.startsWith("OK") && counts(p).includes('"s":0,"o":0'));
}
for (const [label, init] of [["original above MaxMoney", st("9999999999999999999", "ch_1", "9999999999999999999")], ["refunds disabled", st("1000", "ch_1", "1000", false)],
  ["remaining above original", st("1001")], ["empty charge id", st("1000", "")]] as [string, any][]) {
  const c = { ...cfg, initialState: init };
  const h = restart(H, `${OUT}/s7-${++n}.sqlite`, c), v = restart(V6, `${OUT}/s7-v6-${n}.sqlite`, c);
  rec("S7", `NEG configured initial charge: ${label}`, "hardened REFUSED; (v6 control: STARTED)", `hardened ${h.slice(0, 90)}; v6 ${v.slice(0, 40)}`, h.startsWith("REFUSED") && (label === "empty charge id" || v.startsWith("STARTED")));
}

// ---------------- S5 append-only
neg("S5", "Z1: delete the middle zero-amount row rq_z1 (settled and outbox)", "h-sink S5", db => db.exec("DELETE FROM settled WHERE request_id='rq_z1'; DELETE FROM outbox WHERE request_id='rq_z1'"),
  db => db.exec("DELETE FROM settled WHERE request_id='rq_z1'; DELETE FROM outbox WHERE request_id='rq_z1'"));
neg("S5", "delete all outbox rows", "h-sink S5", db => db.exec("DELETE FROM outbox"), db => db.exec("DELETE FROM outbox"));
neg("S5", "renumber settled seq", "h-sink S5", db => db.exec("UPDATE settled SET seq = seq + 100"), db => db.exec("UPDATE settled SET seq = seq + 100"));
neg("S5", "rewrite an outbox intent amount", "h-sink S5", db => db.exec(`UPDATE outbox SET intent = replace(intent, '"amount":"100"', '"amount":"900"')`),
  db => db.exec(`UPDATE outbox SET intent = replace(intent, '"amount":"100"', '"amount":"900"')`));
neg("S5", "delete the state row", "h-sink S5", db => db.exec("DELETE FROM state"), db => db.exec("DELETE FROM state"));
{ // A writer who DROPS a trigger: SQL no longer stops it; the start-up schema check does.
  const p = honest(H, "h-S5-drop"); const got = raw(p, db => db.exec("DROP TRIGGER h_settled_bd; DROP TRIGGER h_outbox_bd; DELETE FROM settled WHERE request_id='rq_z1'; DELETE FROM outbox WHERE request_id='rq_z1'"));
  rec("S5", "triggers dropped, then Z1 delete", "OK (SQL cannot stop it); restart REFUSED (schema)", `${got}; restart ${restart(H, p)}`, got.startsWith("OK") && restart(H, p).includes("schema"));
  // ... and restored with the same text: schema check passes; the chain refuses (row 3's prev is not row 1's self).
  const db = new DatabaseSync(`${OUT}/ddl.sqlite`); db.exec(HM.SINK_DDL);
  const sql = (db.prepare("SELECT name, sql FROM sqlite_schema WHERE name IN ('h_settled_bd','h_outbox_bd')").all() as any[]).map(r => r.sql + ";").join("\n"); db.close();
  const got2 = raw(p, d => d.exec(sql));
  rec("S5", "same triggers restored with the same text", "OK; restart REFUSED (seq gap or chain link)", `${got2}; restart ${restart(H, p)}`, got2.startsWith("OK") && /seq is not contiguous|chain link/.test(restart(H, p)));
}
{ // sqlite3 shell: `.dbconfig enable_trigger off` disables triggers for that connection WITHOUT changing the schema.
  const p = honest(H, "h-S5-dbconfig"); let got: string;
  try { execFileSync("/usr/bin/sqlite3", [p, ".dbconfig enable_trigger off", "DELETE FROM settled WHERE request_id='rq_z1'; DELETE FROM outbox WHERE request_id='rq_z1';"], { env: { PATH: "/usr/bin:/bin" }, stdio: "pipe" }); got = "OK (no abort)"; }
  catch (e) { got = "ABORT: " + String((e as any).stderr ?? e).slice(0, 120); }
  rec("S5", "sqlite3 shell `.dbconfig enable_trigger off`, then Z1 delete", "OK (triggers off; schema unchanged); restart REFUSED (seq gap or chain link)", `${got}; ${counts(p)}; restart ${restart(H, p)}`,
    got.startsWith("OK") && /seq is not contiguous|chain link/.test(restart(H, p)));
}

// ---------------- S6 row-log chain and anchor
neg("S6", "settled row whose prev is not the last self", "h-sink S1/S2/S3/S6", db => rawCommit(db, tok(st("850"), "rq_3", "0"), { prev: "0".repeat(64) }));
neg("S6", "settled row with the right prev but seq + 2 (gap)", "h-sink S1/S2/S3/S6", db => rawCommit(db, tok(st("850"), "rq_3", "0"), { seq: 6 }));
{
  const p = honest(H, "h-S6-self"); const got = raw(p, db => rawCommit(db, tok(st("850"), "rq_3", "10"), { self: "e".repeat(64) }));
  rec("S6", "raw next commit, validly signed, right prev, WRONG self (SQL cannot hash)", "OK; restart REFUSED (chain link)", `${got}; restart ${restart(H, p)}`, got.startsWith("OK") && restart(H, p).includes("chain link"));
  const q = honest(H, "h-S6-good"); const got2 = raw(q, db => rawCommit(db, tok(st("850"), "rq_3", "10")));
  rec("S6", "raw next commit, validly signed (key holder), right prev and self", "OK; restart STARTED head=5 (a key holder who writes authorized rows is a legitimate writer)", `${got2}; restart ${restart(H, q)}`, got2.startsWith("OK") && restart(H, q) === "STARTED head=5");
}
{ // expectedHead: equal -> start; prefix of the store (store extends it) -> start; other hash, longer count -> refuse.
  const p = honest(H, "h-S6-anchor"); const s = new H(p, cfg); const h4 = s.head(); s.close();
  const p3 = `${OUT}/anchor3.sqlite`; const s3 = new H(p3, cfg); s3.init(S0); for (const t of [T.r1, T.z1, T.z2]) s3.commit(t); const h3 = s3.head(); s3.close();
  const r = (hd: any) => restart(H, p, { ...cfg, expectedHead: hd });
  const res = [r(h4), r(h3), r({ count: 4, chainHash: "f".repeat(64) }), r({ count: 5, chainHash: h4.chainHash }), r({ count: 0, chainHash: HM.genesisOf(canon(S0), cfg.specLockSha256, cfg.checkerSha256, pem) })];
  rec("S6", "expectedHead = head; = an earlier head; other hash; count 5; genesis", "STARTED, STARTED, REFUSED, REFUSED, STARTED", res.map(x => x.slice(0, 20)).join(", "),
    res[0].startsWith("STARTED") && res[1].startsWith("STARTED") && res[2].startsWith("REFUSED") && res[3].startsWith("REFUSED") && res[4].startsWith("STARTED"));
  // HOSTILE full rewrite: drop all triggers, delete rq_z1, renumber, recompute the (unkeyed) chain, restore the triggers.
  const db = new DatabaseSync(`${OUT}/ddl.sqlite`);
  const trig = (db.prepare("SELECT name, sql FROM sqlite_schema WHERE type = 'trigger' ORDER BY name").all() as any[]); db.close();
  const got = raw(p, d => {
    for (const t of trig) d.exec(`DROP TRIGGER ${t.name}`);
    d.exec("DELETE FROM settled WHERE request_id='rq_z1'; DELETE FROM outbox WHERE request_id='rq_z1'; UPDATE settled SET seq = seq - 1 WHERE seq > 2; UPDATE outbox SET seq = seq - 1 WHERE seq > 2; UPDATE state SET seq = 3");
    let prev = (d.prepare("SELECT genesis FROM meta").get() as any).genesis;
    for (const row of d.prepare("SELECT s.seq, s.request_id, s.token, s.token_sha256, o.intent FROM settled s JOIN outbox o ON o.seq = s.seq ORDER BY s.seq").all() as any[]) {
      const self = HM.linkOf(prev, row.token, row.intent);
      d.prepare("UPDATE settled SET prev = ?, self = ? WHERE seq = ?").run(prev, self, row.seq); d.prepare("UPDATE outbox SET prev = ?, self = ? WHERE seq = ?").run(prev, self, row.seq); prev = self;
    }
    for (const t of trig) d.exec(t.sql);
  });
  rec("S6", "HOSTILE: triggers dropped, Z1 deleted, chain recomputed, triggers restored", "OK; restart WITHOUT expectedHead STARTED head=3 (honest limit); WITH the earlier head REFUSED",
    `${got}; no anchor: ${restart(H, p)}; anchor h4: ${r(h4).slice(0, 60)}`, got.startsWith("OK") && restart(H, p) === "STARTED head=3" && r(h4).startsWith("REFUSED"));
}
{ // Review F2 on the running sink: a foreign append is accepted (only the new rows audited); a foreign rollback halts.
  const p = honest(H, "h-S6-running"); const s = new H(p, cfg);
  const extra = raw(p, db => rawCommit(db, tok(st("850"), "rq_3", "10")));
  const c1 = s.commit(tok(st("840"), "rq_4", "0")); const r1 = s.reaudits, h = s.head();
  rec("S6", "running sink: a foreign key holder appends rq_3; the sink commits rq_4", "committed; 1 re-audit; head 6", `${extra}; ${c1.status}; reaudits ${r1}; head ${h.count}`, c1.status === "committed" && r1 === 1 && h.count === 6);
  // file rollback by another connection (copy of an earlier file over the store, as a foreign writer would)
  s.close(); const q = honest(H, "h-S6-rollback"); const old = `${OUT}/rollback-old.sqlite`; copyFileSync(q, old);
  const s2 = new H(q, cfg); s2.commit(tok(st("850"), "rq_3", "10"));
  const src = new DatabaseSync(old); src.exec(`VACUUM INTO '${OUT}/rollback-img.sqlite'`); src.close();
  const dst = new DatabaseSync(q); dst.exec(`ATTACH '${OUT}/rollback-img.sqlite' AS img`); let gotR: string;
  try { dst.exec("BEGIN IMMEDIATE"); for (const t of ["settled", "outbox"]) dst.exec(`DELETE FROM ${t} WHERE seq = 5`); dst.exec("COMMIT"); gotR = "OK"; } catch (e) { try { dst.exec("ROLLBACK"); } catch { /* none */ } gotR = "ABORT: " + short(e); } dst.close();
  rec("S6", "running sink: a foreign connection tries the rollback of the last commit by SQL", "ABORT h-sink S5", gotR, isAbort(gotR, "h-sink S5"));
}
// ---------------- C-ATT-04: U+0000 and BLOB-typed columns (exact bytes)
{
  const fresh = (label: string) => { const p = `${OUT}/${++n}-${label}.sqlite`; const db = new DatabaseSync(p); db.exec(HM.SINK_DDL); db.close(); return p; };
  // CHECK constraints alone (the triggers of settled dropped in a scratch copy of the DDL): NUL and BLOB are refused.
  const p = fresh("check-only"); const ins = (v: any, col: string) => raw(p, db => { db.exec("DROP TRIGGER IF EXISTS h_settled_bi; DROP TRIGGER IF EXISTS h_settled_ai");
    const r: any = { request_id: "rq_a", token: '{"body":{"requestId":"rq_a"}}', token_sha256: "a".repeat(64), prev: "b".repeat(64), self: "c".repeat(64) }; r[col] = v;
    db.prepare("INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (1, ?, ?, ?, ?, ?)").run(r.request_id, r.token, r.token_sha256, r.prev, r.self); });
  for (const [label, v, col] of [["request_id with U+0000 + 'x'", "rq_a\u0000x", "request_id"], ["request_id as BLOB", Buffer.from("rq_a"), "request_id"],
    ["token as BLOB", Buffer.from('{"body":{"requestId":"rq_a"}}'), "token"], ["self with U+0000", "c".repeat(63) + "\u0000", "self"]] as [string, any, string][]) {
    const got = ins(v, col); rec("NUL", "NEG CHECK only (settled triggers dropped): " + label, "ABORT (CHECK constraint failed)", got, got.startsWith("ABORT") && got.includes("CHECK"));
  }
  // Triggers present: the C-ATT-04 statement (append U+0000 'x' to request_id) is an UPDATE: S5 aborts it.
  neg("NUL", "C-ATT-04 statement: request_id || char(0) || 'x' on settled and outbox", "h-sink S5",
    db => db.exec("UPDATE settled SET request_id = request_id || char(0) || 'x' WHERE request_id='rq_z1'; UPDATE outbox SET request_id = request_id || char(0) || 'x' WHERE request_id='rq_z1'"),
    db => db.exec("UPDATE settled SET request_id = request_id || char(0) || 'x' WHERE request_id='rq_z1'; UPDATE outbox SET request_id = request_id || char(0) || 'x' WHERE request_id='rq_z1'"));
  // HOSTILE (triggers dropped and restored, CHECKs ignored): the start-up audit reads exact bytes and refuses.
  const db0 = new DatabaseSync(`${OUT}/ddl.sqlite`); const trig = (db0.prepare("SELECT name, sql FROM sqlite_schema WHERE type = 'trigger'").all() as any[]); db0.close();
  for (const [label, sql] of [["U+0000 'x' appended to rq_z1 in settled and outbox", "UPDATE settled SET request_id = request_id || char(0) || 'x' WHERE request_id='rq_z1'; UPDATE outbox SET request_id = request_id || char(0) || 'x' WHERE request_id='rq_z1'"],
    ["outbox intent stored as BLOB", "UPDATE outbox SET intent = CAST(intent AS BLOB) WHERE seq = 2"]]) {
    const q = honest(H, "h-nul"); const got = raw(q, d => { d.exec("PRAGMA ignore_check_constraints = ON"); for (const t of trig) d.exec(`DROP TRIGGER ${t.name}`); d.exec(sql); for (const t of trig) d.exec(t.sql); });
    const r = restart(H, q); let recommit = "-";
    rec("NUL", "HOSTILE (triggers dropped/restored, CHECKs ignored): " + label, "OK; restart REFUSED (integrity_check sees the CHECK violation; the exact-bytes reader is the second line)", `${got}; restart ${r}; ${recommit}`, got.startsWith("OK") && r.startsWith("REFUSED") && /U\+0000|not TEXT|integrity_check/.test(r));
  }
  { // The exact-bytes reader by itself (core/store.ts hexText), on values read by SQL hex().
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const S = require(TREE + "/ts/refund-finality/core/store.ts"); const d = new DatabaseSync(":memory:");
    const r = (v: any) => { const x = d.prepare("SELECT typeof(?) AS t, hex(?) AS h").get(v, v) as any; try { return S.hexText(x.t, x.h, "v"); } catch (e) { return "REFUSED: " + short(e); } };
    const out = [r("rq_z1\u0000x"), r(Buffer.from("rq_z1")), r("rq_\u{1F600}"), r("plain")]; d.close();
    rec("NUL", "hexText on 'rq_z1'+U+0000+'x', a BLOB, non-BMP text, plain text", "REFUSED, REFUSED, text, text", out.join(" | "),
      out[0].startsWith("REFUSED") && out[1].startsWith("REFUSED") && out[2] === "rq_\u{1F600}" && out[3] === "plain");
  }
}
writeFileSync(`${OUT}/db_safeguards.json`, JSON.stringify({ bad, rows }, null, 1));
console.log(`rows ${rows.length}; failed ${bad}`);
process.exitCode = bad === 0 ? 0 : 1;
