// r-drafts attack C (night shift 2026-11-19, Orchestrator B, adversarial review). Own generator, not the worker's.
// Real minter.ts vs draft minter_issuebytes.ts, both as child processes with in-process test keys, mode "off"
// (and a few "on" cases). Each issued draft token is checked: canonical text, the signature over EXACTLY the
// embedded body text, and the unchanged sink.ts pinned to the draft's ids accepts it exactly once.
// Usage (cwd = repository root): node --import tsx c_minter.ts <core .cjs> <spec lock> <out json>
import { spawn, ChildProcessWithoutNullStreams } from "node:child_process";
import { createPublicKey, verify } from "node:crypto";
import { writeFileSync } from "node:fs";
import { canon, isToken, sha256hex } from "<REPO>/ts/refund-finality/encoding";
import { Sink } from "<REPO>/ts/refund-finality/sink";

const ROOT = "<REPO>";
const REAL = ROOT + "/ts/refund-finality/minter.ts";
const DRAFT = ROOT + "/results/night-shift-20261119/orch-B/d-minter/minter_issuebytes.ts";
const [corePath, specLockPath, outPath] = process.argv.slice(2);

class Client {
  ready: any; private waiting: ((l: string) => void)[] = [];
  constructor(private child: ChildProcessWithoutNullStreams) {}
  static start(file: string, mode: string): Promise<Client> {
    const child = spawn(process.execPath, ["--import", "tsx", file, corePath, specLockPath, mode],
      { cwd: ROOT, stdio: ["pipe", "pipe", "pipe"] }) as unknown as ChildProcessWithoutNullStreams;
    const c = new Client(child);
    child.stderr.on("data", (d: Buffer) => { const s = d.toString(); if (!/ExperimentalWarning|trace-warnings/.test(s)) process.stderr.write("[" + file.split("/").pop() + "] " + s); });
    return new Promise((done, fail) => {
      child.on("exit", code => fail(new Error(file + " ended " + code)));
      let buf = Buffer.alloc(0);
      child.stdout.on("data", (chunk: Buffer) => {
        buf = Buffer.concat([buf, chunk]); let nl: number;
        while ((nl = buf.indexOf(0x0a)) !== -1) {
          const line = buf.subarray(0, nl).toString("utf8"); buf = buf.subarray(nl + 1);
          if (c.ready === undefined) { c.ready = JSON.parse(line); done(c); continue; }
          const w = c.waiting.shift(); if (w) w(line);
        }
      });
    });
  }
  // Answers come in order (one answer line per input line). Raw line: the caller gives the exact text.
  sendRaw(line: string): Promise<string> { return new Promise(done => { this.waiting.push(done); this.child.stdin.write(line + "\n"); }); }
  stop(): void { this.child.removeAllListeners("exit"); this.child.stdin.end(); this.child.kill(); }
}

// ------------------------------------------------------------------ generator (boundary biased)
type Req = { name: string; line: string; pre?: any };
const reqs: Req[] = [];
let nid = 1;
const st = (chargeId: any, original: any, remaining: any, refundEnabled: any = true) => ({ chargeId, original, remaining, refundEnabled });
const sub = (a: any, b: any): any => { try { if (typeof a === "string" && typeof b === "string" && /^-?[0-9]+$/.test(a) && /^-?[0-9]+$/.test(b)) return (BigInt(a) - BigInt(b)).toString(); } catch {} return a; };
function honest(pre: any, requestId: any, amount: any, reason: any) {
  return { request: { requestId, amount, reason }, post: { ...pre, remaining: sub(pre.remaining, amount) },
           intent: { chargeId: pre.chargeId, requestId, amount, reason } };
}
function add(name: string, pre: any, transition: any) { reqs.push({ name, pre, line: JSON.stringify({ id: nid++, pre, transition }) }); }
function raw(name: string, f: (id: number) => string) { reqs.push({ name, line: f(nid++) }); }
const P = st("ch_1", "1000", "600");
const REASONS = ["duplicate_charge", "service_not_delivered", "returned_item", "", "Duplicate_charge", "duplicate_charge ", "other", "returned_item\u0000", "returnedéitem"];
for (const r of REASONS) for (const a of ["0", "1", "600", "601"]) add(`reason[${JSON.stringify(r)}] amt ${a}`, P, honest(P, "rq_r", a, r));
const MAX = "9223372036854775807", MAXP1 = "9223372036854775808", D19 = "9999999999999999999", D20 = "10000000000000000000";
for (const [o, r, a] of [[MAX, MAX, MAX], [MAX, MAX, "0"], [MAX, MAX, "1"], [MAXP1, MAXP1, "1"], [MAXP1, "5", "1"], [D19, D19, D19], [D20, D20, "1"],
  [MAX, "0", "0"], [MAX, "0", "1"], ["0", "0", "0"], ["1", "1", "1"], ["100", "200", "50"], ["100", "200", "0"], ["100", "101", "101"]])
  add(`money o=${o} r=${r} a=${a}`, st("ch_1", o, r), honest(st("ch_1", o, r), "rq_m", a, "duplicate_charge"));
