// x-bridge3 G3c (modified copy of d-minter/conf/run.ts; the case generator is unchanged). Was: d-minter G4: light conformance of the DRAFT minter (minter_issuebytes.ts) against the REAL minter.ts.
// Both run as their own processes with test keys generated in those processes. Read-only use of the repository.
// Usage: node --import tsx run.ts <compiled module .cjs> <spec lock> <out json>
import { spawn, ChildProcessWithoutNullStreams } from "node:child_process";
import { createPublicKey, verify } from "node:crypto";
import { writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { canon, isToken, signedBytes, signatureBytes } from "../../../../../ts/refund-finality/encoding";
import { Sink } from "../../../../../ts/refund-finality/sink";
import { propose } from "../../../../../ts/refund-finality/proposer";

const ROOT = resolve(__dirname, "../../../../..");
const [corePath, specLockPath, outPath] = process.argv.slice(2);

type Answer = { line: string; msg: any };
class Client {
  private next = 1;
  private readonly waiting = new Map<number, (a: Answer) => void>();
  ready: any;
  constructor(private readonly child: ChildProcessWithoutNullStreams) {}
  static start(file: string, args: string[], env?: Record<string, string>): Promise<Client> {
    const child = spawn(process.execPath, ["--import", "tsx", file, ...args],
      { cwd: ROOT, stdio: ["pipe", "pipe", "inherit"], env: { ...process.env, ...(env ?? {}) } }) as unknown as ChildProcessWithoutNullStreams;
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

// ---------------------------------------------------------------- run (x-bridge3: real minter.ts, d-minter draft, minter_bridged.ts)
const X3 = resolve(__dirname, "..");
const BIN = join(X3, "bin", "refund"), PIN = "b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8";
const WORK = join(X3, "run", "work-minter");
const sha = (p: string) => require("node:crypto").createHash("sha256").update(require("node:fs").readFileSync(p)).digest("hex");
const bridgedArgs = (core: string, bin: string, pin: string) => [core, specLockPath, "off", bin, pin, WORK];
const isIssue = (a: Answer) => a.msg.ok === true;
(async () => {
  require("node:fs").mkdirSync(WORK, { recursive: true });
  const out: any = { node: process.version, phases: {} };
  const diffs: any[] = [];
  // Phase 1: honest configuration. Same decision for all three; bridged tokens commit once in the unchanged sink.
  const real = await Client.start(join(ROOT, "ts/refund-finality/minter.ts"), [corePath, specLockPath, "off"]);
  const draft = await Client.start(resolve(X3, "../d-minter/minter_issuebytes.ts"), [corePath, specLockPath, "off"]);
  const br = await Client.start(resolve(X3, "minter_bridged.ts"), bridgedArgs(corePath, BIN, PIN));
  const brKey = createPublicKey(br.ready.publicKeyPem);
  const brCfg = { publicKeyPem: br.ready.publicKeyPem, specLockSha256: br.ready.specLockSha256, checkerSha256: br.ready.checkerSha256 };
  const t = { cases: cases.length, allIssue: 0, allRefuse: 0, zeroIssued: 0, bodyEqualModuloChecker: 0, sigOk: 0, verbatimInLine: 0,
    sinkCommitted: 0, sinkReplayed: 0, sinkStateOk: 0, auditClean: 0, crossPinRejected: 0 };
  const authorized = new Set<string>();
  const refusalReasons: Record<string, number> = {};
  for (const c of cases) {
    const [a, d, b] = await Promise.all([real.send(c.body), draft.send(c.body), br.send(c.body)]);
    if (isIssue(a) !== isIssue(d) || isIssue(a) !== isIssue(b)) {
      diffs.push({ phase: 1, case: c.name, real: a.msg.reason ?? "issue", draft: d.msg.reason ?? "issue", bridged: b.msg.reason ?? "issue" }); continue;
    }
    if (!isIssue(a)) { t.allRefuse++; const k = b.msg.reason; refusalReasons[k] = (refusalReasons[k] ?? 0) + 1; continue; }
    t.allIssue++; authorized.add(c.name);
    const dt = d.msg.token, bt = b.msg.token;
    if (!isToken(bt)) { diffs.push({ phase: 1, case: c.name, problem: "token shape" }); continue; }
    if (bt.body.intent.amount === "0") t.zeroIssued++;
    const exp = canon(dt.body).replace(`"checkerSha256":"${draft.ready.checkerSha256}"`, `"checkerSha256":"${br.ready.checkerSha256}"`);
    if (exp === canon(bt.body)) t.bodyEqualModuloChecker++; else diffs.push({ phase: 1, case: c.name, problem: "body text" });
    if (verify(null, signedBytes(bt.body), brKey, signatureBytes(bt.signature)!)) t.sigOk++; else diffs.push({ phase: 1, case: c.name, problem: "signature" });
    const text = canon(bt);
    if (b.line === "{\"id\":" + b.msg.id + ",\"ok\":true,\"token\":" + text + "}") t.verbatimInLine++; else diffs.push({ phase: 1, case: c.name, problem: "line" });
    const pre = (c.body as any).pre, tr = (c.body as any).transition;
    const sink = new Sink(":memory:", brCfg); sink.init(pre);
    const r1 = sink.commit(text), r2 = sink.commit(text);
    if (r1.status === "committed") t.sinkCommitted++; else diffs.push({ phase: 1, case: c.name, problem: "sink commit", r1 });
    if (r2.status === "replayed" && sink.outbox().length === 1) t.sinkReplayed++; else diffs.push({ phase: 1, case: c.name, problem: "sink replay" });
    if (sink.stateBlob() === canon(tr.post) && sink.outbox()[0]?.intent === canon(tr.intent)) t.sinkStateOk++;
    if (sink.audit().length === 0) t.auditClean++;
    sink.close();
    const xs = new Sink(":memory:", { ...brCfg, checkerSha256: draft.ready.checkerSha256 }); xs.init(pre);
    const xr = xs.commit(text);
    if (xr.status === "rejected" && xr.reason === "checker is not the pinned one") t.crossPinRejected++;
    xs.close();
  }
  // Phase 5 (cost): 20 honest mints, sequential, one request in flight; draft (no launch) and bridged (one launch each).
  const honest = cases.filter(c => authorized.has(c.name)).slice(0, 20);
  const timeIt = async (cl: Client) => { const ms: number[] = []; for (const c of honest) { const t0 = performance.now(); const a = await cl.send(c.body); ms.push(performance.now() - t0); if (!isIssue(a)) ms.push(NaN); } return ms; };
  const stats = (ms: number[]) => { const s = [...ms].sort((a, b) => a - b); return { n: ms.length, meanMs: +(ms.reduce((a, b) => a + b, 0) / ms.length).toFixed(2), medianMs: +s[Math.floor(s.length / 2)].toFixed(2), maxMs: +s[s.length - 1].toFixed(2) }; };
  const costDraft = stats(await timeIt(draft)), costBridged = stats(await timeIt(br));
  real.stop(); draft.stop(); br.stop();
  out.phases.p1 = { totals: t, refusalReasons, bridgedReady: { ...br.ready, publicKeyPem: undefined }, draftChecker: draft.ready.checkerSha256 };
  out.phases.cost = { draft: costDraft, bridged: costBridged, extraPerMintMs: +(costBridged.meanMs - costDraft.meanMs).toFixed(2) };

  // Phases 2-4: one bridged minter each, all cases. "unauthorized" = issued where phase 1 (real minter) refused.
  async function phase(name: string, core: string, bin: string, pin: string, env?: Record<string, string>) {
    const cl = await Client.start(resolve(X3, "minter_bridged.ts"), bridgedArgs(core, bin, pin), env);
    const p = { issued: 0, unauthorizedIssued: 0, honestIssued: 0, refused: 0, reasons: {} as Record<string, number>, unauthorizedCases: [] as string[] };
    for (const c of cases) {
      const a = await cl.send(c.body);
      if (isIssue(a)) {
        p.issued++;
        if (authorized.has(c.name)) p.honestIssued++; else { p.unauthorizedIssued++; p.unauthorizedCases.push(c.name); }
      } else { p.refused++; p.reasons[a.msg.reason] = (p.reasons[a.msg.reason] ?? 0) + 1; }
    }
    cl.stop();
    out.phases[name] = { ...p, unauthorizedCases: p.unauthorizedCases.slice(0, 10) };
    if (p.unauthorizedIssued !== 0) diffs.push({ phase: name, problem: "unauthorized issued", n: p.unauthorizedIssued });
    return p;
  }
  // 2: STAND-IN wrong native program (authorize-all: prints one fixed AUTHORIZED frame) + the real checker.
  const aa = join(X3, "standin", "authorize-all");
  await phase("p2_wrongNative_realChecker", corePath, aa, sha(aa));
  // 3: STAND-IN miscompiled checker (issues every transition) + the real native program.
  const p3 = await phase("p3_miscompiledChecker_realNative", resolve(__dirname, "miscompiled_core.cjs"), BIN, PIN, { FORGE_X3_CORE: corePath });
  if (p3.honestIssued !== authorized.size) diffs.push({ phase: "p3", problem: "honest not issued", n: p3.honestIssued });
  // 3b: both STAND-INs (outside the guarantee; expected to issue unauthorized cases). Recorded, not a difference.
  {
    const cl = await Client.start(resolve(X3, "minter_bridged.ts"), bridgedArgs(resolve(__dirname, "miscompiled_core.cjs"), aa, sha(aa)), { FORGE_X3_CORE: corePath });
    let issued = 0, unauth = 0; const ex: string[] = [];
    for (const c of cases) { const a = await cl.send(c.body); if (isIssue(a)) { issued++; if (!authorized.has(c.name)) { unauth++; ex.push(c.name); } } }
    cl.stop();
    out.phases.p3b_bothWrong_outsideGuarantee = { issued, unauthorizedIssued: unauth, examples: ex.slice(0, 5) };
  }
  // 4: absent binary (fail closed).
  const p4 = await phase("p4_absentBinary", corePath, join(X3, "bin", "absent-refund"), PIN);
  if (p4.issued !== 0) diffs.push({ phase: "p4", problem: "issued without binary" });
  // 5: changed pin (the binary is present, the pin is another digest).
  const p5 = await phase("p5_wrongPin", corePath, BIN, "0".repeat(64));
  if (p5.issued !== 0) diffs.push({ phase: "p5", problem: "issued with wrong pin" });
  out.differences = diffs.length; out.diffs = diffs.slice(0, 30);
  writeFileSync(outPath, JSON.stringify(out, null, 1));
  process.stdout.write(JSON.stringify({ p1: t, cost: out.phases.cost, differences: diffs.length,
    p2: out.phases.p2_wrongNative_realChecker.reasons, p2issued: out.phases.p2_wrongNative_realChecker.issued,
    p3issued: p3.issued, p3unauth: p3.unauthorizedIssued, p3reasons: p3.reasons, p3b: out.phases.p3b_bothWrong_outsideGuarantee,
    p4: p4.reasons, p5: p5.reasons }) + "\n");
  process.exit(diffs.length === 0 ? 0 : 1);
})().catch(e => { process.stderr.write(String(e && e.stack) + "\n"); process.exit(3); });
