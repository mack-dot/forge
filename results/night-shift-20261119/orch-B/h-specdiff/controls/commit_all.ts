// CONTROL (h-specdiff): a commit-all stand-in sink. Same tables as sink.ts, no UNIQUE, no check at all.
// It writes the token's post and intent for every JSON token. It must violate P1.
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
  commit(t: unknown) {
    let tok: any; try { tok = JSON.parse(String(t)); } catch { return { status: "rejected", reason: "not JSON" }; }
    const b = tok?.body; if (!b?.post || !b?.intent) return { status: "rejected", reason: "no body" };
    this.db.exec("BEGIN IMMEDIATE");
    this.db.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(b.post));
    this.db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, ?, '')").run(String(b.requestId), String(t));
    this.db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run(String(b.requestId), canon(b.intent));
    this.db.exec("COMMIT");
    return { status: "committed" };
  }
  close(): void { this.db.close(); }
}
