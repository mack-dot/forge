// One dispatcher run in its own process. emit = the external effect: append a line to effectsFile.
// If the effect's request id equals blockRid, the emit writes <ctl>/<name>-blocked and waits for <ctl>/<name>-go
// (a slow payment call; deterministic, no timing guess). Usage: dchild.ts db ledger dcfg effects name blockRid ctl
import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { ROOT } from "./common";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Dispatcher } = require(join(ROOT, "ts/refund-finality/dispatcher.ts"));
const [db, ledger, dcfg, effects, name, blockRid, ctl] = process.argv.slice(2);
const pause = new Int32Array(new SharedArrayBuffer(4));
const d = new Dispatcher(db, ledger, JSON.parse(readFileSync(dcfg, "utf8")), (e: any) => {
  appendFileSync(effects, JSON.stringify({ by: name, ...e }) + "\n");
  if (e.requestId === blockRid) {
    writeFileSync(join(ctl, name + "-blocked"), "");
    const t0 = Date.now();
    while (!existsSync(join(ctl, name + "-go"))) { if (Date.now() - t0 > 60000) throw new Error("go timeout"); Atomics.wait(pause, 0, 0, 10); }
  }
});
try { const r = d.flush(); process.stdout.write(JSON.stringify({ name, emitted: r.emitted.map((x: any) => x.requestId), refused: r.refused, already: r.alreadyDispatched }) + "\n"); }
catch (err) { process.stdout.write(JSON.stringify({ name, stopped: String((err as Error).message) }) + "\n"); }
