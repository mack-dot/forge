// Regression (issuer-side idempotency per request). The issuer never signs two DIFFERENT candidates for one key.
// Rule 2 (IssueAuth, night shift h-minter2) changed what this file can expect; it keeps its name and tests what stays true.
// (1) NoStore mode, ONE pre-state S0: rq_x is minted for 100 (not committed); rq_y (another id, same S0) is issued and
//     commits; rq_x for 30 on S0 (same key, other candidate bytes) is refused. FAILS on the merged per-pre-state rule
//     (rq_y is refused: C-ATT-03) and with no rule ("off": rq_x for 30 is signed).
// (2) Store mode (the issuer reads the sink's store): rq_x for 100 on S0 (not committed); rq_y commits; rq_x for 30 on the
//     NEW stored state S1 is refused: "stale candidate: use a new request id" (protocol.md:64-65). A fresh id on S1 commits.
// (3) NoStore mode on a NEW pre-state: rule 2 SIGNS rq_x on S1 (its key holds the pre-state hash). Not judged here; one
//     line "EXPECTATION CHANGED by rule 2: ..." is printed (SINGLE_USE_2.md, OQ-H2-2). The sink commits at most one rq_x.
// Usage and exit codes: m_lib.ts.
import { spawn } from "node:child_process";
import { join } from "node:path";
import { makeKeyFile, makeMemoryFile } from "./kf_lib";
import { State, argv, guard, load, tempDir, verdict, world } from "./m_lib";
// ---- issuer driver (own copy in each m2_*.ts: standalone). Raw bytes in, one parsed answer per 0x0A-ended line.
// Returns null when the issuer does not start with these arguments (the earlier issuer has no store argument).
async function startIssuer(root: string, core: string, mode: "on" | "off", store?: string): Promise<Issuer | null> {
  const args = [join(root, "ts/refund-finality/minter.ts"), core, join(root, "spec/refund/spec.lock"), mode, makeKeyFile().path, ...(store ? [store, ...(mode === "on" ? [makeMemoryFile()] : [])] : [])];
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
  const S0: State = { chargeId: "ch_md", original: "1000", remaining: "1000", refundEnabled: true };
  const r: any = {};
  {
    const w = await world(root, core, S0);
    const first = await w.mint(S0, "rq_x", "100");
    const y = await w.mint(S0, "rq_y", "200");
    const second = await w.mint(S0, "rq_x", "30");
    r.noStoreFirst = first.ok; r.noStoreOtherRequest = w.commit(y);
    r.noStoreSameIdSamePreOtherCandidate = second.ok ? "SIGNED" : "refused: " + second.reason;
    const onNew = await w.mint(y.post, "rq_x", "30");
    const c = w.commit(onNew);
    r.noStoreSameIdNewPre = onNew.ok ? "signed; sink: " + c : c;
    r.noStoreRqXSettled = w.sink.settled().filter((s: any) => s.request_id === "rq_x").length;
    w.stop();
  }
  {
    const path = join(tempDir(), "s.sqlite");
    const m = await startIssuer(root, core, "on", path);
    if (m === null) r.store = "STORE MODE NOT SUPPORTED";
    else {
      const sink = sinkFor(root, m.ready, S0, path);
      await m.mint(S0, propose(S0, "rq_x", "100"));
      const y = await m.mint(S0, propose(S0, "rq_y", "200"));
      r.storeOtherRequest = y.ok ? sink.commit(E.tokenText(y.token)).status : "refused: " + y.reason;
      const s1 = JSON.parse(sink.stateBlob());
      const again = await m.mint(s1, propose(s1, "rq_x", "30"));
      r.storeSameIdNewState = again.ok ? "SIGNED" : "refused: " + again.reason;
      const fresh = await m.mint(s1, propose(s1, "rq_z", "30"));
      r.storeFreshId = fresh.ok ? sink.commit(E.tokenText(fresh.token)).status : "refused: " + fresh.reason;
      sink.close(); m.stop();
    }
  }
  if (typeof r.noStoreSameIdNewPre === "string" && r.noStoreSameIdNewPre.startsWith("signed")) {
    console.log("EXPECTATION CHANGED by rule 2: without a store the same request id on a NEW pre-state is a new key and is signed (" +
      r.noStoreSameIdNewPre + "; rq_x settled " + r.noStoreRqXSettled + " time(s)); the Store mode refuses it (SINGLE_USE_2.md, OQ-H2-2)");
  }
  verdict(r.noStoreFirst === true && r.noStoreOtherRequest === "committed" && r.noStoreSameIdSamePreOtherCandidate.startsWith("refused") &&
    r.noStoreRqXSettled <= 1 && r.storeOtherRequest === "committed" &&
    r.storeSameIdNewState === "refused: stale candidate: use a new request id" && r.storeFreshId === "committed", r);
})());
