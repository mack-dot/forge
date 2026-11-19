// Slice 1 (F2.2): the sink, core-backed and hardened (h1; night shift 2026-11-19, task h-sink; h-sink2: C-ATT-21, 23 to 27,
// durability, repair; base: the v6 sink). The same exported interface as the earlier sink.ts, plus the REQUIRED config field
// initialState, the optional config fields expectedHead, outsideHead and onHead, head(), the head in each CommitResult, and
// the operator step Sink.recover. The store layout, the triggers, the file checks and the audit are in core/store.ts
// (shared with the dispatcher). Claims per attacker class, assumptions and limits: orch-B/h-sink2/HARDENING_NOTES_2.md.
// THE DECISION of commit() is the value of the compiled ShellCoreV6.StepQ6 (impl/finality-core/ShellCoreV6.dfy, compiled
// to core/sinkcore-v6.cjs by `dafny build --target js`; scripts/exit_slice1.py rebuilds it and compares). StepQ6 =
// ShellCoreV4.StepQ (ids, signature, request id, settled, pre-state, charge id) plus the approved relation AuthorizesX on
// the STORED charge (reason RejectNotAuthorized). Unchanged from v6.
// The start-up audit (core/store.ts StoreAuditor): schema TEXT compare (sqlite_schema rows incl. triggers), the FULL
// PRAGMA integrity_check, the header values user_version and application_id (0), the meta row, then the compiled
// ShellCoreV5 fold over every stored commit read NOT INDEXED as exact bytes (C-ATT-04), with Ed25519 re-verification, the
// replayed pre-state hash, the row-log chain and AuditEnd. Proved (ShellCoreV5.AuditV5SoundRelativeToSuppliedInitial):
// money is conserved RELATIVE TO THE SUPPLIED INITIAL CHARGE cfg.initialState (from outside the database).
// FILES (h-sink2, C-ATT-21/23): BEFORE the first SQLite lock the sink refuses a database with a -journal, -wal or -shm file
// next to it (a hot journal is applied by SQLite at the first lock, before any audit), a database with more than one hard
// link, and a header in WAL mode; it pins journal_mode = DELETE, synchronous = FULL and fullfsync = ON and reads them
// back. Before every write transaction it checks again: the same inode, one link, no -wal, no -shm; and (h-sink3,
// C-ATT-35) once more inside the write transaction right before COMMIT and once after COMMIT, before acknowledging. After
// an honest crash a -journal is legitimate: the sink then refuses to start (naming the journal's class), and the operator
// runs Sink.recover: a NOT-HOT journal (zero length or zero first byte: SQLite ignores it; C-ATT-33) is removed after a
// preview on a copy proves the store and head unchanged; a HOT journal is rolled back after a preview, and only when the
// step establishes that no acknowledged commit is lost (the depth rule, C-ATT-34). h-sink3 notes: HARDENING_NOTES_3.md.
// Assumption DIR-EXCLUSIVE: no other party can create, replace, rename or link files in the database directory.
// Database-level safeguards (DDL in core/store.ts): S1 request identity; S2 one-statement commit; S3 charge binding; S4
// cumulative refund limit with canonical money text; S5 append-only; S6 the row-log chain; NUL-free TEXT and typed INTEGER
// columns. They stop buggy or old writers and partial failures (attacker class b: a writer that keeps the schema). They do
// NOT stop a FILE writer (class c/d: drop triggers, `.dbconfig enable_trigger off`, PRAGMA ignore_check_constraints, page
// edits, a new file). SQLite has no hash function, so a trigger cannot refuse a wrong `self` or an unsigned token: such a
// row halts the store (repair: HARDENING_NOTES_2.md, item 8).
// Two signed transitions for one pre-state are NORMAL operation under the minter's per-(charge id, request id) rule (two
// requests minted on one state; the sink commits one, the other is refused as stale). They are not a sign of a faulty issuer.
// So a file writer WITHOUT the key can swap a committed row for the other signed transition and recompute the (unkeyed)
// chain (red team d14, C-ATT-25); and it can delete zero-amount rows or roll back to an earlier valid log (C-ATT-12, 27).
// What sees that: (1) the RUNNING sink: on a foreign change (data_version or the guard values) it re-checks schema text,
// integrity, header and meta, re-reads EVERY kept row (prefixSame: exact bytes, ids, token hashes, the chain recomputed to
// its kept head; C-ATT-24) and audits only new rows from the kept fold state (FoldResume); anything else HALTS the sink
// ("sink halted"). The commit path also compares the indexed lookup of the request id with the kept id map (C-ATT-24).
// (2) a RESTART: only with an outside head. cfg.expectedHead (h1): the stored log must EXTEND it; rows after it are not
// protected (C-ATT-27). cfg.outsideHead (h-sink2): the stored head must EQUAL outsideHead.committed or outsideHead.pending;
// with it the sink is the SINGLE WRITER: any foreign change halts. cfg.onHead(next) runs inside the write transaction,
// after every check and BEFORE the SQLite COMMIT (ANCHOR-FIRST); if it throws, nothing is committed. FRESHNESS RULE: the
// host persists onHead's value as `pending` before COMMIT, persists result.head as `committed` before it acknowledges the
// commit, and passes {committed, pending} at the next start (and committed as the dispatcher's expectedHead). Rollback
// resistance is claimed ONLY with that rule (attacker class d). Without an outside head (class c) the sink does not detect
// a rewrite or rollback that happened while it was stopped. S7: cfg.initialState must be a valid context.
// TypeScript does only: the decoder (K1), the Ed25519 call, the SHA-256 compares, the SQL reads and writes, the value
// conversion, the schema/meta/file compares, and the loops that call AuditStep once per row.
// NOT proved: this file, core/store.ts (DDL and triggers: TESTED-UNPROVED), the Dafny JS compiler and runtime,
// bignumber.js, SQLite (triggers, constraints, integrity_check, IMMEDIATE transactions, data_version, hot-journal
// rollback, fullfsync), the file system, Node, OpenSSL, SHA-256, Ed25519. Durability against power loss: NOT TESTED.
import { createPublicKey } from "node:crypto";
import { closeSync, copyFileSync, existsSync, fsyncSync, mkdtempSync, openSync, readFileSync, rmSync, unlinkSync, writeFileSync, writeSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { ChargeState, isState, canon, sha256hex } from "./encoding";
import { AuditedRow, CoreMod, Pos, SinkHead, StoreAuditor, StoreFile, STORE_FORMAT, checkStoreFile, classifyJournal, conv, createSchema, decodeToken, isHead,
  linkOf, loadCore, must, presentCompanions, readStateBlob, realStorePath, sameStoreFile, sigOkOf, validInitial } from "./core/store";
export { STORE_FORMAT, SINK_DDL, genesisOf, linkOf } from "./core/store";
export type { SinkHead } from "./core/store";

// outsideHead: the host's persisted outside head (see the header): committed = the head of the last acknowledged commit;
// pending = the value that onHead received for a commit not yet acknowledged (absent when none).
export type OutsideHead = { committed: SinkHead; pending?: SinkHead };
export type SinkConfig = { publicKeyPem: string; specLockSha256: string; checkerSha256: string; initialState: ChargeState; expectedHead?: SinkHead;
  outsideHead?: OutsideHead; onHead?: (next: SinkHead) => void };
// head: the audited head after this call (absent when the sink is halted or the decoder refused the input).
export type CommitResult = { status: "committed" | "replayed" | "rejected"; reason?: string; head?: SinkHead };
export type OutboxRow = { seq: number; request_id: string; intent: string };
export type RecoverReport = { companions: string[]; before: SinkHead | string; after: SinkHead | string; rolledBack: number | null; applied: boolean; reason: string;
  journalClass?: "hot" | "not-hot"; journalWhy?: string };

const sameHead = (a: SinkHead, b: SinkHead): boolean => a.count === b.count && a.chainHash === b.chainHash;
// Pins and reads back the durability and journal settings (item 7 of h-sink2). Throws if SQLite does not keep them.
function pinPragmas(db: DatabaseSync): void {
  db.exec("PRAGMA busy_timeout = 30000");
  const jm = String((db.prepare("PRAGMA journal_mode = DELETE").get() as any).journal_mode);
  db.exec("PRAGMA synchronous = FULL; PRAGMA fullfsync = ON");
  const sy = Number((db.prepare("PRAGMA synchronous").get() as any).synchronous), ff = Number((db.prepare("PRAGMA fullfsync").get() as any).fullfsync);
  if (jm !== "delete" || sy !== 2 || ff !== 1) throw new Error("SQLite did not keep journal_mode = DELETE, synchronous = FULL, fullfsync = ON (got " + jm + ", " + sy + ", " + ff + ")");
}

export class Sink {
  private readonly db: DatabaseSync;
  private readonly M: CoreMod;
  private readonly cv: ReturnType<typeof conv>;
  private readonly au: StoreAuditor;
  private readonly file: StoreFile;
  private pos: Pos;                   // the audited position after this sink's last transaction (in memory)
  private rids: string[] = [];        // the request id of each audited row, by seq - 1 (C-ATT-24)
  private ids = new Map<string, string>();   // request id -> token_sha256 of each audited row (C-ATT-24)
  private dv = -1;                    // PRAGMA data_version after this sink's last transaction
  private guard = "";                 // [stored state, max seq settled, max seq outbox, last self] after it
  private halted: string | null = null;
  public reaudits = 0;                // number of guard-triggered re-checks (for tests)
  constructor(path: string, private readonly cfg: SinkConfig) {
    if (cfg === null || typeof cfg !== "object" || !isState((cfg as any).initialState)) {
      throw new Error("h1 sink refuses to serve: cfg.initialState is required (the initial charge, from outside the database)");
    }
    if (cfg.expectedHead !== undefined && !isHead(cfg.expectedHead)) throw new Error("h1 sink refuses to serve: cfg.expectedHead is not {count, chainHash}");
    const oh = cfg.outsideHead;
    if (oh !== undefined && (oh === null || typeof oh !== "object" || !isHead(oh.committed) || (oh.pending !== undefined && !isHead(oh.pending)))) {
      throw new Error("h1 sink refuses to serve: cfg.outsideHead is not {committed: {count, chainHash}, pending?: {count, chainHash}}");
    }
    if (cfg.onHead !== undefined && typeof cfg.onHead !== "function") throw new Error("h1 sink refuses to serve: cfg.onHead is not a function");
    this.M = loadCore();
    this.cv = conv(this.M);
    if (!validInitial(this.M, this.cv, cfg.initialState)) {
      throw new Error("h1 sink refuses to serve: cfg.initialState is not a valid context (charge id, refunds enabled, original <= MaxMoney, 0 <= remaining <= original)");
    }
    this.au = new StoreAuditor(this.M, this.cv, createPublicKey(cfg.publicKeyPem), cfg, cfg.initialState);
    this.pos = this.au.start();
    // C-ATT-21/23: the files, BEFORE the first SQLite lock (no -journal, -wal, -shm; one link; rollback-journal header).
    try { checkStoreFile(path); } catch (error) { throw new Error("h1 sink refuses to serve: " + String((error as Error).message)); }
    this.db = new DatabaseSync(path);
    let ok = false, why = "";
    let file: StoreFile | undefined;
    try {
      pinPragmas(this.db);
      // C-ATT-02: a file with no committed schema gets the WHOLE schema in one transaction; any other file is never
      // changed here: the schema check decides.
      createSchema(this.db);
      file = checkStoreFile(path, ["-wal", "-shm"]);
      // The start-up audit (schema, integrity, header, meta, compiled AuditV5 fold, chain, anchors). No option skips it.
      this.db.exec("BEGIN IMMEDIATE");
      const rows: AuditedRow[] = [];
      const at = this.au.fullAudit(this.db, cfg.expectedHead ?? oh?.committed, r => rows.push(r));
      if (at !== null && this.outsideOk(at)) { this.pos = at; this.keep(rows, true); ok = true; }
      else if (at !== null) why = ": the stored head " + at.count + " is not the outside head (committed " + oh!.committed.count + (oh!.pending ? ", pending " + oh!.pending.count : "") + ")";
      this.mark(readStateBlob(this.db));
      this.db.exec("ROLLBACK");
    } catch (error) {
      try { this.db.exec("ROLLBACK"); } catch { /* no open transaction */ }
      why = ": " + String((error as Error).message);
    }
    if (!ok || file === undefined) {
      this.db.close();
      throw new Error("h1 sink refuses to serve: start-up audit (schema, integrity, initial charge, AuditV5 replay, chain, anchor) is false" + why);
    }
    this.file = file;
  }
  // cfg.outsideHead: the stored head must EQUAL committed or pending (not merely extend committed: C-ATT-27).
  private outsideOk(at: Pos): boolean {
    const oh = this.cfg.outsideHead;
    if (oh === undefined) return true;
    const h = { count: at.count, chainHash: at.chain };
    return sameHead(h, oh.committed) || (oh.pending !== undefined && sameHead(h, oh.pending));
  }
  private keep(rows: AuditedRow[], reset: boolean): void {
    if (reset) { this.rids = []; this.ids = new Map(); }
    for (const r of rows) { this.rids.push(r.requestId); this.ids.set(r.requestId, r.tokenSha256); }
  }
  // Before each write transaction: the files (DIR-EXCLUSIVE checks). A violation halts the sink.
  private fileCheck(): string | null {
    const bad = sameStoreFile(this.file, this.cfg.outsideHead !== undefined);
    if (bad !== "") this.halted = bad;
    return this.halted;
  }
  // Writes meta (and, by trigger h_meta_ai, the state row) once. Only cfg.initialState may be written.
  init(state: ChargeState): void {
    if (!isState(state)) throw new Error("initial state shape");
    const blob = canon(state);
    if (blob !== this.au.initText) throw new Error("initial state is not cfg.initialState");
    if (this.halted !== null || this.fileCheck() !== null) throw new Error("sink halted: " + this.halted);
    this.db.exec("BEGIN IMMEDIATE");
    try {
      const stored = readStateBlob(this.db);
      if (this.changed(stored)) {                       // another writer acted since this sink's last transaction
        if (this.cfg.outsideHead !== undefined) throw new Error("another writer changed the store (cfg.outsideHead: single writer)");
        const rows: AuditedRow[] = [];
        const at = this.au.fullAudit(this.db, undefined, r => rows.push(r));
        if (at === null) throw new Error("another writer changed the store and the full audit is false");
        this.pos = at; this.keep(rows, true);
      }
      if (this.db.prepare("SELECT 1 AS x FROM meta WHERE id = 1").get() === undefined) {
        this.db.prepare("INSERT INTO meta(id, format, charge_id, initial_state, initial_state_sha256, genesis) VALUES (1, ?, ?, ?, ?, ?)")
          .run(STORE_FORMAT, state.chargeId, blob, sha256hex(blob), this.au.genesis);
      }
      this.mark(readStateBlob(this.db));
      this.db.exec("COMMIT");
    } catch (error) { this.db.exec("ROLLBACK"); throw error; }
  }
  // The durability and journal settings of this sink's connection, read back from SQLite (h-sink2, item 7).
  pragmas(): { journal_mode: string; synchronous: number; fullfsync: number } {
    const g = (p: string) => (this.db.prepare("PRAGMA " + p).get() as any)[p];
    return { journal_mode: String(g("journal_mode")), synchronous: Number(g("synchronous")), fullfsync: Number(g("fullfsync")) };
  }
  // The audited head after this sink's last transaction: count of commits and the chain hash (genesis for 0).
  head(): SinkHead { return { count: this.pos.count, chainHash: this.pos.chain }; }
  storedBlob(): string | undefined { return readStateBlob(this.db); }
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
  // ---- the writer guard: values read inside the open transaction. O(log n) each (rowid b-tree max).
  private dataVersion(): number { return Number((this.db.prepare("PRAGMA data_version").get() as any).data_version); }
  private guardOf(stored: string | undefined): string {
    const g = this.db.prepare("SELECT (SELECT MAX(seq) FROM settled) AS ms, (SELECT MAX(seq) FROM outbox) AS mo, " +
      "(SELECT hex(self) FROM outbox WHERE seq = (SELECT MAX(seq) FROM outbox)) AS h").get() as any;
    return JSON.stringify([stored ?? null, g.ms, g.mo, g.h]);
  }
  private mark(stored: string | undefined): void { this.dv = this.dataVersion(); this.guard = this.guardOf(stored); }
  private changed(stored: string | undefined): boolean { return this.dataVersion() !== this.dv || this.guardOf(stored) !== this.guard; }
  // S6 / review F2 / C-ATT-12 / C-ATT-24: a foreign change is accepted only as an APPEND of audit-passing rows after this
  // sink's head, with EVERY kept row unchanged (prefixSame). With cfg.outsideHead no foreign change is accepted.
  private foreignCheck(stored: string | undefined): { at: Pos; rows: AuditedRow[] } | null {
    if (this.cfg.outsideHead !== undefined) return null;
    if (!this.au.schemaAndMeta(this.db)) return this.pos.count === 0 && stored === undefined ? { at: this.pos, rows: [] } : null;
    if (stored === undefined || !this.au.prefixSame(this.db, this.pos, this.rids)) return null;
    const rows: AuditedRow[] = [];
    const at = this.au.auditFrom(this.db, this.pos, stored, undefined, r => rows.push(r));
    return at === null ? null : { at, rows };
  }
  private halt(why: string): CommitResult {
    this.halted = why;
    try { this.db.exec("ROLLBACK"); } catch { /* no open transaction */ }
    return { status: "rejected", reason: "sink halted: " + this.halted };
  }
  commit(input: unknown): CommitResult {
    // (1) the decoder (K1), unchanged from sink.ts. It can only refuse.
    const token = decodeToken(input);
    if (typeof token === "string") return { status: "rejected", reason: token };
    if (this.halted !== null || this.fileCheck() !== null) return { status: "rejected", reason: "sink halted: " + this.halted };
    const { M, cv } = this, b = token.body;
    const tokenText = input as string, tokenSha256 = sha256hex(tokenText);
    const sigOk = sigOkOf(this.au.key, token);
    const tok = M.Shell.ShellToken.create_ShellToken(
      new M.BigNumber(b.specLockSha256 === this.cfg.specLockSha256 ? 1 : 0), new M.BigNumber(b.checkerSha256 === this.cfg.checkerSha256 ? 2 : 0),
      cv.text(b.requestId), cv.charge(b.post), cv.intent(b.intent), cv.text(""));
    let committing = false;
    try {
      this.db.exec("BEGIN IMMEDIATE");
      let stored: string | undefined;
      try { stored = readStateBlob(this.db); } catch (error) {
        return this.halt("the state row cannot be read: " + String((error as Error).message));
      }
      // (iv) the writer guard: a foreign change -> schema, integrity, header, meta, every kept row, new rows; false -> HALT.
      if (this.changed(stored)) {
        this.reaudits++;
        let r: { at: Pos; rows: AuditedRow[] } | null = null, why = "";
        try { r = this.foreignCheck(stored); } catch (error) { r = null; why = ": " + String((error as Error).message); }
        if (r === null) return this.halt("another writer changed the store and the change is not an append of audit-passing rows" +
          (this.cfg.outsideHead !== undefined ? " (cfg.outsideHead: single writer)" : "") + why);
        this.pos = r.at; this.keep(r.rows, false);
        this.mark(stored);
      }
      // (i) constant state: the stored charge and ONE indexed lookup, compared with the kept id map (C-ATT-24: a row
      // changed behind the sink, with data_version unchanged or not, never yields a second commit for a kept id).
      const charge = stored === undefined ? M.F.Charge.Default() : (() => { const v = JSON.parse(stored); return cv.charge(must(isState(v), v, "state")); })();
      const preOk = stored !== undefined && sha256hex(stored) === b.preStateSha256;   // A4'
      const prior = this.db.prepare("SELECT token_sha256 FROM settled WHERE request_id = ?").get(b.requestId) as { token_sha256: string } | undefined;
      if (prior?.token_sha256 !== this.ids.get(b.requestId)) return this.halt("the stored row of request id " + JSON.stringify(b.requestId) + " is not the audited one (a change behind the sink)");
      // THE DECISION: one call of the compiled core.
      const q = M.Shell6.__default.StepQ6(charge, tok, sigOk, preOk, prior !== undefined);
      if (q.is_Commit) {
        // exactly the StepQ result (Apply): state := newCharge; settled += addId; outbox += intent. ONE statement (S2):
        // the triggers write the outbox row and the state row from the token text; the reads below compare them with
        // the core's values and roll back on any difference.
        const rid = cv.back(q.dtor_addId), next = canon(cv.backCharge(q.dtor_newCharge)), intent = canon(cv.backIntent(q.dtor_intent));
        const seq = this.pos.count + 1, prev = this.pos.chain, self = linkOf(prev, tokenText, intent);
        this.db.prepare("INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (?, ?, ?, ?, ?, ?)").run(seq, rid, tokenText, tokenSha256, prev, self);
        const o = this.db.prepare("SELECT hex(request_id) AS r, hex(intent) AS i FROM outbox WHERE seq = ?").get(seq) as any;
        if (readStateBlob(this.db) !== next || o === undefined || o.r !== Buffer.from(rid, "utf8").toString("hex").toUpperCase() ||
            o.i !== Buffer.from(intent, "utf8").toString("hex").toUpperCase()) throw new Error("stored rows are not the core's Commit value");
        // The kept fold state advances by the same AuditStep the audit uses (the stored pre-state is the fold's state).
        const st = M.Shell5.__default.AuditStep(this.au.initCore.dtor_chargeId, this.pos.st, M.Shell5.Row.create_Row(q.dtor_addId, tok, sigOk, preOk, q.dtor_intent));
        if (st.dtor_ok !== true) throw new Error("the kept audit fold refuses this commit");
        const head = { count: seq, chainHash: self };
        // ANCHOR-FIRST (C-ATT-27): the host persists the next head BEFORE the COMMIT; a throw here commits nothing.
        if (this.cfg.onHead !== undefined) {
          try { this.cfg.onHead({ ...head }); } catch (error) {
            this.db.exec("ROLLBACK");
            return { status: "rejected", reason: "the outside head was not persisted (onHead threw): " + String((error as Error)?.message ?? error), head: this.head() };
          }
        }
        // C-ATT-35 (h-sink3): the file check AGAIN, inside the write transaction (the RESERVED lock is held) and after
        // onHead, right before COMMIT: the same inode at the path, one link, no -wal, no -shm (this transaction's own
        // -journal is expected here). A replaced inode makes this commit roll back and halts the sink.
        const inside = sameStoreFile(this.file, false);
        if (inside !== "") return this.halt(inside + " (seen inside the write transaction, before COMMIT; row " + seq + " is not committed)");
        const before = { pos: this.pos, dv: this.dv, guard: this.guard };
        this.pos = { st, count: seq, chain: self };
        this.mark(next);
        committing = true;
        try { this.db.exec("COMMIT"); } catch (error) {
          this.pos = before.pos; this.dv = before.dv; this.guard = before.guard;
          return this.halt("COMMIT failed after the checks (the store may or may not hold row " + seq + "): " + String((error as Error).message));
        }
        this.keep([{ requestId: rid, tokenSha256 } as AuditedRow], false);
        // C-ATT-35 (h-sink3): and once more AFTER COMMIT, before the acknowledgement: if the path no longer names the inode
        // that took the commit, the row may exist only in an unlinked inode; it is NOT acknowledged (the host must not
        // count it) and the sink halts. Remaining window: a replacement after this check and before the host persists
        // result.head (stated in HARDENING_NOTES_3.md).
        const after = sameStoreFile(this.file, false);
        if (after !== "") { this.halted = after + " (seen after COMMIT of row " + seq + "; the row may exist only in the replaced inode; not acknowledged)"; return { status: "rejected", reason: "sink halted: " + this.halted }; }
        return { status: "committed", head };
      }
      this.db.exec("ROLLBACK");
      const h = this.head();
      if (q.is_RejectNotAuthorized) return { status: "rejected", reason: "not authorized by the approved relation for the stored state", head: h };
      return { ...this.label(q.dtor_why, prior?.token_sha256 === tokenSha256, stored === undefined, b.specLockSha256 === this.cfg.specLockSha256), head: h };
    } catch (error) {
      try { this.db.exec("ROLLBACK"); } catch { /* no open transaction */ }
      if (committing) return this.halt("transaction failed during COMMIT: " + String((error as Error).message));
      return { status: "rejected", reason: "transaction failed: " + String((error as Error).message) };
    }
  }
  // The label of a rejection: the text that sink.ts returns. It never changes the store.
  private label(why: any, sameToken: boolean, noState: boolean, specOk: boolean): CommitResult {
    if (why.is_IdsNotPinned) return { status: "rejected", reason: specOk ? "checker is not the pinned one" : "spec lock is not the pinned one" };
    if (why.is_SignatureInvalid) return { status: "rejected", reason: "signature does not verify" };
    if (why.is_ReqIdMismatch) return { status: "rejected", reason: "request id is not the intent's request id" };
    if (why.is_RequestSettled) return sameToken ? { status: "replayed" } : { status: "rejected", reason: "request id is already settled with another token" };
    if (why.is_PreStateMismatch) return { status: "rejected", reason: noState ? "the sink has no stored state" : "stored state is not the token's pre-state" };
    if (why.is_ChargeIdMismatch) return { status: "rejected", reason: "charge id is not the stored charge id" };
    return { status: "rejected", reason: "core: " + String(why) };
  }
  // Offline audit: the problems the full store audit finds (empty = none). Not part of the commit decision.
  audit(): string[] {
    try {
      this.db.exec("BEGIN");
      if (readStateBlob(this.db) === undefined) return ["the sink has no stored state"];
      return this.au.fullAudit(this.db) === null ? ["store audit is false (AuditEnd, counts, refunded, or anchor)"] : [];
    } catch (error) { return ["store audit: " + String((error as Error).message)]; }
    finally { try { this.db.exec("ROLLBACK"); } catch { /* none */ } }
  }
  close(): void { this.db.close(); }

  // THE REPAIR READER (h-sink2, item 8; read only). A store with one row that the triggers accept but the audit refuses
  // (an unsigned token, a wrong `self`: SQLite has no hash function, so no trigger can refuse it) halts for good. The
  // repair never edits a store in place: (1) read the valid prefix with this function (the token texts of the rows that
  // the compiled AuditStep accepted, in order, and their head); (2) create a NEW store file at a new path with the same
  // cfg (the same genesis), init(cfg.initialState), and commit the prefix tokens in order: every commit must be
  // "committed", and the new head must equal prefixHead; (3) append to the operator log: old path, old file's SHA-256,
  // `problem`, prefixHead, new path; keep the old file; (4) if the host keeps an outside head, the new head must equal
  // or extend it (else acknowledged rows are lost: stop and escalate); (5) point the host and the dispatcher (same ledger:
  // the claimed rows keep their row heads) to the new path. Request ids of the prefix stay settled in the new store.
  static validPrefix(path: string, cfg: SinkConfig): { tokens: string[]; prefixHead: SinkHead; complete: boolean; problem: string } {
    const M = loadCore(), cv = conv(M);
    if (!isState(cfg.initialState) || !validInitial(M, cv, cfg.initialState)) throw new Error("cfg.initialState is not a valid context");
    const au = new StoreAuditor(M, cv, createPublicKey(cfg.publicKeyPem), cfg, cfg.initialState);
    checkStoreFile(path);
    const db = new DatabaseSync(path, { readOnly: true }), tokens: string[] = [];
    let head: SinkHead = { count: 0, chainHash: au.genesis }, problem = "";
    try {
      db.exec("BEGIN");
      try {
        if (au.fullAudit(db, undefined, r => { tokens.push(r.token); head = { count: r.seq, chainHash: r.self }; }) === null) problem = "AuditEnd, counts or refunded column is false after the last row";
      } catch (error) { problem = String((error as Error).message); }
      db.exec("ROLLBACK");
    } finally { db.close(); }
    return { tokens, prefixHead: head, complete: problem === "", problem };
  }
  // THE OPERATOR STEP after a crash (C-ATT-21; h-sink2; h-sink3: C-ATT-33, C-ATT-34). The sink refuses to start while a
  // -journal exists. This step: (1) refuses -wal and -shm (the sink pins journal_mode = DELETE and never makes them: a
  // person must inspect and remove them) and a database with more than one link; (2) classifies the journal by SQLite's
  // hot-journal rule (core/store.ts classifyJournal).
  // NOT HOT (zero length or zero first byte; C-ATT-33): SQLite ignores such a journal, so it cannot change the store. The
  // step proves that on COPIES before it touches the real files: (a) the copy without the journal passes the audit
  // (head B); (b) a copy WITH the journal is opened by SQLite and audited: the journal must still be there, byte-equal, the
  // database copy byte-equal, and the head equal to B (SQLite ignored it); (c) on the real database, under a RESERVED lock
  // (BEGIN IMMEDIATE: no other writer; SQLite's own rule H2), the journal must still be byte-equal to the previewed one; it
  // is removed (directory synced) and the real store audited: its head must be B; with cfg.outsideHead, B must equal
  // committed or pending. Nothing is rolled back.
  // HOT: (3) audits a COPY of the database WITHOUT the journal ("before"; after a real crash it may be unreadable or hold
  // the unfinished commit); (4) applies the journal to a second COPY (SQLite's own hot-journal rollback) and audits it
  // ("after"), with cfg.expectedHead / cfg.outsideHead as at start; (5) THE DEPTH RULE (C-ATT-34): the step reports
  // success only when it ESTABLISHES that the rollback loses no acknowledged commit: either (i) "before" passes the audit
  // and "after" is "before" or "before" minus its last row (an honest crash rolls back at most the one unfinished,
  // unacknowledged commit; in DELETE mode the commit point is the journal's deletion, and the sink acknowledges only
  // after COMMIT returned), or (ii) cfg.outsideHead is given (the host's persisted heads under the FRESHNESS RULE) and
  // "after" EQUALS outsideHead.committed or outsideHead.pending: the outside head authorises exactly that head. Every other
  // case is refused: also a "before" that fails the audit without cfg.outsideHead (the head before the rollback is then
  // unknown, so the depth of the rollback is unknown; cfg.expectedHead does not authorise it: it only bounds from below).
  // (6) only then applies the journal to the real database and audits it again: its head must be the previewed "after".
  // (7) One JSON line with the files, the class, the heads before and after and the decision is appended to logPath and
  // synced. The real files are not changed when the step refuses. Without an outside head, a planted journal that rolls
  // back exactly one row of a valid store is indistinguishable from an honest crash (stated limit). Temporary copies are
  // removed.
  static recover(path: string, cfg: SinkConfig, logPath: string): RecoverReport {
    const report: RecoverReport = { companions: presentCompanions(path), before: "", after: "", rolledBack: null, applied: false, reason: "" };
    const log = () => {
      const fd = openSync(logPath, "a");
      try { writeSync(fd, JSON.stringify({ at: new Date().toISOString(), path: realStorePath(path), ...report }) + "\n"); fsyncSync(fd); } finally { closeSync(fd); }
    };
    const refuse = (why: string): RecoverReport => { report.reason = why; log(); throw new Error("Sink.recover refuses: " + why); };
    try { checkStoreFile(path, ["-wal", "-shm"]); } catch (error) { return refuse(String((error as Error).message)); }
    const real = realStorePath(path), journal = presentCompanions(path, ["-journal"]);
    if (journal.length === 0) { report.reason = "no -journal: nothing to recover"; log(); return report; }
    if (journal.length !== 1 || journal[0] !== real + "-journal") return refuse("the journal is not at the real path of the database: " + journal.join(", "));
    const jc = classifyJournal(path);
    if (jc.kind === "none") return refuse("the journal disappeared during the step");
    report.journalClass = jc.kind; report.journalWhy = jc.why;
    const M = loadCore(), cv = conv(M);
    if (!isState(cfg.initialState) || !validInitial(M, cv, cfg.initialState)) return refuse("cfg.initialState is not a valid context");
    const au = new StoreAuditor(M, cv, createPublicKey(cfg.publicKeyPem), cfg, cfg.initialState);
    const auditAt = (p: string, anchor?: SinkHead): Pos => {
      const db = new DatabaseSync(p);
      try {
        db.exec("BEGIN IMMEDIATE");
        const at = au.fullAudit(db, anchor);
        db.exec("ROLLBACK");
        if (at === null) throw new Error("the audit is false");
        return at;
      } finally { db.close(); }
    };
    const oh = cfg.outsideHead;
    const outsideAuthorises = (h: SinkHead): boolean => oh !== undefined && (sameHead(h, oh.committed) || (oh.pending !== undefined && sameHead(h, oh.pending)));
    const tmp = mkdtempSync(join(tmpdir(), "forge-sink-recover-"));
    try {
      if (jc.kind === "not-hot") {
        const dbBytes = readFileSync(real);
        writeFileSync(join(tmp, "before.sqlite"), dbBytes);
        let before: Pos;
        try { before = auditAt(join(tmp, "before.sqlite"), cfg.expectedHead ?? oh?.committed); } catch (error) { return refuse("not-hot journal: the store without it does not pass the audit: " + String((error as Error).message).slice(0, 200)); }
        report.before = { count: before.count, chainHash: before.chain };
        if (oh !== undefined && !outsideAuthorises(report.before)) return refuse("not-hot journal: the stored head is not the outside head");
        const w = join(tmp, "with.sqlite");
        writeFileSync(w, dbBytes); writeFileSync(w + "-journal", jc.bytes);
        let withJ: Pos;
        try { withJ = auditAt(w, cfg.expectedHead ?? oh?.committed); } catch (error) { return refuse("not-hot journal: the copy with the journal does not pass the audit: " + String((error as Error).message).slice(0, 200)); }
        const ignored = existsSync(w + "-journal") && readFileSync(w + "-journal").equals(jc.bytes) && readFileSync(w).equals(dbBytes);
        if (!ignored || withJ.count !== before.count || withJ.chain !== before.chain) return refuse("not-hot journal: SQLite did not ignore it on the copy (the classifier disagrees with SQLite); nothing removed");
        report.after = { count: withJ.count, chainHash: withJ.chain }; report.rolledBack = 0;
        // The real files: under a RESERVED lock (no other writer), the same journal bytes; remove; audit; same head.
        const d = new DatabaseSync(real);
        try {
          pinPragmas(d);
          d.exec("BEGIN IMMEDIATE");
          try {
            const again = classifyJournal(path);
            if (again.kind !== "not-hot" || !again.bytes.equals(jc.bytes)) return refuse("not-hot journal: the journal changed during the step; nothing removed");
            if (!readFileSync(real).equals(dbBytes)) return refuse("not-hot journal: the database file changed during the step; nothing removed");
            unlinkSync(real + "-journal");
            const dfd = openSync(dirname(real), "r");
            try { fsyncSync(dfd); } finally { closeSync(dfd); }
            report.applied = true;
            const now = au.fullAudit(d, cfg.expectedHead ?? oh?.committed);
            if (now === null || now.count !== before.count || now.chain !== before.chain) return refuse("not-hot journal removed, but the real store's head is not the previewed head (the files changed during the step)");
          } finally { try { d.exec("ROLLBACK"); } catch { /* none */ } }
        } finally { d.close(); }
        report.reason = "recovered: a not-hot journal (" + jc.why + ") was removed; SQLite ignores it; the store and its head are unchanged";
        log();
        return report;
      }
      let before: Pos | null = null;
      copyFileSync(real, join(tmp, "before.sqlite"));
      try { before = auditAt(join(tmp, "before.sqlite")); report.before = { count: before.count, chainHash: before.chain }; } catch (error) { report.before = "not a valid log: " + String((error as Error).message).slice(0, 200); }
      copyFileSync(real, join(tmp, "after.sqlite")); copyFileSync(real + "-journal", join(tmp, "after.sqlite-journal"));
      let after: Pos;
      try { after = auditAt(join(tmp, "after.sqlite"), cfg.expectedHead ?? oh?.committed); } catch (error) { return refuse("the recovered copy does not pass the audit: " + String((error as Error).message).slice(0, 200)); }
      report.after = { count: after.count, chainHash: after.chain };
      const ah = report.after;
      if (oh !== undefined && !outsideAuthorises(ah)) return refuse("the recovered head is not the outside head");
      // THE DEPTH RULE (5).
      if (before === null) {
        if (oh === undefined) return refuse("the live file does not pass the audit, so the head before the rollback is unknown and so is the depth of the rollback; supply cfg.outsideHead (the persisted committed/pending heads) to authorise exactly the recovered head");
      } else {
        report.rolledBack = before.count - after.count;
        const prefixOk = before.count === after.count ? before.chain === after.chain : (before.count === after.count + 1 && (() => {
          const d = new DatabaseSync(join(tmp, "before.sqlite"), { readOnly: true });
          try { return (d.prepare("SELECT prev FROM settled WHERE seq = ?").get(before.count) as any)?.prev === after.chain; } finally { d.close(); }
        })());
        if (!prefixOk && !outsideAuthorises(ah)) return refuse("the journal would roll back " + report.rolledBack + " row(s) of a valid log (an honest crash rolls back at most the one unfinished commit; only cfg.outsideHead can authorise this exact head)");
      }
      const d = new DatabaseSync(real);
      try { pinPragmas(d); d.prepare("SELECT COUNT(*) AS n FROM sqlite_schema").get(); } finally { d.close(); }
      report.applied = true;
      if (existsSync(real + "-journal")) return refuse("the journal is still present after the rollback");
      const now = auditAt(real, cfg.expectedHead ?? oh?.committed);
      if (now.count !== after.count || now.chain !== after.chain) return refuse("the real database after the rollback is not the previewed copy (the files changed during the step)");
      report.reason = "recovered";
      log();
      return report;
    } finally { rmSync(tmp, { recursive: true, force: true }); }
  }
}
