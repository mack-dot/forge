// Round 3 task 4 (U431): shared encoding for the booking finality experiment. Research code. NOT proved.
import { canon, sha256hex } from "../../forge2-pillar2-refund-finality/common";
export { canon, sha256hex };

export type Batch = { A: string[][]; c: string[]; w: string[] };                    // integers as decimal strings
export type Certificate = { x: string[]; y: string[]; z: string[] };
export type BookingClaim = {
  checkerSha256: string; minterSha256: string; batchId: string; instanceSha256: string;
  allocation: string[]; alphaBps: string; value: string; certificateSha256: string;
};
export const DOMAIN = "FORGE_BOOKING_FINALITY_V1";
const INT = /^(0|-?[1-9][0-9]{0,15})$/;
const HEX64 = /^[0-9a-f]{64}$/;
const ints = (v: unknown, max = 64): v is string[] => Array.isArray(v) && v.length <= max && v.every(s => typeof s === "string" && INT.test(s));
const plain = (x: unknown, keys: string[]): x is Record<string, unknown> =>
  x !== null && typeof x === "object" && !Array.isArray(x) && Object.getPrototypeOf(x) === Object.prototype &&
  Object.keys(x as object).sort().join() === [...keys].sort().join();
export const isBatch = (b: unknown): b is Batch =>
  plain(b, ["A", "c", "w"]) && Array.isArray(b.A) && b.A.length <= 64 && b.A.every(r => ints(r)) && ints(b.c) && ints(b.w);
export const isCertificate = (c: unknown): c is Certificate => plain(c, ["x", "y", "z"]) && ints(c.x) && ints(c.y) && ints(c.z);
export const isClaim = (c: unknown): c is BookingClaim =>
  plain(c, ["checkerSha256", "minterSha256", "batchId", "instanceSha256", "allocation", "alphaBps", "value", "certificateSha256"]) &&
  [c.checkerSha256, c.minterSha256, c.instanceSha256, c.certificateSha256].every(h => typeof h === "string" && HEX64.test(h)) &&
  typeof c.batchId === "string" && c.batchId.length <= 128 && ints(c.allocation) &&
  typeof c.alphaBps === "string" && /^(0|[1-9][0-9]{0,4})$/.test(c.alphaBps) && typeof c.value === "string" && INT.test(c.value);
export const payload = (c: BookingClaim): Buffer => Buffer.from(canon({ domain: DOMAIN, ...c }), "utf8");
export const batchOf = (I: { A: number[][]; c: number[]; w: number[] }): Batch =>
  ({ A: I.A.map(r => r.map(String)), c: I.c.map(String), w: I.w.map(String) });
