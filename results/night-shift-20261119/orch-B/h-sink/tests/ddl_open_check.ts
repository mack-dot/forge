// h-sink: open a file with the hardened sink (honest config); print "ok" if it starts, init()s and commits a zero-amount
// refund, else the refusal. Used by heavy_h.sh (kill storm). Usage: ddl_open_check.ts <tree> <db>
import { generateKeyPairSync, sign } from "node:crypto";
const [TREE, DB] = process.argv.slice(2);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const E = require(TREE + "/ts/refund-finality/encoding.ts"), { Sink } = require(TREE + "/ts/refund-finality/sink.ts");
const S0 = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
const k = generateKeyPairSync("ed25519"), cfg = { publicKeyPem: k.publicKey.export({ type: "spki", format: "pem" }), specLockSha256: "a".repeat(64), checkerSha256: "b".repeat(64), initialState: S0 };
const body = { domain: E.DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: E.stateSha256(S0), requestId: "rq_z", post: S0, intent: { chargeId: "ch_1", requestId: "rq_z", amount: "0", reason: "returned_item" } };
try { const s = new Sink(DB, cfg); s.init(S0); const r = s.commit(E.canon({ body, signature: sign(null, E.signedBytes(body), k.privateKey).toString("base64") })); s.close(); console.log(r.status === "committed" ? "ok" : "commit " + JSON.stringify(r)); }
catch (e) { console.log("REFUSED " + String((e as Error).message).slice(0, 200)); }
