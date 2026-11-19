// CONTROL (h-specdiff): a reject-all stand-in sink. Same tables as sink.ts. It never commits. It must violate P5.
import { DatabaseSync } from "node:sqlite";
const DDL = `CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL);
  CREATE TABLE IF NOT EXISTS settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL, token TEXT NOT NULL, token_sha256 TEXT NOT NULL);
  CREATE TABLE IF NOT EXISTS outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL, intent TEXT NOT NULL);`;
const canon = (v: any): string => typeof v === "string" ? JSON.stringify(v) : typeof v === "boolean" ? String(v)
  : "{" + Object.keys(v).sort().map(k => JSON.stringify(k) + ":" + canon(v[k])).join(",") + "}";
export class Sink {
  private db: DatabaseSync;
  constructor(path: string, _cfg: unknown) { this.db = new DatabaseSync(path); this.db.exec(DDL); }
  init(s: unknown): void { this.db.prepare("INSERT OR IGNORE INTO state(id, blob) VALUES (1, ?)").run(canon(s)); }
  commit(_t: unknown) { return { status: "rejected", reason: "reject-all control" }; }
  close(): void { this.db.close(); }
}
