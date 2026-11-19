// h-sink C-ATT-02 (light): for each kill point K in [FROM, TO], a fresh file; a child constructs the hardened sink and
// init()s it, and SIGKILLs itself at its K-th exec call (statement boundaries of schema creation, the audit transaction
// and init); then this process opens the file with an honest config: it must START (complete or re-initialise), init,
// and commit a zero-amount and a 100 refund. Also: a file with a PARTIAL h1 schema committed by hand is refused (it
// cannot arise from the sink: one transaction). Usage: ddl_crash.ts <tree> <out> <FROM> <TO>
import { execFileSync } from "node:child_process";
import { generateKeyPairSync, sign } from "node:crypto";
import { existsSync, mkdirSync, rmSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
const [TREE, OUT, F, T] = process.argv.slice(2);
mkdirSync(OUT, { recursive: true });
// eslint-disable-next-line @typescript-eslint/no-require-imports
const E = require(TREE + "/ts/refund-finality/encoding.ts"); const HM = require(TREE + "/ts/refund-finality/sink.ts");
const S0 = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
const k = generateKeyPairSync("ed25519"), pem = k.publicKey.export({ type: "spki", format: "pem" }) as string;
const cfg = { publicKeyPem: pem, specLockSha256: "a".repeat(64), checkerSha256: "b".repeat(64), initialState: S0 };
const tok = (pre: any, rid: string, amount: string) => { const body = { domain: E.DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256,
  preStateSha256: E.stateSha256(pre), requestId: rid, post: { ...pre, remaining: String(BigInt(pre.remaining) - BigInt(amount)) },
  intent: { chargeId: "ch_1", requestId: rid, amount, reason: "returned_item" } }; return E.canon({ body, signature: sign(null, E.signedBytes(body), k.privateKey).toString("base64") }); };
let bad = 0;
for (let K = Number(F); K <= Number(T); K++) {
  const p = `${OUT}/k${K}.sqlite`; rmSync(p, { force: true }); rmSync(p + "-journal", { force: true });
  let child = "";
  try { child = execFileSync(process.execPath, ["--import", "tsx", __dirname + "/ddl_child.ts", TREE, p, String(K)], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim(); }
  catch (e) { child = String((e as any).stdout ?? "").trim() + " (signal " + (e as any).signal + ")"; }
  const journal = existsSync(p + "-journal");
  let r: string;
  try { const s = new HM.Sink(p, cfg); s.init(S0); const a = s.commit(tok(S0, "rq_z", "0")).status, b = s.commit(tok(S0, "rq_1", "100")).status; s.close(); r = `started; z:${a} r1:${b}`; }
  catch (e) { r = "REFUSED: " + String((e as Error).message).slice(0, 120); }
  const pass = r === "started; z:committed r1:committed";
  if (!pass) bad++;
  console.log(`${pass ? "PASS" : "FAIL"} K=${K} child: ${child} | hot journal after kill: ${journal} | next open: ${r}`);
}
if (Number(F) === 1) { // partial h1 schema committed by hand (first 2 DDL statements): refused (not completed by the sink).
  const p = `${OUT}/partial.sqlite`; rmSync(p, { force: true }); const db = new DatabaseSync(p); db.exec(HM.SINK_DDL.split(";\n")[0] + ";"); db.close();
  let r: string; try { new HM.Sink(p, cfg).close(); r = "STARTED"; } catch (e) { r = "REFUSED: " + String((e as Error).message).replace(/^.*is false: /, ""); }
  const pass = r.startsWith("REFUSED") && r.includes("schema text"); if (!pass) bad++;
  console.log(`${pass ? "PASS" : "FAIL"} partial h1 schema (meta table only, committed outside the sink) | ${r}`);
}
console.log(`failed ${bad}`); process.exitCode = bad ? 1 : 0;
