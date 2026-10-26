import assert, { AssertionError } from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import fc from "fast-check";
import { applyModel } from "../interop/model";
import type { Apply, Request, State } from "../ts/types";

const SEED = 3032026;
const RUNS = 300;
const MAX_OPERATIONS = 40;
const LIMIT = 1n << 128n;
const accounts = [-2n, 3n, 0n, 1n << 80n];
const kinds = ["random", "exact", "retry", "conflict", "self", "unknown", "nonpositive", "insufficient", "amount-only", "fee-account"] as const;
type Kind = typeof kinds[number];
type Operation = { kind: Kind; sender: number; recipient: number; id: bigint; amount: bigint };
const argument = (name: string): string => {
  const index = process.argv.indexOf(name);
  if (index < 0 || !process.argv[index + 1]) throw new Error("Missing argument " + name);
  return process.argv[index + 1];
};
const serializable = (value: unknown): unknown => JSON.parse(JSON.stringify(value,
  (_key, item: unknown) => typeof item === "bigint" ? item.toString() : item));
const normalized = (state: State): unknown => ({
  balances: [...state.balances].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0),
  accepted: [...state.accepted].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0),
});

function main(): number {
  const implementation = argument("--impl");
  if (!["ts/ledger.ts", "bugs/self_transfer.ts"].includes(implementation)) throw new Error("Unsupported fixture path");
  const output = path.resolve(argument("--report"));
  if (!output.startsWith(path.resolve("build") + path.sep)) throw new Error("Report must stay under build/");
  fs.rmSync(output, { force: true });
  const candidate = require(path.resolve(implementation)).apply as Apply;
  if (typeof candidate !== "function") throw new Error("Implementation has no apply function");
  const counters = { compared_steps: 0, successful: 0, rejected: 0, retries: 0, fresh_successes: 0,
    self_transfers: 0, conflicting_ids: 0, exact_balance: 0, unknown_accounts: 0,
    nonpositive_amounts: 0, insufficient_funds: 0, above_safe_integer: 0,
    exact_with_fee: 0, fee_account_requests: 0, missing_fee_account: 0 };
  const operation = fc.record({ kind: fc.constantFrom(...kinds), sender: fc.integer({ min: 0, max: 3 }),
    recipient: fc.integer({ min: 0, max: 3 }), id: fc.bigInt({ min: -3n, max: 5n }),
    amount: fc.bigInt({ min: -LIMIT, max: LIMIT }) });
  const scenario = fc.record({ balances: fc.tuple(...accounts.map(() => fc.bigInt({ min: 0n, max: LIMIT }))),
    hasFeeAccount: fc.boolean(),
    operations: fc.array(operation, { maxLength: MAX_OPERATIONS }) });
  const prefix: Operation[] = kinds.slice(1).map(kind => ({ kind, sender: 0, recipient: 1, id: 0n, amount: 1n }));
  // The self-transfer targets the account just credited by the exact-balance move.
  prefix.find(item => item.kind === "self")!.sender = 1;
  const details = fc.check(fc.property(scenario, input => {
    let expected: State = { balances: new Map(accounts.flatMap((account, i): [bigint, bigint][] =>
      account === 0n && !input.hasFeeAccount ? [] : [[account, input.balances[i]]])),
      accepted: new Map() };
    let actual: State = { balances: new Map(expected.balances), accepted: new Map() };
    for (const [index, item] of [...prefix, ...input.operations].entries()) {
      let id = item.id;
      let request: Request = { sender: accounts[item.sender], recipient: accounts[item.recipient], amount: item.amount };
      const accepted = [...expected.accepted];
      const balance = expected.balances.get(request.sender) ?? 0n;
      if (item.kind !== "random") id = 1000n + BigInt(index);
      if (item.kind === "exact") request = { ...request,
        recipient: accounts[(item.sender + 1) % accounts.length], amount: balance - 1n };
      if (item.kind === "amount-only") request = { ...request, amount: balance };
      if (item.kind === "fee-account") request = { ...request, recipient: 0n, amount: 1n };
      if (item.kind === "self") request = { ...request, recipient: request.sender, amount: 1n };
      if (item.kind === "unknown") request = { ...request, recipient: 999n };
      if (item.kind === "nonpositive") request = { ...request, amount: -1n };
      if (item.kind === "insufficient") request = { ...request, amount: balance + 1n };
      if ((item.kind === "retry" || item.kind === "conflict") && accepted.length) {
        const pair = accepted[item.sender % accepted.length];
        id = pair[0]; request = { ...pair[1] };
        if (item.kind === "conflict") request = { ...request, amount: request.amount + 1n };
      }
      const snapshot = structuredClone(normalized(actual));
      const previous = expected.accepted.get(id);
      const reference = applyModel(expected, id, request);
      const result = candidate(actual, id, request);
      assert.deepStrictEqual(normalized(actual), snapshot, "INPUT_MUTATION: input state changed");
      assert.equal(result.outcome, reference.outcome, "C3 C4 C5: outcome differs from compiled Dafny model");
      assert.deepStrictEqual(normalized(result.state), normalized(reference.state),
        "C1 C2 C3 C4 C5: resulting state differs from compiled Dafny model");
      counters.compared_steps++;
      if (reference.outcome === "Ok") {
        counters.successful++;
        if (previous) counters.retries++; else counters.fresh_successes++;
      } else counters.rejected++;
      if (request.sender === request.recipient) counters.self_transfers++;
      if (previous && (previous.sender !== request.sender || previous.recipient !== request.recipient || previous.amount !== request.amount)) counters.conflicting_ids++;
      if (request.amount === expected.balances.get(request.sender)) counters.exact_balance++;
      if (request.amount + 1n === expected.balances.get(request.sender)) counters.exact_with_fee++;
      if (request.sender === 0n || request.recipient === 0n) counters.fee_account_requests++;
      if (!expected.balances.has(0n)) counters.missing_fee_account++;
      if (!expected.balances.has(request.sender) || !expected.balances.has(request.recipient)) counters.unknown_accounts++;
      if (request.amount <= 0n) counters.nonpositive_amounts++;
      if (request.amount > balance) counters.insufficient_funds++;
      if ([...expected.balances.values(), request.amount].some(value => value > BigInt(Number.MAX_SAFE_INTEGER))) counters.above_safe_integer++;
      expected = reference.state; actual = result.state;
    }
  }), { seed: SEED, numRuns: RUNS, examples: [
    [{ balances: [1n << 100n, 0n, 7n, 1n << 120n], hasFeeAccount: true, operations: [] }],
    [{ balances: [11n, 0n, 0n, 20n], hasFeeAccount: false, operations: [] }],
  ] });
  const report = { method: "tested_against_proved_model", result: details.failed ? "failed" : "passed",
    implementation, tool: "fast-check", tool_version: fc.__version, seed: details.seed,
    requested_runs: RUNS, num_runs: details.numRuns, num_skips: details.numSkips,
    num_shrinks: details.numShrinks, max_generated_operations: MAX_OPERATIONS,
    fixed_prefix: kinds.slice(1), generated_integer_magnitude_limit: LIMIT.toString(),
    counters, counterexample: serializable(details.counterexample),
    counterexample_path: details.counterexamplePath,
    failure_kind: details.failed ? (details.errorInstance instanceof AssertionError ? "comparison_assertion" : "unexpected_error") : null,
    failure_message: details.errorInstance instanceof Error ? details.errorInstance.message.split("\n")[0] : null,
    end_to_end: false };
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, JSON.stringify(report) + "\n");
  console.log(JSON.stringify(report));
  if (details.failed) return report.failure_kind === "comparison_assertion" ? 1 : 2;
  assert(Object.values(counters).every(value => value > 0), "The fixed corpus missed a required category");
  return 0;
}

try { process.exitCode = main(); }
catch (error) { console.error(error); process.exitCode = 2; }
