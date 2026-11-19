// Slice 3 (F3.2): the booking effect sink. It is the store of one board (the capacity of each slot),
// of the batches that wait for an allocation, and of the outbox of committed allocations.
// It holds ONLY the issuer's public key, two pinned ids, the hash of the first board and the largest
// gap that it takes. It cannot sign, and it does not check a certificate: no booking rule is in this
// file.
// commit(input) takes TEXT only: the one canonical JSON text of a token (the rule of Slice 1's sink).
// commit makes an effect ONLY IF all of the following hold (and then it makes the effect, unless the
// transaction fails):
//   1. the token has the exact shape and the pinned domain, specification id and checker id;
//   2. the gap that the token states is not above the largest gap of this sink;
//   3. the Ed25519 signature verifies for exactly the token body (valid token);
//   4. the request id is not settled (fresh request id);
//   5. a batch with this request id waits here and its hash equals the token's batch hash;
//   6. the hash of the stored board equals the token's pre-state hash (matching pre-state hash).
// Checks 4 to 6 and the three writes (board, settled row, one outbox row) are one SQLite IMMEDIATE
// transaction.
// These statements are about commit(). A process that writes the database file behind the sink is
// outside them.
// NOT proved. Trusted: this file, SQLite, Node and OpenSSL, the database file (writable only by the
// sink), SHA-256 collision resistance, Ed25519. One database holds one board.
import { createPublicKey, verify, KeyObject } from "node:crypto";
import { DatabaseSync } from "node:sqlite";
import { Batch, Board, Token, canon, intentText, isBatch, isBoard, isToken, sha256hex, signatureBytes, signedBytes } from "./encoding";

const MAX_TOKEN_TEXT = 16384;

// initialBoardSha256: the hash of the first board. It is a pin OUTSIDE the database: init takes no
// other board, and audit starts its chain there (review findings R1 and R6).
export type SinkConfig = { publicKeyPem: string; specSha256: string; checkerSha256: string; maxAlphaBps: number; initialBoardSha256: string };
export type CommitResult = { status: "committed" | "replayed" | "rejected"; reason?: string };
export type SettledRow = { seq: number; request_id: string; token: string; token_sha256: string };
export type OutboxRow = { seq: number; request_id: string; intent: string };

