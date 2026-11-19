import assert from "node:assert/strict";
import fs from "node:fs";
import { apply } from "../ts/ledger";
import { applyModel } from "../interop/model";
import type { Request, State } from "../ts/types";

const state = (balances: [bigint, bigint][], accepted: [bigint, Request][] = []): State =>
  ({ balances: new Map(balances), accepted: new Map(accepted) });
const request: Request = { sender: 1n, recipient: 2n, amount: 10n };
let count = 0;
function check(input: State, id: bigint, req: Request, expected: { state: State; outcome: "Ok" | "Rejected" }) {
  for (const implementation of [apply, applyModel]) {
    const before = structuredClone(input);
    assert.deepStrictEqual(implementation(input, id, req), expected);
    assert.deepStrictEqual(input, before);
  }
  count++;
}
const initial = state([[0n, 0n], [1n, 11n], [2n, 0n]]);
const accepted = state([[0n, 1n], [1n, 0n], [2n, 10n]], [[7n, request]]);
check(initial, 7n, request, { state: accepted, outcome: "Ok" });
check(accepted, 7n, request, { state: accepted, outcome: "Ok" });
check(accepted, 7n, { ...request, amount: 9n }, { state: accepted, outcome: "Rejected" });
const amountOnly = state([[0n, 0n], [1n, 10n], [2n, 0n]]);
check(amountOnly, 8n, request, { state: amountOnly, outcome: "Rejected" });
const missingFee = state([[1n, 11n], [2n, 0n]]);
check(missingFee, 8n, request, { state: missingFee, outcome: "Rejected" });
for (const req of [{ sender: 0n, recipient: 2n, amount: 1n },
  { sender: 1n, recipient: 0n, amount: 1n }, { sender: 1n, recipient: 1n, amount: 1n },
  { sender: 1n, recipient: 2n, amount: 0n }]) {
  const input = state([[0n, 20n], [1n, 20n], [2n, 0n]]);
  check(input, 8n, req, { state: input, outcome: "Rejected" });
}
// WellFormed historical accepted records retain the approved retry semantics.
const oldRequest = { sender: 0n, recipient: 1n, amount: 1n };
const historical = state([[0n, 10n], [1n, 2n]], [[9n, oldRequest]]);
check(historical, 9n, oldRequest, { state: historical, outcome: "Ok" });
const report = { result: "passed", method: "unit_tested", cases: count,
  implementations: ["ts/ledger.ts", "compiled Dafny model"], end_to_end: false };
fs.mkdirSync("build/stage4-fees", { recursive: true });
fs.writeFileSync("build/stage4-fees/examples.json", JSON.stringify(report) + "\n");
console.log(JSON.stringify(report));
