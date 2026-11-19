// r-bytes3: which token shapes does the real decoder accept? Single short run.
import { isToken, canon, DOMAIN } from "./encoding-copy.mts";
const h = "a".repeat(64), sig = Buffer.alloc(64, 1).toString("base64");
const body = (o = {}) => ({ domain: DOMAIN, specLockSha256: h, checkerSha256: h, preStateSha256: h, requestId: "rq",
  post: { chargeId: "ch", original: "100", remaining: "60", refundEnabled: true },
  intent: { chargeId: "ch", requestId: "rq", amount: "0", reason: "duplicate_charge" }, ...o });
const tok = (b, extra = {}) => ({ body: b, signature: sig, ...extra });
const cases = {
  base: tok(body()),
  loneSurrogateReqId: tok(body({ requestId: "r\uD800" })),
  text257: tok(body({ requestId: "r".repeat(257) })),
  text256: tok(body({ requestId: "r".repeat(256) })),
  money19digits: tok(body({ post: { chargeId: "ch", original: "9999999999999999999", remaining: "9999999999999999999", refundEnabled: true } })),
  money20digits: tok(body({ post: { chargeId: "ch", original: "10000000000000000000", remaining: "0", refundEnabled: true } })),
  moneyLeadingZero: tok(body({ intent: { chargeId: "ch", requestId: "rq", amount: "01", reason: "x" } })),
  extraBodyKey: tok({ ...body(), x: "y" }),
  extraTokenKey: tok(body(), { x: 1 }),
  otherDomain: tok(body({ domain: "OTHER" })),
  upperHexPre: tok(body({ preStateSha256: "A".repeat(64) })),
  nulInReason: tok(body({ intent: { chargeId: "ch", requestId: "rq", amount: "0", reason: "a\u0000" } })),
  protoKey: JSON.parse('{"body":' + canon(body()) + ',"signature":"' + sig + '","__proto__":1}'),
  emptyChargeId: tok(body({ post: { chargeId: "", original: "1", remaining: "1", refundEnabled: true } })),
  remainingAboveOriginal: tok(body({ post: { chargeId: "ch", original: "1", remaining: "5", refundEnabled: true } })),
};
for (const [k, v] of Object.entries(cases)) console.log(k, isToken(v));
