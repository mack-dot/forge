// Wave Gate 1 (M1 conformance): calls the compiled Dafny refund code on a list of vectors and
// writes what it returned. NOT proved. This file decides nothing and compares nothing: the EXIT
// script compares its output with the output of the M1 executable.
//
// Arguments: <compiled core module (.cjs)> <vectors.json> <output.json>
// A text is a list of Unicode scalar values in the input and in the output. An integer is a decimal
// text. No JSON number carries money.
//
// For each vector:
//   assess    Refund.Assess(context, response). When `candidate` is false, every non-candidate
//             constructor of ModelResponse is called (Missing, TimedOut, Failed, Malformed,
//             Oversized, Unsupported).
//   finality  RefundFinality.Check(pre, hash, transition), only when `opened` and `candidate` are
//             true (the checker core takes the request as open and the response as a candidate):
//             once with the honest transition and once for each listed tampered transition.
"use strict";
const { readFileSync, writeFileSync } = require("node:fs");
const { resolve } = require("node:path");
const BigNumber = require("bignumber.js");

const [corePath, vectorsPath, outputPath] = process.argv.slice(2);
if (!corePath || !vectorsPath || !outputPath) {
  process.stderr.write("usage: driver.cjs <compiled core module> <vectors.json> <output.json>\n");
  process.exit(2);
}
const core = require(resolve(corePath));
const F = core.RefundFinality, R = core.Refund, runtime = core.runtime;

// The text is built in pieces. LIMIT of the Dafny JavaScript runtime (measured once, 2026-11-18):
// Seq.UnicodeFromString passes every code point as one call argument; a text of 50,000 code points ends
// with a RangeError, a text of 20,000 does not. The corpus has no text above 20,000 code points.
const text = (points) => {
  let s = "";
  for (let i = 0; i < points.length; i += 4096) s += String.fromCodePoint(...points.slice(i, i + 4096));
  return runtime.Seq.UnicodeFromString(s);
};
const pointsOf = (s) => Array.from(s.toVerbatimString(false), (c) => c.codePointAt(0));
const num = (s) => new BigNumber(s);
const dec = (n) => BigInt(n.toFixed()).toString();
const intentOf = (i) => ({
  chargeId: pointsOf(i.dtor_chargeId), requestId: pointsOf(i.dtor_requestId),
  amount: dec(i.dtor_amount), reason: pointsOf(i.dtor_reason),
});
const chargeOf = (c) => ({
  chargeId: pointsOf(c.dtor_chargeId), original: dec(c.dtor_original), remaining: dec(c.dtor_remaining),
  refundEnabled: c.dtor_refundEnabled,
});
const NON_CANDIDATES = ["Missing", "TimedOut", "Failed", "Malformed", "Oversized", "Unsupported"];

function assess(v, response, label) {
  const context = R.Context.create_ChargeContext(
    text(v.charge), text(v.request), num(v.original), num(v.remaining), v.enabled, v.opened);
  const [decision, plan] = R.__default.Assess(context, response);
  if (decision.is_Authorized === decision.is_Rejected) throw new Error("decision shape");
  const out = { response: label, authorized: decision.is_Authorized === true, plan: [] };
  if (out.authorized) { out.amount = dec(decision.dtor_amount); out.reason = pointsOf(decision.dtor_reason); }
  for (let i = 0; i < plan.length; i++) out.plan.push(intentOf(plan[i]));
  return out;
}

function charge(c) {
  return F.Charge.create_Charge(text(c.chargeId), num(c.original), num(c.remaining), c.refundEnabled);
}
function check(pre, hash, t, label) {
  const [verdict, plan] = F.__default.Check(charge(pre), text(hash), F.Transition.create_Transition(
    F.Request.create_Request(text(t.request.requestId), num(t.request.amount), text(t.request.reason)),
    charge(t.post),
    R.RefundIntent.create_Intent(text(t.intent.chargeId), text(t.intent.requestId), num(t.intent.amount), text(t.intent.reason))));
  if (verdict.is_Issue === verdict.is_Refuse) throw new Error("verdict shape");
  const out = { transition: label, issued: verdict.is_Issue === true, plan: [] };
  if (out.issued) {
    const token = verdict.dtor_token;
    out.token = { preStateHash: pointsOf(token.dtor_preStateHash), requestId: pointsOf(token.dtor_requestId),
                  post: chargeOf(token.dtor_post), intent: intentOf(token.dtor_intent) };
  }
  for (let i = 0; i < plan.length; i++) out.plan.push(intentOf(plan[i]));
  return out;
}

const vectors = JSON.parse(readFileSync(vectorsPath, "utf8"));
const results = [];
for (const v of vectors) {
  const row = { id: v.id, assess: [], finality: [] };
  if (v.candidate) {
    row.assess.push(assess(v, R.ModelResponse.create_Candidate(num(v.amount), text(v.reason)), "Candidate"));
  } else {
    for (const name of NON_CANDIDATES) row.assess.push(assess(v, R.ModelResponse["create_" + name](), name));
  }
  if (v.finality) {
    for (const t of v.finality.transitions) row.finality.push(check(v.finality.pre, v.finality.hash, t, t.label));
  }
  results.push(row);
}
writeFileSync(outputPath, JSON.stringify(results) + "\n");
