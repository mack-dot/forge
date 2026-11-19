// Exercise the exact approved T2 callback. This is a finite assertion test,
// not a proof checker or a replacement for the real Stage 8 verifier runs.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { runInNewContext } from "node:vm";
import BigNumber from "bignumber.js";
import ts from "typescript";

const option = (name: string): string => {
  const i = process.argv.indexOf(name);
  if (i < 0 || !process.argv[i + 1]) throw new Error("missing " + name);
  return process.argv[i + 1];
};
const sha = (data: string | Buffer): string => createHash("sha256").update(data).digest("hex");

async function main() {
  const filename = "gate/refund/hostile.ts";
  const source = readFileSync(filename, "utf8");
  assert.equal(sha(source), "0e15d543f42c32b0b6c2b7aab7eb66962dc7c1facde380c44f00a8710a9c475a");
  const syntax = ts.createSourceFile(filename, source, ts.ScriptTarget.ES2022, true, ts.ScriptKind.TS);
  const fragments = new Map<string, string>();
  let callback: ts.ArrowFunction | undefined;
  function visit(node: ts.Node): void {
    if (ts.isFunctionDeclaration(node) && node.name && ["expected", "model"].includes(node.name.text)) {
      fragments.set(node.name.text, node.getText(syntax));
    }
    if (ts.isVariableDeclaration(node) && ts.isIdentifier(node.name) && ["MAX", "reasons", "rejected"].includes(node.name.text)) {
      fragments.set(node.name.text, "const " + node.getText(syntax) + ";");
    }
    if (ts.isPropertyAssignment(node) && node.name.getText(syntax) === "T2") {
      assert(ts.isCallExpression(node.initializer));
      assert.equal(node.initializer.expression.getText(syntax), "fc.asyncProperty");
      const last = node.initializer.arguments[node.initializer.arguments.length - 1];
      assert(ts.isArrowFunction(last)); assert.equal(callback, undefined); callback = last;
    }
    ts.forEachChild(node, visit);
  }
  visit(syntax);
  assert(callback); assert.equal(fragments.size, 5);
  const callbackSource = callback.getText(syntax);
  const extracted = [...["MAX", "reasons", "rejected", "expected", "model"].map(name => fragments.get(name)),
    "({ model, property: (assess) => (" + callbackSource + ") });"].join("\n");
  // Use the established TypeScript compiler and Node runtime. These fragments
  // come from the hash-bound approved test file; no assertion is reimplemented.
  const compiled = ts.transpileModule(extracted, { fileName: "snapshot-controls-extracted.ts",
    reportDiagnostics: true, compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS } });
  assert.equal(compiled.diagnostics?.filter(d => d.category === ts.DiagnosticCategory.Error).length, 0);
  const loaded = runInNewContext(compiled.outputText, { assert, BigNumber, require, resolve },
    { filename: "snapshot-controls-extracted.js" });
  const assess = loaded.model(option("--module"));
  const report: any = { method: "unit_tested", result: "running", stage8_exit: false, end_to_end: false,
    approved_test_sha256: sha(source), callback_sha256: sha(callbackSource),
    compiled_module_sha256: sha(readFileSync(option("--module"))),
    extraction: "TypeScript AST selects the exact T2 callback, expected oracle, compiled-model bridge and constants",
    injection: "Mutate the actual input after the real compiled model returns; require the snapshot assertion to reject",
    controls: [] };
  const save = () => writeFileSync(option("--report"), JSON.stringify(report, null, 2) + "\n");
  writeFileSync(option("--report") + ".extracted.ts", extracted);
  writeFileSync(option("--report") + ".extracted.js", compiled.outputText);
  save();
  const mutations: Record<string, (c: any, r: any) => void> = {
    "context-field": c => { c.original = -2n; },
    "response-field": (_c, r) => { r.amount = -2n; },
    "context-prototype": c => { Object.setPrototypeOf(c, Object.getPrototypeOf(c) === null ? Object.prototype : null); },
    "response-prototype": (_c, r) => { Object.setPrototypeOf(r, Object.getPrototypeOf(r) === null ? Object.prototype : null); },
  };
  try {
    for (const contextNull of [false, true]) for (const responseNull of [false, true]) {
      const inputs = () => ({
        c: Object.assign(Object.create(contextNull ? null : Object.prototype), {
          chargeId: "charge", requestId: "request", original: -1n, remaining: 0n, refundEnabled: false, requestOpen: false }),
        r: Object.assign(Object.create(responseNull ? null : Object.prototype), { kind: "Candidate", amount: -1n, reason: "" }),
      });
      const base = { context_prototype: contextNull ? "null" : "Object.prototype",
        response_prototype: responseNull ? "null" : "Object.prototype" };
      const stable = inputs(); await loaded.property(assess)(stable.c, stable.r);
      report.controls.push({ ...base, control: "unchanged-input", result: "accepted" }); save();
      for (const [name, mutate] of Object.entries(mutations)) {
        const input = inputs(); let failure: unknown;
        const property = loaded.property((c: any, r: any) => {
          const outcome = assess(c, r); mutate(c, r); return outcome;
        });
        try { await property(input.c, input.r); } catch (error) { failure = error; }
        assert(failure instanceof assert.AssertionError, name + " escaped the real assertion");
        // The value-oracle assertion has decision/plan objects. Only the exact
        // snapshot assertion has c/r objects. An earlier error is not success.
        assert(failure.actual !== null && typeof failure.actual === "object" && "c" in failure.actual && "r" in failure.actual);
        assert(failure.expected !== null && typeof failure.expected === "object" && "c" in failure.expected && "r" in failure.expected);
        report.controls.push({ ...base, control: name, result: "rejected", assertion_code: failure.code,
          raw_assertion: String(failure) }); save();
      }
    }
    report.result = "passed"; report.unchanged_accepted = 4; report.mutations_rejected = 16; save();
    console.log("SNAPSHOT_CONTROLS: 4 unchanged inputs accepted; 16 real field/prototype mutations rejected");
  } catch (error) { report.result = "failed"; report.error = String(error); save(); throw error; }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