for (const a of ["-1", "-0", "01", "00", "+1", "1e2", "1E2", "1.0", "1.", ".5", " 1", "1 ", "0x10", "١", "1_0", "", "NaN", "Infinity"])
  add(`amount text ${JSON.stringify(a)}`, P, honest(P, "rq_a", a, "duplicate_charge"));
for (const a of [1, 0, -1, 1.5, 1e2, 600, null, true, [], {}])
  add(`amount json ${JSON.stringify(a)}`, P, honest(P, "rq_j", a, "duplicate_charge"));
for (const o of ["01", "+1000", "1e3", 1000, "-1"]) add(`original text ${JSON.stringify(o)}`, st("ch_1", o, "600"), honest(st("ch_1", o, "600"), "rq_o", "1", "duplicate_charge"));
add("refundEnabled false", st("ch_1", "1000", "600", false), honest(st("ch_1", "1000", "600", false), "rq_f", "1", "duplicate_charge"));
add("refundEnabled false amt 0", st("ch_1", "1000", "600", false), honest(st("ch_1", "1000", "600", false), "rq_f0", "0", "duplicate_charge"));
for (const e of ["false", 0, 1, null, "true"]) add(`refundEnabled ${JSON.stringify(e)}`, st("ch_1", "1000", "600", e), honest(st("ch_1", "1000", "600", e), "rq_e", "1", "duplicate_charge"));
// every code unit 0x00..0x2FF in the request id and in the charge id
for (let u = 0; u <= 0x2ff; u++) {
  const c = String.fromCharCode(u);
  add(`requestId unit ${u.toString(16)}`, P, honest(P, "r" + c, "1", "duplicate_charge"));
  const p = st("c" + c, "1000", "600");
  add(`chargeId unit ${u.toString(16)}`, p, honest(p, "rq_c", "1", "returned_item"));
}
for (const [nm, s] of [["lone D800", "a\uD800"], ["lone DBFF end", "\uDBFF"], ["lone DC00", "\uDC00a"], ["lone DFFF", "x\uDFFF"], ["reversed pair", "\uDC00\uD800"],
  ["pair", "𝄞"], ["U+FFFE", "￾"], ["U+FFFF", "￿"], ["U+FEFF", "﻿"], ["U+2028", " "], ["U+10FFFF", "\u{10FFFF}"], ["empty", ""]] as [string, string][]) {
  add(`requestId ${nm}`, P, honest(P, s, "1", "duplicate_charge"));
  const p = st(s, "1000", "600"); add(`chargeId ${nm}`, p, honest(p, "rq_s", "1", "duplicate_charge"));
}
const NB = "\u{1F600}";
for (const [nm, s] of [["255", "x".repeat(255)], ["256", "x".repeat(256)], ["257", "x".repeat(257)], ["nb128=256u", NB.repeat(128)], ["nb128+x=257u", NB.repeat(128) + "x"],
  ["x255+nb=257u", "x".repeat(255) + NB], ["x254+nb=256u", "x".repeat(254) + NB], ["e9x256", "é".repeat(256)], ["long19000", "y".repeat(19000)]] as [string, string][]) {
  add(`requestId len ${nm}`, P, honest(P, s, "1", "duplicate_charge"));
  const p = st(s, "1000", "600"); add(`chargeId len ${nm}`, p, honest(p, "rq_L", "1", "duplicate_charge"));
}
// inconsistent transitions (one field off)
const H = honest(P, "rq_x", "100", "duplicate_charge");
const mut = (nm: string, f: (t: any) => void) => { const t = JSON.parse(JSON.stringify(H)); f(t); add("mut " + nm, P, t); };
mut("post.remaining+1", t => t.post.remaining = "501"); mut("post.remaining-1", t => t.post.remaining = "499");
mut("post.original", t => t.post.original = "999"); mut("post.chargeId", t => t.post.chargeId = "ch_2"); mut("post.refundEnabled", t => t.post.refundEnabled = false);
mut("intent.chargeId", t => t.intent.chargeId = "ch_2"); mut("intent.requestId", t => t.intent.requestId = "rq_y"); mut("intent.amount", t => t.intent.amount = "99");
mut("intent.reason", t => t.intent.reason = "returned_item"); mut("request.reason", t => t.request.reason = "returned_item"); mut("request.amount", t => t.request.amount = "99");
mut("post = pre (no decrease)", t => t.post.remaining = "600"); mut("extra key in intent", t => t.intent.x = 1); mut("missing key in post", t => delete t.post.original);
mut("extra key in transition", t => t.extra = {}); mut("extra key in request", t => t.request.extra = "1");
mut("__proto__ key in intent", t => Object.defineProperty(t.intent, "__proto__", { value: {}, enumerable: true }));
// raw lines: framing, duplicate keys, message shape
const PJ = JSON.stringify(P), TJ = JSON.stringify(H);
raw("dup key chargeId (last wins)", id => `{"id":${id},"pre":{"chargeId":"ch_9","chargeId":"ch_1","original":"1000","remaining":"600","refundEnabled":true},"transition":${TJ}}`);
raw("dup key amount in request", id => `{"id":${id},"pre":${PJ},"transition":{"request":{"requestId":"rq_x","amount":"1","amount":"100","reason":"duplicate_charge"},"post":${JSON.stringify(H.post)},"intent":${JSON.stringify(H.intent)}}}`);
raw("dup key pre", id => `{"id":${id},"pre":{},"pre":${PJ},"transition":${TJ}}`);
raw("dup key id", id => `{"id":"x","id":${id},"pre":${PJ},"transition":${TJ}}`);
raw("extra msg key", id => `{"id":${id},"pre":${PJ},"transition":${TJ},"x":1}`);
raw("missing transition", id => `{"id":${id},"pre":${PJ}}`);
raw("id string", () => `{"id":"1","pre":${PJ},"transition":${TJ}}`);
raw("id negative", () => `{"id":-1,"pre":${PJ},"transition":${TJ}}`);
raw("id 1.5", () => `{"id":1.5,"pre":${PJ},"transition":${TJ}}`);
raw("id 2^53", () => `{"id":9007199254740992,"pre":${PJ},"transition":${TJ}}`);
raw("id 1e0", () => `{"id":1e0,"pre":${PJ},"transition":${TJ}}`);
raw("whitespace around", id => `  {"id":${id} , "pre":${PJ},"transition":${TJ}}  \r`);
raw("BOM prefix", id => `﻿{"id":${id},"pre":${PJ},"transition":${TJ}}`);
raw("array", () => `[1,2]`); raw("null", () => `null`); raw("empty line", () => ``); raw("not json", () => `{`);
raw("deep nesting 9000", () => "[".repeat(9000) + "]".repeat(9000));
raw("escaped unicode ids", id => `{"id":${id},"pre":{"chargeId":"\\u0063h_1","original":"1000","remaining":"600","refundEnabled":true},"transition":${TJ}}`);
raw("long padding 19000 spaces", id => `{"id":${id},"pre":${PJ},"transition":${TJ}${" ".repeat(19000)}}`);
raw("invalid utf8 byte in id (text)", id => `{"id":${id},"pre":${PJ},"transition":${JSON.stringify(honest(P, "rq_�", "1", "duplicate_charge"))}}`);

