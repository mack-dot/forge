// Regression for red team C-ATT-29 as SPECIFIED behaviour (night shift 2026-11-19, task h-minter2). A TEST, not a proof.
// Replaces m_same_request_different_candidate_refused.ts, whose expectation changed with rule 2 (IssueAuth): without a
// store the key now holds the pre-state hash, so the same request id on ANOTHER pre-state is a new key.
// protocol.md:64-65: "Reusing the pair with different trusted context is rejected. A new attempt needs a new request ID."
// Store mode: rq_x is signed for 100 on S0 (not committed); rq_y commits; rq_x for 30 on the new state S1 is refused
// with the fixed text "stale candidate: use a new request id"; a NEW id on S1 commits; the identical rq_x request on
// S0 still returns the SAME token (an identical retry), and the sink refuses that stale token.
// NoStore mode (documented, not the text rule: the issuer cannot know the trusted state): rq_x on S1 is signed; the
// sink commits AT MOST ONE token for rq_x.
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
  const S0: State = { chargeId: "ch_st", original: "1000", remaining: "1000", refundEnabled: true };
  const r: any = {};
  {
    const path = join(tempDir(), "s.sqlite");
    const m = await startIssuer(root, core, "on", path);
    if (m === null) r.store = "STORE MODE NOT SUPPORTED (the issuer does not start with a store argument)";
    else {
      const sink = sinkFor(root, m.ready, S0, path);
      const x = await m.mint(S0, propose(S0, "rq_x", "100"));
      const y = await m.mint(S0, propose(S0, "rq_y", "200"));
      r.storeY = y.ok ? sink.commit(E.tokenText(y.token)).status : "refused: " + y.reason;
      const s1 = JSON.parse(sink.stateBlob());
      const again = await m.mint(s1, propose(s1, "rq_x", "30"));
      r.storeSameIdNewState = again.ok ? "SIGNED" : "refused: " + again.reason;
      const fresh = await m.mint(s1, propose(s1, "rq_z", "30"));
      r.storeFreshId = fresh.ok ? sink.commit(E.tokenText(fresh.token)).status : "refused: " + fresh.reason;
      const retry = await m.mint(S0, propose(S0, "rq_x", "100"));
      r.storeIdenticalRetry = x.ok && retry.ok && E.tokenText(retry.token) === E.tokenText(x.token) ? "same token" : "DIFFERENT OR REFUSED: " + retry.reason;
      r.storeStaleTokenAtSink = x.ok ? sink.commit(E.tokenText(x.token)).status : "none";
      sink.close(); m.stop();
    }
  }
  {
    const m = await startIssuer(root, core, "on");
    if (m === null) throw new Error("the issuer did not start");
    const sink = sinkFor(root, m.ready, S0, join(tempDir(), "n.sqlite"));
    const x = await m.mint(S0, propose(S0, "rq_x", "100"));
    const y = await m.mint(S0, propose(S0, "rq_y", "200"));
    r.noStoreY = y.ok ? sink.commit(E.tokenText(y.token)).status : "refused: " + y.reason;
    const s1 = JSON.parse(sink.stateBlob());
    const again = await m.mint(s1, propose(s1, "rq_x", "30"));
    r.noStoreSameIdNewState = again.ok ? "signed; sink: " + sink.commit(E.tokenText(again.token)).status : "refused: " + again.reason;
    r.noStoreOldToken = x.ok ? sink.commit(E.tokenText(x.token)).status : "none";
    r.noStoreSettledRowsForRqX = sink.settled().filter((s: any) => s.request_id === "rq_x").length;
    sink.close(); m.stop();
  }
  verdict(r.storeY === "committed" && r.storeSameIdNewState === "refused: stale candidate: use a new request id" &&
    r.storeFreshId === "committed" && r.storeIdenticalRetry === "same token" && r.storeStaleTokenAtSink === "rejected" &&
    r.noStoreY === "committed" && r.noStoreSettledRowsForRqX <= 1 && r.noStoreOldToken !== "committed", r);
})());
