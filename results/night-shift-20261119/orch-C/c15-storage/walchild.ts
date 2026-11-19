// Child: on the attacker's OWN copy, switch to WAL, disable checkpoints, make the edit, then SIGKILL itself (leaves <copy>-wal).
import { DatabaseSync } from "node:sqlite";
const [path] = process.argv.slice(2);
const w = new DatabaseSync(path);
w.exec("PRAGMA journal_mode=WAL"); w.exec("PRAGMA wal_autocheckpoint=0");
w.exec("BEGIN");
w.prepare("UPDATE settled SET request_id = ? WHERE request_id = ?").run("r3\u0000x", "r3");
w.prepare("UPDATE outbox SET request_id = ? WHERE request_id = ?").run("r3\u0000x", "r3");
w.exec("PRAGMA user_version = 77");
w.exec("COMMIT");
process.kill(process.pid, "SIGKILL");
