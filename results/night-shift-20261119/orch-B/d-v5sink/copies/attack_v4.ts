// r-repairs: adversarial scenarios against the UNCHANGED d-v3sink2/sink_core_backed_v4.ts (imported read-only).
// Test keys made in this process. Databases only under r-repairs/v4run. One short run.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { canon, signedBytes, stateSha256, sha256hex, DOMAIN, ChargeState } from "/Users/mackianni/forge/ts/refund-finality/encoding";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const V4 = require("/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-v3sink2/sink_core_backed_v4.ts").Sink;
const dir = process.argv[2]; rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true });
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const cfg: any = { publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64) };
const st = (remaining: string, cid = "ch_1", original = "1000"): ChargeState => ({ chargeId: cid, original, remaining, refundEnabled: true });
function tok(pre: ChargeState, requestId: string, amount: string): string {
  const post = { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
  const body = { domain: DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: stateSha256(pre),
    requestId, post, intent: { chargeId: pre.chargeId, requestId, amount, reason: "duplicate_charge" } };
  return canon({ body, signature: sign(null, signedBytes(body as any), privateKey).toString("base64") });
}
const say = (k: string, v: any) => console.log(JSON.stringify({ k, ...v }));
const tryNew = (p: string, c: any) => { try { return { s: new V4(p, c), err: null }; } catch (e) { return { s: null, err: String((e as Error).message).slice(0, 140) }; } };
const intentText = (cid: string, rid: string, amount: string) => canon({ chargeId: cid, requestId: rid, amount, reason: "duplicate_charge" });

// S1 balance reset by another connection: noticed (data_version), re-audit passes, sink over-refunds.
{ const p = dir + "/s1.sqlite"; const s = new V4(p, cfg); s.init(st("1000"));
  const c1 = s.commit(tok(st("1000"), "rq_1", "1000"));
  const o = new DatabaseSync(p); o.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(st("1000"))); o.close();
  const c2 = s.commit(tok(st("1000"), "rq_2", "1000"));
  say("S1-balance-reset", { c1: c1.status, c2: c2.status, reason2: c2.reason ?? "", reaudits: s.reaudits, refundedTotal: 2000, original: 1000, offlineAudit: s.audit() }); s.close(); }
// S2 outbox row JSON rewritten (amount 1000 -> 1), MAX(seq) and state unchanged.
{ const p = dir + "/s2.sqlite"; const s = new V4(p, cfg); s.init(st("1000"));
  s.commit(tok(st("1000"), "rq_1", "100"));
  const o = new DatabaseSync(p); o.prepare("UPDATE outbox SET intent = ? WHERE seq = 1").run(intentText("ch_1", "rq_1", "1")); o.close();
  const c2 = s.commit(tok(st("900"), "rq_2", "100"));
  say("S2-outbox-json-rewrite", { c2: c2.status, reaudits: s.reaudits, offlineAudit: s.audit() }); s.close(); }
// S3 settled token text changed only.
{ const p = dir + "/s3.sqlite"; const s = new V4(p, cfg); s.init(st("1000"));
  const t1 = tok(st("1000"), "rq_1", "100"); s.commit(t1);
  const o = new DatabaseSync(p); o.prepare("UPDATE settled SET token = 'x', token_sha256 = 'y' WHERE seq = 1").run(); o.close();
  const r = s.commit(t1); const c2 = s.commit(tok(st("900"), "rq_2", "100"));
  say("S3-settled-token-only", { replay: r.status, replayReason: r.reason ?? "", c2: c2.status, reaudits: s.reaudits, offlineAudit: s.audit().length }); s.close(); }
// S4 schema attack: settled.request_id COLLATE NOCASE; settled {rq_1}; outbox [RQ_1]. Model AuditStart is FALSE.
for (const coll of ["NOCASE", "BINARY"]) {
  const p = dir + "/s4-" + coll + ".sqlite"; const db = new DatabaseSync(p); const init = canon(st("900"));
  db.exec(`CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT NOT NULL); CREATE TABLE state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL);
    CREATE TABLE settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT COLLATE ${coll} NOT NULL UNIQUE, token TEXT NOT NULL, token_sha256 TEXT NOT NULL);
    CREATE TABLE outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE, intent TEXT NOT NULL);`);
  const i0 = canon(st("1000"));
  db.prepare("INSERT INTO meta VALUES ('initial_state_sha256', ?), ('initial_state', ?)").run(sha256hex(i0), i0);
  db.prepare("INSERT INTO state VALUES (1, ?)").run(init);
  db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES ('rq_1', 'x', 'y')").run();
  db.prepare("INSERT INTO outbox(request_id, intent) VALUES ('RQ_1', ?)").run(intentText("ch_1", "RQ_1", "100")); db.close();
  const { s, err } = tryNew(p, cfg);
  const c = s ? s.commit(tok(st("900"), "rq_2", "100")) : null;
  say("S4-schema-" + coll, { started: s !== null, err, modelAuditStart: false, commitRq2: c?.status ?? null }); s?.close();
}
// S5 meta rewritten to ch_2 (state ch_2, empty outbox); cfg.initialState = ch_1 is given and IGNORED.
{ const p = dir + "/s5.sqlite"; const s0 = new V4(p, cfg); s0.init(st("1000")); s0.close();
  const o = new DatabaseSync(p); const f = canon(st("1000", "ch_2"));
  o.prepare("UPDATE meta SET v = ? WHERE k = 'initial_state'").run(f); o.prepare("UPDATE meta SET v = ? WHERE k = 'initial_state_sha256'").run(sha256hex(f));
  o.prepare("UPDATE state SET blob = ? WHERE id = 1").run(f); o.close();
  const { s, err } = tryNew(p, { ...cfg, initialState: st("1000") });
  const c = s ? s.commit(tok(st("1000", "ch_2"), "rq_9", "1000")) : null;
  say("S5-meta-rewrite-cfg-initialState-ignored", { started: s !== null, err, commitCh2: c?.status ?? null }); s?.close(); }
// S6 legacy store: no meta hash; cfg.initialState given.
{ const p = dir + "/s6.sqlite"; const s0 = new V4(p, cfg); s0.init(st("1000")); s0.close();
  const o = new DatabaseSync(p); o.exec("DELETE FROM meta"); o.close();
  const { s, err } = tryNew(p, { ...cfg, initialState: st("1000") });
  say("S6-legacy-no-meta-hash", { started: s !== null, err }); s?.close(); }
// S7 same initial id, other amounts: meta initial_state = ch_1 original 5000 (sha matches). Binding is id only.
{ const p = dir + "/s7.sqlite"; const s0 = new V4(p, cfg); s0.init(st("1000")); s0.close();
  const o = new DatabaseSync(p); const f = canon(st("5000", "ch_1", "5000"));
  o.prepare("UPDATE meta SET v = ? WHERE k = 'initial_state'").run(f); o.prepare("UPDATE meta SET v = ? WHERE k = 'initial_state_sha256'").run(sha256hex(f));
  o.prepare("UPDATE state SET blob = ? WHERE id = 1").run(f); o.close();
  const { s, err } = tryNew(p, cfg);
  const c = s ? s.commit(tok(st("5000", "ch_1", "5000"), "rq_1", "5000")) : null;
  say("S7-amounts-rewritten-same-id", { started: s !== null, err, commit5000: c?.status ?? null }); s?.close(); }
