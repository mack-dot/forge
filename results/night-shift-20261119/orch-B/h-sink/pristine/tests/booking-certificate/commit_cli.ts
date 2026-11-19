// One commit attempt in a separate operating-system process (for the race control of suite.ts).
// The process opens the database and reads the token text first. Then it waits for the common start
// time, so that all processes of one race call commit in the same millisecond.
import { readFileSync } from "node:fs";
import { Sink } from "../../ts/booking-certificate/sink";

const [dbPath, cfgPath, tokenPath, startAt] = process.argv.slice(2);
const sink = new Sink(dbPath, JSON.parse(readFileSync(cfgPath, "utf8")));
const text = readFileSync(tokenPath, "utf8");
const onTime = Date.now() < Number(startAt);
while (Date.now() < Number(startAt)) { /* wait for the common start time */ }
const result = sink.commit(text);
process.stdout.write(JSON.stringify({ ...result, onTime }) + "\n");
sink.close();
