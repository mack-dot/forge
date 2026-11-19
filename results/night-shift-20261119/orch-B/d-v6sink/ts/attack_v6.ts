// d-v5sink: copy of r-repairs/attack_v4.ts (copies/attack_v4.ts), pointed at the v5 draft, changed: cfg.initialState
// is always given (v5 requires it); each scenario is tried on the RUNNING sink (writer guard + re-audit) AND at
// RESTART (a new sink on the same file). NEW scenarios: S3b (token replaced by an attacker-signed one), S4r (a trigger
// added while running), S5b/S7b (meta deleted as well), honest restart, zero amounts, faulty signer, missing cfg.
// Test keys made in this process. Databases only under the given directory. One short run. A TEST, not a proof.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { canon, signedBytes, stateSha256, sha256hex, DOMAIN, ChargeState } from "<REPO>/ts/refund-finality/encoding";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const V5 = require("<REPO>/results/night-shift-20261119/orch-B/d-v6sink/sink_core_backed_v6.ts").Sink;   // d-v6sink: the v6 draft (name V5 kept)
const dir = process.argv[2]; rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true });
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const attacker = generateKeyPairSync("ed25519");
const st = (remaining: string, cid = "ch_1", original = "1000"): ChargeState => ({ chargeId: cid, original, remaining, refundEnabled: true });
const cfg: any = { publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: st("1000") };
function tok(pre: ChargeState, requestId: string, amount: string, key = privateKey, reason = "duplicate_charge"): string {
  const post = { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
  const body = { domain: DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: stateSha256(pre),
    requestId, post, intent: { chargeId: pre.chargeId, requestId, amount, reason } };
  return canon({ body, signature: sign(null, signedBytes(body as any), key).toString("base64") });
}
const say = (k: string, v: any) => console.log(JSON.stringify({ k, ...v }));
const short = (e: unknown) => String((e as Error).message).replace(/^v5 sink refuses to serve: /, "").slice(0, 150);
const tryNew = (p: string, c: any) => { try { return { s: new V5(p, c), err: null }; } catch (e) { return { s: null, err: short(e) }; } };
const restart = (p: string, c: any = cfg) => { const { s, err } = tryNew(p, c); s?.close(); return err === null ? "STARTED" : "REFUSED: " + err; };
const intentText = (cid: string, rid: string, amount: string) => canon({ chargeId: cid, requestId: rid, amount, reason: "duplicate_charge" });
const foreign = (p: string, f: (o: DatabaseSync) => void) => { const o = new DatabaseSync(p); f(o); o.close(); };
const res = (r: any) => r.status + (r.reason ? " (" + r.reason.slice(0, 60) + ")" : "");

// S1 balance reset by another connection.
{ const p = dir + "/s1.sqlite"; const s = new V5(p, cfg); s.init(st("1000"));
  const c1 = s.commit(tok(st("1000"), "rq_1", "1000"));
  foreign(p, o => o.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(st("1000"))));
  const atRestart = restart(p);
  const c2 = s.commit(tok(st("1000"), "rq_2", "1000"));
  say("S1-balance-reset", { c1: c1.status, running_c2: res(c2), reaudits: s.reaudits, restart: atRestart }); s.close(); }
// S2 outbox row JSON rewritten (amount 100 -> 1).
{ const p = dir + "/s2.sqlite"; const s = new V5(p, cfg); s.init(st("1000"));
  s.commit(tok(st("1000"), "rq_1", "100"));
  foreign(p, o => o.prepare("UPDATE outbox SET intent = ? WHERE seq = 1").run(intentText("ch_1", "rq_1", "1")));
  const atRestart = restart(p);
  const c2 = s.commit(tok(st("900"), "rq_2", "100"));
  say("S2-outbox-amount-rewrite", { running_c2: res(c2), reaudits: s.reaudits, restart: atRestart }); s.close(); }
