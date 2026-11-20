// Regression for the review gap of U576 (night shift 2026-11-19, task h-minter2). A TEST, not a proof.
// protocol.md:61-62: "Completion, rejection, failure, or timeout closes that attempt." Rule 2 (IssueAuth): the core's
// refusal at the FIRST use of a key closes the key. rq_c for 2000 on S0 (remaining 1000; a well-formed message whose
// post-state has remaining 0) is refused ("core: Refuse");
// rq_c for 40 on S0 (authorized) is then refused ("attempt closed: use a new request id"); the identical refused request
// is refused again; a NEW id rq_d for 40 commits; a zero-amount request with a new id commits. Store mode and NoStore mode.
// EXPECTATION CHANGE (h-minter3, owner decision D-2 of 2026-11-19: "A minter refusal closes ONLY that attempt, NOT the
// whole request ID"): rq_c for 40 after the refusal is now SIGNED (a refusal records nothing; red team C-ATT-38). The
// file name keeps its old words; the rule it now checks: a refusal does NOT close the pair, the refused request is
// refused again ("core: Refuse"), new ids and zero amounts still commit. Replacement for the old expectation: none (the
// owner removed it); the old rule's spray is kept as the Dafny model OldRuleFreeze (IssueAuth.dfy). Usage, exit codes: as m2_squat_invented_prestate_does_not_block.ts.
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
  const S0: State = { chargeId: "ch_cl", original: "1000", remaining: "1000", refundEnabled: true };
  // Well-formed but not authorized: amount 2000 > remaining 1000 (propose() would make a negative post-state).
  const over = (pre: State, requestId: string) => ({ ...propose(pre, requestId, "1000"),
    request: { requestId, amount: "2000", reason: "duplicate_charge" },
    intent: { chargeId: pre.chargeId, requestId, amount: "2000", reason: "duplicate_charge" } });
  const r: any = {};
  for (const mode of ["NoStore", "Store"]) {
    const path = join(tempDir(), "s.sqlite");
    const m = await startIssuer(root, core, "on", mode === "Store" ? path : undefined);
    if (m === null) { r[mode] = "STORE MODE NOT SUPPORTED (the issuer does not start with a store argument)"; continue; }
    const sink = sinkFor(root, m.ready, S0, path);
    const a = await m.mint(S0, over(S0, "rq_c"));
    const b = await m.mint(S0, propose(S0, "rq_c", "40"));
    const a2 = await m.mint(S0, over(S0, "rq_c"));
    const d = await m.mint(S0, propose(S0, "rq_d", "40"));
    const dc = d.ok ? sink.commit(E.tokenText(d.token)).status : "refused: " + d.reason;
    const s1 = JSON.parse(sink.stateBlob());
    const z = await m.mint(s1, propose(s1, "rq_zero", "0"));
    const zc = z.ok ? sink.commit(E.tokenText(z.token)).status : "refused: " + z.reason;
    r[mode] = { refused: a.ok ? "SIGNED" : a.reason, sameIdValid: b.ok ? "SIGNED" : b.reason, refusedAgain: a2.ok ? "SIGNED" : a2.reason, newId: dc, zero: zc };
    sink.close(); m.stop();
  }
  const ok = (x: any) => typeof x === "object" && x.refused === "core: Refuse" && x.sameIdValid === "SIGNED" &&
    x.refusedAgain === "core: Refuse" && x.newId === "committed" && x.zero === "committed";
  verdict(ok(r.NoStore) && ok(r.Store), r);
})());
