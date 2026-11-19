// a5_child.ts <root> <db> <ledger> <dcfg> <effects> <name> <startAt>: a dispatcher run WITHOUT the shared lock (its lock
// file is private to this process: models "the lock was removed" for every run), started at a common instant.
import { appendFileSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { hostname } from "node:os";
import { join } from "node:path";
const [root, db, ledger, dcfg, effects, name, startAt] = process.argv.slice(2);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Dispatcher } = require(join(root, "ts/refund-finality/dispatcher.ts"));
const d = new Dispatcher(db, ledger, JSON.parse(readFileSync(dcfg, "utf8")), (e: any) => { appendFileSync(effects, JSON.stringify({ by: name, requestId: e.requestId, intent: e.intent }) + "\n"); });
d.acquire = function () { appendFileSync(ledger, ""); this.lockPath = realpathSync(ledger) + ".lock." + process.pid; writeFileSync(this.lockPath, JSON.stringify({ pid: process.pid, run: this.run, host: hostname() })); };
while (Date.now() < Number(startAt)) { /* barrier */ }
let out: any;
try { const r = d.flush(); out = { name, emitted: r.emitted.length, refused: r.refused.length }; } catch (e) { out = { name, stopped: String((e as Error).message).slice(0, 90) }; }
process.stdout.write(JSON.stringify(out) + "\n");