type Diff = { name: string; real: string; draft: string; problem: string };
async function main() {
  const real = await Client.start(REAL, "off"), draft = await Client.start(DRAFT, "off");
  const dKey = createPublicKey(draft.ready.publicKeyPem), rKey = createPublicKey(real.ready.publicKeyPem);
  const diffs: Diff[] = [];
  const t = { requests: 0, bothIssue: 0, bothRefuse: 0, zeroIssued: 0, sinkOnce: 0, crossRejected: 0, sigExact: 0, reasonDiff: 0 };
  for (const q of reqs) {
    t.requests++;
    const [rl, dl] = await Promise.all([real.sendRaw(q.line), draft.sendRaw(q.line)]);
    const rm = JSON.parse(rl), dm = JSON.parse(dl);
    const d = (problem: string) => diffs.push({ name: q.name, real: rl.slice(0, 300), draft: dl.slice(0, 300), problem });
    if (rm.ok !== dm.ok) { d("decision"); continue; }
    if (rm.id !== dm.id) d("id");
    if (!rm.ok) { t.bothRefuse++; if (rm.reason !== dm.reason) { t.reasonDiff++; d("reason text (not a decision)"); } continue; }
    t.bothIssue++;
    if (dm.token.body.intent.amount === "0") t.zeroIssued++;
    const rb = { ...rm.token.body, checkerSha256: "" }, db = { ...dm.token.body, checkerSha256: "" };
    if (canon(rb) !== canon(db)) d("body");
    if (dm.token.body.checkerSha256 !== draft.ready.checkerSha256 || rm.token.body.checkerSha256 !== real.ready.checkerSha256) d("checker id");
    // the token text exactly as the draft wrote it
    const prefix = `{"id":${dm.id},"ok":true,"token":`;
    if (!dl.startsWith(prefix) || !dl.endsWith("}")) { d("answer framing"); continue; }
    const tokenText = dl.slice(prefix.length, -1);
    const tok = JSON.parse(tokenText);
    if (!isToken(tok) || canon(tok) !== tokenText) d("token not canonical");
    const bodyText = tokenText.slice('{"body":'.length, tokenText.lastIndexOf(',"signature":'));
    const sig = Buffer.from(tok.signature, "base64");
    if (canon(tok.body) !== bodyText) d("embedded body text is not canon(body)");
    if (verify(null, Buffer.from(bodyText, "utf8"), dKey, sig)) t.sigExact++; else d("signature does not cover the embedded body text");
    if (verify(null, Buffer.from(bodyText, "utf8"), rKey, sig)) d("draft signature verifies under the real key");
    // the unchanged sink, pinned to the draft ids, initialised at the token's pre-state
    const pre = q.pre ?? JSON.parse(q.line.replace(/^\uFEFF/, "")).pre;
    if (sha256hex(canon(pre)) !== tok.body.preStateSha256) d("pre hash is not H(canon(pre))");
    const s = new Sink(":memory:", { publicKeyPem: draft.ready.publicKeyPem, specLockSha256: draft.ready.specLockSha256, checkerSha256: draft.ready.checkerSha256 });
    s.init(pre);
    const c1 = s.commit(tokenText), c2 = s.commit(tokenText);
    const realTokText = canon(rm.token), c3 = s.commit(realTokText);
    if (c1.status === "committed" && c2.status === "replayed" && s.outbox().length === 1 && s.stateBlob() === canon(tok.body.post) && s.audit().length === 0) t.sinkOnce++;
    else d(`sink: ${JSON.stringify([c1, c2, s.outbox().length, s.audit()])}`);
    if (c3.status === "rejected") t.crossRejected++; else d("real-minter token accepted by the draft-pinned sink");
    s.close();
  }
  real.stop(); draft.stop();
  // single-use "on": a second, different transition for one pre-state must be refused by both; a repeat is allowed.
  const ron = await Client.start(REAL, "on"), don = await Client.start(DRAFT, "on");
  const on: any[] = [];
  for (const [nm, tr] of [["first", honest(P, "rq_u1", "5", "duplicate_charge")], ["repeat", honest(P, "rq_u1", "5", "duplicate_charge")],
    ["other amount", honest(P, "rq_u1", "6", "duplicate_charge")], ["other id", honest(P, "rq_u2", "5", "duplicate_charge")], ["refused one", honest(P, "rq_u3", "601", "duplicate_charge")]] as [string, any][]) {
    const line = JSON.stringify({ id: nid++, pre: P, transition: tr });
    const [a, b] = await Promise.all([ron.sendRaw(line), don.sendRaw(line)]);
    const am = JSON.parse(a), bm = JSON.parse(b);
    on.push({ nm, real: am.ok ? "ok" : am.reason, draft: bm.ok ? "ok" : bm.reason });
    if (am.ok !== bm.ok) diffs.push({ name: "single-use " + nm, real: a.slice(0, 200), draft: b.slice(0, 200), problem: "decision" });
  }
  ron.stop(); don.stop();
  const out = { node: process.version, totals: t, singleUseOn: on, differences: diffs };
  writeFileSync(outPath, JSON.stringify(out, null, 1));
  console.log(JSON.stringify({ totals: t, differences: diffs.length, decisionDiffs: diffs.filter(x => x.problem === "decision").length, singleUseOn: on }));
}
main().catch(e => { console.error("FAILED", e); process.exit(1); });
