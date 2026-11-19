// One dispatcher run in a separate operating-system process (for the overlap control of suite.ts).
// Each outbound effect is one appended line in the effects file. The effect takes some time, so that
// runs with a common start time overlap.
import { appendFileSync, readFileSync } from "node:fs";
import { Dispatcher } from "../../ts/refund-finality/dispatcher";

const [dbPath, ledgerPath, cfgPath, effectsPath, startAt] = process.argv.slice(2);
const slow = new Int32Array(new SharedArrayBuffer(4));
const dispatcher = new Dispatcher(dbPath, ledgerPath, JSON.parse(readFileSync(cfgPath, "utf8")), effect => {
  appendFileSync(effectsPath, JSON.stringify(effect) + "\n");
  Atomics.wait(slow, 0, 0, 150);
});
const onTime = Date.now() < Number(startAt);
while (Date.now() < Number(startAt)) { /* wait for the common start time */ }
let answer: Record<string, unknown>;
try { answer = { emitted: dispatcher.flush().emitted.length, onTime }; } catch (error) { answer = { stopped: String((error as Error).message), onTime }; }
process.stdout.write(JSON.stringify(answer) + "\n");
