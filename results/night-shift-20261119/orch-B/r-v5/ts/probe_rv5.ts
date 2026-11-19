// r-v5: small probes: (a) the reason of the max-amount rejection; (b) data_version after a foreign no-op and a
// foreign change+restore in one transaction. One short run. A TEST.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { canon, signedBytes, stateSha256, DOMAIN, ChargeState } from "<REPO>/ts/refund-finality/encoding";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const V6 = require("<REPO>/results/night-shift-20261119/orch-B/d-v6sink/sink_core_backed_v6.ts").Sink;
const dir = process.argv[2]; rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true });
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const st = (remaining: string, original = "1000"): ChargeState => ({ chargeId: "ch_1", original, remaining, refundEnabled: true });
const mk = (i: ChargeState): any => ({ publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: i });
function tok(pre: ChargeState, requestId: string, amount: string): string {
  const post = { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
  const body = { domain: DOMAIN, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), preStateSha256: stateSha256(pre), requestId, post, intent: { chargeId: "ch_1", requestId, amount, reason: "duplicate_charge" } };
  return canon({ body, signature: sign(null, signedBytes(body as any), privateKey).toString("base64") });
}
for (const [o, a] of [["9999999999999999999", "9999999999999999999"], ["9999999999999999999", "1"], ["1000000", "1000000"], ["1000", "1000"], ["100000000", "1"]]) {
  const p = `${dir}/m${o.length}-${a.length}.sqlite`; const s = new V6(p, mk(st(o, o))); s.init(st(o, o));
  console.log(JSON.stringify({ k: "max", original: o, amount: a, r: s.commit(tok(st(o, o), "rq_m", a)) })); s.close();
}
{ const p = `${dir}/g.sqlite`; const c = mk(st("1000")); const s = new V6(p, c); s.init(st("1000"));
  const dv = (d: DatabaseSync) => Number((d.prepare("PRAGMA data_version").get() as any).data_version);
  const mine = (s as any).db as DatabaseSync; const v0 = dv(mine);
  const f = new DatabaseSync(p); f.exec("UPDATE state SET blob = blob"); const v1 = dv(mine);
  f.exec("BEGIN IMMEDIATE; UPDATE state SET blob = 'x'; UPDATE state SET blob = '" + canon(st("1000")) + "'; COMMIT"); const v2 = dv(mine);
  f.close(); console.log(JSON.stringify({ k: "data_version", v0, afterNoop: v1, afterChangeRestore: v2 })); s.close(); }
