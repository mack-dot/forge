// h-sink E2: copy of r-v5/ts/attack_rv5.ts; the sink module is argv[3] (v6 or hardened); a foreign SQL write that ABORTs is recorded (sqlAbort).
// Earlier header: r-v5 (night shift 2026-11-19, Orchestrator B). ADVERSARIAL TEST of the v6 draft's start-up audit and writer guard.
// Honest stores are written by the v6 draft (d-v6sink/sink_core_backed_v6.ts, used read-only) with test keys made in
// this process. Hostile stores are made with raw SQL from a second connection. One short run. A TEST, not a proof.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { canon, signedBytes, stateSha256, sha256hex, DOMAIN, ChargeState } from "/Users/mackianni/forge/results/night-shift-20261119/orch-B/h-sink/tree/ts/refund-finality/encoding";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const V6 = require(process.argv[3]).Sink;
const dir = process.argv[2]; rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true });
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const st = (remaining: string, cid = "ch_1", original = "1000"): ChargeState => ({ chargeId: cid, original, remaining, refundEnabled: true });
const mkcfg = (init: ChargeState): any => ({ publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: init });
const cfg = mkcfg(st("1000"));
function tok(pre: ChargeState, requestId: string, amount: string, reason = "duplicate_charge"): string {
  const post = { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
  const body = { domain: DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: stateSha256(pre),
    requestId, post, intent: { chargeId: pre.chargeId, requestId, amount, reason } };
  return canon({ body, signature: sign(null, signedBytes(body as any), privateKey).toString("base64") });
}
const say = (k: string, v: any) => console.log(JSON.stringify({ k, ...v }));
const short = (e: unknown) => String((e as Error).message).replace(/^(v[56]|h1) sink refuses to serve: start-up audit \([^)]*\) is false/, "").slice(0, 110);
const restart = (p: string, c: any = cfg) => { try { const s = new V6(p, c); s.close(); return "STARTED"; } catch (e) { return "REFUSED" + short(e); } };
const res = (r: any) => r.status + (r.reason ? " (" + r.reason.slice(0, 50) + ")" : "");
let lastAbort = "";
const foreign = (p: string, f: (o: DatabaseSync) => void) => { const o = new DatabaseSync(p); lastAbort = "";
  try { o.exec("BEGIN IMMEDIATE"); f(o); o.exec("COMMIT"); } catch (e) { try { o.exec("ROLLBACK"); } catch { /* none */ } lastAbort = "SQL-ABORT: " + String((e as Error).message).slice(0, 60); } o.close(); };
const counts = (p: string) => { let x: any; const keep = lastAbort; foreign(p, o => { x = o.prepare("SELECT (SELECT COUNT(*) FROM settled) s, (SELECT COUNT(*) FROM outbox) o, (SELECT COUNT(*) FROM outbox WHERE request_id='rq_z1') z1").get(); }); lastAbort = keep; return x; };

// Honest base: rq_1 100 (1000->900), rq_z1 0, rq_z2 0, rq_2 50 (900->850)... variants below build their own.
const T = { r1: tok(st("1000"), "rq_1", "100"), z1: tok(st("900"), "rq_z1", "0"), z2: tok(st("900"), "rq_z2", "0"), r2: tok(st("900"), "rq_2", "50"),
  z0: tok(st("1000"), "rq_z0", "0"), r3: tok(st("850"), "rq_3", "10") };
const honest = (name: string, seq: string[]) => { const p = `${dir}/${name}.sqlite`; const s = new V6(p, cfg); s.init(st("1000"));
  const out = seq.map(k => s.commit((T as any)[k]).status); s.close(); if (out.some(x => x !== "committed")) throw new Error(name + " honest " + out); return p; };
const hostile = (name: string, seq: string[], sql: (o: DatabaseSync) => void, then?: string[]) => {
  const p = honest(name, seq); foreign(p, sql); const r = restart(p);
  let after: string[] | null = null;
  if (r === "STARTED" && then) { const s = new V6(p, cfg); after = then.map(k => k + ":" + res(s.commit((T as any)[k]))); s.close(); }
  say(name, { sqlAbort: lastAbort || null, restart: r, after, counts: counts(p), restartAfter: after ? restart(p) : null });
};
const stateSet = (o: DatabaseSync, s: ChargeState) => o.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(s));

