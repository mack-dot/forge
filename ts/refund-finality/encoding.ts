// Slice 1 (master idea items F2.1 to F2.3): shared encoding of the refund finality boundary.
// NOT proved. No refund rule is in this file. The checks here are shape checks only: they can
// refuse an input, they can never authorize one.
// Canonical JSON: objects with sorted keys; only strings, booleans, arrays and plain objects.
// No JSON numbers: money is a decimal string.
import { KeyObject, createHash, createPublicKey } from "node:crypto";

export type ChargeState = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export type RefundRequest = { requestId: string; amount: string; reason: string };
export type Intent = { chargeId: string; requestId: string; amount: string; reason: string };
export type Transition = { request: RefundRequest; post: ChargeState; intent: Intent };
// The signed part of a token. `preStateSha256` and `requestId` are the two bindings that the sink
// compares with its own store. `post` and `intent` are the effect that the token allows.
export type TokenBody = {
  domain: string; specLockSha256: string; checkerSha256: string;
  preStateSha256: string; requestId: string; post: ChargeState; intent: Intent;
};
// OWNER DECISION D-1 (h-key): every token names the issuer key that signed it. keyId is OUTSIDE the proved body
// bytes (the Dafny byte model is unchanged) and INSIDE the signed bytes (signedBytes below): glue step KEYID-GLUE.
export type Token = { body: TokenBody; keyId: string; signature: string };

export const DOMAIN = "FORGE_REFUND_FINALITY_SLICE1_V1";
// Domain of the signed envelope {body, keyId, sigDomain} (h-key, D-1). Old tokens signed the body alone.
export const KEYID_DOMAIN = "FORGE_REFUND_FINALITY_KEYID_V1";
export const MAX_TEXT = 256;
const MONEY = /^(0|[1-9][0-9]{0,18})$/;
const HEX64 = /^[0-9a-f]{64}$/;
const LONE_SURROGATE = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/;

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
// U+0000 is refused: node:sqlite returns a TEXT value cut at the first U+0000, so a request id with
// that character does not read back as it was written (review finding F3).
const text = (v: unknown): v is string =>
  typeof v === "string" && v.length <= MAX_TEXT && !LONE_SURROGATE.test(v) && !v.includes("\u0000");
const money = (v: unknown): v is string => typeof v === "string" && MONEY.test(v);
const hex64 = (v: unknown): v is string => typeof v === "string" && HEX64.test(v);

export function isState(x: unknown): x is ChargeState {
  return exact(x, ["chargeId", "original", "remaining", "refundEnabled"]) && text(x.chargeId) &&
    money(x.original) && money(x.remaining) && typeof x.refundEnabled === "boolean";
}
export function isRequest(x: unknown): x is RefundRequest {
  return exact(x, ["requestId", "amount", "reason"]) && text(x.requestId) && money(x.amount) && text(x.reason);
}
export function isIntent(x: unknown): x is Intent {
  return exact(x, ["chargeId", "requestId", "amount", "reason"]) && text(x.chargeId) && text(x.requestId) &&
    money(x.amount) && text(x.reason);
}
export function isTransition(x: unknown): x is Transition {
  return exact(x, ["request", "post", "intent"]) && isRequest(x.request) && isState(x.post) && isIntent(x.intent);
}
export function isTokenBody(x: unknown): x is TokenBody {
  return exact(x, ["domain", "specLockSha256", "checkerSha256", "preStateSha256", "requestId", "post", "intent"]) &&
    x.domain === DOMAIN && hex64(x.specLockSha256) && hex64(x.checkerSha256) && hex64(x.preStateSha256) &&
    text(x.requestId) && isState(x.post) && isIntent(x.intent);
}
// An Ed25519 signature is 64 bytes. Only the one canonical base64 text of those bytes is accepted.
export function signatureBytes(signature: unknown): Buffer | null {
  if (typeof signature !== "string" || signature.length !== 88) return null;
  const raw = Buffer.from(signature, "base64");
  return raw.length === 64 && raw.toString("base64") === signature ? raw : null;
}
export function isToken(x: unknown): x is Token {
  return exact(x, ["body", "keyId", "signature"]) && isTokenBody(x.body) && hex64(x.keyId) && signatureBytes(x.signature) !== null;
}
export const isKeyId = hex64;
// key_id (D-1): the lower-case hex SHA-256 of the DER SubjectPublicKeyInfo bytes of the Ed25519 public key
// (44 bytes: the 12-byte SPKI prefix 302a300506032b6570032100 and the 32-byte raw key). Throws for any other key type.
export function keyIdOf(publicKey: KeyObject | string): string {
  const key = typeof publicKey === "string" ? createPublicKey(publicKey) : publicKey;
  if (key.type !== "public" || key.asymmetricKeyType !== "ed25519") throw new Error("key id: not an Ed25519 public key");
  const der = key.export({ type: "spki", format: "der" });
  if (der.length !== 44) throw new Error("key id: the SPKI encoding is not 44 bytes");
  return sha256hex(der);
}
// The one text of a token that the sink accepts.
export const tokenText = (token: Token): string => canon(token);
// The signed bytes (D-1, KEYID-GLUE): the canonical text of {body, keyId, sigDomain}. It holds the canonical body
// text VERBATIM: '{"body":' + canon(body) + ',"keyId":"<64 hex>","sigDomain":"FORGE_REFUND_FINALITY_KEYID_V1"}'.
// So the key id is signed together with the proved body bytes; a signature of the old format (body alone) never
// verifies here (its bytes start with '{"checkerSha256"'). Throws if keyId is not 64 lower-case hex digits.
export const signedBytes = (body: TokenBody, keyId: string): Buffer => {
  if (!hex64(keyId)) throw new Error("signed bytes: keyId is not 64 lower-case hex digits");
  return Buffer.from(canon({ body, keyId, sigDomain: KEYID_DOMAIN }), "utf8");
};
export const stateSha256 = (state: ChargeState): string => sha256hex(canon(state));
// Identity of the token issuer: the compiled core module and the two glue files of the minter process.
export function checkerSha256Of(coreModule: Buffer, encodingSource: Buffer, minterSource: Buffer): string {
  return sha256hex(canon({
    coreModuleSha256: sha256hex(coreModule), encodingSha256: sha256hex(encodingSource), minterSha256: sha256hex(minterSource),
  }));
}
