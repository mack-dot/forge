// h-minter: COPY of d-minter/conf/run.ts (G4c). The "real" minter = the merged minter.ts (pristine export of the branch
// head) with its RefundFinality module; the "draft" = the h-minter minter.ts (scratch tree) with the IssueOnce module.
// Changes to the copy: paths and modules are arguments; the memory mode (on|off) is an argument for both processes;
// the case list, the checks and the output are unchanged.
// Both run as their own processes with test keys generated in those processes. Read-only use of the repository.
// Usage: node --import tsx run.ts <realRoot> <realCore> <draftRoot> <draftCore> <spec lock> <on|off> <out json>
import { spawn, ChildProcessWithoutNullStreams } from "node:child_process";
import { createPublicKey, verify } from "node:crypto";
import { writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
const [realRoot, realCore, draftRoot, draftCore, specLockPath, mode, outPath] = process.argv.slice(2);
/* eslint-disable @typescript-eslint/no-require-imports */
const { canon, isToken, signedBytes, signatureBytes } = require(join(draftRoot, "ts/refund-finality/encoding.ts"));
const { Sink } = require(join(draftRoot, "ts/refund-finality/sink.ts"));
const { propose } = require(join(draftRoot, "ts/refund-finality/proposer.ts"));

const ROOT = draftRoot; const corePath = draftCore;

type Answer = { line: string; msg: any };
class Client {
  private next = 1;
  private readonly waiting = new Map<number, (a: Answer) => void>();
  ready: any;
  constructor(private readonly child: ChildProcessWithoutNullStreams) {}
  static start(root: string, core: string): Promise<Client> {
    const file = join(root, "ts/refund-finality/minter.ts");
    const child = spawn(process.execPath, ["--import", "tsx", file, core, specLockPath, mode],
      { cwd: root, stdio: ["pipe", "pipe", "inherit"] }) as unknown as ChildProcessWithoutNullStreams;
    const c = new Client(child);
    return new Promise((done, fail) => {
      child.on("exit", code => fail(new Error(file + " ended " + code)));
      // Split at the byte 0x0A only (Node's readline also splits at U+2028/U+2029: known finding F5 of proposer.ts).
      let buf = Buffer.alloc(0);
      child.stdout.on("data", (chunk: Buffer) => {
        buf = Buffer.concat([buf, chunk]);
        let nl: number;
        while ((nl = buf.indexOf(0x0a)) !== -1) {
          const line = buf.subarray(0, nl).toString("utf8"); buf = buf.subarray(nl + 1);
          const msg = JSON.parse(line);
          if (msg.ready) { c.ready = msg; done(c); continue; }
          const w = c.waiting.get(msg.id); if (w) { c.waiting.delete(msg.id); w({ line, msg }); }
        }
      });
    });
  }
  send(body: Record<string, unknown>): Promise<Answer> {
    const id = this.next++;
    return new Promise(done => { this.waiting.set(id, done); this.child.stdin.write(JSON.stringify({ id, ...body }) + "\n"); });
  }
  stop(): void { this.child.removeAllListeners("exit"); this.child.stdin.end(); this.child.kill(); }
}

// ---------------------------------------------------------------- cases
const TEXTS: [string, string][] = [
  ["plain", "ch_1"], ["quote", "a\"b"], ["backslash", "a\\b"], ["ctl01", "a\u0001b"], ["nl-tab", "a\nb\tc\r\f\b"],
  ["ctl1f-7f", "\u001f\u007f"], ["u2028", "\u2028\u2029"], ["nonBMP", "\u{1D11E}x"], ["latin", "\u00e9\u00fc"],
  ["lone-surrogate", "a\uD800b"], ["NUL", "a\u0000b"], ["NUL-only", "\u0000"], ["empty", ""],
  ["len256", "x".repeat(256)], ["len257", "x".repeat(257)], ["nonBMP128(256u)", "\u{1D11E}".repeat(128)],
  ["nonBMP128+x(257u)", "\u{1D11E}".repeat(128) + "x"], ["esc-text", "\\u0000\"}"], ["json-inject", "\",\"requestId\":\"z"],
];
type Case = { name: string; body: Record<string, unknown> };
const cases: Case[] = [];
const st = (chargeId: string, original: string, remaining: string, refundEnabled = true) => ({ chargeId, original, remaining, refundEnabled });
const rq = (requestId: string, amount: string, reason = "duplicate_charge") => ({ requestId, amount, reason });
function add(name: string, pre: any, t: any) { cases.push({ name, body: { pre, transition: t } }); }
function proposeSafe(pre: any, r: any): any {
  try { return propose(pre, r); } catch { return { request: r, post: pre, intent: { chargeId: pre.chargeId, requestId: r.requestId, amount: r.amount, reason: r.reason } }; }
}
function withMutants(name: string, pre: any, r: any) {
  const t = proposeSafe(pre, r);
  add(name, pre, t);
  add(name + "/post+1", pre, { ...t, post: { ...t.post, remaining: (BigInt(t.post.remaining) + 1n).toString() } });
  add(name + "/intent.amount", pre, { ...t, intent: { ...t.intent, amount: (BigInt(t.intent.amount) + 1n).toString() } });
  add(name + "/intent.chargeId", pre, { ...t, intent: { ...t.intent, chargeId: t.intent.chargeId + "x" } });
  add(name + "/intent.requestId", pre, { ...t, intent: { ...t.intent, requestId: t.intent.requestId + "x" } });
  add(name + "/post.enabled", pre, { ...t, post: { ...t.post, refundEnabled: !t.post.refundEnabled } });
  add(name + "/post.original", pre, { ...t, post: { ...t.post, original: (BigInt(t.post.original) + 1n).toString() } });
  add(name + "/post.chargeId", pre, { ...t, post: { ...t.post, chargeId: t.post.chargeId + "y" } });
}
for (const [n, s] of TEXTS) {
  withMutants("chargeId:" + n, st(s, "100", "60"), rq("rq_1", "40"));
  withMutants("requestId:" + n, st("ch_1", "100", "60"), rq(s, "40"));
  add("reason:" + n, st("ch_1", "100", "60"), proposeSafe(st("ch_1", "100", "60"), rq("rq_1", "40", s)));
  add("chargeId0:" + n, st(s, "100", "60"), proposeSafe(st(s, "100", "60"), rq("rq_0", "0")));
}
for (const reason of ["duplicate_charge", "service_not_delivered", "returned_item", "other", "Duplicate_charge", "returned_item\u0000"]) {
  add("reasonset:" + reason, st("ch_1", "100", "60"), proposeSafe(st("ch_1", "100", "60"), rq("rq_r", "5", reason)));
}
const MAX = "9223372036854775807";
const PRES: [string, string][] = [["100", "60"], ["0", "0"], ["100", "0"], ["100", "100"], [MAX, MAX], [MAX, "1"],
  ["9223372036854775808", "1"], ["9999999999999999999", "5"], ["10000000000000000000", "5"], ["100", "101"], ["01", "1"], ["-1", "0"]];
for (const [o, r] of PRES) {
  const amounts = new Set(["0", "1", r, (() => { try { return (BigInt(r) + 1n).toString(); } catch { return "2"; } })(), MAX, "9999999999999999999", "01", "-1"]);
  for (const a of amounts) {
    for (const en of [true, false]) {
      const name = `money:${o}/${r}/amt${a}/en${en}`;
      if (o === "100" && r === "60" && en) withMutants(name, st("ch_m", o, r, en), rq("rq_m", a));
      else add(name, st("ch_m", o, r, en), proposeSafe(st("ch_m", o, r, en), rq("rq_m", a)));
    }
  }
}
// message shapes
add("shape:extra-key", st("ch_1", "100", "60"), { ...propose(st("ch_1", "100", "60"), rq("rq_1", "4")), extra: 1 });
cases.push({ name: "shape:missing-pre", body: { transition: propose(st("ch_1", "100", "60"), rq("rq_1", "4")) } });
cases.push({ name: "shape:pre-array", body: { pre: [], transition: propose(st("ch_1", "100", "60"), rq("rq_1", "4")) } });
add("shape:amount-number", st("ch_1", "100", "60"), { ...propose(st("ch_1", "100", "60"), rq("rq_1", "4")), request: { requestId: "rq_1", amount: 4, reason: "duplicate_charge" } });
cases.push({ name: "shape:extra-top", body: { pre: st("ch_1", "100", "60"), transition: propose(st("ch_1", "100", "60"), rq("rq_1", "4")), x: 1 } });

// ---------------------------------------------------------------- run
(async () => {
  const real = await Client.start(realRoot, realCore);
  const draft = await Client.start(draftRoot, draftCore);
  const realKey = createPublicKey(real.ready.publicKeyPem), draftKey = createPublicKey(draft.ready.publicKeyPem);
  const draftCfg = { publicKeyPem: draft.ready.publicKeyPem, specLockSha256: draft.ready.specLockSha256, checkerSha256: draft.ready.checkerSha256 };
  const realCfg = { publicKeyPem: real.ready.publicKeyPem, specLockSha256: real.ready.specLockSha256, checkerSha256: real.ready.checkerSha256 };
  const t = { cases: cases.length, bothIssue: 0, bothRefuse: 0, zeroIssued: 0, bodyEqualModuloChecker: 0, draftSigOk: 0, realSigOk: 0,
    draftVerbatimInLine: 0, sinkCommitted: 0, sinkReplayed: 0, sinkStateOk: 0, realSinkCommitted: 0, crossPinRejected: 0, auditClean: 0 };
  const diffs: any[] = [];
  const refusalReasons: Record<string, number> = {};
  for (const c of cases) {
    const [a, b] = await Promise.all([real.send(c.body), draft.send(c.body)]);
    if (a.msg.ok !== b.msg.ok) { diffs.push({ case: c.name, real: a.msg.ok ? "issue" : a.msg.reason, draft: b.msg.ok ? "issue" : b.msg.reason, body: c.body }); continue; }
    if (!a.msg.ok) {
      t.bothRefuse++;
      const k = a.msg.reason + " | " + b.msg.reason; refusalReasons[k] = (refusalReasons[k] ?? 0) + 1;
      continue;
    }
    t.bothIssue++;
    const rt = a.msg.token, dt = b.msg.token;
    if (!isToken(rt) || !isToken(dt)) { diffs.push({ case: c.name, problem: "token shape" }); continue; }
    if (dt.body.intent.amount === "0") t.zeroIssued++;
    const expected = canon(rt.body).replace(`"checkerSha256":"${real.ready.checkerSha256}"`, `"checkerSha256":"${draft.ready.checkerSha256}"`);
    if (expected === canon(dt.body)) t.bodyEqualModuloChecker++; else diffs.push({ case: c.name, problem: "body text", real: canon(rt.body), draft: canon(dt.body) });
    if (verify(null, signedBytes(dt.body), draftKey, signatureBytes(dt.signature)!)) t.draftSigOk++; else diffs.push({ case: c.name, problem: "draft signature" });
    if (verify(null, signedBytes(rt.body), realKey, signatureBytes(rt.signature)!)) t.realSigOk++;
    const draftText = canon(dt);
    if (b.line === "{\"id\":" + b.msg.id + ",\"ok\":true,\"token\":" + draftText + "}") t.draftVerbatimInLine++; else diffs.push({ case: c.name, problem: "answer line" });
    const pre = (c.body as any).pre, tr = (c.body as any).transition;
    const sink = new Sink(":memory:", draftCfg); sink.init(pre);
    const r1 = sink.commit(draftText), r2 = sink.commit(draftText);
    if (r1.status === "committed") t.sinkCommitted++; else diffs.push({ case: c.name, problem: "sink commit", r1 });
    if (r2.status === "replayed" && sink.outbox().length === 1) t.sinkReplayed++; else diffs.push({ case: c.name, problem: "sink replay", r2 });
    if (sink.stateBlob() === canon(tr.post) && sink.outbox()[0]?.intent === canon(tr.intent)) t.sinkStateOk++;
    if (sink.audit().length === 0) t.auditClean++;
    sink.close();
    const rs = new Sink(":memory:", realCfg); rs.init(pre);
    if (rs.commit(canon(rt)).status === "committed") t.realSinkCommitted++;
    rs.close();
    const xs = new Sink(":memory:", { ...realCfg, publicKeyPem: draft.ready.publicKeyPem }); xs.init(pre);
    const xr = xs.commit(draftText);
    if (xr.status === "rejected" && xr.reason === "checker is not the pinned one") t.crossPinRejected++;
    xs.close();
  }
  real.stop(); draft.stop();
  // Direct calls of the compiled method (no TypeScript shape check in front): the proved WfBody guard.
  const core = require(resolve(corePath)), F = core.RefundFinality, R = core.Refund, I = core.IssueBytes2, rtm = core.runtime;
  const tx = (s: string) => rtm.Seq.UnicodeFromString(s);
  const BN = require(require.resolve("bignumber.js", { paths: [ROOT] }));
  const ch = (id: string, o: number, r: number) => F.Charge.create_Charge(tx(id), new BN(o), new BN(r), true);
  const trn = (id: string, rqid: string, amt: number, r: number, o: number) => F.Transition.create_Transition(
    F.Request.create_Request(tx(rqid), new BN(amt), tx("duplicate_charge")), ch(id, o, r - amt),
    R.RefundIntent.create_Intent(tx(id), tx(rqid), new BN(amt), tx("duplicate_charge")));
  const H = "a".repeat(64), Z = "0".repeat(64);
  const call = (id: string, rqid: string, amt: number, h = H) => I.__default.IssueTokenBytes(ch(id, 100, 60), trn(id, rqid, amt, 60, 100), tx(Z), tx(Z), tx(h));
  const direct: Record<string, boolean | string> = {};
  const ok = call("ch_1", "rq_1", 40);
  const bodyObj = { domain: "FORGE_REFUND_FINALITY_SLICE1_V1", specLockSha256: Z, checkerSha256: Z, preStateSha256: H, requestId: "rq_1",
    post: { chargeId: "ch_1", original: "100", remaining: "20", refundEnabled: true },
    intent: { chargeId: "ch_1", requestId: "rq_1", amount: "40", reason: "duplicate_charge" } };
  direct.authorizedIssues = ok.is_Some === true &&
    Buffer.from(Array.from(ok.dtor_value as Iterable<unknown>, (b: unknown) => Number(b))).equals(signedBytes(bodyObj as any));
  direct.zeroIssues = call("ch_1", "rq_0", 0).is_Some === true;
  direct.unauthorizedRefused = call("ch_1", "rq_1", 61).is_Some === false;
  direct.nulChargeIdRefused = call("a\u0000b", "rq_1", 40).is_Some === false;
  direct.nulRequestIdRefused = call("ch_1", "r\u0000", 40).is_Some === false;
  direct.len257Refused = call("x".repeat(257), "rq_1", 40).is_Some === false;
  direct.len256Issues = call("x".repeat(256), "rq_1", 40).is_Some === true;
  direct.badHashRefused = call("ch_1", "rq_1", 40, "A".repeat(64)).is_Some === false;
  direct.longText20kRefused = call("x".repeat(20000), "rq_1", 40).is_Some === false;
  for (const [k, v] of Object.entries(direct)) if (v !== true) diffs.push({ case: "direct:" + k, problem: "direct call" });
  const out = { node: process.version, realReady: { ...real.ready, publicKeyPem: undefined }, draftReady: { ...draft.ready, publicKeyPem: undefined },
    totals: t, direct, differences: diffs.length, diffs: diffs.map(d => ({ ...d, body: undefined })), refusalReasons };
  writeFileSync(outPath, JSON.stringify(out, null, 1));
  process.stdout.write(JSON.stringify({ totals: t, direct, differences: diffs.length }) + "\n");
  process.exit(diffs.length === 0 ? 0 : 1);
})().catch(e => { process.stderr.write(String(e && e.stack) + "\n"); process.exit(3); });