// S3 settled token text changed only ('x').
{ const p = dir + "/s3.sqlite"; const s = new V5(p, cfg); s.init(st("1000"));
  const t1 = tok(st("1000"), "rq_1", "100"); s.commit(t1);
  foreign(p, o => o.prepare("UPDATE settled SET token = 'x', token_sha256 = 'y' WHERE seq = 1").run());
  const atRestart = restart(p);
  const r = s.commit(t1); const c2 = s.commit(tok(st("900"), "rq_2", "100"));
  say("S3-settled-token-x", { running_replay: res(r), running_c2: res(c2), reaudits: s.reaudits, restart: atRestart }); s.close(); }
// S3b settled token replaced by an ATTACKER-signed token with the same body (hash column consistent).
{ const p = dir + "/s3b.sqlite"; const s = new V5(p, cfg); s.init(st("1000"));
  s.commit(tok(st("1000"), "rq_1", "100"));
  const bad = tok(st("1000"), "rq_1", "100", attacker.privateKey);
  foreign(p, o => o.prepare("UPDATE settled SET token = ?, token_sha256 = ? WHERE seq = 1").run(bad, sha256hex(bad)));
  const atRestart = restart(p);
  const c2 = s.commit(tok(st("900"), "rq_2", "100"));
  say("S3b-settled-token-attacker-signed", { running_c2: res(c2), restart: atRestart }); s.close(); }
// S4 schema attack (pre-built file). Model AuditStart is FALSE for NOCASE.
for (const coll of ["NOCASE", "BINARY"]) {
  const p = dir + "/s4-" + coll + ".sqlite"; const db = new DatabaseSync(p); const init = canon(st("900"));
  db.exec(`CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT NOT NULL); CREATE TABLE state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL);
    CREATE TABLE settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT COLLATE ${coll} NOT NULL UNIQUE, token TEXT NOT NULL, token_sha256 TEXT NOT NULL);
    CREATE TABLE outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE, intent TEXT NOT NULL);`);
  const i0 = canon(st("1000"));
  db.prepare("INSERT INTO meta VALUES ('initial_state_sha256', ?), ('initial_state', ?)").run(sha256hex(i0), i0);
  db.prepare("INSERT INTO state VALUES (1, ?)").run(init);
  const t = tok(st("1000"), "rq_1", "100");
  db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES ('rq_1', ?, ?)").run(t, sha256hex(t));
  db.prepare("INSERT INTO outbox(request_id, intent) VALUES ('RQ_1', ?)").run(intentText("ch_1", "RQ_1", "100")); db.close();
  const { s, err } = tryNew(p, cfg);
  const c = s ? s.commit(tok(st("900"), "rq_2", "100")) : null;
  say("S4-schema-" + coll, { started: s !== null, err, commitRq2: c?.status ?? null }); s?.close();
}
// S4c the exact sink schema but COLLATE NOCASE only, honest rows (no other defect): the schema check alone refuses.
{ const p = dir + "/s4c.sqlite"; const db = new DatabaseSync(p);
  db.exec(`CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT NOT NULL); CREATE TABLE state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL);
    CREATE TABLE settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT COLLATE NOCASE NOT NULL UNIQUE, token TEXT NOT NULL, token_sha256 TEXT NOT NULL);
    CREATE TABLE outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE, intent TEXT NOT NULL);`); db.close();
  say("S4c-schema-NOCASE-empty", { restart: restart(p) }); }
// S4r a trigger added by another connection while the sink runs.
{ const p = dir + "/s4r.sqlite"; const s = new V5(p, cfg); s.init(st("1000"));
  s.commit(tok(st("1000"), "rq_1", "100"));
  foreign(p, o => o.exec("CREATE TRIGGER t AFTER INSERT ON outbox BEGIN UPDATE state SET blob = blob WHERE id = 1; END;"));
  const c2 = s.commit(tok(st("900"), "rq_2", "100"));
  say("S4r-trigger-added-running", { running_c2: res(c2), restart: restart(p) }); s.close(); }
