// r-harden probe P1 (minter.ts on branch 608b5165, compiled IssueOnce). Standalone. Test keys only (made by the issuer).
// usage: node --import tsx p1_minter.ts <treeRoot> <compiled issueonce.cjs>
// Checks. Exit 1 if any DEFEAT row is true; exit 0 otherwise; exit 3 if the harness broke.
//  A0 the same with a SHAPE refusal (negative post) instead of a core refusal.
//  A refused-then-issued: same (charge id, request id): first refused by the core (amount > remaining), then a
//    different candidate for the SAME pair is SIGNED. protocol.md:61-65 "rejection ... closes that attempt ... A new
//    attempt needs a new request ID." -> DEFEAT of the protocol reading in SINGLE_USE.md section 2 if signed.
//  B retry identical -> same token text (expected).
//  C same pair, other amount after an issue -> refused (expected).
//  D NFC vs NFD request ids -> two distinct keys: both signed (information; consistent with SQLite BINARY).
//  E restart: a NEW issuer process signs the same pair with another candidate (P-idem per process only; information).
//  F two request ids on ONE pre-state both signed (information: the D14 precondition is now normal operation).
import { spawn } from "node:child_process";
import { join, resolve } from "node:path";
const [root0, core0] = process.argv.slice(2);
const root = resolve(root0), core = resolve(core0);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { propose } = require(join(root, "ts/refund-finality/proposer.ts"));
function issuer() {
  const child = spawn(process.execPath, ["--import", "tsx", join(root, "ts/refund-finality/minter.ts"), core, join(root, "spec/refund/spec.lock"), "on"],
    { cwd: root, stdio: ["pipe", "pipe", "ignore"] });
  let buf = ""; const lines: any[] = []; const waiters: (() => void)[] = [];
  child.stdout.on("data", (c: Buffer) => { buf += c.toString("utf8"); let i;
    while ((i = buf.indexOf("\n")) >= 0) { lines.push(JSON.parse(buf.slice(0, i))); buf = buf.slice(i + 1); }
    while (waiters.length) waiters.shift()!(); });
  const wait = async (n: number) => { const end = Date.now() + 20000;
    while (lines.length < n && Date.now() < end) await new Promise<void>(r => { waiters.push(r); setTimeout(r, 200); });
    if (lines.length < n) throw new Error("issuer timeout"); };
  let id = 0;
  const mint = async (pre: any, rq: string, amount: string, tweak?: (t: any) => void) => {
    const t = propose(pre, { requestId: rq, amount, reason: "duplicate_charge" }); if (tweak) tweak(t);
    const k = ++id; child.stdin.write(JSON.stringify({ id: k, pre, transition: t }) + "\n");
    await wait(k + 1); return lines[k];
  };
  return { mint, ready: async () => { await wait(1); return lines[0]; }, stop: () => { child.stdin.end(); child.kill(); } };
}
(async () => {
  const pre = { chargeId: "ch_1", original: "100", remaining: "60", refundEnabled: true };
  const out: any = {}; let defeat = false;
  const a = issuer(); const r1 = await a.ready();
  const A0 = await a.mint(pre, "rq_y", "61");   // shape refusal (negative post)
  out.A0 = { shapeRefusal: A0.ok ? "signed" : A0.reason, thenSamePairSigned: (await a.mint(pre, "rq_y", "40")).ok };
  // core refusal: a shape-valid candidate whose post is not pre - amount (not authorized), then the honest one
  const A1 = await a.mint(pre, "rq_x", "40", t => { t.post.remaining = "25"; }), A2 = await a.mint(pre, "rq_x", "40");
  out.A = { first: A1.ok ? "signed" : A1.reason, second: A2.ok ? "signed" : A2.reason };
  if (!A1.ok && A2.ok) { out.A.verdict = "DEFEAT: a refused attempt does not close the pair; another candidate for it is signed"; defeat = true; }
  const B = await a.mint(pre, "rq_x", "40");
  out.B = { sameTokenOnRetry: B.ok && JSON.stringify(B.token) === JSON.stringify(A2.token) };
  const C = await a.mint(pre, "rq_x", "39"); out.C = { otherCandidate: C.ok ? "signed (BAD)" : C.reason };
  if (C.ok) defeat = true;
  const nfc = "réq", nfd = "réq";
  const D1 = await a.mint(pre, nfc, "1"), D2 = await a.mint(pre, nfd, "2");
  out.D = { nfcSigned: D1.ok, nfdSigned: D2.ok };
  const F1 = await a.mint(pre, "rq_f1", "10"), F2 = await a.mint(pre, "rq_f2", "20");
  out.F = { twoRequestIdsOnePreStateBothSigned: F1.ok && F2.ok };
  a.stop();
  const b = issuer(); const r2 = await b.ready();
  const E = await b.mint(pre, "rq_x", "39");
  out.E = { afterRestartOtherCandidateSamePair: E.ok ? "signed" : E.reason, keyChanged: r1.publicKeyPem !== r2.publicKeyPem };
  b.stop();
  console.log(JSON.stringify(out, null, 1));
  console.log(defeat ? "DEFEATED" : "SAFE");
  process.exit(defeat ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
