// c16 hmig: an honest store written by the v6 sink (target-v6), then opened by the h1 sink (fix-608b5165) with the
// same config. B's notes section 6 say: REFUSED; import designed, not implemented. Usage: hmig.ts <work>
// Exit 1 = the h1 sink refuses an honest v6 store (upgrade false rejection, documented by B); 0 = it serves.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
const SC = "<SCRATCH>/redteam-C";
/* eslint-disable @typescript-eslint/no-require-imports */
const E = require(join(SC, "target-v6/ts/refund-finality/encoding.ts"));
const V6 = require(join(SC, "target-v6/ts/refund-finality/sink.ts"));
const H1 = require(join(SC, "fix-608b5165/ts/refund-finality/sink.ts"));
/* eslint-enable @typescript-eslint/no-require-imports */
const [work] = process.argv.slice(2);
rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
const k = generateKeyPairSync("ed25519"), pem = k.publicKey.export({ type: "spki", format: "pem" }) as string;
const ids = { publicKeyPem: pem, specLockSha256: "a".repeat(64), checkerSha256: "b".repeat(64) };
const s0 = { chargeId: "ch_mig", original: "1000", remaining: "1000", refundEnabled: true }, s1 = { ...s0, remaining: "900" };
const body = { domain: E.DOMAIN, ...{ specLockSha256: ids.specLockSha256, checkerSha256: ids.checkerSha256 }, preStateSha256: E.stateSha256(s0), requestId: "r1", post: s1,
  intent: { chargeId: "ch_mig", requestId: "r1", amount: "100", reason: "duplicate_charge" } };
const tok = E.canon({ body, signature: sign(null, Buffer.from(E.canon(body), "utf8"), k.privateKey).toString("base64") });
const db = join(work, "v6.sqlite");
const a = new V6.Sink(db, { ...ids, initialState: s0 }); a.init(s0); const c = a.commit(tok); const au = a.audit(); a.close();
let h1 = "serves"; try { new H1.Sink(db, { ...ids, initialState: s0 }).close(); } catch (e) { h1 = String((e as Error).message).slice(0, 220); }
console.log(JSON.stringify({ v6commit: c, v6audit: au, h1open: h1 }));
process.exit(h1 === "serves" ? 0 : 1);
