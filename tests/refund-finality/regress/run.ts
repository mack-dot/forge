// Runner of the refund-finality regressions (tasks h-regress and h-judges, night shift 2026-11-19). A TEST, not a proof.
// Usage (pinned Node 24.3.0; cwd = a tree with node_modules):
//   node --import tsx tests/refund-finality/regress/run.ts <sinkModulePath> <dispatcherModulePath> [expectedHeadMode]
//     [--expect-fail <id,id,...>] [--only <id,id,...>]
// expectedHeadMode: "none" (default) or the path of an anchor adapter module (harness.ts, AnchorAdapter).
// PROCESS MODEL: this process is the JUDGE (parent). It never loads the modules under test. Each regression starts
// its own child process (worker.ts) that loads them by path; the parent sends operations, reads the database and
// ledger files itself, and decides. Child output is never forwarded as a verdict line; a child that exits, is
// killed or stops answering makes that regression FAIL. The parent prints exactly one verdict line per expected id:
//   PASS | KNOWN-LIMIT | FAIL <id>: <reason>
// and checks at the end that every expected id has exactly one verdict.
// Exit codes: 0 when every id is PASS or KNOWN-LIMIT and the count matches; with --expect-fail: 0 when exactly the
// listed ids FAIL and every other id is PASS or KNOWN-LIMIT; 1 otherwise; 2 on a usage error.
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { controls } from "./controls";
import { Harness, Outcome, Regression, TRUSTED_ENCODING_PATH, fail } from "./harness";
import { Remote } from "./remote";
import { judges } from "./k_judge_blindspots";
import { regression as x1 } from "./x1_reqid_mismatch_duplicate";
import { regression as x2, regressionB as x2b } from "./x2_cross_charge_duplicate";
import { regression as x3 } from "./x3_upgrade_legacy_gap_duplicate";
import { regression as x4 } from "./x4_signed_unauthorized_commits";
import { regressionA as x5a, regressionB as x5b } from "./x5_hostile_writer_store";
import { regressionP1 as x6p1, regressionZ1 as x6z1 } from "./x6_zero_row_and_prefix_rollback";

export const ALL: Regression[] = [...controls, x1, x2, x2b, x3, x4, x5a, x5b, x6z1, x6p1, ...judges];
const PER_REGRESSION_MS = 120000;

export function word(r: Regression, o: Outcome): "PASS" | "KNOWN-LIMIT" | "FAIL" {
  if (!o.ok) return "FAIL";
  return r.kind === "limit" && o.limit === true ? "KNOWN-LIMIT" : "PASS";
}
const flat = (s: string) => s.replace(/[\r\n]+/g, " ");
const sha = (p: string) => createHash("sha256").update(readFileSync(p)).digest("hex");

// After the regression, every child is stopped and the effect channel is checked (remote.ts): a record outside a
// flush, a line that is not a record, or a channel held open after the child died makes the regression FAIL, whatever
// its own outcome was (an effect that the regression did not see is still an effect).
async function runOne(r: Regression, sink: string, disp: string, anchor: string | null): Promise<Outcome> {
  const h = new Harness(sink, disp, anchor);
  let timer: NodeJS.Timeout | undefined;
  let o: Outcome;
  try {
    await h.begin(r.id);
    const timeout = new Promise<Outcome>(res => { timer = setTimeout(() => { h.remote.kill(); res(fail(`regression timed out after ${PER_REGRESSION_MS} ms`)); }, PER_REGRESSION_MS); });
    o = await Promise.race([r.run(h), timeout]);
  } catch (e) {
    const tail = h.remote ? flat(h.remote.outputTail(160)) : "";
    o = fail("regression threw: " + flat(String((e as Error)?.message ?? e)).slice(0, 160) + (tail ? " | child output: " + tail : ""));
  } finally { if (timer) clearTimeout(timer); await h.end(); }
  if (h.channelProblems.length > 0) return fail("EFFECT CHANNEL: " + h.channelProblems.slice(0, 3).join("; ") + " | regression: " + o.reason);
  return o;
}

