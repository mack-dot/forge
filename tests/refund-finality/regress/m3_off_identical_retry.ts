// Regression for red team C-ATT-40 (night shift 2026-11-19, task h-minter3; logic of orch-C s2_stale.ts "off"). A TEST.
// Memory rule "off" (a TEST mode since D-2) with the sink's store. The header of minter.ts states the rule for an
// identical request in this mode; this file checks each case of it:
//  (a) before the commit: the identical request gets byte-identical token text (deterministic Ed25519);
//  (b) after the sink settled THAT token: the identical request (old pre-state) gets the byte-identical token text
//      (Replayed from the settled row; the sink answers "replayed"); earlier it was refused;
//  (c) after the commit, another candidate for that settled id: refused "attempt completed: use a new request id";
//  (d) the stated EXCEPTION: a token minted but never committed, after the store moved on by another request: the
//      identical request is refused "core: Refuse" (generic text; its old token cannot commit: stale pre-state);
//  (e) zero-amount refunds commit.
// FAILS on the earlier issuer ((b) refused). Usage: <treeRoot> <compiledIssuerModule>. Exit 0 PASS, 1 FAIL.
import { spawn } from "node:child_process";
import { join } from "node:path";
import { State, argv, guard, load, tempDir, verdict } from "./m_lib";
// ---- issuer driver (own copy in each m3_*.ts: standalone). Raw bytes in, one parsed answer per 0x0A-ended line.
// Returns null when the issuer does not start with these arguments (an earlier issuer has no such option).
async function startIssuer(root: string, core: string, mode: "on" | "off", store?: string, extra: string[] = []): Promise<Issuer | null> {
  const args = [join(root, "ts/refund-finality/minter.ts"), core, join(root, "spec/refund/spec.lock"), mode, ...(store ? [store] : []), ...extra];
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
  const S0: State = { chargeId: "ch_m3f", original: "1000", remaining: "1000", refundEnabled: true };
  const path = join(tempDir(), "s.sqlite");
  const m = await startIssuer(root, core, "off", path);
  if (m === null) verdict(false, { issuer: "DID NOT START" });
  const sink = sinkFor(root, m!.ready, S0, path);
  const r: any = { singleUse: m!.ready.singleUse };
  const t1 = await m!.mint(S0, propose(S0, "rq_1", "300"));
  const t2 = await m!.mint(S0, propose(S0, "rq_2", "200"));
  const t2b = await m!.mint(S0, propose(S0, "rq_2", "200"));
  r.a = t2.ok && t2b.ok && E.tokenText(t2.token) === E.tokenText(t2b.token) ? "same bytes" : "DIFFERENT OR REFUSED";
  r.commit2 = sink.commit(E.tokenText(t2.token)).status;
  const re2 = await m!.mint(S0, propose(S0, "rq_2", "200"));
  r.b = re2.ok ? (E.tokenText(re2.token) === E.tokenText(t2.token) ? "same bytes; sink: " + sink.commit(E.tokenText(re2.token)).status : "OTHER bytes") : "refused: " + re2.reason;
  const s1: State = JSON.parse(sink.stateBlob());
  const other = await m!.mint(s1, propose(s1, "rq_2", "50"));
  r.c = other.ok ? "SIGNED" : "refused: " + other.reason;
  const re1 = await m!.mint(S0, propose(S0, "rq_1", "300"));
  r.d = re1.ok ? "SIGNED" : "refused: " + re1.reason;
  r.d_oldTokenAtSink = t1.ok ? sink.commit(E.tokenText(t1.token)).status : "none";
  const z = await m!.mint(s1, propose(s1, "rq_z", "0"));
  r.e = z.ok ? sink.commit(E.tokenText(z.token)).status : "refused: " + z.reason;
  sink.close(); m!.stop();
  verdict(r.a === "same bytes" && r.b === "same bytes; sink: replayed" && r.c === "refused: attempt completed: use a new request id" &&
    r.d === "refused: core: Refuse" && r.d_oldTokenAtSink !== "committed" && r.e === "committed", r);
})());
