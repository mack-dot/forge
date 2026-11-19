// Supplemental runtime checks. These are finite observations, not source proof.
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
import BigNumber from "bignumber.js";
import fc from "fast-check";
import { createHost, decode, type Assess, type Context, type Intent, type Outcome } from "../ts/refund";

const MAX = 9223372036854775807n;
const base = (): Context => ({ chargeId: "charge", requestId: "request", original: 100n,
  remaining: 60n, refundEnabled: true, requestOpen: true });
const bytes = (s: string) => Buffer.from(s, "utf8");
const wire = (amount_minor = "40", reason = "duplicate_charge") => bytes(JSON.stringify({ amount_minor, reason }));
const rejected = (): Outcome => ({ decision: { kind: "Rejected" }, plan: [] });
const option = (name: string) => {
  const i = process.argv.indexOf(name);
  if (i < 0 || !process.argv[i + 1]) throw new Error("missing " + name);
  return process.argv[i + 1];
};

async function main() {
  const { Refund: R, runtime } = require(resolve(option("--module")));
  const str = (s: string) => runtime.Seq.UnicodeFromString(s);
  const num = (n: bigint) => new BigNumber(String(n));
  const int = (n: BigNumber) => { assert(n.isInteger()); return BigInt(n.toFixed()); };
  const assess: Assess = (c, r) => {
    const [d, p] = R.__default.Assess(R.Context.create_ChargeContext(str(c.chargeId), str(c.requestId),
      num(c.original), num(c.remaining), c.refundEnabled, c.requestOpen),
    r.kind === "Candidate" ? R.ModelResponse.create_Candidate(num(r.amount), str(r.reason)) : R.ModelResponse["create_" + r.kind]());
    return { decision: d.is_Authorized ? { kind: "Authorized", amount: int(d.dtor_amount), reason: d.dtor_reason.toVerbatimString(false) }
      : { kind: "Rejected" }, plan: Array.from(p, (i: any) => ({ chargeId: i.dtor_chargeId.toVerbatimString(false),
        requestId: i.dtor_requestId.toVerbatimString(false), amount: int(i.dtor_amount), reason: i.dtor_reason.toVerbatimString(false) })) };
  };
  const report: any = { result: "running", method: "property_tested", fixtures: [], runs: [],
    generated_cases: 0, model_quality: "unmeasured", end_to_end: false };
  const save = () => writeFileSync(option("--report"), JSON.stringify(report, (_k, v) => typeof v === "bigint" ? String(v) : v, 2) + "\n");
  const test = async (name: string, fn: () => void | Promise<void>) => {
    report.active_fixture = name; save(); await fn(); report.fixtures.push(name); delete report.active_fixture; save();
  };
  const rig = () => {
    let now = 0;
    const effects: Intent[] = [];
    const host = createHost({ assess, execute: i => effects.push({ ...i }), now: () => now });
    return { host, effects, at: (n: number) => { now = n; } };
  };
  try {
    for (const text of ["1\n", "0\r", "1\r\n", "1\u2028", "1\u2029", "\t1", "1\t"]) {
      await test("exact-numeric-string-" + JSON.stringify(text), async () => {
        assert.notEqual((await decode(wire(text))).kind, "Candidate");
      });
    }
    await test("valid-escaped-keys-and-json-whitespace", async () => {
      assert.deepEqual(await decode(bytes(' \r\n{"reason":"duplicate_charge","\\u0061mount_minor":"40"}\t ')),
        { kind: "Candidate", amount: 40n, reason: "duplicate_charge" });
    });
    await test("exact-byte-cap", async () => {
      const raw = wire(); const padded = bytes(raw.toString() + " ".repeat(4096 - raw.length));
      assert.equal(padded.length, 4096); assert.equal((await decode(padded)).kind, "Candidate");
      assert.notEqual((await decode(Buffer.concat([padded, bytes(" ")]))).kind, "Candidate");
    });
    await test("concurrent-terminal-calls-dispatch-once", async () => {
      const r = rig(), c = base(); await r.host.begin(c);
      const outcomes = await Promise.all([r.host.chunk(c, wire(), true), r.host.chunk(c, wire(), true),
        r.host.fail(c), r.host.begin({ ...c }), r.host.tick(c)]);
      for (const outcome of outcomes) assert.deepEqual(outcome, outcomes[0]);
      assert.equal(r.effects.length, 1); assert.equal(r.effects[0].amount, 40n);
    });
    await test("stale-completion-after-timeout", async () => {
      const r = rig(), c = base(); await r.host.begin(c); r.at(5000);
      assert.deepEqual(await r.host.tick(c), rejected());
      assert.deepEqual(await r.host.chunk(c, wire(), true), rejected());
      assert.deepEqual(await r.host.begin({ ...c }), rejected()); assert.equal(r.effects.length, 0);
      const next = { ...c, requestId: "next" }; await r.host.begin(next);
      assert.equal((await r.host.chunk(next, wire(), true))?.decision.kind, "Authorized");
      assert.equal(r.effects.length, 1); assert.equal(r.effects[0].requestId, "next");
    });
    await test("context-and-result-copies", async () => {
      const r = rig(), original = base(), caller = { ...original }; await r.host.begin(caller);
      caller.remaining = MAX;
      assert.deepEqual(await r.host.chunk(caller, wire(), true), rejected()); assert.equal(r.effects.length, 0);
      const outcome = await r.host.chunk(original, wire(), true); assert(outcome);
      const saved = structuredClone(outcome); outcome.plan.push({ ...r.effects[0], amount: MAX });
      if (outcome.decision.kind === "Authorized") outcome.decision.amount = MAX;
      assert.deepEqual(await r.host.begin(original), saved); assert.equal(r.effects.length, 1);
    });
    await test("executor-reentry-observes-terminal-state", async () => {
      const c = base(); let calls = 0; const reentries: Promise<Outcome | null>[] = [];
      const host = createHost({ assess, now: () => 0, execute: () => {
        calls++; reentries.push(host.begin(c), host.chunk(c, wire(), true), host.fail(c));
      } });
      await host.begin(c); const first = await host.chunk(c, wire(), true);
      for (const entry of await Promise.all(reentries)) assert.deepEqual(entry, first);
      assert.equal(calls, 1);
    });
    await test("executor-error-never-retries", async () => {
      let calls = 0; const c = base();
      const host = createHost({ assess, now: () => 0, execute: () => { calls++; throw new Error("recording executor fault"); } });
      await host.begin(c); const first = await host.chunk(c, wire(), true);
      assert.equal(first?.decision.kind, "Authorized");
      assert.deepEqual(await host.begin(c), first); assert.deepEqual(await host.chunk(c, wire(), true), first);
      assert.equal(calls, 1);
    });
    await test("empty-stream-chunks", async () => {
      const r = rig(), c = base(); await r.host.begin(c);
      for (let i = 0; i < 8000; i++) assert.equal(await r.host.chunk(c, new Uint8Array(), false), null);
      assert.equal((await r.host.chunk(c, wire(), true))?.decision.kind, "Authorized"); assert.equal(r.effects.length, 1);
    });
    for (const patch of [{ chargeId: "" }, { requestId: "" }, { original: -1n }, { original: MAX + 1n },
      { remaining: -1n }, { remaining: 101n }, { refundEnabled: false }, { requestOpen: false }]) {
      await test("invalid-context-" + JSON.stringify(patch, (_k, v) => typeof v === "bigint" ? String(v) : v), async () => {
        const r = rig(), c = { ...base(), ...patch }; await r.host.begin(c);
        assert.deepEqual(await r.host.chunk(c, wire(), true), rejected()); assert.equal(r.effects.length, 0);
      });
    }
    const property = fc.asyncProperty(fc.uint8Array({ maxLength: 5000 }), fc.integer({ min: 1, max: wire().length - 1 }),
      async (raw, cutoff) => {
        const parsed = await decode(raw); const result = assess(base(), parsed);
        if (result.decision.kind === "Authorized") {
          assert(result.decision.amount >= 0n && result.decision.amount <= 60n);
          assert(["duplicate_charge", "service_not_delivered", "returned_item"].includes(result.decision.reason));
        } else assert.deepEqual(result.plan, []);
        assert.notEqual((await decode(wire().subarray(0, cutoff))).kind, "Candidate");
      });
    for (const seed of [8004, 8005]) {
      const result = await fc.check(property, { seed, numRuns: 250 });
      report.runs.push({ seed, num_runs: result.numRuns, failed: result.failed }); report.generated_cases += result.numRuns;
      if (result.failed) {
        report.failure = { seed, counterexample: result.counterexample, path: result.counterexamplePath,
          shrinks: result.numShrinks, error: String(result.errorInstance) };
        throw new Error("supplemental property failed");
      }
    }
    report.result = "passed"; save(); console.log("SUPPLEMENTAL: " + report.fixtures.length + " fixtures; 500 generated cases");
  } catch (error) { report.result = "failed"; report.error = String(error); save(); throw error; }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
