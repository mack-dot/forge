// r-v5: cost of the guard's full re-audit with two alternating honest writers at N rows. One short run. A TEST.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { canon, signedBytes, stateSha256, DOMAIN, ChargeState } from "<REPO>/ts/refund-finality/encoding";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const V6 = require("<REPO>/results/night-shift-20261119/orch-B/d-v6sink/sink_core_backed_v6.ts").Sink;
const dir = process.argv[2], N = Number(process.argv[3]); rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true });
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const st = (remaining: string, original = "1000000"): ChargeState => ({ chargeId: "ch_1", original, remaining, refundEnabled: true });
const cfg: any = { publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: st("1000000") };
function tok(pre: ChargeState, requestId: string, amount: string): string {
  const post = { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
  const body = { domain: DOMAIN, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), preStateSha256: stateSha256(pre), requestId, post, intent: { chargeId: "ch_1", requestId, amount, reason: "duplicate_charge" } };
  return canon({ body, signature: sign(null, signedBytes(body as any), privateKey).toString("base64") });
}
const ms = (t: bigint) => Number(process.hrtime.bigint() - t) / 1e6;
const p = dir + "/c.sqlite"; let t = process.hrtime.bigint();
const a = new V6(p, cfg); a.init(st("1000000")); let rem = 1000000, ok = 0;
for (let i = 0; i < N; i++) { if (a.commit(tok(st(String(rem)), "rq_" + i, "1")).status === "committed") { ok++; rem--; } }
console.log(JSON.stringify({ k: "build", N, ok, ms: ms(t).toFixed(0) }));
t = process.hrtime.bigint(); const b = new V6(p, cfg); console.log(JSON.stringify({ k: "startup-audit", ms: ms(t).toFixed(0) }));
const per: string[] = [];
for (let i = 0; i < 6; i++) { const w = i % 2 ? b : a; t = process.hrtime.bigint(); const r = w.commit(tok(st(String(rem)), "rq_alt" + i, "1")); per.push(r.status[0] + ms(t).toFixed(0)); if (r.status === "committed") rem--; }
console.log(JSON.stringify({ k: "alternating-commits-ms", per, reauditsA: a.reaudits, reauditsB: b.reaudits }));
t = process.hrtime.bigint(); const r1 = a.commit(tok(st(String(rem)), "rq_same1", "1")); rem--; const r2 = a.commit(tok(st(String(rem)), "rq_same2", "1"));
console.log(JSON.stringify({ k: "same-writer-twice-ms", r: [r1.status, r2.status], ms: ms(t).toFixed(1) }));
a.close(); b.close();
{ const M = "9223372036854775807"; const c2 = { ...cfg, initialState: st(M, M) }; const q = dir + "/max.sqlite"; const s = new V6(q, c2); s.init(st(M, M));
  const r = s.commit(tok(st(M, M), "rq_max", M)); s.close(); let rs = "STARTED"; try { new V6(q, c2).close(); } catch { rs = "REFUSED"; }
  console.log(JSON.stringify({ k: "MaxMoney-full-refund", r: r.status, restart: rs })); }
