// h-regress stand-in (evidence only, NOT on the branch): a sink that rejects every token. It creates the merged
// schema and stores the initial state, so every read of the regressions works. Used to show that the positive
// controls of run.ts FAIL on a reject-all sink.
import { DatabaseSync } from "node:sqlite";
const DDL = `CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT NOT NULL);
  CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL);
  CREATE TABLE IF NOT EXISTS settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE, token TEXT NOT NULL, token_sha256 TEXT NOT NULL);
  CREATE TABLE IF NOT EXISTS outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE, intent TEXT NOT NULL);`;
const canon = (v: any): string => typeof v === "string" ? JSON.stringify(v) : typeof v === "boolean" ? String(v)
  : "{" + Object.keys(v).sort().map(k => JSON.stringify(k) + ":" + canon(v[k])).join(",") + "}";
export class Sink {
  private db: DatabaseSync;
  constructor(path: string, _cfg: unknown) { this.db = new DatabaseSync(path); this.db.exec(DDL); }
  init(state: any): void { this.db.prepare("INSERT OR IGNORE INTO state(id, blob) VALUES (1, ?)").run(canon(state)); }
  commit(_input: unknown) { return { status: "rejected", reason: "reject-all stand-in" }; }
  outbox() { return []; }
  settled() { return []; }
  audit(): string[] { return []; }
  close(): void { this.db.close(); }
}
