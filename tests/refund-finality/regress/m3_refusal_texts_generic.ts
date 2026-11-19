// Regression for the state-oracle part of red team C-ATT-38 (night shift 2026-11-19, task h-minter3). A TEST, not a proof.
// A caller without the key, who knows the charge id and the original amount, sends one UNAUTHORIZED request (unapproved
// reason) per guessed pre-state (remaining = 1000 down to 0) with a fresh request id each. The answers must not tell the
// guesses apart: every answer is the same refusal text, and nothing is signed. (Earlier: "pre-state is not the
// authoritative stored state" for a wrong guess and "core: Refuse" for the right one: 364 probes found the state.)
// Store mode (production). NOT covered (a stated limit, m3_zero_squat_limit.ts): AUTHORIZED zero-amount guesses, where
// the answer is a token for the right guess.
// FAILS on the earlier issuer (two distinct texts). Usage: <treeRoot> <compiledIssuerModule>. Exit 0 PASS, 1 FAIL.
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
  const { E } = load(root);
  const S0: State = { chargeId: "ch_m3o", original: "1000", remaining: "1000", refundEnabled: true };
  const path = join(tempDir(), "s.sqlite");
  const m = await startIssuer(root, core, "on", path);
  if (m === null) verdict(false, { issuer: "DID NOT START" });
  const sink = sinkFor(root, m!.ready, S0, path);
  let cur = S0;
  for (const [rid, a] of [["rq_h1", "137"], ["rq_h2", "226"]]) {
    const t = await m!.mint(cur, propose(cur, rid, a)); sink.commit(E.tokenText(t.token)); cur = JSON.parse(sink.stateBlob());
  }
  const texts = new Map<string, number>(); let signed = 0, probes = 0;
  for (let rem = 1000; rem >= 1; rem--) {
    const g: State = { ...S0, remaining: String(rem) }; probes++;
    const a = await m!.mint(g, propose(g, "rq_probe_" + rem, "1", "attacker_text"));
    if (a.ok) signed++; else texts.set(a.reason, (texts.get(a.reason) ?? 0) + 1);
  }
  const r = { probes, signed, distinctTexts: Object.fromEntries(texts), hiddenRemaining: cur.remaining, settledRows: sink.settled().length };
  sink.close(); m!.stop();
  verdict(signed === 0 && texts.size === 1, r);
})());