export class Sink {
  private readonly db: DatabaseSync;
  private readonly key: KeyObject;
  private readonly cfg: SinkConfig;
  constructor(path: string, config: SinkConfig) {
    // A copy by value: a later change of the caller's object changes nothing here.
    const cfg: SinkConfig = { publicKeyPem: String(config.publicKeyPem), specSha256: String(config.specSha256),
      checkerSha256: String(config.checkerSha256), maxAlphaBps: config.maxAlphaBps, initialBoardSha256: String(config.initialBoardSha256) };
    this.cfg = cfg;
    if (!Number.isSafeInteger(cfg.maxAlphaBps) || cfg.maxAlphaBps < 0 || cfg.maxAlphaBps > 10000) throw new Error("largest gap of the sink");
    if (!/^[0-9a-f]{64}$/.test(cfg.initialBoardSha256)) throw new Error("hash of the first board");
    this.db = new DatabaseSync(path);
    this.db.exec("PRAGMA busy_timeout = 30000");
    this.db.exec(`CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS batches(request_id TEXT PRIMARY KEY, blob TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE,
        token TEXT NOT NULL, token_sha256 TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE, intent TEXT NOT NULL);`);
    this.key = createPublicKey(cfg.publicKeyPem);
  }
  // Sets the initial board once. Only the pinned first board is taken. A second call changes nothing.
  init(board: Board): void {
    if (!isBoard(board)) throw new Error("initial board shape");
    const blob = canon(board);
    if (sha256hex(blob) !== this.cfg.initialBoardSha256) throw new Error("initial board is not the pinned one");
    this.db.exec("BEGIN IMMEDIATE");
    try {
      if (this.db.prepare("SELECT 1 AS x FROM state WHERE id = 1").get() === undefined) {
        this.db.prepare("INSERT INTO state(id, blob) VALUES (1, ?)").run(blob);
        this.db.prepare("INSERT INTO meta(k, v) VALUES ('initial_state_sha256', ?)").run(sha256hex(blob));
      }
      this.db.exec("COMMIT");
    } catch (error) { this.db.exec("ROLLBACK"); throw error; }
  }
  // Intake of a batch. This is the trusted way in for requests: an optimizer has no access to it.
  // A request id can be given once. Returns false, with no change, for a known request id.
  submit(batch: Batch): boolean {
    if (!isBatch(batch)) throw new Error("batch shape");
    const done = this.db.prepare("INSERT OR IGNORE INTO batches(request_id, blob) VALUES (?, ?)").run(batch.requestId, canon(batch));
    return Number(done.changes) === 1;
  }
  storedBlob(): string | undefined {
    return (this.db.prepare("SELECT blob FROM state WHERE id = 1").get() as { blob: string } | undefined)?.blob;
  }
  stateBlob(): string {
    const blob = this.storedBlob();
    if (blob === undefined) throw new Error("the sink has no stored board");
    return blob;
  }
  batchBlob(requestId: string): string | undefined {
    return (this.db.prepare("SELECT blob FROM batches WHERE request_id = ?").get(requestId) as { blob: string } | undefined)?.blob;
  }
  settled(): SettledRow[] {
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
    if (token.body.specSha256 !== this.cfg.specSha256) return { status: "rejected", reason: "specification is not the pinned one" };
    if (token.body.checkerSha256 !== this.cfg.checkerSha256) return { status: "rejected", reason: "checker is not the pinned one" };
    if (Number(token.body.alphaBps) > this.cfg.maxAlphaBps) return { status: "rejected", reason: "gap is above the largest gap of this sink" };
    if (!this.verified(token)) return { status: "rejected", reason: "signature does not verify" };
    const tokenText = input, tokenSha256 = sha256hex(tokenText);
    const requestId = token.body.requestId, postText = canon(token.body.post), intent = intentText(token.body);
    try {
      this.db.exec("BEGIN IMMEDIATE");
      const prior = this.db.prepare("SELECT token_sha256 FROM settled WHERE request_id = ?").get(requestId) as { token_sha256: string } | undefined;
      if (prior !== undefined) {
        this.db.exec("ROLLBACK");
        return prior.token_sha256 === tokenSha256 ? { status: "replayed" }
          : { status: "rejected", reason: "request id is already settled with another token" };
      }
      const batch = this.batchBlob(requestId);
      if (batch === undefined) {
        this.db.exec("ROLLBACK");
        return { status: "rejected", reason: "no batch with this request id waits here" };
      }
      if (sha256hex(batch) !== token.body.batchSha256) {
        this.db.exec("ROLLBACK");
        return { status: "rejected", reason: "stored batch is not the token's batch" };
      }
      const stored = this.storedBlob();
      if (stored === undefined) {
        this.db.exec("ROLLBACK");
        return { status: "rejected", reason: "the sink has no stored board" };
      }
      if (sha256hex(stored) !== token.body.preStateSha256) {
        this.db.exec("ROLLBACK");
        return { status: "rejected", reason: "stored board is not the token's pre-state" };
      }
      this.db.prepare("UPDATE state SET blob = ? WHERE id = 1").run(postText);
      this.db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, ?, ?)").run(requestId, tokenText, tokenSha256);
      this.db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run(requestId, intent);
      this.db.exec("COMMIT");
      return { status: "committed" };
    } catch (error) {
      try { this.db.exec("ROLLBACK"); } catch { /* no open transaction */ }
      return { status: "rejected", reason: "transaction failed: " + String((error as Error).message) };
    }
  }
  // Offline audit with the public key and the pinned hash of the first board: every settled row holds
  // a verifying token within the largest gap, for the batch that is stored under its request id; the
  // rows form one chain from the PINNED first board to the stored board; the outbox has exactly the
  // settled allocations in the same order. An empty result means no problem was found.
  // NOT found by this audit (stated limits): a database that was set back as a whole to an earlier
  // state of its own chain (the last commits removed and the board set back); a waiting batch that was
  // changed before its commit (intake is trusted).
  audit(): string[] {
    const problems: string[] = [];
    if (this.storedBlob() === undefined) return ["the sink has no stored board"];
    const rows = this.settled();
    const first = (this.db.prepare("SELECT v FROM meta WHERE k = 'initial_state_sha256'").get() as { v: string } | undefined)?.v;
    if (first !== this.cfg.initialBoardSha256) problems.push("first board in the database is not the pinned one");
    let expected: string | undefined = this.cfg.initialBoardSha256;
    const tokens: (Token | null)[] = [];
    for (const row of rows) {
      let token: unknown;
      try { token = JSON.parse(row.token); } catch { problems.push(`row ${row.seq}: token is not JSON`); tokens.push(null); continue; }
      if (!isToken(token) || canon(token) !== row.token || sha256hex(row.token) !== row.token_sha256) {
        problems.push(`row ${row.seq}: token bytes`); tokens.push(null); continue;
      }
      tokens.push(token);
      if (token.body.requestId !== row.request_id) problems.push(`row ${row.seq}: request id`);
      if (token.body.specSha256 !== this.cfg.specSha256 || token.body.checkerSha256 !== this.cfg.checkerSha256) problems.push(`row ${row.seq}: ids`);
      if (Number(token.body.alphaBps) > this.cfg.maxAlphaBps) problems.push(`row ${row.seq}: gap`);
      if (!this.verified(token)) problems.push(`row ${row.seq}: signature`);
      const batch = this.batchBlob(row.request_id);
      if (batch === undefined || sha256hex(batch) !== token.body.batchSha256) problems.push(`row ${row.seq}: batch`);
      if (token.body.preStateSha256 !== expected) problems.push(`row ${row.seq}: chain`);
      expected = sha256hex(canon(token.body.post));
    }
    if (sha256hex(this.stateBlob()) !== expected) problems.push("stored board is not the end of the chain");
    const out = this.outbox();
    if (out.length !== rows.length) problems.push("outbox length differs from settled length");
    out.forEach((o, i) => {
      const token = tokens[i];
      if (!token || o.request_id !== rows[i].request_id || o.intent !== intentText(token.body)) problems.push(`outbox ${o.seq}: not the settled allocation`);
    });
    return problems;
  }
  close(): void { this.db.close(); }
}
