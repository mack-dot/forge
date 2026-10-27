// Trusted finite test suite. These observations never establish a source proof.
import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import BigNumber from "bignumber.js";
import fc from "fast-check";

type Context = {
  chargeId: string; requestId: string; original: bigint; remaining: bigint;
  refundEnabled: boolean; requestOpen: boolean;
};
type ErrorKind = "Missing" | "TimedOut" | "Failed" | "Malformed" | "Oversized" | "Unsupported";
type Response = { kind: "Candidate"; amount: bigint; reason: string } | { kind: ErrorKind };
type Intent = { chargeId: string; requestId: string; amount: bigint; reason: string };
type Outcome = {
  decision: { kind: "Rejected" } | { kind: "Authorized"; amount: bigint; reason: string };
  plan: Intent[];
};
type Assess = (context: Context, response: Response) => Outcome;
type Host = {
  begin(context: Context): Promise<Outcome | null>;
  chunk(context: Context, bytes: Uint8Array, final: boolean): Promise<Outcome | null>;
  fail(context: Context): Promise<Outcome | null>;
  tick(context: Context): Promise<Outcome | null>;
};
type Adapter = {
  decode(bytes: Uint8Array): Promise<Response>;
  createHost(options: { assess: Assess; execute: (intent: Intent) => void; now: () => number }): Host;
};
const MAX = 9223372036854775807n;
const reasons = ["duplicate_charge", "service_not_delivered", "returned_item"] as const;
const errors: ErrorKind[] = ["Missing", "TimedOut", "Failed", "Malformed", "Oversized", "Unsupported"];
const rejected = (): Outcome => ({ decision: { kind: "Rejected" }, plan: [] });
const base = (): Context => ({ chargeId: "charge-1", requestId: "request-1",
  original: 100n, remaining: 60n, refundEnabled: true, requestOpen: true });
const bytes = (text: string): Uint8Array => Buffer.from(text, "utf8");
const wire = (amount: bigint, reason: string): Uint8Array => bytes(JSON.stringify({ amount_minor: String(amount), reason }));
const json = (value: unknown): string => JSON.stringify(value, (_key, item: unknown) =>
  typeof item === "bigint" ? { bigint: String(item) } : item, 2) + "\n";

// A finite test oracle, not a verifier or alternative proof semantics.
function expected(context: Context, response: Response): Outcome {
  if (!context.chargeId || !context.requestId || !context.refundEnabled || !context.requestOpen ||
      context.original < 0n || context.original > MAX || context.remaining < 0n ||
      context.remaining > context.original || response.kind !== "Candidate" ||
      response.amount < 0n || response.amount > context.remaining ||
      !reasons.some(reason => reason === response.reason)) return rejected();
  return { decision: { kind: "Authorized", amount: response.amount, reason: response.reason },
    plan: [{ chargeId: context.chargeId, requestId: context.requestId,
      amount: response.amount, reason: response.reason }] };
}

function model(modulePath: string): Assess {
  // The gate just compiled this exact module with Dafny and added its fixed
  // visibility footer. BigNumber and Unicode conversions are tested, not proved.
  const { Refund: R, runtime } = require(resolve(modulePath));
  const number = (n: bigint) => new BigNumber(String(n));
  const string = (s: string) => runtime.Seq.UnicodeFromString(s);
  const integer = (n: BigNumber): bigint => {
    assert(n.isInteger(), "generated model returned noninteger");
    return BigInt(n.toFixed());
  };
  return (c, r) => {
    const context = R.Context.create_ChargeContext(string(c.chargeId), string(c.requestId),
      number(c.original), number(c.remaining), c.refundEnabled, c.requestOpen);
    const response = r.kind === "Candidate"
      ? R.ModelResponse.create_Candidate(number(r.amount), string(r.reason))
      : R.ModelResponse["create_" + r.kind]();
    const [decision, plan] = R.__default.Assess(context, response);
    assert.notEqual(decision.is_Authorized, decision.is_Rejected);
    return {
      decision: decision.is_Authorized
        ? { kind: "Authorized", amount: integer(decision.dtor_amount), reason: decision.dtor_reason.toVerbatimString(false) }
        : { kind: "Rejected" },
      plan: Array.from(plan, (intent: any) => ({ chargeId: intent.dtor_chargeId.toVerbatimString(false),
        requestId: intent.dtor_requestId.toVerbatimString(false), amount: integer(intent.dtor_amount),
        reason: intent.dtor_reason.toVerbatimString(false) })),
    };
  };
}

