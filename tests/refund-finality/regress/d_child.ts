// Helper process of d_att17_lock_theft.ts and d_host02_dead_lock_takeover.ts (not a regression by itself).
// One dispatcher run. emit = append one line to <effects>. For the effect of <blockRid>:
//   mode "block": write <ctl>/<name>-blocked, then wait for <ctl>/<name>-go (a slow payment call; no timing guess);
//   mode "die":   after the line is written, the process kills itself with SIGKILL (a crash after the effect).
// Usage: d_child.ts <treeRoot> <db> <ledger> <dcfg json file> <effects> <name> <blockRid> <ctl> <block|die>
import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [root, db, ledger, dcfg, effects, name, blockRid, ctl, mode] = process.argv.slice(2);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Dispatcher } = require(join(root, "ts/refund-finality/dispatcher.ts"));
const pause = new Int32Array(new SharedArrayBuffer(4));
const d = new Dispatcher(db, ledger, JSON.parse(readFileSync(dcfg, "utf8")), (e: { requestId: string; intent: string }) => {
  appendFileSync(effects, JSON.stringify({ by: name, ...e }) + "\n");
  if (e.requestId !== blockRid) return;
  if (mode === "die") process.kill(process.pid, "SIGKILL");
  writeFileSync(join(ctl, name + "-blocked"), "");
  const t0 = Date.now();
  while (!existsSync(join(ctl, name + "-go"))) { if (Date.now() - t0 > 60000) throw new Error("go timeout"); Atomics.wait(pause, 0, 0, 10); }
});
try { const r = d.flush(); process.stdout.write(JSON.stringify({ name, emitted: r.emitted.map((x: any) => x.requestId), refused: r.refused.map((x: any) => x.requestId) }) + "\n"); }
catch (err) { process.stdout.write(JSON.stringify({ name, stopped: String((err as Error).message) }) + "\n"); }
