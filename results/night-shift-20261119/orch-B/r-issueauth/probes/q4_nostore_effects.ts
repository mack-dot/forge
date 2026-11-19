// r-issueauth Q4: NoStore mode. Does single-use still bound EFFECTS to one per request id when combined with the real
// sink at this commit? A NoStore issuer signs the SAME (chargeId,requestId) on TWO different pre-states (its key
// includes the pre-state hash, so it signs both). Feed both tokens to the real sink. The sink commits at most one per
// request id and only on its stored pre-state. exit 0 = HOLDS (<=1 effect/commit). exit 1 = DEFEATED (two commits).
import { join, resolve } from "node:path";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
const root = resolve(process.argv[2]), core = resolve(process.argv[3]);
/* eslint-disable @typescript-eslint/no-require-imports */
const E = require(join(root, "ts/refund-finality/encoding.ts"));
const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
const { MinterClient } = require(join(root, "ts/refund-finality/proposer.ts"));
const dir = mkdtempSync(join(tmpdir(), "forge-r-q4-"));
process.on("exit", () => { try { rmSync(dir, { recursive: true, force: true }); } catch {} });
const propose = (pre: any, rq: string, amt: string) => ({ request: { requestId: rq, amount: amt, reason: "duplicate_charge" },
  post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amt)).toString() },
  intent: { chargeId: pre.chargeId, requestId: rq, amount: amt, reason: "duplicate_charge" } });
(async () => {
  const S0 = { chargeId: "ch_q4", original: "1000", remaining: "1000", refundEnabled: true };
  const S1 = { chargeId: "ch_q4", original: "1000", remaining: "900", refundEnabled: true }; // a different (invented or later) pre-state
  const m = await MinterClient.start(root, core, join(root, "spec/refund/spec.lock"), "on"); // NoStore: no store arg
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const sink = new Sink(join(dir, "s.sqlite"), { ...ids, initialState: S0 }); sink.init(S0);
  const t0 = await m.mint(S0, propose(S0, "rq_dup", "100")); // on the stored pre-state
  const t1 = await m.mint(S1, propose(S1, "rq_dup", "100")); // same request id, a DIFFERENT pre-state
  const signedBoth = t0.ok && t1.ok;
  const c0 = t0.ok ? sink.commit(E.tokenText(t0.token)) : { status: "mint refused: " + t0.reason };
  const c1 = t1.ok ? sink.commit(E.tokenText(t1.token)) : { status: "mint refused: " + t1.reason };
  const committed = [c0, c1].filter(c => c.status === "committed").length;
  const r = { noStoreSignedTwoTokensForOneId: signedBoth, firstPreState: c0.status, secondPreState: c1.status, committedCount: committed };
  console.log(JSON.stringify(r, null, 0));
  sink.close(); m.stop();
  const defeated = committed > 1;
  console.log(defeated ? "DEFEATED: two effects for one request id" : "HOLDS: at most one effect for one request id (NoStore signs two tokens, sink commits one)");
  process.exit(defeated ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
