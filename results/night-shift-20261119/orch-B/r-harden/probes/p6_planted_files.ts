// r-harden probe P6: C-ATT-21 ported to the hardened sink (branch 608b5165). The attacker READS the database file and
// CREATES files in its directory (<db>-journal or <db>-wal). It never opens the database for writing. Its edits are made
// on its OWN copy (where it may drop triggers). Standalone, one short run, test keys only.
// usage (cwd = tree): node --import tsx p6_planted_files.ts <treeRoot> <scratch dir>
// Per mode: start without anchor, start with expectedHead (the honest head before the plant), a running sink's next commit,
// and the dispatcher whose ledger holds the honest rows. Class: detected / ii (only the anchor or the ledger sees it) /
// i (a non-prefix rewrite that passes the start-up audit AND the dispatcher, or a forged store served with the anchor).
// Exit 1 if any mode is class i; exit 0 otherwise.
import { generateKeyPairSync, sign } from "node:crypto";
import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { join, resolve } from "node:path";
import { makeJournal } from "./journal";
const [T0, O0] = process.argv.slice(2); const TREE = resolve(T0), OUT = resolve(O0);
rmSync(OUT, { recursive: true, force: true }); mkdirSync(OUT, { recursive: true });
/* eslint-disable @typescript-eslint/no-require-imports */
const E = require(join(TREE, "ts/refund-finality/encoding.ts")); const HM = require(join(TREE, "ts/refund-finality/sink.ts"));
const { Dispatcher } = require(join(TREE, "ts/refund-finality/dispatcher.ts"));
/* eslint-enable @typescript-eslint/no-require-imports */
const { canon, signedBytes, stateSha256, sha256hex, DOMAIN } = E;
const { publicKey, privateKey } = generateKeyPairSync("ed25519"); const pem = publicKey.export({ type: "spki", format: "pem" }) as string;
const st = (r: string) => ({ chargeId: "ch_1", original: "1000", remaining: r, refundEnabled: true });
const S0 = st("1000"); const cfg: any = { publicKeyPem: pem, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: S0 };
const genesis = HM.genesisOf(canon(S0), cfg.specLockSha256, cfg.checkerSha256, pem);
const tok = (pre: any, rid: string, amount: string) => { const body = { domain: DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256,
  preStateSha256: stateSha256(pre), requestId: rid, post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() },
  intent: { chargeId: "ch_1", requestId: rid, amount, reason: "duplicate_charge" } };
  return canon({ body, signature: sign(null, signedBytes(body), privateKey).toString("base64") }); };
