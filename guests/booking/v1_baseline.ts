// Slice 3: UNTRUSTED optimizer v1 (the simple baseline). No authority. Not proved. Not reviewed for
// correctness: the checker core judges every answer.
// It reads ONE line (the problem as JSON) and writes ONE line (allocation, prices, stated gap).
// The search is a solver function of Rounds 2 and 3, used unchanged:
// proposals/forge2-pillar3-dual-certificate/finality/solvers.ts (default: number 11, heaviest request
// first with a swap search, prices by 5 rounds of ascent).
// Usage: node --import tsx guests/booking/v1_baseline.ts [solver number]
import { V } from "../../proposals/forge2-pillar3-dual-certificate/finality/solvers";

const wanted = Number(process.argv[2] ?? "11");
let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", chunk => { input += chunk; });
process.stdin.on("end", () => {
  const problem = JSON.parse(input.split("\n")[0]);
  const I = {
    name: "problem", kind: "general" as const,
    A: (problem.needs as string[][]).map(row => row.map(Number)), c: (problem.capacity as string[]).map(Number),
    w: (problem.values as string[]).map(Number),
  };
  const solver = V.find(v => v.id === wanted);
  if (!solver) throw new Error("no solver with this number");
  const { x, y, z } = solver.solve(I);
  // The gap that this optimizer states: the smallest one that its own prices support.
  const value = x.reduce((s, v, j) => s + v * I.w[j], 0);
  const bound = y.reduce((s, v, i) => s + v * I.c[i], 0) + z.reduce((s, v) => s + v, 0);
  const alpha = bound <= value || bound <= 0 ? 0 : Math.min(10000, Math.ceil((10000 * (bound - value)) / bound));
  process.stdout.write(JSON.stringify({
    allocation: x.map(String), slotPrices: y.map(String), requestPrices: z.map(String), alphaBps: String(alpha) }) + "\n");
});
