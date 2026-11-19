// h-sink C-ATT-02 child: construct the hardened sink on argv[3]; SIGKILL itself at the argv[4]-th DatabaseSync.exec call
// (before that call runs). The kill leaves whatever SQLite has on disk (a hot rollback journal inside a transaction).
import { generateKeyPairSync } from "node:crypto";
import { DatabaseSync } from "node:sqlite";
const [TREE, DB, KS, MODE] = process.argv.slice(2);   // MODE "noinit": construct only (kill storm) const K = Number(KS);
const P = DatabaseSync.prototype as any, orig = P.exec; let n = 0;
P.exec = function (sql: string) { if (++n === K) { process.stdout.write("killed-at " + n + " " + sql.slice(0, 40).replace(/\s+/g, " ") + "\n"); process.kill(process.pid, "SIGKILL"); } return orig.call(this, sql); };
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Sink } = require(TREE + "/ts/refund-finality/sink.ts");
const S0 = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
const pem = generateKeyPairSync("ed25519").publicKey.export({ type: "spki", format: "pem" });
const s = new Sink(DB, { publicKeyPem: pem, specLockSha256: "a".repeat(64), checkerSha256: "b".repeat(64), initialState: S0 });
if (MODE !== "noinit") s.init(S0); s.close();
process.stdout.write("completed after " + n + " exec calls\n");
