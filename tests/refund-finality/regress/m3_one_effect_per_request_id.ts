// Regression for owner decision D-2, end to end (night shift 2026-11-19, task h-minter3). A TEST, not a proof.
// Production mode ("on" + the sink's store). Checks I1 (at most one valid token per (charge id, request id): another
// candidate for a minted pair is refused; an identical request gets the identical bytes), I3 (a settled request id
// stays closed), the stale-candidate case (protocol.md:64-65: "A new attempt needs a new request ID"), and the COMPOSED
// claim at most one EFFECT per request id (I1 + the sink rule: request_id UNIQUE in the settled table): one settled row
// per request id. Also: the ready line says "singleUse":true in production and "singleUse":"none" in the no-store TEST
// mode; zero-amount refunds commit. Proved parts: RunSeq I1, I3 (IssueAuth.dfy).
// FAILS on the earlier issuer (its ready line has no test-mode marker). Usage: <treeRoot> <compiledIssuerModule>.
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
  const S0: State = { chargeId: "ch_m3e", original: "1000", remaining: "1000", refundEnabled: true };
  const path = join(tempDir(), "s.sqlite");
  const m = await startIssuer(root, core, "on", path);
  if (m === null) verdict(false, { issuer: "DID NOT START" });
  const sink = sinkFor(root, m!.ready, S0, path);
  const r: any = { productionSingleUse: m!.ready.singleUse };
  const tx = (a: any) => a.ok ? E.tokenText(a.token) : "refused: " + a.reason;
  const T = await m!.mint(S0, propose(S0, "rq_r", "100"));
  r.identical = tx(await m!.mint(S0, propose(S0, "rq_r", "100"))) === tx(T) && T.ok ? "same bytes" : "DIFFERENT";
  r.otherCandidate = tx(await m!.mint(S0, propose(S0, "rq_r", "50")));
  r.commit = sink.commit(tx(T)).status;
  r.commitAgain = sink.commit(tx(T)).status;
  const s1: State = JSON.parse(sink.stateBlob());
  r.settledOtherCandidate = tx(await m!.mint(s1, propose(s1, "rq_r", "30")));
  r.settledIdentical = tx(await m!.mint(S0, propose(S0, "rq_r", "100"))) === tx(T) ? "same bytes" : "DIFFERENT";
  const S = await m!.mint(s1, propose(s1, "rq_s", "100"));
  const U = await m!.mint(s1, propose(s1, "rq_u", "50"));
  r.otherRequestCommit = sink.commit(tx(U)).status;
  const s2: State = JSON.parse(sink.stateBlob());
  r.staleRetry = tx(await m!.mint(s2, propose(s2, "rq_s", "100")));
  r.staleOldTokenAtSink = S.ok ? sink.commit(tx(S)).status : "none";
  r.newIdOnS2 = sink.commit(tx(await m!.mint(s2, propose(s2, "rq_s2", "100")))).status;
  const s3: State = JSON.parse(sink.stateBlob());
  r.zero = sink.commit(tx(await m!.mint(s3, propose(s3, "rq_z0", "0")))).status;
  const rows = sink.settled().map((x: any) => x.request_id);
  r.settledRowsPerId = Object.fromEntries([...new Set(rows)].map(id => [id, rows.filter((x: string) => x === id).length]));
  sink.close(); m!.stop();
  const t = await startIssuer(root, core, "on");
  r.noStoreSingleUse = t === null ? "DID NOT START" : t.ready.singleUse;
  t?.stop();
  verdict(r.productionSingleUse === true && r.noStoreSingleUse === "none" && r.identical === "same bytes" &&
    r.otherCandidate === "refused: other candidate: use a new request id" && r.commit === "committed" && r.commitAgain === "replayed" &&
    r.settledOtherCandidate === "refused: attempt completed: use a new request id" && r.settledIdentical === "same bytes" &&
    r.otherRequestCommit === "committed" && r.staleRetry === "refused: stale candidate: use a new request id" &&
    r.staleOldTokenAtSink !== "committed" && r.newIdOnS2 === "committed" && r.zero === "committed" &&
    Object.values(r.settledRowsPerId).every(n => n === 1), r);
})());