async function main(argv: string[]): Promise<number> {
  const args = argv.slice(2);
  const take = (flag: string): string[] | null => {
    const i = args.indexOf(flag); if (i < 0) return null;
    const v = args[i + 1]; args.splice(i, 2);
    return v === undefined ? ["\u0000bad"] : v.split(",").map(s => s.trim()).filter(s => s.length > 0);
  };
  const expectFail = take("--expect-fail"), only = take("--only");
  if (args.length < 2 || args.length > 3) {
    console.error("usage: run.ts <sinkModulePath> <dispatcherModulePath> [expectedHeadMode] [--expect-fail <ids>] [--only <ids>]");
    return 2;
  }
  const ids = new Set(ALL.map(r => r.id));
  for (const x of [...(expectFail ?? []), ...(only ?? [])]) if (!ids.has(x)) { console.error("unknown regression id: " + JSON.stringify(x)); return 2; }
  const sink = resolve(args[0]), disp = resolve(args[1]);
  const mode = args[2] ?? "none";
  for (const p of [sink, disp, ...(mode === "none" ? [] : [mode])]) if (!existsSync(p)) { console.error("no such file: " + p); return 2; }
  const list = only ? ALL.filter(r => only.includes(r.id)) : ALL;
  console.log(`# judge=${__filename}\n# sink=${sink} sha256=${sha(sink)}\n# dispatcher=${disp} sha256=${sha(disp)}`);
  console.log(`# trusted encoding=${TRUSTED_ENCODING_PATH} sha256=${sha(TRUSTED_ENCODING_PATH)}`);
  // The module graph that the code under test ACTUALLY loads (reported by a probe child; hashed HERE).
  { const probe = new Remote(sink, disp);
    try { await probe.ready; const c = await probe.call<{ graph: string[]; encodingModules: string[] }>("hello");
      for (const p of c.graph) console.log(`# loaded ${c.encodingModules.includes(p) ? "ENCODING " : ""}${p} sha256=${existsSync(p) ? sha(p) : "missing"}`);
    } catch (e) { console.log("# module graph: probe child failed: " + flat(String((e as Error).message))); }
    finally { await probe.stop(); } }
  console.log(`# expectedHeadMode=${mode} node=${process.version} expected ids=${list.length} expect-fail=${expectFail ? expectFail.join(",") : "-"}`);
  const verdicts = new Map<string, string[]>();
  for (const r of list) {
    const o = await runOne(r, sink, disp, mode === "none" ? null : resolve(mode));
    const w = word(r, o);
    verdicts.set(r.id, [...(verdicts.get(r.id) ?? []), w]);
    console.log(`${w} ${r.id}: ${flat(o.reason)}`);
  }
  // Count check: every expected id exactly one verdict.
  const missing = list.filter(r => (verdicts.get(r.id) ?? []).length !== 1).map(r => r.id);
  const failed = list.filter(r => verdicts.get(r.id)?.[0] === "FAIL").map(r => r.id);
  const limits = list.filter(r => verdicts.get(r.id)?.[0] === "KNOWN-LIMIT").map(r => r.id);
  const want = new Set(expectFail ?? []);
  const unexpectedFail = failed.filter(x => !want.has(x)), unexpectedPass = [...want].filter(x => !failed.includes(x));
  const ok = missing.length === 0 && unexpectedFail.length === 0 && unexpectedPass.length === 0;
  console.log(`# verdicts=${verdicts.size}/${list.length} PASS=${list.length - failed.length - limits.length} KNOWN-LIMIT=${limits.length} FAIL=${failed.length} [${failed.join(",")}]`);
  console.log(`# unexpected FAIL=[${unexpectedFail.join(",")}] unexpected non-FAIL (listed in --expect-fail)=[${unexpectedPass.join(",")}] missing verdicts=[${missing.join(",")}]`);
  console.log(`# JUDGE RESULT ${ok ? "OK" : "NOT OK"} (exit ${ok ? 0 : 1})`);
  return ok ? 0 : 1;
}
if (require.main === module) {
  main(process.argv).then(code => process.exit(code), e => { console.error("judge error: " + String((e as Error)?.stack ?? e)); process.exit(1); });
}
