// c21 dispatcher child: one flush() (or resolveInDoubt) of the target Dispatcher with a CONTROLLED emit.
// emit(rid): if <ctl>/block-<name>-<rid> exists: create <ctl>/at-<name>-<rid>, wait for <ctl>/go-<name>-<rid>; then if
// <ctl>/throw-<name>-<rid> exists throw BEFORE the effect; else append {by, rid, amount} to <work>/effects.jsonl (fsync).
// Usage: dchild.ts <work> <name> [resolve <rid> <sent|retry>]. Prints one JSON line.
import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { Dispatcher } from "./lib";
const [work, name, op, rid, outc] = process.argv.slice(2);
const ctl = join(work, "ctl"), dcfg = JSON.parse(readFileSync(join(work, "dcfg.json"), "utf8"));
const sleep = (ms: number) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
const emit = (e: any) => {
  const b = join(ctl, "block-" + name + "-" + e.requestId);
  if (existsSync(b)) { writeFileSync(join(ctl, "at-" + name + "-" + e.requestId), ""); while (!existsSync(join(ctl, "go-" + name + "-" + e.requestId))) sleep(20); }
  if (existsSync(join(ctl, "throw-" + name + "-" + e.requestId))) throw new Error("payment call failed before sending");
  appendFileSync(join(work, "effects.jsonl"), JSON.stringify({ by: name, rid: e.requestId, amount: JSON.parse(e.intent).amount }) + "\n");
};
const d = new Dispatcher(join(work, "sink.sqlite"), join(work, "ledger.jsonl"), dcfg, emit);
try {
  if (op === "resolve") { d.resolveInDoubt(rid, outc as any, "operator"); console.log(JSON.stringify({ name, resolved: rid })); }
  else { const f = d.flush(); console.log(JSON.stringify({ name, emitted: f.emitted.map((x: any) => x.requestId), inDoubt: f.inDoubt, refused: f.refused.map((r: any) => r.requestId + ":" + r.reason.slice(0, 50)) })); }
} catch (e) { console.log(JSON.stringify({ name, error: String((e as Error).message).slice(0, 160) })); }
