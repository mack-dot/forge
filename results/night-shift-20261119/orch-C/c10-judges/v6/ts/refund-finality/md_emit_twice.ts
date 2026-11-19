// MUTANT emit_twice (c10-judges attack input; edited copy of v6 sink/dispatcher). NOT a fix.
// Slice 1 (F2.2): the outbound refund dispatcher. It stands between the outbox and the external effect.
// It trusts NOTHING in the database. Before each effect it checks, with the public key only:
//   1. the settled row for the outbox row holds a token in canonical form with the pinned ids;
//   2. the Ed25519 signature of the issuer verifies for exactly that token body;
//   3. the outbox intent and request id are the signed ones;
//   4. chain: the token's pre-state hash is the post-state hash of the last dispatched token (first:
//      the pinned initial state hash);
//   5. the request id is not in the dispatcher's own append-only ledger.
// The ledger is a file OUTSIDE the database. A line is appended and synced BEFORE the effect: at most
// once. A crash between the two loses that effect (it is never sent twice); a person must reconcile it.
// One run at a time: flush() creates the lock file <resolved ledger path>.lock exclusively and removes
// it at its end. The ledger path is resolved first (the ledger file is created empty if it is missing),
// so a symbolic link to the ledger file or to a folder above it gives the same lock. (With a lock named
// after the path text, two names for one ledger file had two locks: finding of the repair check.)
// NOT covered: a hard link to the ledger file, and a file system that does not make exclusive creation
// atomic.
// A second run that starts meanwhile stops with an error and sends nothing. (Without the lock, two
// overlapping runs each read the ledger once and both sent the same refunds: review finding F2.)
// A process that dies inside a run leaves the lock file. Every later run then stops until a person
// has reconciled the last ledger line and removed the lock file.
// A missing ledger file is read as an empty ledger: a lost ledger sends everything again.
// NOT proved. Assumed and not checked: the ledger file, this process and the pinned configuration are
// out of the attacker's reach; the issuer's key is not leaked.
// Known limit (U428, case D14): if the issuer signs two transitions for one pre-state and an attacker
// can write the database file, the dispatcher can send the one that the sink did not commit.
import { createPublicKey, verify, KeyObject } from "node:crypto";
import { closeSync, existsSync, fsyncSync, openSync, readFileSync, realpathSync, unlinkSync, writeSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { Intent, canon, isToken, sha256hex, signatureBytes, signedBytes } from "./encoding";

export type DispatcherConfig = { publicKeyPem: string; specLockSha256: string; checkerSha256: string; initialStateSha256: string };
export type Effect = { requestId: string; intent: string };
export type FlushResult = { emitted: Effect[]; refused: { seq: number; requestId: string; reason: string }[]; alreadyDispatched: number };
type LedgerLine = { requestId: string; tokenSha256: string; preStateSha256: string; postStateSha256: string; intentSha256: string };
type OutboxRow = { seq: number; request_id: string; intent: string };

export class Dispatcher {
  private readonly key: KeyObject;
  constructor(private readonly dbPath: string, private readonly ledgerPath: string, private readonly cfg: DispatcherConfig,
              private readonly emit: (effect: Effect, intent: Intent) => void) {
    this.key = createPublicKey(cfg.publicKeyPem);
  }
  // Reads the dispatcher's own ledger and checks that it is one chain from the pinned initial state. Fails closed.
  private ledger(): { head: string; done: Set<string> } {
    let head = this.cfg.initialStateSha256;
    const done = new Set<string>();
    if (existsSync(this.ledgerPath)) {
      for (const line of readFileSync(this.ledgerPath, "utf8").split("\n").filter(l => l.length > 0)) {
        const entry = JSON.parse(line) as LedgerLine;
        if (typeof entry.requestId !== "string" || typeof entry.postStateSha256 !== "string" ||
            entry.preStateSha256 !== head || done.has(entry.requestId)) throw new Error("dispatcher ledger is not one chain");
        head = entry.postStateSha256; done.add(entry.requestId);
      }
    }
    return { head, done };
  }
  private check(row: OutboxRow, tokenText: string | undefined, head: string):
      { ok: true; line: LedgerLine; intent: Intent } | { ok: false; reason: string } {
    if (tokenText === undefined) return { ok: false, reason: "no settled row" };
    let token: unknown;
    try { token = JSON.parse(tokenText); } catch { return { ok: false, reason: "token is not JSON" }; }
    if (!isToken(token) || canon(token) !== tokenText) return { ok: false, reason: "token is not canonical" };
    const body = token.body;
    if (body.specLockSha256 !== this.cfg.specLockSha256 || body.checkerSha256 !== this.cfg.checkerSha256) return { ok: false, reason: "ids are not the pinned ones" };
    if (body.requestId !== row.request_id || body.intent.requestId !== row.request_id) return { ok: false, reason: "request id is not the signed one" };
    let good = false;
    try { const raw = signatureBytes(token.signature); good = raw !== null && verify(null, signedBytes(body), this.key, raw); } catch { good = false; }
    if (!good) return { ok: false, reason: "signature does not verify" };
    if (canon(body.intent) !== row.intent) return { ok: false, reason: "outbox intent is not the signed intent" };
    if (body.preStateSha256 !== head) return { ok: false, reason: "token does not continue the dispatched chain" };
    return { ok: true, intent: body.intent, line: { requestId: body.requestId, tokenSha256: sha256hex(tokenText), preStateSha256: head,
      postStateSha256: sha256hex(canon(body.post)), intentSha256: sha256hex(row.intent) } };
  }
  flush(): FlushResult {
    closeSync(openSync(this.ledgerPath, "a"));
    const lockPath = realpathSync(this.ledgerPath) + ".lock";
    let lock: number;
    try { lock = openSync(lockPath, "wx"); } catch { throw new Error("dispatcher lock is held: another run is active, or a stopped run left the lock file"); }
    try { return this.flushLocked(); } finally { closeSync(lock); unlinkSync(lockPath); }
  }
  private flushLocked(): FlushResult {
    let { head, done } = this.ledger();
    const db = new DatabaseSync(this.dbPath, { readOnly: true });
    const result: FlushResult = { emitted: [], refused: [], alreadyDispatched: 0 };
    try {
      const rows = db.prepare("SELECT seq, request_id, intent FROM outbox ORDER BY seq").all() as OutboxRow[];
      const pending = rows.filter(r => typeof r.request_id === "string" && typeof r.intent === "string" && !done.has(r.request_id));
      result.alreadyDispatched = rows.length - pending.length;
      const reasons = new Map<number, { requestId: string; reason: string }>();
      let progress = true;
      while (progress) {                       // a later row can become the next link after an earlier one is dispatched
        progress = false;
        for (const row of pending) {
          if (done.has(row.request_id)) continue;
          const settled = db.prepare("SELECT token FROM settled WHERE request_id = ?").get(row.request_id) as { token: unknown } | undefined;
          const verdict = this.check(row, typeof settled?.token === "string" ? settled.token : undefined, head);
          if (!verdict.ok) { reasons.set(row.seq, { requestId: row.request_id, reason: verdict.reason }); continue; }
          const fd = openSync(this.ledgerPath, "a");
          try { writeSync(fd, JSON.stringify(verdict.line) + "\n"); fsyncSync(fd); } finally { closeSync(fd); }
          head = verdict.line.postStateSha256; done.add(row.request_id); reasons.delete(row.seq); progress = true;
          const effect = { requestId: row.request_id, intent: row.intent };
          this.emit(effect, verdict.intent);    // the external effect: after the ledger line
          this.emit(effect, verdict.intent);    // the external effect: after the ledger line
          result.emitted.push(effect);
        }
      }
      for (const [seq, r] of reasons) if (!done.has(r.requestId)) result.refused.push({ seq, ...r });
    } finally { db.close(); }
    return result;
  }
}
