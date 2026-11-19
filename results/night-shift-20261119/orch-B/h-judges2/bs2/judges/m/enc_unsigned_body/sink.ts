// MUTANT enc_unsigned_body (c19 attack input; edited copy of fix-f08a21c1). NOT a fix.
// Slice 1 (F2.2): the sink, core-backed and hardened (h1; night shift 2026-11-19, task h-sink; base: the v6 sink).
// The same exported interface as the earlier sink.ts, plus the REQUIRED config field initialState, the optional config
// field expectedHead, and head(). The store layout, the triggers and the audit are in core/store.ts (shared with the
// dispatcher).
// THE DECISION of commit() is the value of the compiled ShellCoreV6.StepQ6 (impl/finality-core/ShellCoreV6.dfy, compiled
// to core/sinkcore-v6.cjs by `dafny build --target js`; scripts/exit_slice1.py rebuilds it and compares). StepQ6 =
// ShellCoreV4.StepQ (ids, signature, request id, settled, pre-state, charge id) plus the approved relation AuthorizesX on
// the STORED charge (reason RejectNotAuthorized). Unchanged from v6.
// The start-up audit (core/store.ts StoreAuditor): schema TEXT compare (sqlite_schema rows incl. triggers), the FULL
// PRAGMA integrity_check (index b-trees agree with their tables; the schema text compare alone does not see a substituted
// index b-tree: red team C-ATT-10/11), the meta row, then the compiled ShellCoreV5 fold over every stored commit read
// NOT INDEXED as exact bytes (C-ATT-04), with Ed25519 re-verification, the replayed pre-state hash, the row-log chain and
// AuditEnd (replayed charge == stored charge; row counts of both tables and the number of distinct request ids, all
// computed from the TABLE rows, equal). Proved (ShellCoreV5.AuditV5SoundRelativeToSuppliedInitial): money is conserved
// RELATIVE TO THE SUPPLIED INITIAL CHARGE cfg.initialState (THE ANCHOR; from outside the database).
// Database-level safeguards (DDL in core/store.ts): S1 request identity; S2 one-statement commit (INSERT INTO settled;
// its trigger writes outbox and state; direct writes of outbox or state are refused); S3 charge binding (immutable meta);
// S4 cumulative refund limit with canonical money text; S5 append-only; S6 the row-log chain; NUL-free TEXT and typed
// INTEGER columns. They stop buggy or old writers and partial failures. They do NOT stop a hostile writer with full file
// access (drop triggers, `.dbconfig enable_trigger off` in the sqlite3 shell, PRAGMA ignore_check_constraints, a new file).
// What the audit sees of such a writer: a changed schema text; a broken index; any row that the compiled AuditStep
// refuses; a broken chain. What it does NOT see without an external anchor (cfg.expectedHead): a rollback to an earlier
// valid log; a log rewritten with a recomputed (unkeyed) chain whose rows all pass the audit, e.g. zero-amount rows
// deleted, or one of two transitions that a faulty issuer signed for one pre-state swapped for the other (a writer
// WITHOUT the key can do that swap: red team d14; the earlier v6 comment said such a writer "holds the signing key").
// cfg.expectedHead: the sink starts only if the stored log EXTENDS it (row expectedHead.count has that chain hash; later
// rows pass the audit). The running sink keeps its audited head and fold state in memory; on a foreign change (data_version
// or the guard values) it re-checks schema text, integrity and meta, re-hashes its head row, and audits ONLY the new rows
// from the kept fold state (FoldResume). Anything else (a changed or missing head row: a rollback, red team C-ATT-12) HALTS
// the sink: every later commit is refused with "sink halted". S7: cfg.initialState must be a valid context (compiled
// Refund.ValidContext; review r-v5 finding F4).
// TypeScript does only: the decoder (K1), the Ed25519 call, the SHA-256 compares, the SQL reads and writes, the value
// conversion, the schema/meta compare, and the loops that call AuditStep once per row.
// NOT proved: this file, core/store.ts (DDL and triggers: TESTED-UNPROVED), the Dafny JS compiler and runtime,
// bignumber.js, SQLite (triggers, constraints, integrity_check, IMMEDIATE transactions, data_version), Node, OpenSSL,
// SHA-256, Ed25519.
import { createPublicKey } from "node:crypto";
import { DatabaseSync } from "node:sqlite";
import { ChargeState, isState, canon, sha256hex } from "<REPO>/results/night-shift-20261119/orch-C/c19-dispatch2/judges/m/enc_unsigned_body/lib/encoding";
import { CoreMod, Pos, SinkHead, StoreAuditor, STORE_FORMAT, conv, createSchema, decodeToken, isHead, linkOf, loadCore,
  must, readStateBlob, sigOkOf, validInitial } from "<REPO>/results/night-shift-20261119/orch-C/c19-dispatch2/judges/m/enc_unsigned_body/store";
