// helper: leave a HOT rollback journal next to a SQLite file: a write transaction that spills pages to the database
// file, then SIGKILL of this process before COMMIT (mechanically the same as a crash of a writer during a commit).
// Usage: crasher.ts <db>
import { DatabaseSync } from "node:sqlite";
const [p] = process.argv.slice(2);
const db = new DatabaseSync(p);
db.exec("PRAGMA journal_mode = DELETE; PRAGMA synchronous = FULL; PRAGMA cache_size = 2; BEGIN IMMEDIATE; CREATE TABLE junk(x);");
const ins = db.prepare("INSERT INTO junk VALUES (randomblob(3000))");
for (let i = 0; i < 200; i++) ins.run();
process.kill(process.pid, "SIGKILL");
