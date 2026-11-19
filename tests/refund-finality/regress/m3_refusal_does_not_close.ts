// Regression for red team C-ATT-38 and owner decision D-2 (night shift 2026-11-19, task h-minter3). A TEST, not a proof.
// D-2: "A minter refusal closes ONLY that attempt, NOT the whole request ID." A caller without the key sprays REFUSED
// requests with the victim's request id: the first on the REAL stored state with an amount over the remaining amount
// (the core refuses: under the earlier rule this closed the pair), the others with an unapproved reason on guessed
// pre-states. After 1, 10 and 1,000 such refusals, the victim's honest request is signed and commits. Store mode
// (production: "on" + the sink's store) and the no-store TEST mode (key = charge, request id, pre-state hash: the
// spray covers the real hash). Positive controls: a zero-amount refund and two zero-amount refunds with two ids commit.
// FAILS on the earlier rule (h-minter2: "attempt closed: use a new request id"). Proved part: SprayHarmless (I2).
// Usage: node --import tsx m3_refusal_does_not_close.ts <treeRoot> <compiledIssuerModule>. Exit 0 PASS, 1 FAIL, 3 harness.
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
  const S0: State = { chargeId: "ch_m3s", original: "1000", remaining: "1000", refundEnabled: true };
  const r: any = {};
  for (const mode of ["Store", "NoStore"]) {
    const path = join(tempDir(), "s.sqlite");
    const m = await startIssuer(root, core, "on", mode === "Store" ? path : undefined);
    if (m === null) { r[mode] = "ISSUER DID NOT START"; continue; }
    const sink = sinkFor(root, m.ready, S0, path);
    const h = await m.mint(S0, propose(S0, "rq_h1", "137"));
    sink.commit(E.tokenText(h.token));
    let cur: State = JSON.parse(sink.stateBlob());
    const out: any = {};
    for (const n of [1, 10, 1000]) {
      const victim = "rq_victim_" + n;
      let refused = 0;
      for (let i = 0; i < n; i++) {
        let a: any;
        if (i === 0) {
          // on the REAL state, amount over the remaining amount (well-formed message; the core refuses)
          a = await m.mint(cur, { ...propose(cur, victim, "1"), request: { requestId: victim, amount: "5000", reason: "duplicate_charge" },
            intent: { chargeId: cur.chargeId, requestId: victim, amount: "5000", reason: "duplicate_charge" } });
        } else {
          const g: State = { ...cur, remaining: String((Number(cur.remaining) + i) % 1001) };
          a = await m.mint(g, propose(g, victim, "1", "attacker_text"));
        }
        if (!a.ok) refused++;
      }
      const v = await m.mint(cur, propose(cur, victim, "50"));
      const vc = v.ok ? sink.commit(E.tokenText(v.token)).status : "refused: " + v.reason;
      out["after" + n] = { refused, victim: vc };
      if (vc === "committed") cur = JSON.parse(sink.stateBlob());
    }
    const z1 = await m.mint(cur, propose(cur, "rq_z1", "0"));
    out.zero1 = z1.ok ? sink.commit(E.tokenText(z1.token)).status : "refused: " + z1.reason;
    cur = JSON.parse(sink.stateBlob());
    const z2 = await m.mint(cur, propose(cur, "rq_z2", "0"));
    out.zero2 = z2.ok ? sink.commit(E.tokenText(z2.token)).status : "refused: " + z2.reason;
    out.singleUse = m.ready.singleUse;
    r[mode] = out;
    sink.close(); m.stop();
  }
  const ok = (x: any) => typeof x === "object" && [1, 10, 1000].every(n => x["after" + n].refused === n && x["after" + n].victim === "committed") &&
    x.zero1 === "committed" && x.zero2 === "committed";
  verdict(ok(r.Store) && ok(r.NoStore), r);
})());
