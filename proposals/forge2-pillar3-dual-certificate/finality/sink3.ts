// Round 3 task 4 (U431): the booking sink. Holds only the minter's public key and two pinned hashes. One commit is one
// SQLite IMMEDIATE transaction: signature, pinned ids, the batch is pending and its stored instance hash is the
// signed one, gap policy; then the allocation row and the status change. Research code. NOT proved.
import { createPublicKey, verify, KeyObject } from "node:crypto";
import { DatabaseSync } from "node:sqlite";
import { Batch, BookingClaim, canon, isClaim, payload, sha256hex } from "./booking_common";

export type SinkConfig = { publicKeyPem: string; checkerSha256: string; minterSha256: string; maxAlphaBps: number };
// Anyone can run this with the public key: no database, no minter.
export function verifyReceipt(cfg: Omit<SinkConfig, "maxAlphaBps">, batch: Batch, claim: unknown, sig: unknown): boolean {
  try {
    if (!isClaim(claim) || typeof sig !== "string") return false;
    const raw = Buffer.from(sig, "base64");
    return claim.checkerSha256 === cfg.checkerSha256 && claim.minterSha256 === cfg.minterSha256 &&
      claim.instanceSha256 === sha256hex(canon(batch)) && raw.length === 64 && verify(null, payload(claim), createPublicKey(cfg.publicKeyPem), raw);
  } catch { return false; }
}
export class BookingSink {
  readonly db: DatabaseSync;
  private readonly key: KeyObject;
  constructor(path: string, private readonly cfg: SinkConfig) {
    this.db = new DatabaseSync(path);
    this.db.exec(`CREATE TABLE IF NOT EXISTS batches(batch_id TEXT PRIMARY KEY, instance TEXT NOT NULL, instance_sha TEXT NOT NULL, status TEXT NOT NULL CHECK (status IN ('pending','allocated')));
      CREATE TABLE IF NOT EXISTS allocations(batch_id TEXT PRIMARY KEY, claim TEXT NOT NULL, sig TEXT NOT NULL);`);
    this.key = createPublicKey(cfg.publicKeyPem);
  }
  open(batchId: string, batch: Batch): void {
    const text = canon(batch);
    this.db.prepare("INSERT INTO batches(batch_id, instance, instance_sha, status) VALUES (?, ?, ?, 'pending')").run(batchId, text, sha256hex(text));
  }
  commit(claim: unknown, sig: unknown): { status: "committed" | "rejected"; reason?: string } {
    if (!isClaim(claim) || typeof sig !== "string") return { status: "rejected", reason: "shape" };
    if (claim.checkerSha256 !== this.cfg.checkerSha256 || claim.minterSha256 !== this.cfg.minterSha256) return { status: "rejected", reason: "ids are not the pinned ones" };
    let good = false;
    try { const raw = Buffer.from(sig, "base64"); good = raw.length === 64 && verify(null, payload(claim), this.key, raw); } catch { good = false; }
    if (!good) return { status: "rejected", reason: "signature does not verify" };
    if (Number(claim.alphaBps) > this.cfg.maxAlphaBps) return { status: "rejected", reason: "gap is above the sink's policy" };
    this.db.exec("BEGIN IMMEDIATE");
    try {
      const row = this.db.prepare("SELECT instance_sha, status FROM batches WHERE batch_id = ?").get(claim.batchId) as { instance_sha: string; status: string } | undefined;
      const refuse = row === undefined ? "unknown batch" : row.status !== "pending" ? "batch is already allocated"
        : row.instance_sha !== claim.instanceSha256 ? "stored instance is not the signed instance" : null;
      if (refuse !== null) { this.db.exec("ROLLBACK"); return { status: "rejected", reason: refuse }; }
      this.db.prepare("INSERT INTO allocations(batch_id, claim, sig) VALUES (?, ?, ?)").run(claim.batchId, canon(claim), sig);
      this.db.prepare("UPDATE batches SET status = 'allocated' WHERE batch_id = ?").run(claim.batchId);
      this.db.exec("COMMIT");
      return { status: "committed" };
    } catch (error) {
      try { this.db.exec("ROLLBACK"); } catch { /* no open transaction */ }
      return { status: "rejected", reason: "transaction failed: " + String((error as Error).message) };
    }
  }
  allocations(): { batch_id: string; claim: BookingClaim; sig: string; instance: Batch }[] {
    return (this.db.prepare("SELECT a.batch_id, a.claim, a.sig, b.instance FROM allocations a JOIN batches b USING (batch_id) ORDER BY a.batch_id").all() as any[])
      .map(r => ({ batch_id: r.batch_id, claim: JSON.parse(r.claim), sig: r.sig, instance: JSON.parse(r.instance) }));
  }
  close(): void { this.db.close(); }
}
