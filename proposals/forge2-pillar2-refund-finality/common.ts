// Round 2 task 3 (U420): shared encoding for the refund finality experiment. Research code under proposals/.
// NOT proved. Canonical JSON: objects with sorted keys; only strings, booleans, arrays, objects. No numbers.
import { createHash } from "node:crypto";

export type ChargeState = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export type RefundRequest = { requestId: string; amount: string; reason: string };
export type Intent = { chargeId: string; requestId: string; amount: string; reason: string };
export type Claim = {
  specLockSha256: string; minterSha256: string; pre: ChargeState; reqId: string;
  request: RefundRequest; post: ChargeState; intent: Intent;
};
export const DOMAIN = "FORGE_REFUND_FINALITY_V1";
const MONEY = /^(0|[1-9][0-9]{0,18})$/;
const HEX64 = /^[0-9a-f]{64}$/;

export function canon(value: unknown): string {
  if (typeof value === "string") return JSON.stringify(value);
  if (typeof value === "boolean") return value ? "true" : "false";
  if (Array.isArray(value)) return "[" + value.map(canon).join(",") + "]";
  if (value !== null && typeof value === "object" && Object.getPrototypeOf(value) === Object.prototype) {
    const keys = Object.keys(value as object).sort();
    return "{" + keys.map(k => JSON.stringify(k) + ":" + canon((value as Record<string, unknown>)[k])).join(",") + "}";
  }
  throw new Error("non-canonical value");
}
export const sha256hex = (data: string | Buffer): string => createHash("sha256").update(data).digest("hex");

function exact(x: unknown, keys: string[]): x is Record<string, unknown> {
  if (x === null || typeof x !== "object" || Array.isArray(x) || Object.getPrototypeOf(x) !== Object.prototype) return false;
  const own = Object.keys(x as object).sort();
  return own.length === keys.length && [...keys].sort().every((k, i) => own[i] === k);
}
const str = (v: unknown): v is string => typeof v === "string" && v.length <= 256;
function isState(x: unknown): x is ChargeState {
  return exact(x, ["chargeId", "original", "remaining", "refundEnabled"]) && str(x.chargeId) &&
    typeof x.original === "string" && MONEY.test(x.original) && typeof x.remaining === "string" && MONEY.test(x.remaining) &&
    typeof x.refundEnabled === "boolean";
}
export function isClaim(x: unknown): x is Claim {
  if (!exact(x, ["specLockSha256", "minterSha256", "pre", "reqId", "request", "post", "intent"])) return false;
  const r = x.request, i = x.intent;
  return typeof x.specLockSha256 === "string" && HEX64.test(x.specLockSha256) &&
    typeof x.minterSha256 === "string" && HEX64.test(x.minterSha256) && isState(x.pre) && isState(x.post) && str(x.reqId) &&
    exact(r, ["requestId", "amount", "reason"]) && str(r.requestId) && typeof r.amount === "string" && MONEY.test(r.amount) && str(r.reason) &&
    exact(i, ["chargeId", "requestId", "amount", "reason"]) && str(i.chargeId) && str(i.requestId) &&
    typeof i.amount === "string" && MONEY.test(i.amount) && str(i.reason);
}
// The signed bytes. Every field of the claim is bound, by value or by hash.
export function payload(c: Claim): Buffer {
  return Buffer.from(canon({
    domain: DOMAIN, specLockSha256: c.specLockSha256, minterSha256: c.minterSha256,
    preSha256: sha256hex(canon(c.pre)), reqId: c.reqId, requestSha256: sha256hex(canon(c.request)),
    postEffectSha256: sha256hex(canon({ post: c.post, intent: c.intent })),
  }), "utf8");
}
export function makeClaim(specLockSha256: string, minterSha256: string, pre: ChargeState, request: RefundRequest): Claim {
  const remaining = (BigInt(pre.remaining) - BigInt(request.amount)).toString();
  return {
    specLockSha256, minterSha256, pre, reqId: request.requestId, request,
    post: { ...pre, remaining: remaining.startsWith("-") ? "0" : remaining },
    intent: { chargeId: pre.chargeId, requestId: request.requestId, amount: request.amount, reason: request.reason },
  };
}
