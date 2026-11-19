// KNOWN-LIMIT regression (night shift 2026-11-19, task h-minter3; red team C-ATT-08 class, s8_squat_search.ts "zero").
// A caller without the key, who knows the charge id, the original amount and the victim's request id, sends AUTHORIZED
// zero-amount requests with the victim's request id on every guessed pre-state. Wrong guesses are refused and record
// nothing; the right guess is MINTED (a valid zero-amount token), and that token takes the victim's request id (I1:
// at most one valid token per request id). The victim's honest request is then refused. The issuer has no caller
// identity, so no issuer rule can tell this caller from the victim (Dafny witness: WSquatRealState). No money moves.
// Exit codes: the limit reproduced: prints KNOWN-LIMIT and exits 0 ONLY with the argument --expect-limit; else exit 1.
// The limit not reproduced (the victim commits): PASS, exit 0. Store mode (production).
// Usage: node --import tsx m3_zero_squat_limit.ts <treeRoot> <compiledIssuerModule> [--expect-limit]
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
  const expectLimit = process.argv.slice(4).includes("--expect-limit");
  const { E } = load(root);
  const S0: State = { chargeId: "ch_m3z", original: "1000", remaining: "1000", refundEnabled: true };
  const path = join(tempDir(), "s.sqlite");
  const m = await startIssuer(root, core, "on", path);
  if (m === null) verdict(false, { issuer: "DID NOT START" });
  const sink = sinkFor(root, m!.ready, S0, path);
  let cur = S0;
  for (const [rid, a] of [["rq_h1", "137"], ["rq_h2", "226"]]) {
    const t = await m!.mint(cur, propose(cur, rid, a)); sink.commit(E.tokenText(t.token)); cur = JSON.parse(sink.stateBlob());
  }
  const victim = "rq_victim"; let probes = 0, hit: string | null = null;
  for (let rem = 1000; rem >= 0 && hit === null; rem--) {
    const g: State = { ...S0, remaining: String(rem) }; probes++;
    const a = await m!.mint(g, propose(g, victim, "0"));
    if (a.ok) hit = String(rem);
  }
  const v = await m!.mint(cur, propose(cur, victim, "250"));
  const r = { probes, squatMintedOnRemaining: hit, sinkRows: sink.settled().length,
    victim: v.ok ? "issued -> " + sink.commit(E.tokenText(v.token)).status : "refused: " + v.reason };
  sink.close(); m!.stop();
  if (v.ok) verdict(true, r);
  console.log(JSON.stringify(r));
  if (expectLimit) { console.log("KNOWN-LIMIT (C-ATT-08 class: a minted squat on the real state takes the request id; no caller identity)"); process.exit(0); }
  console.log("FAIL (the limit is present; run with --expect-limit to accept it as the known limit)"); process.exit(1);
})());
