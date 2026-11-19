// r-harden probe P4 (HEAVY CLASS: a race run; PREPARED, NOT RUN by r-harden because hol.lock existed).
// Two sink PROCESSES on one file commit the same 200 signed tokens in different orders.
// usage (cwd = tree): node --import tsx p4_two_process_race.ts <treeRoot> <scratch dir>
// Exit 1: a request id committed twice, a wrong final state, a failed audit, or a child that does not finish in 60 s.
import { generateKeyPairSync, sign } from "node:crypto";
import { spawn } from "node:child_process";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { join, resolve } from "node:path";
const [T0, O0, role, file] = process.argv.slice(2); const TREE = resolve(T0), OUT = resolve(O0);
/* eslint-disable @typescript-eslint/no-require-imports */
const E = require(join(TREE, "ts/refund-finality/encoding.ts")); const HM = require(join(TREE, "ts/refund-finality/sink.ts"));
/* eslint-enable @typescript-eslint/no-require-imports */
if (role === "child") {
  const job = JSON.parse(require("node:fs").readFileSync(file, "utf8"));
  const s = new HM.Sink(job.db, job.cfg); const st: Record<string, number> = {};
  for (let round = 0; round < 3; round++) for (const t of job.order) { const r = s.commit(t).status; st[r] = (st[r] ?? 0) + 1; }
  s.close(); console.log(JSON.stringify(st)); process.exit(0);
}
rmSync(OUT, { recursive: true, force: true }); mkdirSync(OUT, { recursive: true });
const { publicKey, privateKey } = generateKeyPairSync("ed25519"); const pem = publicKey.export({ type: "spki", format: "pem" }) as string;
const S0 = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
const cfg = { publicKeyPem: pem, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: S0 };
// a chain of 200 tokens (each on the previous post state), amounts 0 or 1; plus for each a competing token (other amount) for the same id
const toks: string[] = []; let rem = 1000;
for (let i = 0; i < 200; i++) {
  const pre = { ...S0, remaining: String(rem) }, amt = i % 2 ? "1" : "0";
  const body = { domain: E.DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: E.stateSha256(pre), requestId: "rq_" + i,
    post: { ...pre, remaining: String(rem - Number(amt)) }, intent: { chargeId: "ch_1", requestId: "rq_" + i, amount: amt, reason: "duplicate_charge" } };
  toks.push(E.canon({ body, signature: sign(null, E.signedBytes(body), privateKey).toString("base64") })); rem -= Number(amt);
}
const db = join(OUT, "race.sqlite"); { const s = new HM.Sink(db, cfg); s.init(S0); s.close(); }
const jobs = [toks, [...toks].reverse()].map((order, k) => { const f = join(OUT, `job${k}.json`); writeFileSync(f, JSON.stringify({ db, cfg, order })); return f; });
const run = (f: string) => new Promise<string>(res => {
  const c = spawn(process.execPath, ["--import", "tsx", __filename, TREE, OUT, "child", f], { cwd: TREE, stdio: ["ignore", "pipe", "inherit"] });
  let o = ""; c.stdout.on("data", d => o += d); const t = setTimeout(() => { c.kill(); res("TIMEOUT"); }, 60000);
  c.on("exit", code => { clearTimeout(t); res(`code=${code} ${o.trim()}`); });
});
(async () => {
  const r = await Promise.all(jobs.map(run));
  const d = new DatabaseSync(db, { readOnly: true });
  const c = d.prepare("SELECT COUNT(*) n, COUNT(DISTINCT request_id) dn FROM settled").get() as any; const blob = (d.prepare("SELECT blob FROM state").get() as any).blob; d.close();
  const s = new HM.Sink(db, cfg); const audit = s.audit(); s.close();
  const ok = !r.some(x => x.startsWith("TIMEOUT")) && c.n === 200 && c.dn === 200 && blob === E.canon({ ...S0, remaining: String(rem) }) && audit.length === 0;
  console.log(JSON.stringify({ children: r, settled: c, finalOk: blob === E.canon({ ...S0, remaining: String(rem) }), audit }));
  rmSync(OUT, { recursive: true, force: true }); console.log(ok ? "SAFE" : "DEFEATED"); process.exit(ok ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
