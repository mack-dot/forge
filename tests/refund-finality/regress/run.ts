// Runner of the refund-finality regressions (night shift 2026-11-19, task h-regress). A TEST, not a proof.
// Usage (from the repository root, pinned Node 24.3.0):
//   node --import tsx tests/refund-finality/regress/run.ts <sinkModulePath> <dispatcherModulePath> [expectedHeadMode]
//     [--encoding <encoding.ts>]
// expectedHeadMode: "none" (default) or the path of an anchor adapter module (see harness.ts, AnchorAdapter).
// The encoding module defaults to encoding.ts next to the sink module.
// Prints one line per regression `PASS|FAIL id: reason`; exit 0 only if every line is PASS; exit 2 on a usage error.
// Every regression runs in a fresh directory under the system temp directory; the directories are removed at exit.
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { controls } from "./controls";
import { Harness, Regression, runAll } from "./harness";
import { regression as x1 } from "./x1_reqid_mismatch_duplicate";
import { regression as x2, regressionB as x2b } from "./x2_cross_charge_duplicate";
import { regression as x3 } from "./x3_upgrade_legacy_gap_duplicate";
import { regression as x4 } from "./x4_signed_unauthorized_commits";
import { regressionA as x5a, regressionB as x5b } from "./x5_hostile_writer_store";
import { regressionP1 as x6p1, regressionZ1 as x6z1 } from "./x6_zero_row_and_prefix_rollback";

export const ALL: Regression[] = [...controls, x1, x2, x2b, x3, x4, x5a, x5b, x6z1, x6p1];

function main(argv: string[]): number {
  const args = argv.slice(2);
  let encoding: string | null = null;
  const i = args.indexOf("--encoding");
  if (i >= 0) { encoding = args[i + 1] ?? null; args.splice(i, 2); }
  if (args.length < 2 || args.length > 3 || (i >= 0 && encoding === null)) {
    console.error("usage: run.ts <sinkModulePath> <dispatcherModulePath> [expectedHeadMode] [--encoding <path>]");
    return 2;
  }
  const sink = resolve(args[0]), disp = resolve(args[1]);
  const mode = args[2] ?? "none";
  const enc = resolve(encoding ?? join(dirname(sink), "encoding.ts"));
  for (const p of [sink, disp, enc, ...(mode === "none" ? [] : [mode])]) if (!existsSync(p)) { console.error("no such file: " + p); return 2; }
  console.log(`# sink=${sink}\n# dispatcher=${disp}\n# encoding=${enc}\n# expectedHeadMode=${mode} node=${process.version}`);
  const h = new Harness(sink, disp, enc, mode === "none" ? null : resolve(mode));
  const fails = runAll(h, ALL);
  console.log(`# ${ALL.length - fails} not failed (PASS or KNOWN-LIMIT; a KNOWN-LIMIT line is an unsafe outcome that is a stated limit), ${fails} FAIL`);
  return fails === 0 ? 0 : 1;
}
if (require.main === module) process.exitCode = main(process.argv);
