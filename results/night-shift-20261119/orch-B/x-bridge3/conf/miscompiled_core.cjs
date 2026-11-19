// x-bridge3 STAND-IN (a MISCOMPILED checker model). NOT a real build. It loads the real compiled module
// (path in FORGE_X3_CORE, else d-minter/build/issuebytes2.cjs) and REPLACES IssueBytes2.IssueTokenBytes by a
// function that issues the canonical body of ANY transition it is given (no Check, no authorization).
// The real RefundFinality / Refund / runtime are kept, so the minter's conversions run unchanged.
"use strict";
const path = require("node:path");
const real = require(process.env.FORGE_X3_CORE ||
  path.resolve(__dirname, "../../d-minter/build/issuebytes2.cjs"));
const back = (s) => s.toVerbatimString(false);
const dec = (n) => BigInt(n.toFixed()).toString();
function canon(v) {          // copy of ts/refund-finality/encoding.ts canon (strings, booleans, plain objects)
  if (typeof v === "string") return JSON.stringify(v);
  if (typeof v === "boolean") return v ? "true" : "false";
  if (v !== null && typeof v === "object" && Object.getPrototypeOf(v) === Object.prototype) {
    return "{" + Object.keys(v).sort().map(k => JSON.stringify(k) + ":" + canon(v[k])).join(",") + "}";
  }
  throw new Error("non-canonical value");
}
function IssueTokenBytes(pre, t, spec, checker, preHash) {
  const p = t.dtor_post, i = t.dtor_intent;
  const body = { domain: "FORGE_REFUND_FINALITY_SLICE1_V1", specLockSha256: back(spec), checkerSha256: back(checker),
    preStateSha256: back(preHash), requestId: back(t.dtor_request.dtor_requestId),
    post: { chargeId: back(p.dtor_chargeId), original: dec(p.dtor_original), remaining: dec(p.dtor_remaining), refundEnabled: p.dtor_refundEnabled },
    intent: { chargeId: back(i.dtor_chargeId), requestId: back(i.dtor_requestId), amount: dec(i.dtor_amount), reason: back(i.dtor_reason) } };
  return { is_Some: true, is_None: false, dtor_value: Array.from(Buffer.from(canon(body), "utf8")) };
}
module.exports = { ...real, IssueBytes2: { ...real.IssueBytes2, __default: { IssueTokenBytes } }, STANDIN: "miscompiled-issue-all" };
