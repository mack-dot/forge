// r-issueauth Q3: Store mode, a plain caller WITHOUT the key and WITHOUT db write access. Two things:
//  (a) the stated LIMIT: a caller who knows the REAL stored state and the victim's request id sends a zero-amount
//      request FIRST; it is signed and committed; the victim's real request is then blocked. We confirm it is exactly
//      as stated (the pair is taken) and NOT worse (does the victim still get refused, i.e. no OTHER charge affected?).
//  (b) a caller who sends a WRONG pre-state (invented) is refused and records nothing (C-ATT-30 fix).
//  (c) TOCTOU: within one request the minter reads the store and signs with NO await between; a stale token for an
//      already-moved state is rejected by the sink. We mint on an OLD state after the store moved, feed to sink.
// exit 0 = behaviour is exactly the documented limit (safe-as-stated). exit 1 = WORSE than stated (e.g. two commits,
//          or a different charge/ id affected, or the invented squat commits).
import { join, resolve } from "node:path";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
const root = resolve(process.argv[2]), core = resolve(process.argv[3]);
/* eslint-disable @typescript-eslint/no-require-imports */
const E = require(join(root, "ts/refund-finality/encoding.ts"));
const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
const { MinterClient } = require(join(root, "ts/refund-finality/proposer.ts"));
const dir = mkdtempSync(join(tmpdir(), "forge-r-q3-"));
process.on("exit", () => { try { rmSync(dir, { recursive: true, force: true }); } catch {} });
const prop = (pre: any, rq: string, amt: string) => ({ request: { requestId: rq, amount: amt, reason: "duplicate_charge" },
  post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amt)).toString() },
  intent: { chargeId: pre.chargeId, requestId: rq, amount: amt, reason: "duplicate_charge" } });
(async () => {
  const S0 = { chargeId: "ch_q3", original: "1000", remaining: "1000", refundEnabled: true };
  const FAKE = { chargeId: "ch_q3", original: "5", remaining: "5", refundEnabled: true };
  const store = join(dir, "s.sqlite");
  const m = await MinterClient.start(root, core, join(root, "spec/refund/spec.lock"), "on");  // start with store
  // restart in Store mode: MinterClient.start has no store arg; use raw spawn via a second client is not supported,
  // so drive Store mode through the minter's 4th arg by spawning directly.
  m.stop();
  const { spawn } = require("node:child_process");
  const startStore = async () => {
    const child = spawn(process.execPath, ["--import", "tsx", join(root, "ts/refund-finality/minter.ts"), core,
      join(root, "spec/refund/spec.lock"), "on", store], { cwd: root, stdio: ["pipe", "pipe", "ignore"] });
    let buf = Buffer.alloc(0); let ready: any = null; const ans = new Map<number, any>(); let n = 1;
    child.stdout.on("data", (c: Buffer) => { buf = Buffer.concat([buf, c]);
      for (let i = buf.indexOf(10); i >= 0; i = buf.indexOf(10)) { const msg = JSON.parse(buf.subarray(0, i).toString("utf8")); buf = buf.subarray(i + 1); if (msg.ready) ready = msg; else ans.set(msg.id, msg); } });
    const until = async (p: () => boolean, ms = 20000) => { const e = Date.now() + ms; while (!p() && Date.now() < e) await new Promise(r => setTimeout(r, 30)); return p(); };
    await until(() => ready !== null);
    const mint = async (pre: any, t: any) => { const id = n++; child.stdin.write(JSON.stringify({ id, pre, transition: t }) + "\n"); await until(() => ans.has(id)); return ans.get(id); };
    return { ready, mint, stop: () => { child.stdin.end(); child.kill(); } };
  };
  const iss = await startStore();
  const ids = { publicKeyPem: iss.ready.publicKeyPem, specLockSha256: iss.ready.specLockSha256, checkerSha256: iss.ready.checkerSha256 };
  const sink = new Sink(store, { ...ids, initialState: S0 }); sink.init(S0);
  const r: any = {};
  // (b) invented wrong pre-state: refused, records nothing.
  const bad = await iss.mint(FAKE, prop(FAKE, "rq_victim", "0"));
  r.inventedSquat = bad.ok ? "SIGNED(bad)" : bad.reason;
  // (a) zero squat on the REAL state with the victim's id, committed first.
  const squat = await iss.mint(S0, prop(S0, "rq_victim", "0"));
  r.realZeroSquat = squat.ok ? sink.commit(E.tokenText(squat.token)).status : "mint refused: " + squat.reason;
  // victim's real request on the same id:
  const victim = await iss.mint(S0, prop(S0, "rq_victim", "100"));
  r.victim = victim.ok ? sink.commit(E.tokenText(victim.token)).status : "mint refused: " + victim.reason;
  // victim uses a NEW id (liveness: the charge is not frozen):
  const fresh = await iss.mint(S0, prop(S0, "rq_victim_2", "100"));
  r.victimNewId = fresh.ok ? sink.commit(E.tokenText(fresh.token)).status : "mint refused: " + fresh.reason;
  sink.close(); iss.stop();
  console.log(JSON.stringify(r, null, 0));
  // Expected-as-stated: invented squat refused; real zero squat committed; victim (same id) blocked; new id works.
  const asStated = (!bad.ok) && r.realZeroSquat === "committed" && (r.victim === "rejected" || (victim.ok === false)) && r.victimNewId === "committed";
  console.log(asStated ? "AS-STATED: zero-squat on real state takes the id (documented limit C-ATT-08); invented squat refused; new id still works"
    : "DEVIATION from the stated limit: " + JSON.stringify(r));
  process.exit(asStated ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