const T = [tok(S0, "r1", "100"), tok(st("900"), "r2", "200"), tok(st("700"), "r3", "0"), tok(st("700"), "r4", "150")];
const X3 = tok(st("700"), "x3", "0");      // a second signed zero-amount token on the pre-state of r3 (normal under the new minter rule)
const intentOf = (t: string) => canon(JSON.parse(t).body.intent);
const short = (e: unknown) => String((e as Error).message).replace(/\s+/g, " ").slice(0, 110);
const ids = (p: string) => { const d = new DatabaseSync(p, { readOnly: true }); const r = (d.prepare("SELECT request_id FROM settled ORDER BY seq").all() as any[]).map(x => x.request_id); d.close(); return r; };
// attacker's own-copy edits (triggers may be dropped there)
function edit(own: string, kind: string): void {
  const d = new DatabaseSync(own);
  if (kind === "nul") { d.exec("PRAGMA ignore_check_constraints = ON; DROP TRIGGER h_settled_bu; DROP TRIGGER h_outbox_bu"); d.exec("UPDATE settled SET request_id = 'r3' || char(0) || 'x' WHERE seq = 3; UPDATE outbox SET request_id = 'r3' || char(0) || 'x' WHERE seq = 3"); }
  if (kind === "uv") d.exec("PRAGMA user_version = 77");
  if (kind === "swap") {
    const saved = ["h_settled_bu", "h_outbox_bu"].map(n => (d.prepare("SELECT sql FROM sqlite_schema WHERE name = ?").get(n) as any).sql);
    d.exec("DROP TRIGGER h_settled_bu; DROP TRIGGER h_outbox_bu");
    const prev = (d.prepare("SELECT self FROM outbox WHERE seq = 2").get() as any).self, self = HM.linkOf(prev, X3, intentOf(X3));
    d.prepare("UPDATE settled SET request_id = 'x3', token = ?, token_sha256 = ?, self = ? WHERE seq = 3").run(X3, sha256hex(X3), self);
    d.prepare("UPDATE outbox SET request_id = 'x3', intent = ?, self = ? WHERE seq = 3").run(intentOf(X3), self);
    for (const s of saved) d.exec(s);
  }
  d.close();
}
type Row = Record<string, unknown>;
const rows: Row[] = [];
for (const mode of ["restart", "running", "nul", "uv", "swap", "wal-swap", "jinwal"]) {
  const W = join(OUT, mode); mkdirSync(W); const db = join(W, "sink.sqlite"), L = join(W, "ledger.jsonl"); const out: Row = { mode };
  let s = new HM.Sink(db, cfg); s.init(S0);
  s.commit(T[0]); const earlier = readFileSync(db);                 // the attacker's earlier read (after r1)
  s.commit(T[1]); s.commit(T[2]);
  const honestHead = s.head();
  new Dispatcher(db, L, { ...cfg, initialStateSha256: stateSha256(S0), newLedgerH0: genesis }, () => undefined).flush();   // r1..r3 dispatched
  let target = earlier;
  if (mode === "jinwal") { s.close(); const w = new DatabaseSync(db); w.exec("PRAGMA journal_mode = WAL"); w.close(); s = new HM.Sink(db, cfg); }
  if (["nul", "uv", "swap"].includes(mode)) { const own = join(W, "own.sqlite"); copyFileSync(db, own); edit(own, mode); target = readFileSync(own); }
  if (mode !== "running") s.close();
  if (mode === "wal-swap") {
    const own = join(W, "own.sqlite"); copyFileSync(db, own);
    const w = new DatabaseSync(own); w.exec("PRAGMA journal_mode = WAL; PRAGMA wal_autocheckpoint = 0"); w.close();   // header says WAL now
    const w2 = new DatabaseSync(own); w2.exec("PRAGMA wal_autocheckpoint = 0"); w2.close();
    // re-open, make the swap inside the WAL, copy the -wal while the connection is open (no checkpoint yet)
    const w3 = new DatabaseSync(own); w3.exec("PRAGMA wal_autocheckpoint = 0");
    const saved = ["h_settled_bu", "h_outbox_bu"].map(n => (w3.prepare("SELECT sql FROM sqlite_schema WHERE name = ?").get(n) as any).sql);
    w3.exec("BEGIN; DROP TRIGGER h_settled_bu; DROP TRIGGER h_outbox_bu");
    const prev = (w3.prepare("SELECT self FROM outbox WHERE seq = 2").get() as any).self, self = HM.linkOf(prev, X3, intentOf(X3));
    w3.prepare("UPDATE settled SET request_id = 'x3', token = ?, token_sha256 = ?, self = ? WHERE seq = 3").run(X3, sha256hex(X3), self);
    w3.prepare("UPDATE outbox SET request_id = 'x3', intent = ?, self = ? WHERE seq = 3").run(intentOf(X3), self);
    for (const q of saved) w3.exec(q); w3.exec("COMMIT");
    writeFileSync(db + "-wal", readFileSync(own + "-wal")); out.walBytes = readFileSync(own + "-wal").length; w3.close();
  } else writeFileSync(db + "-journal", makeJournal(target));
  if (mode === "running") { const c = s.commit(T[3]); out.runningCommit = c.status + (c.reason ? ": " + c.reason.slice(0, 60) : ""); s.close(); }
  const start = (c: any) => { try { const x = new HM.Sink(db, c); const h = x.head(); x.close(); return "STARTED count=" + h.count; } catch (e) { return "REFUSED: " + short(e).replace(/^h1 sink refuses to serve: start-up audit \(.*?\) is false/, ""); } };
  out.start = start(cfg); out.idsAfter = existsSync(db) ? ids(db) : null;
  out.startAnchor = start({ ...cfg, expectedHead: honestHead });
  try { const f = new Dispatcher(db, L, { ...cfg, initialStateSha256: stateSha256(S0) }, () => undefined).flush(); out.dispatcher = `emitted=${f.emitted.length} refused=${f.refused.length}`; }
  catch (e) { out.dispatcher = "ALARM/throw: " + short(e).slice(0, 70); }
  const changed = JSON.stringify(out.idsAfter) !== JSON.stringify(["r1", "r2", "r3"]) && JSON.stringify(out.idsAfter) !== JSON.stringify(["r1", "r2", "r3", "r4"]);
  const startedNoAnchor = String(out.start).startsWith("STARTED"), startedAnchor = String(out.startAnchor).startsWith("STARTED");
  const prefix = JSON.stringify(out.idsAfter) === JSON.stringify(["r1"]);
  out.cls = !startedNoAnchor && !startedAnchor ? (changed || mode === "nul" ? "detected" : "no change")
    : startedAnchor && (changed || mode === "uv") ? (mode === "uv" ? "i-weak (non-semantic page content served even with the anchor)" : "i")
    : startedNoAnchor && changed && !prefix ? (String(out.dispatcher).startsWith("ALARM") ? "ii (non-prefix rewrite passes the start-up audit; ledger/anchor catch it)" : "i")
    : startedNoAnchor && prefix ? "ii (prefix rollback: stated anchor limit)" : "no change";
  rows.push(out);
}
let bad = 0; for (const r of rows) { console.log(JSON.stringify(r)); if (String(r.cls) === "i") bad++; }
rmSync(OUT, { recursive: true, force: true });
console.log(bad ? "DEFEATED" : "SAFE"); process.exit(bad ? 1 : 0);