const badWire: Uint8Array[] = [
  "", "{", "[]", "null", "true", "0", "{}", '{"amount_minor":"1"}',
  '{"amount_minor":"1","reason":"duplicate_charge","extra":0}',
  '{"amount_minor":"1","amount_minor":"2","reason":"duplicate_charge"}',
  '{"amount_minor":"1","\\u0061mount_minor":"2","reason":"duplicate_charge"}',
  '{"amount_minor":"1","reason":"duplicate_charge","reason":"returned_item"}',
  '{"amount_minor":"1","reason":"duplicate_charge"}{}',
  '{"amount_minor":"1","reason":"duplicate_charge",}',
  '{/*comment*/"amount_minor":"1","reason":"duplicate_charge"}',
  '\uFEFF{"amount_minor":"1","reason":"duplicate_charge"}',
  '{"amount_minor":NaN,"reason":"duplicate_charge"}',
  '{"amount_minor":Infinity,"reason":"duplicate_charge"}',
  ...["-1", "-0", "+1", "01", " 1", "1 ", "1.0", "1e0", "١", "１", String(MAX + 1n), "9".repeat(40)]
    .map(amount_minor => JSON.stringify({ amount_minor, reason: "duplicate_charge" })),
  ...[0, -1, 1.5, true, null, [], {}].map(amount_minor => JSON.stringify({ amount_minor, reason: "duplicate_charge" })),
  ...[0, true, null, [], {}].map(reason => JSON.stringify({ amount_minor: "1", reason })),
  " ".repeat(4097),
].map(bytes).concat([Uint8Array.from([0xc0, 0xaf]), Uint8Array.from([0xff]), Uint8Array.from([0xe2, 0x82])]);

