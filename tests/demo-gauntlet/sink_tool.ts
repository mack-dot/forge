// Wave Gate 3 (demo): a small command-line door to the REAL Slice 1 sink (ts/refund-finality/sink.ts)
// for scripts/demo_gauntlet.py. NOT proved. It holds no rule and makes no decision: `init` stores the
// first state once, `report` prints what the sink's own functions return.
//   sink_tool.ts init   <database> <sink config json> <state json>
//   sink_tool.ts report <database> <sink config json>
import { readFileSync } from "node:fs";
import { Sink } from "../../ts/refund-finality/sink";

const [command, dbPath, cfgPath, stateJson] = process.argv.slice(2);
if ((command !== "init" && command !== "report") || !dbPath || !cfgPath || (command === "init") !== (stateJson !== undefined)) {
  process.stderr.write("usage: sink_tool.ts init <database> <config> <state json> | report <database> <config>\n");
  process.exit(2);
}
const cfg = JSON.parse(readFileSync(cfgPath, "utf8"));
// h-dispatch (C-HOST-06): the initial charge (THE ANCHOR) comes from the config only, never from the command line. A
// config without initialState is refused; on init, the argument must equal it (the sink's init checks that too).
if (cfg === null || typeof cfg !== "object" || cfg.initialState === undefined) {
  process.stderr.write("sink_tool: the config has no initialState; the anchor is never taken from the command line\n");
  process.exit(2);
}
const sink = new Sink(dbPath, cfg);
if (command === "init") sink.init(JSON.parse(stateJson));
process.stdout.write(JSON.stringify({
  state: JSON.parse(sink.stateBlob()),
  settled: sink.settled().map(row => row.request_id),
  outbox: sink.outbox().map(row => ({ requestId: row.request_id, intent: JSON.parse(row.intent) })),
  audit: sink.audit(),
}) + "\n");
sink.close();
