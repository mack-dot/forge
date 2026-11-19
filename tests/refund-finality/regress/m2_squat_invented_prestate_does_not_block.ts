// Regression for red team C-ATT-30 (night shift 2026-11-19, task h-minter2). A TEST, not a proof.
// A caller WITHOUT the key sends a zero-amount request for the VICTIM's (charge id, request id) on an INVENTED
// pre-state (original 5, remaining 5). Then the victim's real request (700 on the real state S0) is sent.
// Store mode (the issuer reads the sink's store): the squat is refused ("pre-state is not the authoritative stored
// state") and records nothing; the victim is issued and commits. NoStore mode: the squat is signed under its OWN key
// (charge id, request id, pre-state hash); it cannot commit; the victim is issued and commits.
// Controls: a zero-amount request on the real state with a new id is issued and commits (Store mode).
// FAILS on rule 1 (IssueOnce, key = (charge id, request id), no store): the victim is refused for ever.
// Usage: node --import tsx m2_squat_invented_prestate_does_not_block.ts <treeRoot> <compiledIssuerModule>
// Exit 0: PASS. Exit 1: FAIL (the defect). Exit 2: usage. Exit 3: the harness broke.
// EXPECTATION CHANGE (h-minter3, red team C-ATT-38 state oracle): the Store-mode squat on an invented pre-state is
// refused with the GENERIC text "core: Refuse" (one text for "not on the authoritative state" and "not authorized";
// the outcome name goes to the operator's stderr). The safety terms are unchanged.
import { spawn } from "node:child_process";
import { join } from "node:path";
import { State, argv, guard, load, tempDir, verdict } from "./m_lib";
import { makeKeyFile, makeMemoryFile } from "./kf_lib";
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
  const S0: State = { chargeId: "ch_sq", original: "1000", remaining: "1000", refundEnabled: true };
  const FAKE: State = { chargeId: "ch_sq", original: "5", remaining: "5", refundEnabled: true };
  const r: any = {};
  {
    const m = await startIssuer(root, core, "on");
    if (m === null) throw new Error("the issuer did not start");
    const sink = sinkFor(root, m.ready, S0, join(tempDir(), "n.sqlite"));
    const squat = await m.mint(FAKE, propose(FAKE, "rq_victim", "0"));
    r.noStoreSquat = squat.ok ? "signed; sink: " + sink.commit(E.tokenText(squat.token)).status : "refused: " + squat.reason;
    const victim = await m.mint(S0, propose(S0, "rq_victim", "700"));
    r.noStoreVictim = victim.ok ? sink.commit(E.tokenText(victim.token)).status : "MINTER REFUSED: " + victim.reason;
    sink.close(); m.stop();
  }
  {
    const path = join(tempDir(), "s.sqlite");
    const m = await startIssuer(root, core, "on", path);
    if (m === null) r.store = "STORE MODE NOT SUPPORTED (the issuer does not start with a store argument)";
    else {
      const sink = sinkFor(root, m.ready, S0, path);
      const squat = await m.mint(FAKE, propose(FAKE, "rq_victim", "0"));
      r.storeSquat = squat.ok ? "SIGNED" : "refused: " + squat.reason;
      const victim = await m.mint(S0, propose(S0, "rq_victim", "700"));
      r.storeVictim = victim.ok ? sink.commit(E.tokenText(victim.token)).status : "MINTER REFUSED: " + victim.reason;
      const s1 = JSON.parse(sink.stateBlob());
      const zero = await m.mint(s1, propose(s1, "rq_zero", "0"));
      r.zeroControl = zero.ok ? sink.commit(E.tokenText(zero.token)).status : "refused: " + zero.reason;
      sink.close(); m.stop();
    }
  }
  verdict(r.noStoreVictim === "committed" && r.storeSquat === "refused: core: Refuse" &&
    r.storeVictim === "committed" && r.zeroControl === "committed", r);
})());
