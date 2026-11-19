// Slice 3: TEST ORACLE ONLY. The certificate check and the optimum written again in plain integer
// arithmetic, to compare the issuer's answers with. It is not used by the issuer or the sink.
// NOT proved. A difference between this file and the compiled core shows only on the proposals that
// the rows use (the recorded batches have numbers of at most 2 digits and no negative entry; one
// suite row uses 17 digits). A difference is a defect of one of the two, to be looked at by a person.
import { Batch, Board, Proposal } from "../../ts/booking-certificate/encoding";

export type Numbers = { c: bigint[]; A: bigint[][]; w: bigint[] };
export const numbersOf = (board: Board, batch: Batch): Numbers =>
  ({ c: board.capacity.map(BigInt), A: batch.needs.map(row => row.map(BigInt)), w: batch.values.map(BigInt) });
const dot = (a: bigint[], b: bigint[]): bigint => a.reduce((s, v, k) => s + v * b[k], 0n);
const sum = (a: bigint[]): bigint => a.reduce((s, v) => s + v, 0n);

export const shaped = (n: Numbers): boolean => n.A.length === n.c.length && n.A.every(row => row.length === n.w.length);
export function feasible(n: Numbers, x: bigint[]): boolean {
  return shaped(n) && x.length === n.w.length && x.every(v => v === 0n || v === 1n) && n.A.every((row, i) => dot(row, x) <= n.c[i]);
}
export const valueOf = (n: Numbers, x: bigint[]): bigint => dot(n.w, x);
export const remainingOf = (n: Numbers, x: bigint[]): bigint[] => n.c.map((c, i) => c - dot(n.A[i], x));

// The specified check (BookingCertificateSpec.Accepts), written again.
export function accepts(board: Board, batch: Batch, p: Proposal): boolean {
  const n = numbersOf(board, batch);
  const x = p.allocation.map(BigInt), y = p.slotPrices.map(BigInt), z = p.requestPrices.map(BigInt), alpha = BigInt(p.alphaBps);
  if (alpha < 0n || alpha > 10000n) return false;
  if (!shaped(n) || x.length !== n.w.length || y.length !== n.A.length || z.length !== n.w.length) return false;
  if (!feasible(n, x)) return false;
  if (y.some(v => v < 0n) || z.some(v => v < 0n)) return false;
  for (let j = 0; j < n.w.length; j++) {
    let covered = z[j];
    for (let i = 0; i < n.A.length; i++) covered += y[i] * n.A[i][j];
    if (n.w[j] > covered) return false;
  }
  return (10000n - alpha) * (dot(y, n.c) + sum(z)) <= 10000n * dot(n.w, x);
}

// The largest value of a feasible allocation, by a search over all subsets. Only for few requests.
// null: no allocation is feasible (a capacity below zero).
export function optimum(board: Board, batch: Batch): bigint | null {
  const n = numbersOf(board, batch), count = n.w.length;
  if (!shaped(n) || count > 16) throw new Error("reference search: batch too large or not rectangular");
  let best: bigint | null = null;
  for (let mask = 0; mask < (1 << count); mask++) {
    const x = Array.from({ length: count }, (_, j) => ((mask >> j) & 1) === 1 ? 1n : 0n);
    if (feasible(n, x)) { const v = valueOf(n, x); if (best === null || v > best) best = v; }
  }
  return best;
}
