// r-ser: lone surrogates are refused by isTokenBody (encoding.ts:24, :46) and by the real decoder path.
import { canon, isTokenBody, DOMAIN, TokenBody } from "../../../../../ts/refund-finality/encoding";
const base: TokenBody = { domain: DOMAIN, specLockSha256: "0".repeat(64), checkerSha256: "f".repeat(64), preStateSha256: "a".repeat(64),
  requestId: "r", post: { chargeId: "c", original: "100", remaining: "60", refundEnabled: true },
  intent: { chargeId: "c", requestId: "r", amount: "0", reason: "x" } };
const out: Record<string, unknown> = {};
let refused = 0, n = 0;
for (let cu = 0xd800; cu <= 0xdfff; cu++) for (const v of [String.fromCharCode(cu), "a" + String.fromCharCode(cu), String.fromCharCode(cu) + "a"]) {
  n++; if (!isTokenBody({ ...base, intent: { ...base.intent, reason: v } })) refused++;
}
out.loneObjects = { n, refused };
const t = canon({ ...base, intent: { ...base.intent, reason: "Q" } });
let tn = 0, trefused = 0;
for (const esc of ["\\ud800", "\\udbff", "\\udc00", "\\udfff", "\\ude00\\ud83d", "\\ud83dx"]) {
  tn++; const x = t.replace("\"reason\":\"Q\"", `"reason":"${esc}"`);
  let ok = false; try { const v = JSON.parse(x); ok = isTokenBody(v) && canon(v) === x; } catch { ok = false; }
  if (!ok) trefused++;
}
out.loneEscapedTexts = { n: tn, refused: trefused };
const pair = canon({ ...base, intent: { ...base.intent, reason: "\u{1F600}" } });
out.pairStringifiedVerbatim = pair.includes("\u{1F600}");
out.stringifyLone = JSON.stringify("\ud800");
out.u2028 = JSON.stringify(" ") === "\" \"";
out.del = JSON.stringify("\u007f") === "\"\u007f\"";
out.ctlLower = JSON.stringify("\u001f");
console.log(JSON.stringify(out));
