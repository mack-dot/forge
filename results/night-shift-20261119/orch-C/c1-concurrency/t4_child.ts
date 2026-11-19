// child: open a Sink on argv[2], commit each token of the file argv[4] in order, print "ack <i> <status>" after each.
import { readFileSync } from "node:fs";
import { S0, Sink } from "./lib";
const ids = JSON.parse(process.argv[3]); const toks: string[] = JSON.parse(readFileSync(process.argv[4], "utf8"));
const sink = new Sink(process.argv[2], { ...ids, initialState: S0 });
process.stdout.write("go\n");
toks.forEach((t, i) => { const r = sink.commit(t); process.stdout.write(`ack ${i} ${r.status}\n`); });
sink.close();
