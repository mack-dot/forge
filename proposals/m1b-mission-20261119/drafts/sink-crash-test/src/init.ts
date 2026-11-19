// Y6 harness (NOT repository code): stores the first state once with the real sink's init.
import { readFileSync, writeSync } from "node:fs";
const [sinkPath, dbPath, cfgPath, stateJson] = process.argv.slice(2);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Sink } = require(sinkPath);
const sink = new Sink(dbPath, JSON.parse(readFileSync(cfgPath, "utf8")));
sink.init(JSON.parse(stateJson));
writeSync(1, sink.stateBlob() + "\n");
sink.close();
