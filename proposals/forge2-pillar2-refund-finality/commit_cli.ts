// One commit attempt in a separate operating-system process (for the concurrency controls).
import { readFileSync } from "node:fs";
import { Sink } from "./sink";
const [dbPath, cfgPath, claimPath] = process.argv.slice(2);
const job = JSON.parse(readFileSync(claimPath, "utf8"));
const sink = new Sink(dbPath, JSON.parse(readFileSync(cfgPath, "utf8")));
process.stdout.write(JSON.stringify(sink.commit(job.claim, job.sig)) + "\n");
sink.close();