// S5 meta rewritten to ch_2 (state ch_2, empty outbox); cfg.initialState = ch_1.
{ const p = dir + "/s5.sqlite"; const s0 = new V5(p, cfg); s0.init(st("1000"));
  const f = canon(st("1000", "ch_2"));
  foreign(p, o => { o.prepare("UPDATE meta SET v = ? WHERE k = 'initial_state'").run(f); o.prepare("UPDATE meta SET v = ? WHERE k = 'initial_state_sha256'").run(sha256hex(f));
    o.prepare("UPDATE state SET blob = ? WHERE id = 1").run(f); });
  const running = s0.commit(tok(st("1000", "ch_2"), "rq_9", "1000")); s0.close();
  const { s, err } = tryNew(p, cfg);
  const c = s ? s.commit(tok(st("1000", "ch_2"), "rq_9", "1000")) : null;
  say("S5-meta-rewrite-ch2", { running_commitCh2: res(running), restartStarted: s !== null, err, commitCh2: c?.status ?? null }); s?.close(); }
// S5b meta deleted and state set to ch_2.
{ const p = dir + "/s5b.sqlite"; const s0 = new V5(p, cfg); s0.init(st("1000")); s0.close();
  foreign(p, o => { o.exec("DELETE FROM meta"); o.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(st("1000", "ch_2"))); });
  say("S5b-meta-deleted-state-ch2", { restart: restart(p) }); }
// S6 legacy store: no meta rows; cfg.initialState given; honest rows. v5: accepted (replay reaches the stored state).
{ const p = dir + "/s6.sqlite"; const s0 = new V5(p, cfg); s0.init(st("1000")); s0.commit(tok(st("1000"), "rq_1", "100")); s0.close();
  foreign(p, o => o.exec("DELETE FROM meta"));
  say("S6-legacy-no-meta", { restart: restart(p), restartOtherInit: restart(p, { ...cfg, initialState: st("900") }) }); }
// S7 same initial id, other amounts: meta initial_state = ch_1 original 5000 (sha matches).
{ const p = dir + "/s7.sqlite"; const s0 = new V5(p, cfg); s0.init(st("1000")); s0.close();
  const f = canon(st("5000", "ch_1", "5000"));
  foreign(p, o => { o.prepare("UPDATE meta SET v = ? WHERE k = 'initial_state'").run(f); o.prepare("UPDATE meta SET v = ? WHERE k = 'initial_state_sha256'").run(sha256hex(f));
    o.prepare("UPDATE state SET blob = ? WHERE id = 1").run(f); });
  const { s, err } = tryNew(p, cfg);
  const c = s ? s.commit(tok(st("5000", "ch_1", "5000"), "rq_1", "5000")) : null;
  say("S7-original-rewritten-same-id", { started: s !== null, err, commit5000: c?.status ?? null }); s?.close(); }
// S7b meta deleted, state rewritten to original 5000 (running sink and restart).
{ const p = dir + "/s7b.sqlite"; const s = new V5(p, cfg); s.init(st("1000"));
  foreign(p, o => { o.exec("DELETE FROM meta"); o.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(st("5000", "ch_1", "5000"))); });
  const atRestart = restart(p);
  const c = s.commit(tok(st("5000", "ch_1", "5000"), "rq_1", "5000"));
  say("S7b-meta-deleted-original-5000", { running: res(c), restart: atRestart }); s.close(); }
// Honest restart with a zero amount; then the next commit; then a replay; then restart again.
{ const p = dir + "/h.sqlite"; const s = new V5(p, cfg); s.init(st("1000"));
  const a = [s.commit(tok(st("1000"), "rq_1", "100")), s.commit(tok(st("900"), "rq_z", "0")), s.commit(tok(st("900"), "rq_z2", "0"))].map(r => r.status); s.close();
  const s2 = new V5(p, cfg); const b = [s2.commit(tok(st("900"), "rq_2", "900")), s2.commit(tok(st("900"), "rq_z", "0"))].map(r => r.status); s2.close();
  say("honest-restart-zero", { first: a, afterRestart: b, restartAgain: restart(p), restartWithoutCfgInit: restart(p, { ...cfg, initialState: undefined }) }); }
