// d-v3sink2: a SCALING MEASUREMENT (not a stress test). One short run. Test keys made in this process.
// For N settled rows (inserted directly with SQL in a test database: N zero-amount outbox rows for ch_1, so the
// store is consistent), it times: the start-up audit (constructor), commit 1 and commit 2 (no other writer), and
// commit 3 after ONE row written by another connection (the writer guard's re-audit path). v3 is timed at the
// smaller sizes only (known quadratic; RangeError near 200,000). It prints EXPLAIN QUERY PLAN of the lookup.
// Usage (cwd = repository): node --import tsx probe_scale.ts <dir> <N,N,...> <v3maxN>
import { generateKeyPairSync, sign } from "node:crypto";
import { existsSync, mkdirSync, rmSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { canon, signedBytes, stateSha256, DOMAIN, ChargeState } from "/Users/mackianni/forge/ts/refund-finality/encoding";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const V4 = require("/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-v3sink2/sink_core_backed_v4.ts").Sink;
// eslint-disable-next-line @typescript-eslint/no-require-imports
const V3 = require("/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-v3sink/sink_core_backed_v3.ts").Sink;

const dir = process.argv[2]; mkdirSync(dir, { recursive: true });
const sizes = process.argv[3].split(",").map(Number), v3max = Number(process.argv[4]);
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const cfg = { publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64) };
const st = (remaining: string): ChargeState => ({ chargeId: "ch_1", original: "1000", remaining, refundEnabled: true });
function tok(pre: ChargeState, requestId: string, amount: string): string {
  const post = { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
  const body = { domain: DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: stateSha256(pre),
    requestId, post, intent: { chargeId: "ch_1", requestId, amount, reason: "duplicate_charge" } };
  return canon({ body, signature: sign(null, signedBytes(body as any), privateKey).toString("base64") });
}
const ms = (t0: bigint) => Math.round(Number(process.hrtime.bigint() - t0) / 1e5) / 10;
let peakRss = 0; const rss = () => { peakRss = Math.max(peakRss, process.memoryUsage().rss); };
const out: any[] = [];
for (const n of sizes) for (const which of ["v4", "v3"]) {
  if (which === "v3" && n > v3max) continue;
  const S = which === "v4" ? V4 : V3, p = `${dir}/scale-${which}-${n}.sqlite`;
  for (const s of ["", "-wal", "-shm", "-journal"]) if (existsSync(p + s)) rmSync(p + s);
  { const s0 = new S(p, cfg); s0.init(st("1000")); s0.close(); }
  let t0 = process.hrtime.bigint();
  { const db = new DatabaseSync(p); db.exec("BEGIN");
    const a = db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, 'x', 'y')"), b = db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)");
    for (let i = 0; i < n; i++) { const r = "rq_pre_" + i; a.run(r); b.run(r, canon({ amount: "0", chargeId: "ch_1", reason: "duplicate_charge", requestId: r })); }
    db.exec("COMMIT");
    if (which === "v4" && n === sizes[0]) out.push({ plan: db.prepare("EXPLAIN QUERY PLAN SELECT token_sha256 FROM settled WHERE request_id = ?").all("rq_x").map((r: any) => r.detail) });
    db.close(); }
  const setupMs = ms(t0); rss();
  t0 = process.hrtime.bigint(); const s = new S(p, cfg); const auditMs = ms(t0); rss();
  t0 = process.hrtime.bigint(); const c1 = s.commit(tok(st("1000"), "rq_new_1", "10")); const c1Ms = ms(t0); rss();
  t0 = process.hrtime.bigint(); const c2 = s.commit(tok(st("990"), "rq_new_2", "10")); const c2Ms = ms(t0); rss();
  { const db = new DatabaseSync(p); db.exec("BEGIN IMMEDIATE");
    db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES ('rq_other', 'x', 'y')").run();
    db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run("rq_other", canon({ amount: "0", chargeId: "ch_1", reason: "duplicate_charge", requestId: "rq_other" }));
    db.exec("COMMIT"); db.close(); }
  t0 = process.hrtime.bigint(); const c3 = s.commit(tok(st("980"), "rq_new_3", "10")); const c3Ms = ms(t0); rss();
  t0 = process.hrtime.bigint(); const c4 = s.commit(tok(st("970"), "rq_new_4", "10")); const c4Ms = ms(t0); rss();
  const row = { which, n, setupMs, startAuditMs: auditMs, commit1Ms: c1Ms, commit2Ms: c2Ms, commitAfterOtherWriterMs: c3Ms, commitNextMs: c4Ms,
    statuses: [c1, c2, c3, c4].map((r: any) => r.status).join(","), reaudits: s.reaudits ?? "n/a", rssMB: Math.round(peakRss / 1048576) };
  s.close(); rmSync(p, { force: true });
  out.push(row); console.log(JSON.stringify(row));
}
console.log(JSON.stringify(out[0]));
