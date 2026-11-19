// x-issuer-bridge: the Dafny side of the bridge tests. Calls the COMPILED RefundFinality.Check (the same
// conversions as ts/refund-finality/minter.ts lines 37-55) and writes the six fields derived from the
// verdict. NOT proved. Decides nothing. Compiled core: d-corebacked/build/shellcore-orig.cjs
// (built from impl/RefundFinality.dfy, impl/Refund.dfy, spec/refund/RefundSpec.dfy byte-equal to the repo).
// Arguments: <compiled core .cjs> <vectors.json> <out.json>
"use strict";
const fs = require("node:fs");
const [corePath, inPath, outPath] = process.argv.slice(2);
const core = require(corePath);
const F = core.RefundFinality, R = core.Refund, runtime = core.runtime, BigNumber = core.BigNumber;
const text = (s) => runtime.Seq.UnicodeFromString(s);
const back = (s) => s.toVerbatimString(false);
const num = (s) => new BigNumber(s);
const dec = (n) => BigInt(n.toFixed()).toString();
const charge = (s) => F.Charge.create_Charge(text(s.chargeId), num(s.original), num(s.remaining), s.refundEnabled);
const out = [];
for (const v of JSON.parse(fs.readFileSync(inPath, "utf8"))) {
  const t = v.transition;
  const [verdict, plan] = F.__default.Check(charge(v.pre), text("0".repeat(64)), F.Transition.create_Transition(
    F.Request.create_Request(text(t.request.requestId), num(t.request.amount), text(t.request.reason)),
    charge(t.post),
    R.RefundIntent.create_Intent(text(t.intent.chargeId), text(t.intent.requestId), num(t.intent.amount), text(t.intent.reason))));
  if (verdict.is_Issue !== true) { out.push({ name: v.name, issue: false }); continue; }
  const tok = verdict.dtor_token, i = tok.dtor_intent;
  out.push({ name: v.name, issue: true, amount: dec(i.dtor_amount), reason: back(i.dtor_reason),
    chargeId: back(i.dtor_chargeId), requestId: back(tok.dtor_requestId), count: String(plan.length) });
}
fs.writeFileSync(outPath, JSON.stringify(out, null, 1));
