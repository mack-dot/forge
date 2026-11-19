// child: one Dispatcher.flush() on db argv[2], ledger path argv[3] (as given), cfg argv[4]; emit sleeps argv[5] ms
// (a slow external call) and prints "emit <rid>"; prints "end <json>" or "error <msg>".
import { Dispatcher } from "./lib";
const [db, ledger, cfgFile, ms] = process.argv.slice(2);
const cfg = JSON.parse(require("node:fs").readFileSync(cfgFile, "utf8"));
const sleep = (t: number) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, t);
try {
  const r = new Dispatcher(db, ledger, cfg, (e: any) => { process.stdout.write("emit " + e.requestId + "\n"); sleep(Number(ms)); }).flush();
  process.stdout.write("end " + JSON.stringify({ emitted: r.emitted.length, refused: r.refused.length }) + "\n");
} catch (e) { process.stdout.write("error " + String((e as Error).message) + "\n"); }
