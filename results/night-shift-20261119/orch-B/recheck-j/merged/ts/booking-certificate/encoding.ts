// Slice 3 (master idea items F3.1 and F3.2): shared encoding of the runtime-certificate boundary.
// NOT proved. No booking rule is in this file. The checks here are shape checks only: they can refuse
// an input, they can never authorize one.
// Canonical JSON is the one of Slice 1 (ts/refund-finality/encoding.ts, used unchanged): objects with
// sorted keys; only strings, booleans, arrays and plain objects. No JSON numbers: every integer is a
// decimal string.
import { canon, sha256hex, signatureBytes } from "../refund-finality/encoding";

export { canon, sha256hex, signatureBytes };

// The stored state of one board: the capacity that remains in each slot.
export type Board = { capacity: string[] };
// One batch of requests. needs[i][j] is the number of units of slot i that request j needs.
// values[j] is the value of request j.
export type Batch = { requestId: string; needs: string[][]; values: string[] };
// What an untrusted optimizer returns: an allocation and a certificate (prices for slots and for
// requests, and the gap in basis points that the optimizer states).
export type Proposal = { allocation: string[]; slotPrices: string[]; requestPrices: string[]; alphaBps: string };
// The signed part of a token. preStateSha256, batchSha256 and requestId are the bindings that the
// sink compares with its own store. allocation and post are the effect that the token allows.
export type TokenBody = {
  domain: string; specSha256: string; checkerSha256: string;
  preStateSha256: string; batchSha256: string; requestId: string;
  allocation: string[]; alphaBps: string; value: string; post: Board;
};
export type Token = { body: TokenBody; signature: string };

export const DOMAIN = "FORGE_BOOKING_CERTIFICATE_SLICE3_V1";
export const MAX_SLOTS = 32;
export const MAX_REQUESTS = 64;
export const MAX_PROPOSAL_TEXT = 16384;
const INT = /^(0|-?[1-9][0-9]{0,17})$/;
const GAP = /^(0|[1-9][0-9]{0,4})$/;
const HEX64 = /^[0-9a-f]{64}$/;
const ID = /^[A-Za-z0-9_.:-]{1,64}$/;

function exact(x: unknown, keys: string[]): x is Record<string, unknown> {
  if (x === null || typeof x !== "object" || Array.isArray(x) || Object.getPrototypeOf(x) !== Object.prototype) return false;
  const own = Object.keys(x as object).sort();
  return own.length === keys.length && [...keys].sort().every((k, i) => own[i] === k);
}
const int = (v: unknown): v is string => typeof v === "string" && INT.test(v);
const hex64 = (v: unknown): v is string => typeof v === "string" && HEX64.test(v);
const id = (v: unknown): v is string => typeof v === "string" && ID.test(v);
// A plain array (no holes, no extra properties are read) of at most `max` decimal integer strings.
const ints = (v: unknown, max: number): v is string[] => {
  if (!Array.isArray(v) || v.length > max) return false;
  for (let i = 0; i < v.length; i++) if (!int(v[i])) return false;
  return true;
};

export function isBoard(x: unknown): x is Board {
  return exact(x, ["capacity"]) && ints(x.capacity, MAX_SLOTS);
}
export function isBatch(x: unknown): x is Batch {
  if (!exact(x, ["requestId", "needs", "values"]) || !id(x.requestId) || !ints(x.values, MAX_REQUESTS)) return false;
  const needs = x.needs;
  if (!Array.isArray(needs) || needs.length > MAX_SLOTS) return false;
  for (let i = 0; i < needs.length; i++) if (!ints(needs[i], MAX_REQUESTS)) return false;
  return true;
}
export function isProposal(x: unknown): x is Proposal {
  return exact(x, ["allocation", "slotPrices", "requestPrices", "alphaBps"]) && ints(x.allocation, MAX_REQUESTS) &&
    ints(x.slotPrices, MAX_SLOTS) && ints(x.requestPrices, MAX_REQUESTS) && int(x.alphaBps);
}
export function isTokenBody(x: unknown): x is TokenBody {
  return exact(x, ["domain", "specSha256", "checkerSha256", "preStateSha256", "batchSha256", "requestId",
    "allocation", "alphaBps", "value", "post"]) &&
    x.domain === DOMAIN && hex64(x.specSha256) && hex64(x.checkerSha256) && hex64(x.preStateSha256) &&
    hex64(x.batchSha256) && id(x.requestId) && ints(x.allocation, MAX_REQUESTS) &&
    typeof x.alphaBps === "string" && GAP.test(x.alphaBps) && Number(x.alphaBps) <= 10000 && int(x.value) && isBoard(x.post);
}
export function isToken(x: unknown): x is Token {
  return exact(x, ["body", "signature"]) && isTokenBody(x.body) && signatureBytes(x.signature) !== null;
}
// The one text of a token that the sink accepts.
export const tokenText = (token: Token): string => canon(token);
// The signed bytes: the whole body, by value.
export const signedBytes = (body: TokenBody): Buffer => Buffer.from(canon(body), "utf8");
export const boardSha256 = (board: Board): string => sha256hex(canon(board));
export const batchSha256 = (batch: Batch): string => sha256hex(canon(batch));
// The outbound record of a committed batch.
export const intentText = (body: TokenBody): string =>
  canon({ requestId: body.requestId, allocation: body.allocation, alphaBps: body.alphaBps, value: body.value });
// A LABEL for the claim text: the hash of the two files that the issuer was started with (the
// candidate specification and the reference file that it includes). Nothing in the issuer links this
// label to the compiled core. The EXIT script and the suites compute it again from the two files of
// the repository and compare.
export function specSha256Of(candidateSpec: Buffer, reference: Buffer): string {
  return sha256hex(canon({ candidateSpecSha256: sha256hex(candidateSpec), referenceSha256: sha256hex(reference) }));
}
// Identity of the token issuer: the compiled core module and the glue files of the issuer process.
export function checkerSha256Of(coreModule: Buffer, encodingSource: Buffer, issuerSource: Buffer, canonSource: Buffer): string {
  return sha256hex(canon({
    coreModuleSha256: sha256hex(coreModule), encodingSha256: sha256hex(encodingSource),
    issuerSha256: sha256hex(issuerSource), canonSha256: sha256hex(canonSource),
  }));
}
