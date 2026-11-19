// c_child.ts <treeRoot> <db> <ledger> <dcfg json> <effects> <name> <ctl> <hooks>
// One dispatcher run in its own process. emit = append {by,requestId,intent} to <effects>.
// hooks (comma list), each pauses DETERMINISTICALLY: writes <ctl>/<name>-<hook>-at, waits for <ctl>/<name>-<hook>-go.
//   preclaim:<rid>  before the ledger write of this run's intent line for <rid> (after its lock check passed)
//   emit:<rid>      inside emit(<rid>), after the effect line is written (a slow payment call)
//   prerelease      before unlinkSync of the lock file in release() (after its owner check passed)
//   kill:<rid>      inside emit(<rid>), after the effect line: SIGKILL self (crash after the effect)
//   throw:<rid>     emit(<rid>) throws before writing anything (nothing sent)
import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const fs = require("node:fs");
const [root, db, ledger, dcfg, effects, name, ctl, hooksArg] = process.argv.slice(2);
const hooks = (hooksArg ?? "").split(",").filter(Boolean);
const pause = new Int32Array(new SharedArrayBuffer(4));
const hold = (h: string) => {
  writeFileSync(join(ctl, `${name}-${h}-at`), String(process.pid));
  const t0 = Date.now();
  while (!existsSync(join(ctl, `${name}-${h}-go`))) { if (Date.now() - t0 > 60000) throw new Error("go timeout " + h); Atomics.wait(pause, 0, 0, 5); }
};
const origWrite = fs.writeSync, origUnlink = fs.unlinkSync;
fs.writeSync = function (fd: number, data: any, ...rest: any[]) {
  const s = typeof data === "string" ? data : Buffer.isBuffer(data) ? data.toString("utf8") : "";
  for (const h of hooks) if (h.startsWith("preclaim:")) {
    const rid = h.slice(9);
    if (s.includes('"kind":"intent"') && s.includes('"requestId":' + JSON.stringify(rid) + ",")) { hooks.splice(hooks.indexOf(h), 1); hold(h.replace(":", "_")); break; }
  }
  return origWrite.call(fs, fd, data, ...rest);
};
fs.unlinkSync = function (p: string, ...rest: any[]) {
  if (String(p).endsWith(".lock") && hooks.includes("prerelease")) { hooks.splice(hooks.indexOf("prerelease"), 1); hold("prerelease"); }
  return origUnlink.call(fs, p, ...rest);
};
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Dispatcher } = require(join(root, "ts/refund-finality/dispatcher.ts"));
const d = new Dispatcher(db, ledger, JSON.parse(readFileSync(dcfg, "utf8")), (e: { requestId: string; intent: string }) => {
  if (hooks.includes("throw:" + e.requestId)) throw new Error("adapter refused (nothing sent)");
  appendFileSync(effects, JSON.stringify({ by: name, ...e }) + "\n");
  if (hooks.includes("kill:" + e.requestId)) process.kill(process.pid, "SIGKILL");
  if (hooks.includes("emit:" + e.requestId)) hold("emit_" + e.requestId);
});
let out: any;
try { const r = d.flush(); out = { name, pid: process.pid, emitted: r.emitted.map((x: any) => x.requestId), refused: r.refused.map((x: any) => x.requestId + ":" + x.reason.slice(0, 40)), inDoubt: r.inDoubt, took: r.staleLockTakenOver ?? null }; }
catch (err) { out = { name, pid: process.pid, stopped: String((err as Error).message).slice(0, 160) }; }
process.stdout.write(JSON.stringify(out) + "\n");