// Honest other writer (D1 style): a second v5 sink on the same file commits; the first re-audits and continues.
{ const p = dir + "/d1.sqlite"; const s = new V5(p, cfg); s.init(st("1000")); s.commit(tok(st("1000"), "rq_1", "100"));
  const o = new V5(p, cfg); const oc = o.commit(tok(st("900"), "rq_2", "100")); o.close();
  const c3 = s.commit(tok(st("800"), "rq_3", "100"));
  say("D1-honest-other-writer", { other: oc.status, c3: res(c3), reaudits: s.reaudits }); s.close(); }
// Faulty signer: a SIGNED but unauthorized token (reason not in the approved set). StepQ commits (no Authorizes in
// the commit path, by design); AuditV5 refuses the store at restart.
{ const p = dir + "/fs.sqlite"; const s = new V5(p, cfg); s.init(st("1000"));
  const c = s.commit(tok(st("1000"), "rq_u", "100", privateKey, "not_an_approved_reason")); s.close();
  say("faulty-signer-unauthorized", { commit: c.status, restart: restart(p) }); }
// d-v6sink NEW: signed (trusted key), hash-matching, pinned, fresh, charge-id-consistent but UNAUTHORIZED tokens.
// Expected (stated before the run): commit rejected with "not authorized by the approved relation for the stored
// state"; store unchanged; restart STARTED; the next honest commit commits.
function tokPost(pre: ChargeState, requestId: string, amount: string, post: ChargeState): string {
  const body = { domain: DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: stateSha256(pre),
    requestId, post, intent: { chargeId: pre.chargeId, requestId, amount, reason: "duplicate_charge" } };
  return canon({ body, signature: sign(null, signedBytes(body as any), privateKey).toString("base64") });
}
for (const [kind, t] of [["amount-above-remaining", tok(st("1000"), "rq_u1", "2000")],
                         ["amount-above-remaining-post-0", tokPost(st("1000"), "rq_u4", "2000", st("0"))],
                         ["wrong-post-state", tokPost(st("1000"), "rq_u2", "100", st("950"))],
                         ["unapproved-reason", tok(st("1000"), "rq_u3", "100", privateKey, "not_an_approved_reason")]] as [string, string][]) {
  const p = dir + "/su-" + kind + ".sqlite"; const s = new V5(p, cfg); s.init(st("1000"));
  const before = JSON.stringify([s.storedBlob(), s.settled(), s.outbox()]);
  const c = s.commit(t);
  const unchanged = JSON.stringify([s.storedBlob(), s.settled(), s.outbox()]) === before;
  s.close();
  const atRestart = restart(p);
  const s2 = new V5(p, cfg); const h = s2.commit(tok(st("1000"), "rq_h", "100")); s2.close();
  say("signed-unauthorized-" + kind, { commit: res(c), storeUnchanged: unchanged, restart: atRestart, nextHonest: h.status, restartAfter: restart(p) });
}
// Rollback (stated assumption): copy after commit 1, commit 2, restore the copy, restart: v5 STARTS (undetectable).
{ const p = dir + "/rb.sqlite"; const s = new V5(p, cfg); s.init(st("1000")); s.commit(tok(st("1000"), "rq_1", "100")); s.close();
  const { copyFileSync } = require("node:fs"); copyFileSync(p, p + ".bak");
  const s2 = new V5(p, cfg); s2.commit(tok(st("900"), "rq_2", "100")); s2.close(); copyFileSync(p + ".bak", p);
  say("rollback-whole-file", { restart: restart(p) }); }
// Missing cfg.initialState.
say("no-cfg-initialState", { restart: restart(dir + "/none.sqlite", { ...cfg, initialState: undefined }) });
