// d-v5sink: ONE SCALING MEASUREMENT (not a stress test), after d-v3sink2/ts/probe_scale.ts. Test keys made here.
// N honest rows are inserted with SQL (real signed zero-amount tokens for ch_1, so AuditV5 is TRUE; the pre-state
// never changes, so one pre-state hash). It times: the start-up audit (constructor: schema, meta, AuditV5 with one
// Ed25519 verification per row), commit 1 and 2, commit 3 after ONE honest row written by another connection (the
// writer guard's full re-audit), and commit 4. Usage (cwd = repository): node --import tsx probe_scale_v5.ts <dir> <N>
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { canon, signedBytes, stateSha256, sha256hex, DOMAIN, ChargeState } from "<REPO>/ts/refund-finality/encoding";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const V5 = require("<REPO>/results/night-shift-20261119/orch-B/d-v5sink/sink_core_backed_v5.ts").Sink;
const dir = process.argv[2]; rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true });
const n = Number(process.argv[3]);
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const st = (remaining: string): ChargeState => ({ chargeId: "ch_1", original: "1000", remaining, refundEnabled: true });
const cfg = { publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: st("1000") };
function tok(pre: ChargeState, requestId: string, amount: string): { text: string; intent: string } {
  const post = { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
  const intent = { chargeId: "ch_1", requestId, amount, reason: "duplicate_charge" };
  const body = { domain: DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: stateSha256(pre), requestId, post, intent };
  return { text: canon({ body, signature: sign(null, signedBytes(body as any), privateKey).toString("base64") }), intent: canon(intent) };
}
const ms = (t0: bigint) => Math.round(Number(process.hrtime.bigint() - t0) / 1e5) / 10;
let peakRss = 0; const rss = () => { peakRss = Math.max(peakRss, process.memoryUsage().rss); };
const p = dir + "/scale-v5-" + n + ".sqlite";
{ const s0 = new V5(p, cfg); s0.init(st("1000")); s0.close(); }
let t0 = process.hrtime.bigint();
{ const db = new DatabaseSync(p); db.exec("BEGIN");
  const a = db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, ?, ?)"), b = db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)");
  for (let i = 0; i < n; i++) { const r = "rq_pre_" + i, t = tok(st("1000"), r, "0"); a.run(r, t.text, sha256hex(t.text)); b.run(r, t.intent); }
  db.exec("COMMIT"); db.close(); }
const setupMs = ms(t0); rss();
t0 = process.hrtime.bigint(); const s = new V5(p, cfg); const auditMs = ms(t0); rss();
t0 = process.hrtime.bigint(); const c1 = s.commit(tok(st("1000"), "rq_new_1", "10").text); const c1Ms = ms(t0); rss();
t0 = process.hrtime.bigint(); const c2 = s.commit(tok(st("990"), "rq_new_2", "10").text); const c2Ms = ms(t0); rss();
{ const o = new V5(p, cfg); o.commit(tok(st("980"), "rq_other", "0").text); o.close(); }   // honest other writer (its own start-up audit is not timed)
t0 = process.hrtime.bigint(); const c3 = s.commit(tok(st("980"), "rq_new_3", "10").text); const c3Ms = ms(t0); rss();
t0 = process.hrtime.bigint(); const c4 = s.commit(tok(st("970"), "rq_new_4", "10").text); const c4Ms = ms(t0); rss();
const row = { which: "v5", n, setupMs, startAuditMs: auditMs, perRowAuditUs: Math.round(auditMs * 1000 / n), commit1Ms: c1Ms, commit2Ms: c2Ms,
  commitAfterOtherWriterMs: c3Ms, commitNextMs: c4Ms, statuses: [c1, c2, c3, c4].map((r: any) => r.status).join(","), reaudits: s.reaudits, rssMB: Math.round(peakRss / 1048576) };
s.close(); rmSync(dir, { recursive: true, force: true });
console.log(JSON.stringify(row));