say("H0-honest-control", { restart: restart(honest("h0", ["r1", "z1", "z2", "r2", "r3"])) });
// JOIN attacks
hostile("A1-outbox-rows-swapped", ["r1", "r2"], o => { const a: any[] = o.prepare("SELECT seq, request_id, intent FROM outbox ORDER BY seq").all();
  o.exec("DELETE FROM outbox"); o.prepare("INSERT INTO outbox(seq, request_id, intent) VALUES (?,?,?),(?,?,?)").run(a[0].seq, a[1].request_id, a[1].intent, a[1].seq, a[0].request_id, a[0].intent); });
hostile("A2-settled-rows-swapped", ["r1", "r2"], o => { const a: any[] = o.prepare("SELECT * FROM settled ORDER BY seq").all();
  o.exec("DELETE FROM settled"); o.prepare("INSERT INTO settled VALUES (?,?,?,?),(?,?,?,?)").run(a[0].seq, a[1].request_id, a[1].token, a[1].token_sha256, a[1].seq, a[0].request_id, a[0].token, a[0].token_sha256); });
hostile("A3-settled-without-outbox-and-orphan-outbox", ["r1", "z1"], o => { o.exec("DELETE FROM outbox WHERE request_id='rq_z1'");
  o.prepare("INSERT INTO outbox(request_id, intent) VALUES ('rq_zz', ?)").run(canon({ chargeId: "ch_1", requestId: "rq_zz", amount: "0", reason: "duplicate_charge" })); });
hostile("A4-seq-gap-both-tables", ["r1", "r2"], o => { o.exec("UPDATE settled SET seq = 10 WHERE seq = 2; UPDATE outbox SET seq = 77 WHERE seq = 2"); }, ["r3"]);
hostile("A4b-seq-renumbered-offset", ["r1", "r2"], o => { o.exec("UPDATE outbox SET seq = seq + 1000"); }, ["r3"]);
hostile("A5-outbox-intent-key-order", ["r1"], o => { o.exec(`UPDATE outbox SET intent = '{"requestId":"rq_1","chargeId":"ch_1","amount":"100","reason":"duplicate_charge"}'`); });
hostile("A5b-outbox-intent-whitespace", ["r1"], o => { o.exec(`UPDATE outbox SET intent = replace(intent, ',', ', ')`); });
hostile("A5c-outbox-intent-reason", ["r1"], o => { o.exec(`UPDATE outbox SET intent = replace(intent, 'duplicate_charge', 'fraudulent')`); });
hostile("A6-settled-request_id-column", ["r1"], o => { o.exec("UPDATE settled SET request_id = 'rq_X'"); });
hostile("A7-token_sha256-column", ["r1"], o => { o.exec("UPDATE settled SET token_sha256 = lower(hex(randomblob(32)))"); });
hostile("A8-outbox-request_id-column", ["r1"], o => { o.exec("UPDATE outbox SET request_id = 'rq_X'"); });
hostile("A8b-outbox-zero-intent-chargeId", ["r1", "z1"], o => { o.exec(`UPDATE outbox SET intent = replace(intent, '"ch_1"', '"ch_2"') WHERE request_id='rq_z1'`); });
// ZERO-AMOUNT rows: presence and order not pinned
hostile("Z1-middle-zero-row-deleted", ["r1", "z1", "z2"], o => { o.exec("DELETE FROM settled WHERE request_id='rq_z1'; DELETE FROM outbox WHERE request_id='rq_z1'"); }, ["z1", "r2"]);
hostile("Z2-zero-rows-swapped", ["r1", "z1", "z2"], o => { const s: any[] = o.prepare("SELECT * FROM settled ORDER BY seq").all(); const b: any[] = o.prepare("SELECT * FROM outbox ORDER BY seq").all();
  o.exec("DELETE FROM settled; DELETE FROM outbox");
  for (const [i, j] of [[0, 0], [1, 2], [2, 1]]) { o.prepare("INSERT INTO settled VALUES (?,?,?,?)").run(s[i].seq, s[j].request_id, s[j].token, s[j].token_sha256); o.prepare("INSERT INTO outbox VALUES (?,?,?)").run(b[i].seq, b[j].request_id, b[j].intent); } }, ["r2"]);
