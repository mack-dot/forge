// Round 3 task 3 (U428): the outbound refund dispatcher. It stands between the outbox and the external effect.
// It trusts NOTHING in the database. Before each effect it checks, with the public key only:
//   1. the settled row for the outbox row holds a claim in canonical form with the pinned ids;
//   2. the Ed25519 signature of the minter verifies for exactly that claim;
//   3. the outbox intent and request id are the signed ones;
//   4. chain: the claim's pre-state hash is the post-state hash of the last dispatched claim (first: the pinned
//      initial state hash);
//   5. idempotency: the request id is not in the dispatcher's own append-only ledger.
// The ledger is a file OUTSIDE the database. A line is appended and synced BEFORE the effect: at most once.
// A crash between the two loses that effect (it is never sent twice); a person must reconcile it.
// Research code. NOT proved. Assumed and not checked: the ledger file, this process and the pinned configuration
// are out of the attacker's reach; the minter key is not leaked.
import { createPublicKey, verify, KeyObject } from "node:crypto";
import { closeSync, existsSync, fsyncSync, openSync, readFileSync, writeSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { Intent, canon, isClaim, payload, sha256hex } from "./common";

export type DispatcherConfig = { publicKeyPem: string; specLockSha256: string; minterSha256: string; initialStateSha256: string };
export type Effect = { reqId: string; intent: string };
export type FlushResult = { emitted: Effect[]; refused: { seq: number; reqId: string; reason: string }[]; alreadyDispatched: number };
type LedgerLine = { reqId: string; claimSha256: string; preSha256: string; postSha256: string; intentSha256: string };

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
        if (entry.preSha256 !== head || done.has(entry.reqId)) throw new Error("dispatcher ledger is not one chain");
        head = entry.postSha256; done.add(entry.reqId);
      }
    }
    return { head, done };
  }
  private check(row: { seq: number; req_id: string; intent: string }, settled: { claim: string; sig: string } | undefined, head: string):
      { ok: true; line: LedgerLine; intent: Intent } | { ok: false; reason: string } {
    if (settled === undefined) return { ok: false, reason: "no settled row" };
    let claim: unknown;
    try { claim = JSON.parse(settled.claim); } catch { return { ok: false, reason: "claim is not JSON" }; }
    if (!isClaim(claim) || canon(claim) !== settled.claim) return { ok: false, reason: "claim is not canonical" };
    if (claim.specLockSha256 !== this.cfg.specLockSha256 || claim.minterSha256 !== this.cfg.minterSha256) return { ok: false, reason: "ids are not the pinned ones" };
    if (claim.reqId !== row.req_id || claim.request.requestId !== row.req_id) return { ok: false, reason: "request id is not the signed one" };
    let good = false;
    try { const raw = Buffer.from(String(settled.sig), "base64"); good = raw.length === 64 && verify(null, payload(claim), this.key, raw); } catch { good = false; }
    if (!good) return { ok: false, reason: "signature does not verify" };
    if (canon(claim.intent) !== row.intent) return { ok: false, reason: "outbox intent is not the signed intent" };
    if (sha256hex(canon(claim.pre)) !== head) return { ok: false, reason: "claim does not continue the dispatched chain" };
    return { ok: true, intent: claim.intent, line: { reqId: claim.reqId, claimSha256: sha256hex(settled.claim), preSha256: head,
      postSha256: sha256hex(canon(claim.post)), intentSha256: sha256hex(row.intent) } };
  }
  flush(): FlushResult {
    let { head, done } = this.ledger();
    const db = new DatabaseSync(this.dbPath, { readOnly: true });
    const result: FlushResult = { emitted: [], refused: [], alreadyDispatched: 0 };
    try {
      const rows = db.prepare("SELECT seq, req_id, intent FROM outbox ORDER BY seq").all() as { seq: number; req_id: string; intent: string }[];
      const pending = rows.filter(r => typeof r.req_id === "string" && typeof r.intent === "string" && !done.has(r.req_id));
      result.alreadyDispatched = rows.length - pending.length;
      const reasons = new Map<number, { reqId: string; reason: string }>();
      let progress = true;
      while (progress) {                       // a later row can become the next link after an earlier one is dispatched
        progress = false;
        for (const row of pending) {
          if (done.has(row.req_id)) continue;
          const settled = db.prepare("SELECT claim, sig FROM settled WHERE req_id = ?").get(row.req_id) as { claim: string; sig: string } | undefined;
          const verdict = this.check(row, settled, head);
          if (!verdict.ok) { reasons.set(row.seq, { reqId: row.req_id, reason: verdict.reason }); continue; }
          const fd = openSync(this.ledgerPath, "a");
          try { writeSync(fd, JSON.stringify(verdict.line) + "\n"); fsyncSync(fd); } finally { closeSync(fd); }
          head = verdict.line.postSha256; done.add(row.req_id); reasons.delete(row.seq); progress = true;
          const effect = { reqId: row.req_id, intent: row.intent };
          this.emit(effect, verdict.intent);    // the external effect: after the ledger line
          result.emitted.push(effect);
        }
      }
      for (const [seq, r] of reasons) if (!done.has(r.reqId)) result.refused.push({ seq, ...r });
    } finally { db.close(); }
    return result;
  }
}

// CONTROL ONLY: a dispatcher without checks. It sends every outbox row once per process. Used to show that the
// attacks of the suite are real.
export function naiveFlush(dbPath: string, emit: (effect: Effect) => void): Effect[] {
  const db = new DatabaseSync(dbPath, { readOnly: true });
  try {
    const out = (db.prepare("SELECT req_id, intent FROM outbox ORDER BY seq").all() as { req_id: string; intent: string }[])
      .map(r => ({ reqId: String(r.req_id), intent: String(r.intent) }));
    out.forEach(emit);
    return out;
  } finally { db.close(); }
}
