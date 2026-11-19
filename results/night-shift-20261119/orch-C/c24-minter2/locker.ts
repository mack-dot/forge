// helper: hold an EXCLUSIVE lock on a SQLite file for <ms> milliseconds, then roll back. Usage: locker.ts <db> <ms>
import { DatabaseSync } from "node:sqlite";
const [p, ms] = process.argv.slice(2);
const db = new DatabaseSync(p); db.exec("PRAGMA busy_timeout = 10000"); db.exec("BEGIN EXCLUSIVE");
process.stdout.write("locked\n");
setTimeout(() => { db.exec("ROLLBACK"); db.close(); process.stdout.write("released\n"); }, Number(ms));
