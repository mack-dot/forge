// Slice 1 (F2.2): the sink. It is the store of one charge and the outbox of outbound refund intents.
// It holds ONLY the issuer's public key and two pinned hashes. It cannot sign.
// commit(input) takes TEXT only: the one canonical JSON text of a token. A value that is not a text
// is refused before any of its properties is read, so no code of the caller runs inside commit, and
// no value can show one token to the signature check and another one to the store. (An object with
// an accessor did that to the first version of this file; a later version that copied the object
// first still ran the caller's accessor inside the sink process: review finding F1.)
// Code that runs inside the sink process by any other way is in the trusted base: it can replace any
// function that the sink uses.
// commit makes an effect if and only if:
//   1. the token has the exact shape and the pinned domain, spec lock and checker id;
//   2. the Ed25519 signature verifies for exactly the token body (valid token);
//   3. the request id is not settled (fresh request id);
//   4. the hash of the stored state equals the token's pre-state hash (matching pre-state hash).
// Checks 3 and 4 and the three writes (state, settled row, one outbox row) are one SQLite IMMEDIATE
// transaction. No refund rule is in this file: the sink does not look at amounts or reasons.
// NOT proved. Trusted: this file, SQLite, Node and OpenSSL, the database file (writable only by the
// sink), SHA-256 collision resistance, Ed25519.
// One database holds one charge.
import { createPublicKey, verify, KeyObject } from "node:crypto";
import { DatabaseSync } from "node:sqlite";
import { ChargeState, Token, canon, isState, isToken, sha256hex, signatureBytes, signedBytes } from "./encoding";

const MAX_TOKEN_TEXT = 8192;

export type SinkConfig = { publicKeyPem: string; specLockSha256: string; checkerSha256: string };
export type CommitResult = { status: "committed" | "replayed" | "rejected"; reason?: string };
export type OutboxRow = { seq: number; request_id: string; intent: string };

