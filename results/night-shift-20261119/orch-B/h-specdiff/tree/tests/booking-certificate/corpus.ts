// Slice 3: the batches of the recorded runs. Deterministic: no clock, no random source of the system.
// 46 batches are the instances of Rounds 2 and 3, used unchanged
// (proposals/forge2-pillar3-dual-certificate/finality/solvers.ts): 40 with runs of slots and capacities
// 1 or 2, and 6 general 0/1 batches. 24 more batches have the capacity 1 in every slot and one unbroken
// run of slots for every request.
import { instances } from "../../proposals/forge2-pillar3-dual-certificate/finality/solvers";
import { Batch, Board } from "../../ts/booking-certificate/encoding";

export type Case = { name: string; kind: "runs" | "general" | "unit runs"; board: Board; batch: Batch };

function rng(seed: number) { let s = seed >>> 0; return () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 4294967296; }; }
function unitRuns(k: number): Case {
  const r = rng(9000 + k), slots = 5 + (k % 8), requests = 7 + (k % 8);
  const needs = Array.from({ length: slots }, () => Array<string>(requests).fill("0")), values: string[] = [];
  for (let j = 0; j < requests; j++) {
    const first = Math.floor(r() * slots), last = Math.min(slots, first + 1 + Math.floor(r() * 4));
    for (let i = first; i < last; i++) needs[i][j] = "1";
    values.push(String(1 + Math.floor(r() * 20)));
  }
  const name = "unit-runs-" + k;
  return { name, kind: "unit runs", board: { capacity: Array<string>(slots).fill("1") }, batch: { requestId: name, needs, values } };
}

export const corpus: Case[] = [
  ...instances.map((I): Case => ({
    name: I.name, kind: I.kind === "interval" ? "runs" : "general", board: { capacity: I.c.map(String) },
    batch: { requestId: I.name, needs: I.A.map(row => row.map(String)), values: I.w.map(String) },
  })),
  ...Array.from({ length: 24 }, (_, k) => unitRuns(k)),
];