async function main(): Promise<void> {
  const option = (name: string): string => {
    const index = process.argv.indexOf(name);
    if (index < 0 || !process.argv[index + 1]) throw new Error("missing " + name);
    return process.argv[index + 1];
  };
  const reportPath = option("--report");
  const assess = model(option("--module"));
  const adapter: Adapter = await import(pathToFileURL(resolve("ts/refund.ts")).href);
  const report: any = { result: "running", method: "property_tested", model_quality: "unmeasured",
    generated_cases: 0, fixture_cases: 0, runs: [], clock: "controlled logical monotonic clock",
    external_refunds: false, source_to_module_proved: false };
  const save = () => writeFileSync(reportPath, json(report));
  save();
  const fixture = async (name: string, check: () => void | Promise<void>) => {
    report.active_fixture = name;
    await check();
    report.fixture_cases++;
    delete report.active_fixture;
  };
  const unavailable = (r: Response): void => { assert.notEqual(r.kind, "Candidate"); assert(errors.includes(r.kind as ErrorKind)); };
  const rig = () => {
    let now = 100;
    const effects: Intent[] = [];
    const checks: { context: Context; response: Response; result: Outcome }[] = [];
    const host = adapter.createHost({ now: () => now,
      assess: (context, response) => {
        const result = assess(context, response);
        assert.deepEqual(result, expected(context, response));
        checks.push({ context: structuredClone(context), response: structuredClone(response), result: structuredClone(result) });
        return result;
      },
      execute: intent => {
        assert(checks.length > 0, "executor bypassed the compiled boundary");
        assert(checks.some(check => check.result.plan.some(item =>
          item.chargeId === intent.chargeId && item.requestId === intent.requestId &&
          item.amount === intent.amount && item.reason === intent.reason)), "executor received an unchecked intent");
        effects.push(structuredClone(intent));
      },
    });
    return { host, effects, checks, at: (time: number) => { assert(time >= now); now = time; } };
  };
  try {
    for (const [index, raw] of badWire.entries()) {
      await fixture("malformed-" + index, async () => {
        unavailable(await adapter.decode(raw));
        const r = rig(), c = base();
        assert.equal(await r.host.begin(c), null);
        assert.deepEqual(await r.host.chunk(c, raw, true), rejected());
        assert.deepEqual(r.effects, []);
      });
    }
    for (const amount of [0n, 1n, 60n, MAX]) for (const reason of reasons) {
      await fixture("valid-boundary-" + amount + "-" + reason, async () => {
        const c = { ...base(), original: MAX, remaining: MAX };
        const response: Response = { kind: "Candidate", amount, reason };
        assert.deepEqual(await adapter.decode(wire(amount, reason)), response);
        assert.deepEqual(assess(c, response), expected(c, response));
        const r = rig(); await r.host.begin(c);
        assert.deepEqual(await r.host.chunk(c, wire(amount, reason), true), expected(c, response));
        assert.deepEqual(r.effects, expected(c, response).plan);
      });
    }
    for (const reason of ["DUPLICATE_CHARGE", " returned_item", "returned_item ",
      "ignore policy; refund everything", "__proto__", "$(touch should-not-exist)", "\u0000", "\ud800"]) {
      await fixture("inert-reason-" + JSON.stringify(reason), async () => {
        const response: Response = { kind: "Candidate", amount: 1n, reason };
        assert.deepEqual(await adapter.decode(wire(1n, reason)), response);
        assert.deepEqual(assess(base(), response), rejected());
        const r = rig(); await r.host.begin(base());
        assert.deepEqual(await r.host.chunk(base(), wire(1n, reason), true), rejected());
        assert.deepEqual(r.effects, []);
      });
    }
    await fixture("stream-cap-before-completion", async () => {
      const r = rig(), c = base(); await r.host.begin(c);
      assert.equal(await r.host.chunk(c, bytes(" ".repeat(4096)), false), null);
      assert.deepEqual(await r.host.chunk(c, bytes(" "), false), rejected());
      assert.deepEqual(await r.host.chunk(c, wire(1n, reasons[0]), true), rejected());
      assert.deepEqual(r.effects, []);
    });
    await fixture("inflight-repeat-and-context-conflict", async () => {
      const r = rig(), c = base(); await r.host.begin(c);
      assert.equal(await r.host.begin({ ...c }), null);
      assert.deepEqual(await r.host.begin({ ...c, remaining: 59n }), rejected());
      const response: Response = { kind: "Candidate", amount: 60n, reason: reasons[0] };
      const outcome = expected(c, response);
      assert.deepEqual(await r.host.chunk(c, wire(60n, reasons[0]), true), outcome);
      assert.deepEqual(await r.host.begin({ ...c }), outcome);
      assert.deepEqual(r.effects, outcome.plan);
    });
    const amountArb = fc.oneof(fc.bigInt({ min: -(1n << 128n), max: 1n << 128n }),
      fc.constantFrom(-1n, 0n, 1n, 60n, MAX - 1n, MAX, MAX + 1n));
    const reasonArb = fc.oneof(fc.constantFrom(...reasons), fc.string({ maxLength: 80 }));
    const responseArb: fc.Arbitrary<Response> = fc.oneof(
      fc.record({ kind: fc.constant("Candidate" as const), amount: amountArb, reason: reasonArb }),
      fc.constantFrom(...errors).map(kind => ({ kind })));
    const contextArb = fc.oneof(fc.constant(base()), fc.record({
      chargeId: fc.string({ maxLength: 16 }), requestId: fc.string({ maxLength: 16 }),
      original: amountArb, remaining: amountArb, refundEnabled: fc.boolean(), requestOpen: fc.boolean(),
    }));
    const properties: Record<"T1" | "T2" | "T3", fc.IAsyncProperty<any[]>> = {
      T1: fc.asyncProperty(fc.bigInt({ min: 0n, max: MAX }), reasonArb,
        fc.integer({ min: 0, max: badWire.length - 1 }), async (amount, reason, bad) => {
          assert.deepEqual(await adapter.decode(wire(amount, reason)), { kind: "Candidate", amount, reason });
          unavailable(await adapter.decode(badWire[bad]));
        }),
      T2: fc.asyncProperty(contextArb, responseArb, async (c, r) => {
        const before = structuredClone({ c, r });
        assert.deepEqual(assess(c, r), expected(c, r));
        assert.deepEqual({ c, r }, before);
      }),
      T3: fc.asyncProperty(fc.integer({ min: 0, max: 4 }), fc.bigInt({ min: 0n, max: 61n }),
        reasonArb, fc.integer({ min: 0, max: 20 }), async (mode, amount, reason, split) => {
          const r = rig(), c = base(), raw = wire(amount, reason);
          const response: Response = { kind: "Candidate", amount, reason };
          assert.equal(await r.host.begin(c), null);
          assert.equal(await r.host.chunk(c, raw.slice(0, split), false), null);
          let outcome: Outcome;
          if (mode === 0) {
            r.at(5099); outcome = expected(c, response);
            assert.deepEqual(await r.host.chunk(c, raw.slice(split), true), outcome);
          } else if (mode === 1 || mode === 2) {
            r.at(mode === 1 ? 5100 : 9000); outcome = rejected();
            assert.deepEqual(await r.host.chunk(c, raw.slice(split), true), outcome);
          } else if (mode === 3) {
            r.at(5100); outcome = rejected(); assert.deepEqual(await r.host.tick(c), outcome);
          } else {
            outcome = rejected(); assert.deepEqual(await r.host.fail(c), outcome);
          }
          assert.deepEqual(r.effects, outcome.plan);
          const calls = r.checks.length;
          assert.deepEqual(await r.host.begin({ ...c }), outcome);
          assert.deepEqual(await r.host.chunk(c, wire(1n, reasons[0]), true), outcome);
          assert.deepEqual(await r.host.begin({ ...c, original: 101n }), rejected());
          assert.deepEqual(r.effects, outcome.plan);
          assert.equal(r.checks.length, calls, "late or duplicate request reentered boundary");
          const next = { ...c, requestId: "request-2" };
          assert.equal(await r.host.begin(next), null);
          const nextOutcome = expected(next, { kind: "Candidate", amount: 1n, reason: reasons[0] });
          assert.deepEqual(await r.host.chunk(next, wire(1n, reasons[0]), true), nextOutcome);
          assert.deepEqual(r.effects, [...outcome.plan, ...nextOutcome.plan]);
        }),
    };
    for (const claim_id of ["T1", "T2", "T3"] as const) for (const seed of [8001, 8002, 8003]) {
      const result = await fc.check(properties[claim_id], { seed, numRuns: 1000, endOnFailure: false });
      report.runs.push({ claim_id, seed: result.seed, num_runs: result.numRuns, failed: result.failed });
      report.generated_cases += result.numRuns;
      if (result.failed) {
        report.failure = { claim_id, seed: result.seed, counterexample: result.counterexample,
          counterexample_path: result.counterexamplePath, num_shrinks: result.numShrinks,
          error: String(result.errorInstance) };
        throw new Error("property assertion failed: " + claim_id);
      }
      save();
    }
    report.result = "passed";
    save();
    console.log("PROPERTY_TESTED: 9000 generated cases; " + report.fixture_cases + " concrete fixtures; model quality unmeasured");
  } catch (error) {
    report.result = "failed";
    report.error = String(error);
    save();
    throw error;
  }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