export { STORE_FORMAT, SINK_DDL, genesisOf, linkOf } from "<REPO>/results/night-shift-20261119/orch-C/c19-dispatch2/judges/m/enc_unsigned_body/store";
export type { SinkHead } from "<REPO>/results/night-shift-20261119/orch-C/c19-dispatch2/judges/m/enc_unsigned_body/store";

export type SinkConfig = { publicKeyPem: string; specLockSha256: string; checkerSha256: string; initialState: ChargeState; expectedHead?: SinkHead };
export type CommitResult = { status: "committed" | "replayed" | "rejected"; reason?: string };
export type OutboxRow = { seq: number; request_id: string; intent: string };

export class Sink {
  private readonly db: DatabaseSync;
  private readonly M: CoreMod;
  private readonly cv: ReturnType<typeof conv>;
  private readonly au: StoreAuditor;
  private pos: Pos;                   // the audited position after this sink's last transaction (in memory)
  private dv = -1;                    // PRAGMA data_version after this sink's last transaction
  private guard = "";                 // [stored state, max seq settled, max seq outbox, last self] after it
  private halted: string | null = null;
  public reaudits = 0;                // number of guard-triggered incremental re-audits (for tests)
  constructor(path: string, private readonly cfg: SinkConfig) {
    if (cfg === null || typeof cfg !== "object" || !isState((cfg as any).initialState)) {
      throw new Error("h1 sink refuses to serve: cfg.initialState is required (the initial charge, from outside the database)");
    }
    if (cfg.expectedHead !== undefined && !isHead(cfg.expectedHead)) throw new Error("h1 sink refuses to serve: cfg.expectedHead is not {count, chainHash}");
    this.M = loadCore();
    this.cv = conv(this.M);
    if (!validInitial(this.M, this.cv, cfg.initialState)) {
      throw new Error("h1 sink refuses to serve: cfg.initialState is not a valid context (charge id, refunds enabled, original <= MaxMoney, 0 <= remaining <= original)");
    }
    this.au = new StoreAuditor(this.M, this.cv, createPublicKey(cfg.publicKeyPem), cfg, cfg.initialState);
    this.pos = this.au.start();
    this.db = new DatabaseSync(path);
    let ok = false, why = "";
    try {
      this.db.exec("PRAGMA busy_timeout = 30000");
      // C-ATT-02: a file with no committed schema gets the WHOLE schema in one transaction; any other file is never
      // changed here: the schema check decides.
      createSchema(this.db);
      // The start-up audit (schema, integrity, meta, compiled AuditV5 fold, chain, expectedHead). No option skips it.
      this.db.exec("BEGIN IMMEDIATE");
      const at = this.au.fullAudit(this.db, cfg.expectedHead);
      if (at !== null) { this.pos = at; ok = true; }
      this.mark(readStateBlob(this.db));
      this.db.exec("ROLLBACK");
    } catch (error) {
      try { this.db.exec("ROLLBACK"); } catch { /* no open transaction */ }
      why = ": " + String((error as Error).message);
    }
    if (!ok) {
      this.db.close();
      throw new Error("h1 sink refuses to serve: start-up audit (schema, integrity, initial charge, AuditV5 replay, chain, anchor) is false" + why);
    }
  }
  // Writes meta (and, by trigger h_meta_ai, the state row) once. Only cfg.initialState may be written.
  init(state: ChargeState): void {
    if (!isState(state)) throw new Error("initial state shape");
    const blob = canon(state);
    if (blob !== this.au.initText) throw new Error("initial state is not cfg.initialState");
    this.db.exec("BEGIN IMMEDIATE");
    try {
      const stored = readStateBlob(this.db);
      if (this.changed(stored)) {                       // another writer acted since this sink's last transaction
        const at = this.au.fullAudit(this.db);
        if (at === null) throw new Error("another writer changed the store and the full audit is false");
        this.pos = at;
      }
      if (this.db.prepare("SELECT 1 AS x FROM meta WHERE id = 1").get() === undefined) {
        this.db.prepare("INSERT INTO meta(id, format, charge_id, initial_state, initial_state_sha256, genesis) VALUES (1, ?, ?, ?, ?, ?)")
          .run(STORE_FORMAT, state.chargeId, blob, sha256hex(blob), this.au.genesis);
      }
      this.mark(readStateBlob(this.db));
      this.db.exec("COMMIT");
    } catch (error) { this.db.exec("ROLLBACK"); throw error; }
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
  // S6 / review F2 / C-ATT-12: a foreign change is accepted only as an APPEND of audit-passing rows after this sink's head.
  private foreignCheck(stored: string | undefined): Pos | null {
    if (!this.au.schemaAndMeta(this.db)) return this.pos.count === 0 && stored === undefined ? this.pos : null;
    if (stored === undefined || !this.au.headRowSame(this.db, this.pos)) return null;
    return this.au.auditFrom(this.db, this.pos, stored);
  }
  commit(input: unknown): CommitResult {
    // (1) the decoder (K1), unchanged from sink.ts. It can only refuse.
    const token = decodeToken(input);
    if (typeof token === "string") return { status: "rejected", reason: token };
    if (this.halted !== null) return { status: "rejected", reason: "sink halted: " + this.halted };
    const { M, cv } = this, b = token.body;
    const tokenText = input as string, tokenSha256 = sha256hex(tokenText);
    const sigOk = sigOkOf(this.au.key, token);
    const tok = M.Shell.ShellToken.create_ShellToken(
      new M.BigNumber(b.specLockSha256 === this.cfg.specLockSha256 ? 1 : 0), new M.BigNumber(b.checkerSha256 === this.cfg.checkerSha256 ? 2 : 0),
      cv.text(b.requestId), cv.charge(b.post), cv.intent(b.intent), cv.text(""));
    try {
      this.db.exec("BEGIN IMMEDIATE");
      let stored: string | undefined;
      try { stored = readStateBlob(this.db); } catch (error) {
        this.halted = "the state row cannot be read: " + String((error as Error).message);
        this.db.exec("ROLLBACK");
        return { status: "rejected", reason: "sink halted: " + this.halted };
      }
      // (iv) the writer guard: a foreign change -> schema, integrity, meta, head row, new rows; false -> HALT.
      if (this.changed(stored)) {
        this.reaudits++;
        let at: Pos | null = null, why = "";
        try { at = this.foreignCheck(stored); } catch (error) { at = null; why = ": " + String((error as Error).message); }
        if (at === null) {
          this.halted = "another writer changed the store and the change is not an append of audit-passing rows" + why;
          this.db.exec("ROLLBACK");
          return { status: "rejected", reason: "sink halted: " + this.halted };
        }
        this.pos = at;
        this.mark(stored);
      }
      // (i) constant state: the stored charge and ONE indexed lookup. The index is checked by integrity_check at start
      // and after every foreign change; a corruption between two commits is a foreign change (data_version).
      const charge = stored === undefined ? M.F.Charge.Default() : (() => { const v = JSON.parse(stored); return cv.charge(must(isState(v), v, "state")); })();
      const preOk = stored !== undefined && sha256hex(stored) === b.preStateSha256;   // A4'
      const prior = this.db.prepare("SELECT token_sha256 FROM settled WHERE request_id = ?").get(b.requestId) as { token_sha256: string } | undefined;
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
        this.pos = { st, count: seq, chain: self };
        this.mark(next);
        this.db.exec("COMMIT");
        return { status: "committed" };
      }
      this.db.exec("ROLLBACK");
      if (q.is_RejectNotAuthorized) return { status: "rejected", reason: "not authorized by the approved relation for the stored state" };
      return this.label(q.dtor_why, prior?.token_sha256 === tokenSha256, stored === undefined, b.specLockSha256 === this.cfg.specLockSha256);
    } catch (error) {
      try { this.db.exec("ROLLBACK"); } catch { /* no open transaction */ }
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
}
