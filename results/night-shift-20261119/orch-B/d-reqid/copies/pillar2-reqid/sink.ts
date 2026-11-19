// Round 2 task 3 (U420): the sink. It holds ONLY the minter's public key and two pinned hashes. It cannot sign.
// One commit is one SQLite IMMEDIATE transaction: signature, pinned ids, compare-and-swap on the stored state hash,
// request-id uniqueness; then state, settled row and exactly one outbox row. Research code. NOT proved.
import { createPublicKey, verify, KeyObject } from "node:crypto";
import { DatabaseSync } from "node:sqlite";
import { ChargeState, Claim, canon, isClaim, payload, sha256hex } from "./common";

export type SinkConfig = { publicKeyPem: string; specLockSha256: string; minterSha256: string };
export type CommitResult = { status: "committed" | "replayed" | "rejected"; reason?: string };

export class Sink {
  readonly db: DatabaseSync;
  private readonly key: KeyObject;
  constructor(path: string, private readonly cfg: SinkConfig) {
    this.db = new DatabaseSync(path);
    this.db.exec("PRAGMA busy_timeout = 20000");
    this.db.exec(`CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL, sha TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, req_id TEXT NOT NULL UNIQUE,
        claim TEXT NOT NULL, claim_sha TEXT NOT NULL, sig TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, req_id TEXT NOT NULL UNIQUE, intent TEXT NOT NULL);`);
    this.key = createPublicKey(cfg.publicKeyPem);
  }
  init(state: ChargeState): void {
    const blob = canon(state);
    this.db.exec("BEGIN IMMEDIATE");
    try {
      if (this.db.prepare("SELECT 1 AS x FROM state WHERE id = 1").get() === undefined) {
        this.db.prepare("INSERT INTO state(id, blob, sha) VALUES (1, ?, ?)").run(blob, sha256hex(blob));
        this.db.prepare("INSERT INTO meta(k, v) VALUES ('initial_sha', ?)").run(sha256hex(blob));
      }
      this.db.exec("COMMIT");
    } catch (error) { this.db.exec("ROLLBACK"); throw error; }
  }
  state(): { blob: string; sha: string } {
    return this.db.prepare("SELECT blob, sha FROM state WHERE id = 1").get() as { blob: string; sha: string };
  }
  outbox(): { seq: number; req_id: string; intent: string }[] {
    return this.db.prepare("SELECT seq, req_id, intent FROM outbox ORDER BY seq").all() as any;
  }
  private verified(claim: Claim, sig: string): boolean {
    try {
      const raw = Buffer.from(sig, "base64");
      return raw.length === 64 && verify(null, payload(claim), this.key, raw);
    } catch { return false; }
  }
  commit(claim: unknown, sig: unknown): CommitResult {
    if (!isClaim(claim)) return { status: "rejected", reason: "claim shape" };
    if (typeof sig !== "string") return { status: "rejected", reason: "signature shape" };
    if (claim.specLockSha256 !== this.cfg.specLockSha256) return { status: "rejected", reason: "spec lock is not the pinned one" };
    if (claim.minterSha256 !== this.cfg.minterSha256) return { status: "rejected", reason: "minter is not the pinned one" };
    if (claim.reqId !== claim.request.requestId || claim.intent.requestId !== claim.reqId) return { status: "rejected", reason: "request id mismatch" };
    if (!this.verified(claim, sig)) return { status: "rejected", reason: "signature does not verify" };
    const claimText = canon(claim), claimSha = sha256hex(claimText);
    this.db.exec("BEGIN IMMEDIATE");
    try {
      const prior = this.db.prepare("SELECT claim_sha FROM settled WHERE req_id = ?").get(claim.reqId) as { claim_sha: string } | undefined;
      if (prior !== undefined) {
        this.db.exec("ROLLBACK");
        return prior.claim_sha === claimSha ? { status: "replayed" }
          : { status: "rejected", reason: "request id already settled with another claim" };
      }
      if (this.state().sha !== sha256hex(canon(claim.pre))) {
        this.db.exec("ROLLBACK");
        return { status: "rejected", reason: "stored state is not the claimed pre-state" };
      }
      const post = canon(claim.post);
      this.db.prepare("UPDATE state SET blob = ?, sha = ? WHERE id = 1").run(post, sha256hex(post));
      this.db.prepare("INSERT INTO settled(req_id, claim, claim_sha, sig) VALUES (?, ?, ?, ?)").run(claim.reqId, claimText, claimSha, sig);
      this.db.prepare("INSERT INTO outbox(req_id, intent) VALUES (?, ?)").run(claim.reqId, canon(claim.intent));
      this.db.exec("COMMIT");
      return { status: "committed" };
    } catch (error) {
      try { this.db.exec("ROLLBACK"); } catch { /* no open transaction */ }
      return { status: "rejected", reason: "transaction failed: " + String((error as Error).message) };
    }
  }
  // Offline audit with the public key only: every settled row verifies, the rows form one chain from the initial
  // state to the stored state, and the outbox has exactly the settled intents.
  audit(): string[] {
    const problems: string[] = [];
    const rows = this.db.prepare("SELECT seq, req_id, claim, claim_sha, sig FROM settled ORDER BY seq").all() as any[];
    const initial = (this.db.prepare("SELECT v FROM meta WHERE k = 'initial_sha'").get() as { v: string } | undefined)?.v;
    let expected = initial;
    for (const row of rows) {
      let claim: unknown;
      try { claim = JSON.parse(row.claim); } catch { problems.push(`row ${row.seq}: claim is not JSON`); continue; }
      if (!isClaim(claim) || canon(claim) !== row.claim || sha256hex(row.claim) !== row.claim_sha) { problems.push(`row ${row.seq}: claim bytes`); continue; }
      if (claim.specLockSha256 !== this.cfg.specLockSha256 || claim.minterSha256 !== this.cfg.minterSha256) problems.push(`row ${row.seq}: ids`);
      if (!this.verified(claim, row.sig)) problems.push(`row ${row.seq}: signature`);
      if (sha256hex(canon(claim.pre)) !== expected) problems.push(`row ${row.seq}: chain`);
      expected = sha256hex(canon(claim.post));
    }
    if (this.state().sha !== expected) problems.push("stored state is not the end of the chain");
    const out = this.outbox();
    if (out.length !== rows.length) problems.push("outbox length differs from settled length");
    out.forEach((o, i) => {
      const claim = rows[i] && JSON.parse(rows[i].claim);
      if (!claim || o.req_id !== rows[i].req_id || o.intent !== canon(claim.intent)) problems.push(`outbox ${o.seq}: not the settled intent`);
    });
    return problems;
  }
  close(): void { this.db.close(); }
}
