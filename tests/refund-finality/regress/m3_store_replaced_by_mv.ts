// Regression for red team C-ATT-39 (night shift 2026-11-19, task h-minter3; copy of the logic of orch-C s4_paths.ts
// "mv"). A TEST, not a proof. Attacker: none. The operator restores the sink's store by `mv` (another inode at the same
// path) while the issuer runs; the honest sink restarts on the file at the path. The issuer must follow the path: the
// next two honest requests are signed and commit. Also: a store path that does not exist is refused with its own text
// "store: the store path is gone" (and nothing is signed).
// FAILS on the earlier issuer (it kept one connection to the old inode and refused every later honest request).
// Usage: <treeRoot> <compiledIssuerModule>. Exit 0 PASS, 1 FAIL, 3 harness.
import { copyFileSync, renameSync } from "node:fs";
import { spawn } from "node:child_process";
import { join } from "node:path";
import { State, argv, guard, load, tempDir, verdict } from "./m_lib";
import { makeKeyFile, makeMemoryFile } from "./kf_lib";
// ---- issuer driver (own copy in each m3_*.ts: standalone). Raw bytes in, one parsed answer per 0x0A-ended line.
// Returns null when the issuer does not start with these arguments (an earlier issuer has no such option).
async function startIssuer(root: string, core: string, mode: "on" | "off", store?: string, extra: string[] = []): Promise<Issuer | null> {
  const args = [join(root, "ts/refund-finality/minter.ts"), core, join(root, "spec/refund/spec.lock"), mode, makeKeyFile().path, ...(store ? [store, ...(mode === "on" ? [makeMemoryFile()] : [])] : []), ...extra];
  const child = spawn(process.execPath, ["--import", "tsx", ...args], { cwd: root, stdio: ["pipe", "pipe", "pipe"] });
  child.stderr.on("data", () => { /* identity information and operator details: not used */ });
  let buf = Buffer.alloc(0), ready: any = null, exited = false, next = 1;
  const answers = new Map<number, any>();
  child.on("exit", () => { exited = true; });
  child.stdout.on("data", (c: Buffer) => {
    buf = Buffer.concat([buf, c]);
    for (let i = buf.indexOf(0x0a); i >= 0; i = buf.indexOf(0x0a)) {
      const msg = JSON.parse(buf.subarray(0, i).toString("utf8")); buf = buf.subarray(i + 1);
      if (msg.ready) ready = msg; else answers.set(msg.id, msg);
    }
  });
  const until = async (p: () => boolean, ms = 30000): Promise<boolean> => {
    const end = Date.now() + ms;
    while (!p() && !exited && Date.now() < end) await new Promise(r => setTimeout(r, 5));
    return p();
  };
  if (!(await until(() => ready !== null))) { child.kill(); return null; }
  const mint = async (pre: State, t: unknown): Promise<any> => {
    const id = next++;
    child.stdin.write(JSON.stringify({ id, pre, transition: t }) + "\n");
    if (!(await until(() => answers.has(id)))) throw new Error("no answer from the issuer");
    return answers.get(id);
  };
  return { ready, mint, stop: () => { child.stdin.end(); child.kill(); } };
}
type Issuer = { ready: any; mint: (pre: State, t: unknown) => Promise<any>; stop: () => void };
const propose = (pre: State, requestId: string, amount: string, reason = "duplicate_charge") => ({
  request: { requestId, amount, reason },
  post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() },
  intent: { chargeId: pre.chargeId, requestId, amount, reason },
});
// A sink pinned to the issuer's key, on a fresh store file.
function sinkFor(root: string, ready: any, s0: State, path: string): any {
  const { Sink } = load(root);
  const sink = new Sink(path, { publicKeyPem: ready.publicKeyPem, specLockSha256: ready.specLockSha256, checkerSha256: ready.checkerSha256, initialState: s0 });
  sink.init(s0);
  return sink;
}
guard((async () => {
  const { root, core } = argv();
  const { E, Sink } = load(root);
  const r: any = {};
  const S0: State = { chargeId: "ch_m3p", original: "1000", remaining: "1000", refundEnabled: true };
  const dir = tempDir(), real = join(dir, "real.sqlite");
  const m = await startIssuer(root, core, "on", real);
  if (m === null) verdict(false, { issuer: "DID NOT START" });
  const ids = { publicKeyPem: m!.ready.publicKeyPem, specLockSha256: m!.ready.specLockSha256, checkerSha256: m!.ready.checkerSha256, initialState: S0 };
  const sink = sinkFor(root, m!.ready, S0, real);
  const t1 = await m!.mint(S0, propose(S0, "rq_1", "100"));
  r.first = t1.ok ? sink.commit(E.tokenText(t1.token)).status : "refused: " + t1.reason;
  const s1: State = JSON.parse(sink.stateBlob());
  sink.close();
  const copy = join(dir, "copy.sqlite"); copyFileSync(real, copy); renameSync(copy, real);   // operator restore by mv
  const sink2 = new Sink(real, ids);
  const t2 = await m!.mint(s1, propose(s1, "rq_2", "100"));
  r.afterReplace = t2.ok ? "issued -> " + sink2.commit(E.tokenText(t2.token)).status : "refused: " + t2.reason;
  const s2: State = JSON.parse(sink2.stateBlob());
  const t3 = await m!.mint(s2, propose(s2, "rq_3", "100"));
  r.afterNextCommit = t3.ok ? "issued -> " + sink2.commit(E.tokenText(t3.token)).status : "refused: " + t3.reason;
  const z = await m!.mint(JSON.parse(sink2.stateBlob()), propose(JSON.parse(sink2.stateBlob()), "rq_z", "0"));
  r.zero = z.ok ? sink2.commit(E.tokenText(z.token)).status : "refused: " + z.reason;
  sink2.close(); m!.stop();
  const g = await startIssuer(root, core, "on", join(dir, "typo.sqlite"));
  if (g === null) verdict(false, { ...r, missing: "DID NOT START" });
  const t = await g!.mint(S0, propose(S0, "rq_1", "100"));
  r.missing = t.ok ? "SIGNED" : "refused: " + t.reason;
  g!.stop();
  verdict(r.first === "committed" && r.afterReplace === "issued -> committed" && r.afterNextCommit === "issued -> committed" &&
    r.zero === "committed" && r.missing === "refused: store: the store path is gone", r);
})());
