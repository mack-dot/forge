// Z5 harness helper (NOT repository code). Loads the REPOSITORY sink.ts unchanged (by tsx, from source)
// and does one operation on one store.
//   sinkctl init    <db> <cfg> <state json>   : Sink.init, prints the stored blob
//   sinkctl state   <db> <cfg>                : prints the stored blob (one line)
//   sinkctl commit  <db> <cfg> <token file>   : Sink.commit(text of the file), prints the CommitResult
//   sinkctl inspect <db> <cfg>                : state, settled rows, outbox rows, audit
import { readFileSync, writeSync } from "node:fs";
import { Sink } from "<HOME>/forge/ts/refund-finality/sink.ts";

const [op, dbPath, cfgPath, arg] = process.argv.slice(2);
const sink = new Sink(dbPath, JSON.parse(readFileSync(cfgPath, "utf8")));
const out = (v: unknown) => writeSync(1, JSON.stringify(v) + "\n");
if (op === "init") { sink.init(JSON.parse(arg)); out(sink.stateBlob()); }
else if (op === "state") out(sink.stateBlob());
else if (op === "commit") out(sink.commit(readFileSync(arg, "utf8")));
else if (op === "inspect") {
  out({
    state: sink.storedBlob() ?? null,
    settled: sink.settled().map(r => ({ seq: r.seq, request_id: r.request_id, token_sha256: r.token_sha256,
      amount: JSON.parse(r.token).body.intent.amount })),
    outbox: sink.outbox().map(r => ({ seq: r.seq, request_id: r.request_id, intent: r.intent })),
    audit: sink.storedBlob() === undefined ? ["no stored state"] : sink.audit(),
  });
} else { process.stderr.write("unknown op\n"); process.exit(2); }
sink.close();
