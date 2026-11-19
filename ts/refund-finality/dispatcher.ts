// Slice 1 (F2.2): the outbound refund dispatcher. It stands between the outbox and the external effect.
// It trusts NOTHING in the database. Before each run it applies the sink's store audit (h1, core/store.ts; see
// flushLocked). Before each effect it checks, with the public key only:
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
// h1: a missing or empty ledger is an ERROR when the store has committed rows, unless cfg.newLedgerH0 is the store's
// registered h_0 (an explicit new ledger). (Before h1 a lost ledger sent everything again: h-anchor probe, control E.)
// NOT proved. Assumed and not checked: the ledger file, this process and the pinned configuration are
// out of the attacker's reach; the issuer's key is not leaked.
// Known limit (U428, case D14): if the issuer signs two transitions for one pre-state and an attacker
// can write the database file WITHOUT the key, the dispatcher can send the one that the sink did not commit. h1: the
// append-only triggers stop that swap through SQL; a writer who disables or drops the triggers and recomputes the
// (unkeyed) row-log chain is not detected here: the store audit accepts any authorized, signed transition.
import { createPublicKey, verify, KeyObject } from "node:crypto";
import { closeSync, existsSync, fsyncSync, openSync, readFileSync, realpathSync, unlinkSync, writeSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { Intent, canon, isState, isToken, sha256hex, signatureBytes, signedBytes } from "./encoding";
import { AuditedRow, StoreAuditor, conv, loadCore, readMeta, validInitial } from "./core/store";

// newLedgerH0 (optional): the registered h_0 of the store (sink.ts genesisOf). A missing or empty ledger is an ERROR when
// the store holds committed rows, unless this field equals the store's h_0 (an explicit "new ledger").
export type DispatcherConfig = { publicKeyPem: string; specLockSha256: string; checkerSha256: string; initialStateSha256: string; newLedgerH0?: string };
export type Effect = { requestId: string; intent: string };
export type FlushResult = { emitted: Effect[]; refused: { seq: number; requestId: string; reason: string }[]; alreadyDispatched: number };
type LedgerLine = { requestId: string; tokenSha256: string; preStateSha256: string; postStateSha256: string; intentSha256: string; n: number; rowHead: string };
type OutboxRow = { seq: number; request_id: string; intent: string };

export class Dispatcher {
  private readonly key: KeyObject;
  private readonly M = loadCore();
  private readonly cv = conv(this.M);
  constructor(private readonly dbPath: string, private readonly ledgerPath: string, private readonly cfg: DispatcherConfig,
              private readonly emit: (effect: Effect, intent: Intent) => void) {
    this.key = createPublicKey(cfg.publicKeyPem);
  }
  // Reads the dispatcher's own ledger and checks that it is one chain from the pinned initial state. Fails closed.
  // h1: each line also carries n (its row number) and rowHead (the sink's row-log head after row n).
  private ledger(): { head: string; done: Set<string>; n: number; rowHead: string } {
    let head = this.cfg.initialStateSha256, n = 0, rowHead = "";
    const done = new Set<string>();
    if (existsSync(this.ledgerPath)) {
      for (const line of readFileSync(this.ledgerPath, "utf8").split("\n").filter(l => l.length > 0)) {
        const entry = JSON.parse(line) as LedgerLine;
        if (typeof entry.requestId !== "string" || typeof entry.postStateSha256 !== "string" ||
            entry.preStateSha256 !== head || done.has(entry.requestId) || entry.n !== n + 1 ||
            typeof entry.rowHead !== "string" || !/^[0-9a-f]{64}$/.test(entry.rowHead)) throw new Error("dispatcher ledger is not one chain");
        head = entry.postStateSha256; done.add(entry.requestId); n = entry.n; rowHead = entry.rowHead;
      }
    }
    return { head, done, n, rowHead };
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
      postStateSha256: sha256hex(canon(body.post)), intentSha256: sha256hex(row.intent), n: row.seq, rowHead: "" } };
  }
  flush(): FlushResult {
    closeSync(openSync(this.ledgerPath, "a"));   // (a missing ledger is judged in flushLocked: no lines = a NEW ledger)
    const lockPath = realpathSync(this.ledgerPath) + ".lock";
    let lock: number;
    try { lock = openSync(lockPath, "wx"); } catch { throw new Error("dispatcher lock is held: another run is active, or a stopped run left the lock file"); }
    try { return this.flushLocked(); } finally { closeSync(lock); unlinkSync(lockPath); }
  }
  // h1 (C-ATT-06): before any effect, the dispatcher applies the SAME store audit as the sink (core/store.ts): schema
  // text, integrity_check, meta (its initial charge must hash to the pinned initialStateSha256), and the compiled
  // ShellCoreV5 fold over every stored commit (signature, ids, bindings, replayed pre-state, the approved relation on the
  // REPLAYED charge), the row-log chain and AuditEnd. If the store audit is false, NOTHING is emitted in this run and every
  // pending row is refused. Then rows go out in seq order; the first row that fails the per-row check (incl. the ledger
  // chain) stops the run. So "no signing hypothesis" (AuditV5SoundRelativeToSuppliedInitial) also covers DISPATCHED effects:
  // same compiled function, TESTED here, not separately proved for this file.
  private flushLocked(): FlushResult {
    const { head: h0, done, n: ledgerN, rowHead } = this.ledger();
    let head = h0;
    const db = new DatabaseSync(this.dbPath, { readOnly: true });
    const result: FlushResult = { emitted: [], refused: [], alreadyDispatched: 0 };
    try {
      db.exec("BEGIN");
      const listed = db.prepare("SELECT seq, request_id FROM outbox NOT INDEXED ORDER BY seq").all() as { seq: number; request_id: unknown }[];
      const audited: AuditedRow[] = [];
      let why = "", genesis = "";
      try {
        const meta = readMeta(db);
        if (meta === undefined) throw new Error("the store has no meta row");
        if (sha256hex(meta.initial_state) !== this.cfg.initialStateSha256) throw new Error("meta initial state is not the pinned initial state");
        const init = JSON.parse(meta.initial_state);
        if (!isState(init) || canon(init) !== meta.initial_state || !validInitial(this.M, this.cv, init)) throw new Error("meta initial state is not a valid charge");
        const au = new StoreAuditor(this.M, this.cv, this.key, this.cfg, init);
        genesis = au.genesis;
        if (au.fullAudit(db, undefined, r => audited.push(r)) === null) throw new Error("AuditEnd, counts or refunded column is false");
      } catch (error) { why = String((error as Error).message); }
      db.exec("ROLLBACK");
      if (why !== "") {
        for (const r of listed) {
          const rid = typeof r.request_id === "string" ? r.request_id : String(r.request_id);
          if (done.has(rid)) result.alreadyDispatched++; else result.refused.push({ seq: r.seq, requestId: rid, reason: "store audit failed: " + why });
        }
        return result;
      }
      // The dispatcher as the row-log witness (h-anchor design, point 2). Its ledger says rows 1..ledgerN were dispatched
      // and the sink's head after them was rowHead. The store must still EXTEND that: otherwise STOP with an alarm
      // (a rollback or rewrite of the sink's store). No ledger lines and committed rows: an ERROR unless newLedgerH0.
      if (ledgerN === 0 && audited.length > 0 && this.cfg.newLedgerH0 !== genesis) {
        throw new Error("dispatcher alarm: the ledger is missing or empty but the store holds " + audited.length + " committed rows; a new ledger needs cfg.newLedgerH0 = the store's registered h_0");
      }
      if (ledgerN > 0 && (audited.length < ledgerN || audited[ledgerN - 1].self !== rowHead)) {
        throw new Error("dispatcher alarm: the sink's rows 1.." + ledgerN + " do not chain to the ledger's last rowHead (rollback or rewrite of the sink's store); nothing sent");
      }
      let stop = "";
      for (const r of audited) {
        if (r.seq <= ledgerN) { result.alreadyDispatched++; continue; }
        if (done.has(r.requestId)) throw new Error("dispatcher alarm: request id " + r.requestId + " is in the ledger but at another row; nothing more sent");
        if (stop !== "") { result.refused.push({ seq: r.seq, requestId: r.requestId, reason: stop }); continue; }
        const row = { seq: r.seq, request_id: r.requestId, intent: r.intent };
        const verdict = this.check(row, r.token, head);
        if (!verdict.ok) { result.refused.push({ seq: r.seq, requestId: r.requestId, reason: verdict.reason }); stop = "an earlier row was refused: " + verdict.reason; continue; }
        verdict.line.rowHead = r.self;
        const fd = openSync(this.ledgerPath, "a");
        try { writeSync(fd, JSON.stringify(verdict.line) + "\n"); fsyncSync(fd); } finally { closeSync(fd); }
        head = verdict.line.postStateSha256; done.add(r.requestId);
        const effect = { requestId: r.requestId, intent: r.intent };
        this.emit(effect, verdict.intent);    // the external effect: after the ledger line
        result.emitted.push(effect);
      }
    } finally { try { db.exec("ROLLBACK"); } catch { /* none */ } db.close(); }
    return result;
  }
}
