// helper: a hardened sink store for ch_L (state 1000/1000), made with a throwaway key. Usage: mkstore.ts <path>
import { generateKeyPairSync } from "node:crypto";
import { join } from "node:path";
const SINK = require(join(process.cwd(), "ts/refund-finality/sink.ts"));
const s0 = { chargeId: "ch_L", original: "1000", remaining: "1000", refundEnabled: true };
const k = generateKeyPairSync("ed25519").publicKey.export({ type: "spki", format: "pem" });
const s = new SINK.Sink(process.argv[2], { publicKeyPem: k, specLockSha256: "0".repeat(64), checkerSha256: "0".repeat(64), initialState: s0 });
s.init(s0); s.close();
