import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { applyModel } from "../interop/model";
import { apply } from "../ts/ledger";
import type { Request, State } from "../ts/types";

const output = process.argv[2];
if (!output || !path.resolve(output).startsWith(path.resolve("build/stage5") + path.sep)) {
  throw new Error("Output must be under build/stage5/");
}
const order = ([a]: [bigint, unknown], [b]: [bigint, unknown]) => a < b ? -1 : a > b ? 1 : 0;
const normalize = (state: State) => ({ balances: [...state.balances].sort(order),
  accepted: [...state.accepted].sort(order) });
const examples: object[] = [];
let accepted = 0;
let rejected = 0;
function observe(name: string, input: State, id: bigint, request: Request): State {
  const before = structuredClone(normalize(input));
  const model = applyModel(input, id, request);
  const actual = apply(input, id, request);
  assert.deepStrictEqual(normalize(input), before, "Input mutation");
  assert.equal(actual.outcome, model.outcome, "Outcome differs from compiled model");
  assert.deepStrictEqual(normalize(actual.state), normalize(model.state), "State differs from compiled model");
  if (model.outcome === "Ok") accepted++; else rejected++;
  examples.push({ id: "E" + String(examples.length + 1).padStart(3, "0"), name,
    input: before, request_id: id, request, outcome: model.outcome, next: normalize(model.state) });
  return model.state;
}
// Enumerate a finite corpus. The compiled model supplies every observed result.
for (const feePresent of [true, false]) {
  for (const sender of [0n, 1n, 2n, 99n]) {
    for (const recipient of [0n, 1n, 2n, 99n]) {
      for (const amount of [-1n, 0n, 1n, 2n, 9n, 10n, 11n]) {
        const balances = new Map([[1n, 11n], [2n, 0n]]);
        if (feePresent) balances.set(0n, 0n);
        observe("enumerated fresh request; fee account " + (feePresent ? "present" : "absent"),
          { balances, accepted: new Map() }, 7n, { sender, recipient, amount });
      }
    }
  }
}
const request = { sender: 1n, recipient: 2n, amount: 10n };
const first = observe("exact funding for amount plus fee", {
  balances: new Map([[0n, 0n], [1n, 11n], [2n, 0n]]), accepted: new Map() }, 7n, request);
observe("identical accepted retry", first, 7n, request);
observe("conflicting accepted ID", first, 7n, { ...request, amount: 9n });
assert(accepted > 0 && rejected > 0);
const report = { method: "tested_against_proved_model", tool: "Node node:assert/strict",
  tool_version: process.versions.node, result: "passed", end_to_end: false,
  finite_corpus: true, counts: { total: examples.length, accepted, rejected }, examples };
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, JSON.stringify(report, (_key, value: unknown) =>
  typeof value === "bigint" ? value.toString() : value) + "\n");
console.log(JSON.stringify(report.counts));
