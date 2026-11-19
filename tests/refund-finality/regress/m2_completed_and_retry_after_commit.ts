// Regression and positive controls for the Store mode of rule 2 (night shift 2026-11-19, task h-minter2). A TEST.
// rq_1 for 50 on S0 is signed and commits. The IDENTICAL request again (a client that lost its answer) returns the
// SAME token, although S0 is no longer the stored state; the sink answers "replayed". rq_1 for 10 on the new state S1
// is refused ("attempt completed: use a new request id": the store has settled rq_1). Zero-amount refunds stay
// legitimate: two zero-amount requests with new ids on S1 both commit; then rq_2 for 100 commits (no freeze).
// FAILS on rule 1 (no store mode). Usage, exit codes: as m2_squat_invented_prestate_does_not_block.ts.
import { spawn } from "node:child_process";
import { join } from "node:path";
import { State, argv, guard, load, tempDir, verdict } from "./m_lib";
// ---- issuer driver (own copy in each m2_*.ts: standalone). Raw bytes in, one parsed answer per 0x0A-ended line.
// Returns null when the issuer does not start with these arguments (the earlier issuer has no store argument).
async function startIssuer(root: string, core: string, mode: "on" | "off", store?: string): Promise<Issuer | null> {
  const args = [join(root, "ts/refund-finality/minter.ts"), core, join(root, "spec/refund/spec.lock"), mode, ...(store ? [store] : [])];
  const child = spawn(process.execPath, ["--import", "tsx", ...args], { cwd: root, stdio: ["pipe", "pipe", "pipe"] });
  child.stderr.on("data", () => { /* identity information: not used */ });
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
    while (!p() && !exited && Date.now() < end) await new Promise(r => setTimeout(r, 50));
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
const propose = (pre: State, requestId: string, amount: string) => ({
  request: { requestId, amount, reason: "duplicate_charge" },
  post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() },
  intent: { chargeId: pre.chargeId, requestId, amount, reason: "duplicate_charge" },
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
  const S0: State = { chargeId: "ch_co", original: "1000", remaining: "1000", refundEnabled: true };
  const path = join(tempDir(), "s.sqlite");
  const m = await startIssuer(root, core, "on", path);
  if (m === null) verdict(false, { store: "STORE MODE NOT SUPPORTED (the issuer does not start with a store argument)" });
  const w = m as Issuer;
  const sink = sinkFor(root, w.ready, S0, path);
  const r: any = {};
  const t1 = await w.mint(S0, propose(S0, "rq_1", "50"));
  r.first = t1.ok ? sink.commit(E.tokenText(t1.token)).status : "refused: " + t1.reason;
  const t1again = await w.mint(S0, propose(S0, "rq_1", "50"));
  r.identicalRetry = t1.ok && t1again.ok && E.tokenText(t1again.token) === E.tokenText(t1.token) ? "same token; sink: " + sink.commit(E.tokenText(t1again.token)).status : "DIFFERENT OR REFUSED: " + t1again.reason;
  const s1 = JSON.parse(sink.stateBlob());
  const other = await w.mint(s1, propose(s1, "rq_1", "10"));
  r.settledIdOtherCandidate = other.ok ? "SIGNED" : other.reason;
  const z1 = await w.mint(s1, propose(s1, "rq_z1", "0")), z2 = await w.mint(s1, propose(s1, "rq_z2", "0"));
  r.zero1 = z1.ok ? sink.commit(E.tokenText(z1.token)).status : "refused: " + z1.reason;
  r.zero2 = z2.ok ? sink.commit(E.tokenText(z2.token)).status : "refused: " + z2.reason;
  const s2 = JSON.parse(sink.stateBlob());
  const p = await w.mint(s2, propose(s2, "rq_2", "100"));
  r.positiveAfterZeros = p.ok ? sink.commit(E.tokenText(p.token)).status : "refused: " + p.reason;
  r.remaining = JSON.parse(sink.stateBlob()).remaining;
  sink.close(); w.stop();
  verdict(r.first === "committed" && r.identicalRetry === "same token; sink: replayed" &&
    r.settledIdOtherCandidate === "attempt completed: use a new request id" && r.zero1 === "committed" && r.zero2 === "committed" &&
    r.positiveAfterZeros === "committed" && r.remaining === "850", r);
})());
