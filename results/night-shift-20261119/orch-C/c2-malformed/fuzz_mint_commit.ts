// c2-malformed: differential fuzz (<= N cases) of the REAL minter process (issuebytes2.cjs) against
// encoding.ts canon()+UTF-8, the spec oracle (RefundSpec.Eligible + Authorizes, by BigInt), and the v6 sink commit.
// Exit 1 when a defect is seen (false rejection, over-issue, byte mismatch, non-injective bytes, sink refuses a
// legitimate token, round-trip break). Exit 0 when the target is safe on all cases.
// Usage: node --import tsx fuzz_mint_commit.ts <target root> <issuer .cjs> <N> <seed>
import { spawn } from "node:child_process";
import { join } from "node:path";
const [root, corePath, nArg, seedArg] = process.argv.slice(2);
const N = Math.min(2000, Number(nArg ?? 500));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const E = require(join(root, "ts/refund-finality/encoding.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { propose } = require(join(root, "ts/refund-finality/proposer.ts"));
let seed = Number(seedArg ?? 1) >>> 0;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const pick = <T>(a: T[]): T => a[Math.floor(rnd() * a.length)];
const CH = ["a", "Z", "0", "\"", "\\", "/", "\u0001", "\u001f", "\b", "\t", "\n", "\f", "\r", "\u007f", "\u0085", " ",
  " ", " ", "￿", "￾", "﻿", "😀", "\u{10FFFF}", "\u{10000}", "é", "é", " ", "<", "\u0000",
];
const BAD = ["\u0000", "\ud800", "\udfff"];
function str(): string {
  const mode = rnd();
  if (mode < 0.25) return pick(["ch_1", "rq_1", "", " ", "1", "0", "__proto__", "constructor", "toString", "true", "null", "9223372036854775807"]);
  const target = mode < 0.6 ? Math.floor(rnd() * 12) : pick([255, 256, 257, 254, 128]);
  let s = "";
  while (s.length < target) s += rnd() < 0.5 ? "x" : pick(CH);
  if (rnd() < 0.2 && s.length > target) s = s.slice(0, target);   // may cut a surrogate pair: lone surrogate
  if (rnd() < 0.05) s = pick(BAD) + s;
  return s;
}
const MONEY = ["0", "0", "100", "9223372036854775807", "1", "40", "100", "9223372036854775807", "9223372036854775806", "9223372036854775808", "9999999999999999999",
  "1000000000000000000", "10000000000000000000", "007", "-1", "1e3", " 1", "0.0"];
const REASONS = ["duplicate_charge", "service_not_delivered", "returned_item", "Duplicate_charge", "duplicate_charge ", "x", ""];
const MAX = 9223372036854775807n;
const MRE = /^(0|[1-9][0-9]{0,18})$/;
function oracle(pre: any, t: any): boolean {
  if (!E.isState(pre) || !E.isTransition(t)) return false;           // shape: the minter refuses (refuse-only, not a decision)
  const o = BigInt(pre.original), r = BigInt(pre.remaining), a = BigInt(t.request.amount);
  const valid = pre.chargeId !== "" && t.request.requestId !== "" && pre.refundEnabled === true && 0n <= o && o <= MAX && 0n <= r && r <= o;
  const elig = valid && 0n <= a && a <= r && ["duplicate_charge", "service_not_delivered", "returned_item"].includes(t.request.reason);
  const postOk = E.canon(t.post) === E.canon({ ...pre, remaining: (r - a).toString() });
  const intOk = E.canon(t.intent) === E.canon({ chargeId: pre.chargeId, requestId: t.request.requestId, amount: t.request.amount, reason: t.request.reason });
  return elig && postOk && intOk;
}
(async () => {
  const child = spawn(process.execPath, ["--import", "tsx", join(root, "ts/refund-finality/minter.ts"), corePath, join(root, "spec/refund/spec.lock"), "off"],
    { cwd: root, stdio: ["pipe", "pipe", "inherit"] });
  const lines: string[] = []; let wake: (() => void) | null = null;
  // framing on 0x0A only (Node readline also splits on U+2028/U+2029: see repro_proposer_u2028.ts)
  let buf = "";
  child.stdout!.setEncoding("utf8");
  child.stdout!.on("data", (c: string) => { buf += c; let k; while ((k = buf.indexOf("\n")) >= 0) { lines.push(buf.slice(0, k)); buf = buf.slice(k + 1); }
    if (wake && lines.length) { const w = wake; wake = null; w(); } });
  const next = async (): Promise<string> => { while (lines.length === 0) await new Promise<void>(r => (wake = r)); return lines.shift()!; };
  const ready = JSON.parse(await next());
  const defects: any[] = []; const bytesSeen = new Map<string, string>();
  let issued = 0, committed = 0, refused = 0, expectedOk = 0, zero = 0;
  const FIX: { pre: any; req: any }[] = [];
  const classes = ["\"", "\\", "\u0001", "\u001f", "\b", "\t", "\n", "\f", "\r", "\u007f", "\u0085", "\u2028", "\u2029", "\uffff", "\ufffe",
    "\ufeff", "\ud83d\ude00", "\u{10FFFF}", "\u{10000}", "e\u0301", "\u00e9", "/", " "];
  for (const c of classes) {
    const full = c.repeat(Math.floor(256 / c.length));          // exactly 256 UTF-16 units (or 255 for 3-unit classes)
    for (const amount of ["0", "1"]) for (const rem of ["0", "5"]) {
      if (BigInt(amount) > BigInt(rem)) continue;
      FIX.push({ pre: { chargeId: full, original: "9223372036854775807", remaining: rem, refundEnabled: true }, req: { requestId: full, amount, reason: "returned_item" } });
    }
    FIX.push({ pre: { chargeId: "c" + c, original: "9223372036854775807", remaining: "9223372036854775807", refundEnabled: true }, req: { requestId: c + "9", amount: "9223372036854775807", reason: "service_not_delivered" } });
  }
  const NN = seedArg === "0" ? FIX.length : N;
  for (let i = 0; i < NN; i++) {
    const fx = seedArg === "0" ? FIX[i] : null;
    const pre: any = { chargeId: rnd() < 0.5 ? "ch_1" : str(), original: pick(MONEY), remaining: pick(MONEY), refundEnabled: rnd() < 0.95 };
    if (rnd() < 0.6 && MRE.test(pre.original)) pre.remaining = pick(["0", pre.original, (BigInt(pre.original) / 2n).toString()]);
    if (fx) Object.assign(pre, fx.pre);
    const req = fx ? fx.req : { requestId: rnd() < 0.3 ? "rq_" + i : str(), amount: pick(["0", "0", "1", pre.remaining, pick(MONEY)]), reason: rnd() < 0.8 ? pick(REASONS.slice(0, 3)) : pick(REASONS) };
    let t: any;
    try { t = propose(pre, req); } catch { t = { request: req, post: pre, intent: { chargeId: pre.chargeId, requestId: req.requestId, amount: req.amount, reason: req.reason } }; }
    if (!fx && rnd() < 0.1) t = JSON.parse(JSON.stringify(t)), t.intent.reason = pick(REASONS);          // tamper: may be unauthorized
    if (!fx && rnd() < 0.05) t = JSON.parse(JSON.stringify(t)), t.post.refundEnabled = !t.post.refundEnabled;
    const exp = oracle(pre, t); if (exp) expectedOk++;
    child.stdin!.write(JSON.stringify({ id: i, pre, transition: t }) + "\n");
    const line = await next();
    const head = "{\"id\":" + i + ",\"ok\":true,\"token\":";
    const ok = line.startsWith(head);
    if (ok !== exp) { defects.push({ i, kind: ok ? "over-issue" : "false-rejection-by-minter", pre, t, line: line.slice(0, 300) }); continue; }
    if (!ok) { refused++; continue; }
    issued++; if (t.request.amount === "0") zero++;
    const tokenText = line.slice(head.length, -1);
    let tok: any;
    try { tok = JSON.parse(tokenText); } catch { defects.push({ i, kind: "minter answer line is not parseable", line: JSON.stringify(line).slice(0, 400), pre, t }); continue; }
    // the minter's bytes vs encoding.ts canon()+UTF-8
    if (E.canon(tok) !== tokenText) defects.push({ i, kind: "token text not canon" });
    const sb = E.signedBytes(tok.body);
    const key = sb.toString("hex");
    const bodyCanon = E.canon(tok.body);
    if (bytesSeen.has(key) && bytesSeen.get(key) !== bodyCanon) defects.push({ i, kind: "non-injective signed bytes" });
    bytesSeen.set(key, bodyCanon);
    if (tok.body.requestId !== t.request.requestId || E.canon(tok.body.post) !== E.canon(t.post) || E.canon(tok.body.intent) !== E.canon(t.intent))
      defects.push({ i, kind: "token body is not the requested transition" });
    // the v6 sink on a fresh store with initialState = pre
    let res: any;
    try {
      const sink = new Sink(":memory:", { publicKeyPem: ready.publicKeyPem, specLockSha256: ready.specLockSha256, checkerSha256: ready.checkerSha256, initialState: pre });
      sink.init(pre);
      res = sink.commit(tokenText);
      const again = sink.commit(tokenText);
      if (res.status === "committed") {
        committed++;
        if (sink.stateBlob() !== E.canon(t.post)) defects.push({ i, kind: "stored post differs from signed post" });
        const o = sink.outbox();
        if (o.length !== 1 || o[0].request_id !== t.request.requestId || o[0].intent !== E.canon(t.intent)) defects.push({ i, kind: "outbox differs from signed intent" });
        if (again.status !== "replayed") defects.push({ i, kind: "replay not replayed", again });
        if (sink.audit().length !== 0) defects.push({ i, kind: "offline audit complains", a: sink.audit() });
      }
      sink.close();
    } catch (e) { res = { status: "exception", reason: String((e as Error).message) }; }
    if (res.status !== "committed") defects.push({ i, kind: "false-rejection-by-sink", res, pre, req: t.request });
  }
  child.kill();
  const summary = { cases: NN, expectedOk, issued, committed, refused, zeroIssued: zero, distinctBodies: bytesSeen.size, defects: defects.length };
  process.stdout.write(JSON.stringify(summary) + "\n");
  for (const d of defects.slice(0, 5)) process.stdout.write(JSON.stringify(d).slice(0, 600) + "\n");
  process.exit(defects.length === 0 ? 0 : 1);
})().catch(e => { process.stderr.write(String(e && e.stack) + "\n"); process.exit(3); });
