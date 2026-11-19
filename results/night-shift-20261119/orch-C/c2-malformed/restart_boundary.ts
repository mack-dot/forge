// c2-malformed: boundary texts through a FILE database: commit (amount 0 and 1), close, restart (start-up AuditV5
// with the compiled core), replay, offline audit, dispatcher flush twice. Also deep-nesting token texts at the
// 8192 limit. Exit 1 if any legitimate case is refused or anything else misbehaves; 0 when safe.
// Usage: node --import tsx restart_boundary.ts <target root> <work dir>
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
const [root, work] = process.argv.slice(2);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const E = require(join(root, "ts/refund-finality/encoding.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Dispatcher } = require(join(root, "ts/refund-finality/dispatcher.ts"));
rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const pem = publicKey.export({ type: "spki", format: "pem" }) as string;
const SPEC = "a".repeat(64), CHK = "b".repeat(64);
function mint(pre: any, rid: string, amount: string) {
  const body: any = { domain: E.DOMAIN, specLockSha256: SPEC, checkerSha256: CHK, preStateSha256: E.stateSha256(pre), requestId: rid,
    post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() }, intent: { chargeId: pre.chargeId, requestId: rid, amount, reason: "returned_item" } };
  return E.canon({ body, signature: sign(null, E.signedBytes(body), privateKey).toString("base64") });
}
const classes = ["\"", "\\", "\u0001", "\b", "\n", "\r", "\u007f", "\u0085", " ", " ", "￿", "￾", "﻿", "😀", "\u{10FFFF}", "é", " ", "0", "1e3"];
let bad = 0;
classes.forEach((c, k) => {
  const id = c.repeat(Math.floor(256 / c.length)), rid0 = c.repeat(Math.floor(255 / c.length)) + "a", rid1 = c.repeat(Math.floor(255 / c.length)) + "b";
  const s0 = { chargeId: id, original: "10", remaining: "10", refundEnabled: true };
  const cfg = { publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK, initialState: s0 };
  const db = join(work, "b" + k + ".sqlite"), ledger = join(work, "b" + k + ".ledger");
  const out: any = {};
  try {
    let sink = new Sink(db, cfg); sink.init(s0);
    const t0 = mint(s0, rid0, "0"); out.c0 = sink.commit(t0).status;
    const s1 = JSON.parse(sink.stateBlob()); const t1 = mint(s1, rid1, "1"); out.c1 = sink.commit(t1).status; sink.close();
    sink = new Sink(db, cfg);                                   // restart: the start-up audit
    out.r0 = sink.commit(t0).status; out.r1 = sink.commit(t1).status; out.audit = sink.audit().length; sink.close();
    const dc = { publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK, initialStateSha256: E.stateSha256(s0) };
    const d1 = new Dispatcher(db, ledger, dc, () => {}).flush(), d2 = new Dispatcher(db, ledger, dc, () => {}).flush();
    out.d1 = d1.emitted.length; out.d1ref = d1.refused.length; out.d2 = d2.emitted.length; out.d2already = d2.alreadyDispatched;
  } catch (e) { out.error = String((e as Error).message).slice(0, 120); }
  const ok = out.c0 === "committed" && out.c1 === "committed" && out.r0 === "replayed" && out.r1 === "replayed" && out.audit === 0 &&
    out.d1 === 2 && out.d1ref === 0 && out.d2 === 0 && out.d2already === 2;
  if (!ok) bad++;
  console.log((ok ? "PASS " : "FAIL ") + JSON.stringify(c) + " " + JSON.stringify(out));
});
// deep nesting and odd JSON at the 8192 limit: rejected, no exception escapes commit()
{
  const s0 = { chargeId: "ch", original: "1", remaining: "1", refundEnabled: true };
  const sink = new Sink(":memory:", { publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK, initialState: s0 }); sink.init(s0);
  const inputs: Record<string, unknown> = { deep: "[".repeat(4096) + "]".repeat(4096), deepObj: "{\"a\":".repeat(1300) + "1" + "}".repeat(1300),
    n8193: " ".repeat(8193), nul: "null", num: "1", arr: "[]", num2: 5, obj: {}, und: undefined };
  const res: any = {}; let b = false;
  for (const [n, v] of Object.entries(inputs)) { let r: any; try { r = sink.commit(v); } catch (e) { r = { status: "THROW " + (e as Error).message }; } res[n] = r.status; if (r.status !== "rejected") b = true; }
  if (b) bad++;
  console.log((b ? "FAIL " : "PASS ") + "malformed inputs rejected without exception " + JSON.stringify(res));
  sink.close();
}
console.log("BAD " + bad);
process.exit(bad === 0 ? 0 : 1);