export class Sink {
  private readonly db: DatabaseSync;
  private readonly key: KeyObject;
  constructor(path: string, private readonly cfg: SinkConfig) {
    this.db = new DatabaseSync(path);
    this.db.exec("PRAGMA busy_timeout = 30000");
    this.db.exec(`CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE,
        token TEXT NOT NULL, token_sha256 TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE, intent TEXT NOT NULL);`);
    this.key = createPublicKey(cfg.publicKeyPem);
  }
  // Sets the initial state once. A second call changes nothing.
  init(state: ChargeState): void {
    if (!isState(state)) throw new Error("initial state shape");
    const blob = canon(state);
    this.db.exec("BEGIN IMMEDIATE");
    try {
      if (this.db.prepare("SELECT 1 AS x FROM state WHERE id = 1").get() === undefined) {
        this.db.prepare("INSERT INTO state(id, blob) VALUES (1, ?)").run(blob);
        this.db.prepare("INSERT INTO meta(k, v) VALUES ('initial_state_sha256', ?)").run(sha256hex(blob));
      }
      this.db.exec("COMMIT");
    } catch (error) { this.db.exec("ROLLBACK"); throw error; }
  }
  // The stored state text, or undefined before init.
  storedBlob(): string | undefined {
    return (this.db.prepare("SELECT blob FROM state WHERE id = 1").get() as { blob: string } | undefined)?.blob;
  }
  stateBlob(): string {
    const blob = this.storedBlob();
    if (blob === undefined) throw new Error("the sink has no stored state");
    return blob;
  }
  settled(): { seq: number; request_id: string; token: string; token_sha256: string }[] {
    return this.db.prepare("SELECT seq, request_id, token, token_sha256 FROM settled ORDER BY seq").all() as any;
  }
  outbox(): OutboxRow[] {
    return this.db.prepare("SELECT seq, request_id, intent FROM outbox ORDER BY seq").all() as any;
  }
  private verified(token: Token): boolean {
    try {
      const raw = signatureBytes(token.signature);
      return raw !== null && verify(null, signedBytes(token.body), this.key, raw);
    } catch { return false; }
  }
  commit(input: unknown): CommitResult {
    if (typeof input !== "string") return { status: "rejected", reason: "token is not a text" };
    if (input.length > MAX_TOKEN_TEXT) return { status: "rejected", reason: "token shape" };
    let token: unknown;
    try { token = JSON.parse(input); } catch { return { status: "rejected", reason: "token shape" }; }
    if (!isToken(token)) return { status: "rejected", reason: "token shape" };
    if (canon(token) !== input) return { status: "rejected", reason: "token text is not canonical" };
    if (token.body.specLockSha256 !== this.cfg.specLockSha256) return { status: "rejected", reason: "spec lock is not the pinned one" };
    if (token.body.checkerSha256 !== this.cfg.checkerSha256) return { status: "rejected", reason: "checker is not the pinned one" };
    if (!this.verified(token)) return { status: "rejected", reason: "signature does not verify" };
    if (token.body.requestId !== token.body.intent.requestId) return { status: "rejected", reason: "request id is not the intent's request id" };
    const tokenText = input, tokenSha256 = sha256hex(tokenText);
    const requestId = token.body.requestId, postText = canon(token.body.post), intentText = canon(token.body.intent);
    try {
      this.db.exec("BEGIN IMMEDIATE");
      const prior = this.db.prepare("SELECT token_sha256 FROM settled WHERE request_id = ?").get(requestId) as { token_sha256: string } | undefined;
      if (prior !== undefined) {
        this.db.exec("ROLLBACK");
        return prior.token_sha256 === tokenSha256 ? { status: "replayed" }
          : { status: "rejected", reason: "request id is already settled with another token" };
      }
      const stored = this.storedBlob();
      if (stored === undefined) {
        this.db.exec("ROLLBACK");
        return { status: "rejected", reason: "the sink has no stored state" };
      }
      if (sha256hex(stored) !== token.body.preStateSha256) {
        this.db.exec("ROLLBACK");
        return { status: "rejected", reason: "stored state is not the token's pre-state" };
      }
      this.db.prepare("UPDATE state SET blob = ? WHERE id = 1").run(postText);
      this.db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, ?, ?)").run(requestId, tokenText, tokenSha256);
      this.db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run(requestId, intentText);
      this.db.exec("COMMIT");
      return { status: "committed" };
    } catch (error) {
      try { this.db.exec("ROLLBACK"); } catch { /* no open transaction */ }
      return { status: "rejected", reason: "transaction failed: " + String((error as Error).message) };
    }
  }
  // Offline audit with the public key only: every settled row holds a verifying token, the rows form
  // one chain from the initial state to the stored state, and the outbox has exactly the settled
  // intents in the same order. An empty result means no problem was found.
  audit(): string[] {
    const problems: string[] = [];
    const rows = this.settled();
    let expected = (this.db.prepare("SELECT v FROM meta WHERE k = 'initial_state_sha256'").get() as { v: string } | undefined)?.v;
    const tokens: (Token | null)[] = [];
    for (const row of rows) {
      let token: unknown;
      try { token = JSON.parse(row.token); } catch { problems.push(`row ${row.seq}: token is not JSON`); tokens.push(null); continue; }
      if (!isToken(token) || canon(token) !== row.token || sha256hex(row.token) !== row.token_sha256) {
        problems.push(`row ${row.seq}: token bytes`); tokens.push(null); continue;
      }
      tokens.push(token);
      if (token.body.requestId !== row.request_id || token.body.intent.requestId !== row.request_id) problems.push(`row ${row.seq}: request id`);
      if (token.body.specLockSha256 !== this.cfg.specLockSha256 || token.body.checkerSha256 !== this.cfg.checkerSha256) problems.push(`row ${row.seq}: ids`);
      if (!this.verified(token)) problems.push(`row ${row.seq}: signature`);
      if (token.body.preStateSha256 !== expected) problems.push(`row ${row.seq}: chain`);
      expected = sha256hex(canon(token.body.post));
    }
    if (sha256hex(this.stateBlob()) !== expected) problems.push("stored state is not the end of the chain");
    const out = this.outbox();
    if (out.length !== rows.length) problems.push("outbox length differs from settled length");
    out.forEach((o, i) => {
      const token = tokens[i];
      if (!token || o.request_id !== rows[i].request_id || o.intent !== canon(token.body.intent)) problems.push(`outbox ${o.seq}: not the settled intent`);
    });
    return problems;
  }
  close(): void { this.db.close(); }
}
