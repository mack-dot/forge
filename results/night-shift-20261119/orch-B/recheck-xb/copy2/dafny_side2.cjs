// x-bridge2: the checker side of the bridge. NOT proved. Calls the COMPILED RefundFinality.Check
// (conversions as in ts/refund-finality/minter.ts lines 37-55) for ONE candidate per input line.
// Compiled core: orch-B/d-corebacked/build/shellcore-orig.cjs (built from the byte-equal Dafny sources).
// Protocol: stdin lines of JSON {pre, t, preStateSha256}; stdout one JSON line per input:
//   {"issue": true|false, "plan": n, "tokenOk": bool}  or {"error": "..."}.
// Arguments: <compiled core .cjs> [STANDIN mode]. Modes (label STAND-IN, a MISCOMPILED checker model):
//   ignore-post   : issue iff the real Check issues for t with post := the correct post (post ignored)
//   ignore-intent : issue iff the real Check issues for t with intent := the correct intent (intent ignored)
//   accept-all    : always issue
"use strict";
const readline = require("node:readline");
const [corePath, mode] = process.argv.slice(2);
const core = require(corePath);
const F = core.RefundFinality, R = core.Refund, runtime = core.runtime, BigNumber = core.BigNumber;
const text = (s) => runtime.Seq.UnicodeFromString(s);
const back = (s) => s.toVerbatimString(false);
const num = (s) => new BigNumber(s);
const charge = (s) => F.Charge.create_Charge(text(s.chargeId), num(s.original), num(s.remaining), s.refundEnabled);

function realCheck(pre, h, t) {
  const [verdict, plan] = F.__default.Check(charge(pre), text(h), F.Transition.create_Transition(
    F.Request.create_Request(text(t.request.requestId), num(t.request.amount), text(t.request.reason)),
    charge(t.post),
    R.RefundIntent.create_Intent(text(t.intent.chargeId), text(t.intent.requestId), num(t.intent.amount), text(t.intent.reason))));
  const issue = verdict.is_Issue === true;
  return { issue, plan: plan.length, tokenOk: issue ? back(verdict.dtor_token.dtor_preStateHash) === h : true };
}

function correctPost(pre, t) {
  return { ...pre, remaining: (BigInt(pre.remaining) - BigInt(t.request.amount)).toString() };
}
function correctIntent(pre, t) {
  return { chargeId: pre.chargeId, requestId: t.request.requestId, amount: t.request.amount, reason: t.request.reason };
}

function check(pre, h, t) {
  if (mode === undefined) return realCheck(pre, h, t);
  if (mode === "ignore-post") return { ...realCheck(pre, h, { ...t, post: correctPost(pre, t) }), standin: mode };
  if (mode === "ignore-intent") return { ...realCheck(pre, h, { ...t, intent: correctIntent(pre, t) }), standin: mode };
  if (mode === "accept-all") return { issue: true, plan: 1, tokenOk: true, standin: mode };
  throw new Error("unknown mode");
}

// Copy of ts/refund-finality/encoding.ts canon (lines 26-35), for the pre-state digest cross-check only.
function canon(value) {
  if (typeof value === "string") return JSON.stringify(value);
  if (typeof value === "boolean") return value ? "true" : "false";
  if (Array.isArray(value)) return "[" + value.map(canon).join(",") + "]";
  if (value !== null && typeof value === "object" && Object.getPrototypeOf(value) === Object.prototype) {
    const keys = Object.keys(value).sort();
    return "{" + keys.map(k => JSON.stringify(k) + ":" + canon(value[k])).join(",") + "}";
  }
  throw new Error("non-canonical value");
}
const sha256hex = (d) => require("node:crypto").createHash("sha256").update(d).digest("hex");

const rl = readline.createInterface({ input: process.stdin });
rl.on("line", (line) => {
  let out;
  try {
    const v = JSON.parse(line);
    out = v.canonOf !== undefined ? { sha: sha256hex(canon(v.canonOf)) } : check(v.pre, v.preStateSha256, v.t);
  } catch (e) {
    out = { error: String(e && e.message || e) };
  }
  process.stdout.write(JSON.stringify(out) + "\n");
});