hostile("Z3-leading-zero-row-deleted", ["z0", "r1"], o => { o.exec("DELETE FROM settled WHERE request_id='rq_z0'; DELETE FROM outbox WHERE request_id='rq_z0'"); }, ["z0", "r2"]);
hostile("Z4-control-nonzero-middle-deleted", ["r1", "r2", "r3"], o => { o.exec("DELETE FROM settled WHERE request_id='rq_2'; DELETE FROM outbox WHERE request_id='rq_2'"); });
// PREFIX rollback (stated limit): drop the last row and restore the state
hostile("P1-prefix-rollback-last-row", ["r1", "r2"], o => { o.exec("DELETE FROM settled WHERE request_id='rq_2'; DELETE FROM outbox WHERE request_id='rq_2'"); stateSet(o, st("900")); }, ["r2"]);
// RUNNING sink: middle zero deletion by a foreign writer; guard re-audits; the deleted token commits again.
{ const p = honest("R1-running", ["r1", "z1", "z2"]); const s = new V6(p, cfg);
  foreign(p, o => o.exec("DELETE FROM settled WHERE request_id='rq_z1'; DELETE FROM outbox WHERE request_id='rq_z1'"));
  const ab = lastAbort; const c = s.commit(T.z1); const c2 = s.commit(T.z1);
  say("R1-running-middle-zero-deleted", { sqlAbort: ab || null, recommitZ1: res(c), replayAgain: res(c2), reaudits: s.reaudits, counts: counts(p) }); s.close(); }
// Writer guard: a foreign write that changes nothing (UPDATE same value), and a WAL switch by a foreign connection.
{ const p = honest("G1-noop-write", ["r1"]); const s = new V6(p, cfg);
  foreign(p, o => o.exec("UPDATE state SET blob = blob"));
  const c = s.commit(T.r2); say("G1-noop-foreign-write", { c: res(c), reaudits: s.reaudits }); s.close(); }
{ const p = honest("G2-wal", ["r1"]); const s = new V6(p, cfg);
  foreign(p, o => { o.exec("PRAGMA journal_mode=WAL"); o.exec("DELETE FROM settled WHERE request_id='rq_1'; DELETE FROM outbox; UPDATE state SET blob = '" + canon(st("1000")) + "'"); });
  const ab = lastAbort; const c = s.commit(T.r1); say("G2-wal-switch-then-rollback-by-foreign", { sqlAbort: ab || null, c: res(c), reaudits: s.reaudits, counts: counts(p) }); s.close(); }
// COMPLETENESS (no brick) for honest stores
{ const p = honest("C1", ["r1"]); const s = new V6(p, cfg); const rj = [s.commit(T.r1).status, s.commit(T.r3).status, s.commit(tok(st("900"), "rq_big", "901")).status, s.commit("x").status]; s.close();
  say("C1-commit-then-rejected-deliveries", { rj, restart: restart(p) }); }
{ const p = `${dir}/C2.sqlite`; const s = new V6(p, cfg); s.init(st("1000")); let n = 0;
  for (let i = 0; i < 300; i++) if (s.commit(tok(st("1000"), "rq_zz" + i, "0")).status === "committed") n++; s.close();
  say("C2-300-zero-commits", { n, restart: restart(p) }); }
try { const M = "9999999999999999999"; const c2 = mkcfg(st(M, "ch_1", M)); const p = `${dir}/C3.sqlite`; const s = new V6(p, c2); s.init(st(M, "ch_1", M));
  const a = s.commit(tok(st(M, "ch_1", M), "rq_max", M)).status, b = s.commit(tok(st("0", "ch_1", M), "rq_after", "0")).status; s.close();
  say("C3-max-amount", { a, b, restart: restart(p, c2) }); } catch (e) { say("C3-max-amount", { constructor: "REFUSED: " + short(e).slice(0, 70) }); }
{ const p1 = `${dir}/C4a.sqlite`; new V6(p1, cfg).close(); const p2 = `${dir}/C4b.sqlite`; const s = new V6(p2, cfg); s.init(st("1000")); s.close();
  say("C4-fresh-and-init-only", { fresh: restart(p1), initOnly: restart(p2) }); }
{ const p = `${dir}/C5.sqlite`; const a = new V6(p, cfg); a.init(st("1000")); const b = new V6(p, cfg); let rem = 1000; const out: string[] = [];
  for (let i = 0; i < 6; i++) { const w = i % 2 ? b : a; out.push(w.commit(tok(st(String(rem)), "rq_alt" + i, "7")).status); rem -= 7; }
  say("C5-two-writers-alternating", { out, reauditsA: a.reaudits, reauditsB: b.reaudits, restart: restart(p) }); a.close(); b.close(); }
{ const cid = "ch_\u{1F600}\"\\\u0001 é\t/"; const rid = "rq_\u{10FFFF}\u{1F4A9}\\\"\u007f"; const c6 = mkcfg(st("1000", cid));
  const p = `${dir}/C6.sqlite`; const s = new V6(p, c6); s.init(st("1000", cid));
  const a = s.commit(tok(st("1000", cid), rid, "100")).status, b = s.commit(tok(st("900", cid), rid + "\u{1F600}", "0")).status; s.close();
  say("C6-non-BMP-and-escapes", { a, b, restart: restart(p, c6) }); }
