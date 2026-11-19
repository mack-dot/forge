// MUTANT no_state_update (c10-judges attack input; edited copy of v6 sink/dispatcher). NOT a fix.
// Slice 1 (F2.2): the sink, core-backed (v6; adopted from the night-shift draft d-v6sink, 2026-11-19).
// The same exported interface as the earlier sink.ts, plus the REQUIRED config field initialState.
// The DECISION of commit() is the value of the compiled ShellCoreV6.StepQ6 (impl/finality-core/ShellCoreV6.dfy,
// compiled to core/sinkcore-v6.cjs by `dafny build --target js`; scripts/exit_slice1.py rebuilds it and compares).
// StepQ6 = ShellCoreV4.StepQ (ids, signature, request id, settled, pre-state, charge id) plus the approved relation
// AuthorizesX on the STORED charge, checked last (reason RejectNotAuthorized). Constant time per commit.
// Changes against the earlier sink.ts:
//  (i)   the start-up audit and every re-audit are the compiled ShellCoreV5 fold (AInit, AuditStep, AuditEnd) over
//        the settled rows zipped with the outbox rows in seq order. Per row the shell decodes the stored token text
//        with the SAME decoder as commit() (decodeToken), re-verifies its Ed25519 signature with the pinned key
//        (sigOk), computes preOk = SHA-256(canonical text of the replayed charge) == token pre-state hash, and gives
//        the decoded outbox intent. AuditStep re-evaluates the approved relation (AuthorizesX == F.Authorizes) on the
//        REPLAYED state. AuditEnd: replayed charge == stored charge; |settled| == |outbox| == #distinct == rows.
//        Proved (ShellCoreV5.AuditV5SoundRelativeToSuppliedInitial): money is conserved RELATIVE TO THE SUPPLIED
//        INITIAL CHARGE; no signature hypothesis.
//  (ii)  cfg.initialState is REQUIRED. It is THE ANCHOR: it must come from OUTSIDE the database (deployment
//        configuration). When meta rows exist, meta 'initial_state_sha256' must equal SHA-256(canonical cfg text)
//        and meta 'initial_state' (if present) must equal the canonical cfg text; otherwise the sink refuses. A
//        legacy store without meta rows is accepted only when the replay from cfg.initialState reaches the stored
//        state (that is AuditV5 itself). init(state) refuses a state other than cfg.initialState.
//  (iii) schema check at start and at every re-audit: every row of sqlite_schema (type, name, tbl_name, sql after
//        whitespace normalisation) must equal the rows that the sink's own DDL creates in an empty in-memory
//        database. Any other table, index, trigger or view, or another column definition (e.g. COLLATE NOCASE),
//        is refused.
//  (iv)  the writer guard (data_version + head) is kept; on a detected foreign change the sink re-audits (schema,
//        meta, AuditV5) and HALTS when that is false. Undetectable (stated assumptions, not solved): a rollback of
//        the whole database to a state this sink wrote earlier (a valid replay prefix; needs an external anchor);
//        a foreign writer who holds the signing key AND writes only authorized transitions (that is a legitimate
//        writer by the audit's definition); a change made and undone between two transactions of this sink.
// TypeScript does only: the decoder (K1), the Ed25519 call (sigOk, A5), the SHA-256 compares (preOk, A4'), the SQL
// reads and writes, the value conversion, the schema/meta compare, and the loop that calls AuditStep once per row
// (TESTED-UNPROVED against the proved fold ShellCoreV5.Fold / AuditLoop).
// NOT proved: this file, the Dafny JS compiler and runtime, bignumber.js, SQLite, Node, OpenSSL, SHA-256, Ed25519.
import { createPublicKey, verify, KeyObject } from "node:crypto";
import { DatabaseSync } from "node:sqlite";
import { ChargeState, Intent, Token, canon, isIntent, isState, isToken, sha256hex, signatureBytes, signedBytes } from "./encoding";

const MAX_TOKEN_TEXT = 8192;

export type SinkConfig = { publicKeyPem: string; specLockSha256: string; checkerSha256: string; initialState: ChargeState };
export type CommitResult = { status: "committed" | "replayed" | "rejected"; reason?: string };
export type OutboxRow = { seq: number; request_id: string; intent: string };

// The sink's DDL (the same text as sink.ts). The schema check compares the file against what this text creates.
const DDL = `CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE,
        token TEXT NOT NULL, token_sha256 TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE, intent TEXT NOT NULL);`;
const schemaRows = (db: DatabaseSync): string =>
  JSON.stringify((db.prepare("SELECT type, name, tbl_name, sql FROM sqlite_schema ORDER BY type, name").all() as any[])
    .map(r => [r.type, r.name, r.tbl_name, r.sql === null ? null : String(r.sql).replace(/\s+/g, " ").trim()]));
const EXPECTED_SCHEMA = (() => { const m = new DatabaseSync(":memory:"); m.exec(DDL); const s = schemaRows(m); m.close(); return s; })();

// ---- the compiled core (dafny build --target js through the lock script; see build/ and logs/)
const CORE_FILE = __dirname + "/core/sinkcore-v6.cjs";
type CoreMod = { Shell6: any; Shell5: any; Shell4: any; Shell: any; C: any; F: any; R: any; rt: any; BigNumber: any };
// eslint-disable-next-line @typescript-eslint/no-require-imports
const loadCore = (): CoreMod => require(CORE_FILE);

// ---- conversion between TypeScript values and core values. Pure maps; no branch on content.
const conv = (M: CoreMod) => {
  const T = (s: string) => M.rt.Seq.UnicodeFromString(s);
  const N = (s: string) => new M.BigNumber(s);
  const S = (x: any): string => x.toVerbatimString(false);
  const D = (n: any): string => n.toFixed();
  return {
    charge: (s: ChargeState) => M.F.Charge.create_Charge(T(s.chargeId), N(s.original), N(s.remaining), s.refundEnabled),
    intent: (i: Intent) => M.R.RefundIntent.create_Intent(T(i.chargeId), T(i.requestId), N(i.amount), T(i.reason)),
    text: T, back: S,
    backCharge: (c: any): ChargeState => ({ chargeId: S(c.dtor_chargeId), original: D(c.dtor_original), remaining: D(c.dtor_remaining), refundEnabled: c.dtor_refundEnabled }),
    backIntent: (i: any): Intent => ({ chargeId: S(i.dtor_chargeId), requestId: S(i.dtor_requestId), amount: D(i.dtor_amount), reason: S(i.dtor_reason) }),
  };
};
// A loaded value that does not decode stops the audit or transaction (an exception: fail-closed, no write).
function must<X>(ok: boolean, x: X, what: string): X { if (!ok) throw new Error("stored " + what + " does not decode"); return x; }

// THE decoder (K1), unchanged from sink.ts; used by commit() AND by the audit. It can only refuse.
function decodeToken(input: unknown): Token | string {
  if (typeof input !== "string") return "token is not a text";
  if (input.length > MAX_TOKEN_TEXT) return "token shape";
  let token: unknown;
  try { token = JSON.parse(input); } catch { return "token shape"; }
  if (!isToken(token)) return "token shape";
  if (canon(token) !== input) return "token text is not canonical";
  return token;
}

export class Sink {
  private readonly db: DatabaseSync;
  private readonly key: KeyObject;
  private readonly M: CoreMod;
  private readonly cv: ReturnType<typeof conv>;
  private readonly initText: string;  // canonical text of cfg.initialState (THE ANCHOR; from outside the database)
  private readonly initCore: any;     // the same value as a core Charge
  private dv = -1;                 // PRAGMA data_version after this sink's last transaction
  private head = "";               // the head after this sink's last transaction
  private halted: string | null = null;
  public reaudits = 0;             // number of guard-triggered re-audits (for tests)
  constructor(path: string, private readonly cfg: SinkConfig) {
    if (cfg === null || typeof cfg !== "object" || !isState((cfg as any).initialState)) {
      throw new Error("v6 sink refuses to serve: cfg.initialState is required (the initial charge, from outside the database)");
    }
    this.db = new DatabaseSync(path);
    this.db.exec("PRAGMA busy_timeout = 30000");
    // Create the tables only in an EMPTY file. A non-empty file is never changed here: the schema check decides.
    if ((this.db.prepare("SELECT COUNT(*) AS n FROM sqlite_schema").get() as any).n === 0) this.db.exec(DDL);
    this.key = createPublicKey(cfg.publicKeyPem);
    this.M = loadCore();
    this.cv = conv(this.M);
    this.initText = canon(cfg.initialState);
    this.initCore = this.cv.charge(cfg.initialState);
    // The start-up audit (schema, meta, compiled AuditV5 fold). No option skips it.
    let ok = false, why = "";
    try {
      this.db.exec("BEGIN IMMEDIATE");
      const stored = this.storedBlob();
      ok = this.fullAudit(stored);
      this.mark(stored);
      this.db.exec("ROLLBACK");
    } catch (error) {
      try { this.db.exec("ROLLBACK"); } catch { /* no open transaction */ }
      why = ": " + String((error as Error).message);
    }
    if (!ok) {
      this.db.close();
      throw new Error("v6 sink refuses to serve: start-up audit (schema, initial charge, AuditV5 replay) is false" + why);
    }
  }
  // COPIED from v4 (sink.ts plus meta 'initial_state'). NEW: only cfg.initialState may be written.
  init(state: ChargeState): void {
    if (!isState(state)) throw new Error("initial state shape");
    const blob = canon(state);
    if (blob !== this.initText) throw new Error("initial state is not cfg.initialState");
    this.db.exec("BEGIN IMMEDIATE");
    try {
      if (this.db.prepare("SELECT 1 AS x FROM state WHERE id = 1").get() === undefined) {
        this.db.prepare("INSERT INTO state(id, blob) VALUES (1, ?)").run(blob);
        this.db.prepare("INSERT INTO meta(k, v) VALUES ('initial_state_sha256', ?)").run(sha256hex(blob));
        this.db.prepare("INSERT INTO meta(k, v) VALUES ('initial_state', ?)").run(blob);
      }
      this.mark(this.storedBlob());
      this.db.exec("COMMIT");
    } catch (error) { this.db.exec("ROLLBACK"); throw error; }
  }
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
  // (2) sigOk. COPIED from sink.ts.
  private verified(token: Token): boolean {
    try {
      const raw = signatureBytes(token.signature);
      return raw !== null && verify(null, signedBytes(token.body), this.key, raw);
    } catch { return false; }
  }
  // ---- the writer guard: values read inside the open transaction. O(log n) each (rowid b-tree max).
  private dataVersion(): number { return Number((this.db.prepare("PRAGMA data_version").get() as any).data_version); }
  private headOf(stored: string | undefined): string {
    const ms = (this.db.prepare("SELECT MAX(seq) AS m FROM settled").get() as any).m, mo = (this.db.prepare("SELECT MAX(seq) AS m FROM outbox").get() as any).m;
    return JSON.stringify([stored === undefined ? null : sha256hex(stored), ms, mo]);
  }
  private mark(stored: string | undefined): void { this.dv = this.dataVersion(); this.head = this.headOf(stored); }
  // (iii) schema and (ii) meta, then (i) AuditV5. Throws or returns false to refuse.
  private fullAudit(stored: string | undefined): boolean {
    if (schemaRows(this.db) !== EXPECTED_SCHEMA) throw new Error("schema is not the sink's DDL");
    const meta = this.db.prepare("SELECT k, v FROM meta").all() as { k: string; v: string }[];
    for (const r of meta) {
      if (r.k === "initial_state_sha256" && r.v !== sha256hex(this.initText)) throw new Error("meta initial_state_sha256 is not cfg.initialState");
      else if (r.k === "initial_state" && r.v !== this.initText) throw new Error("meta initial_state is not cfg.initialState");
      else if (r.k !== "initial_state_sha256" && r.k !== "initial_state") throw new Error("unknown meta key");
    }
    if (stored === undefined) {
      // A fresh store: no state row, no settled row, no outbox row. (init() then writes cfg.initialState.)
      const n = (this.db.prepare("SELECT (SELECT COUNT(*) FROM settled) + (SELECT COUNT(*) FROM outbox) AS n").get() as any).n;
      return n === 0;
    }
    return this.auditV5(stored);
  }
  // (i) the streaming AuditV5. One pass; settled and outbox zipped in seq order; constant core state.
  private auditV5(stored: string): boolean {
    const { M, cv } = this, S5 = M.Shell5.__default;
    const sv = JSON.parse(stored);
    must(isState(sv) && canon(sv) === stored, sv, "state");
    const storedCore = cv.charge(sv);
    const initId = this.initCore.dtor_chargeId;
    const si = (this.db.prepare("SELECT request_id, token, token_sha256 FROM settled ORDER BY seq").iterate() as Iterator<any>);
    const oi = (this.db.prepare("SELECT request_id, intent FROM outbox ORDER BY seq").iterate() as Iterator<any>);
    let st = S5.AInit(this.initCore);
    for (;;) {
      const a = si.next(), b = oi.next();
      if (a.done || b.done) { (si as any).return?.(); (oi as any).return?.(); break; }
      const srow = a.value as { request_id: string; token: string; token_sha256: string };
      const orow = b.value as { request_id: string; intent: string };
      const tk = decodeToken(srow.token);
      if (typeof tk === "string") throw new Error("stored token does not decode: " + tk);
      if (sha256hex(srow.token) !== srow.token_sha256) throw new Error("stored token_sha256 is not the token's hash");
      const iv = JSON.parse(orow.intent);
      must(isIntent(iv) && canon(iv) === orow.intent, iv, "intent");
      if (iv.requestId !== orow.request_id) throw new Error("outbox request_id column is not its intent's request id");
      const body = tk.body;
      const sigOk = this.verified(tk);
      const preOk = sha256hex(canon(cv.backCharge(st.dtor_cur))) === body.preStateSha256;   // A4' on the replay
      const t = M.Shell.ShellToken.create_ShellToken(
        new M.BigNumber(body.specLockSha256 === this.cfg.specLockSha256 ? 1 : 0), new M.BigNumber(body.checkerSha256 === this.cfg.checkerSha256 ? 2 : 0),
        cv.text(body.requestId), cv.charge(body.post), cv.intent(body.intent), cv.text(""));
      st = S5.AuditStep(initId, st, M.Shell5.Row.create_Row(cv.text(srow.request_id), t, sigOk, preOk, cv.intent(iv)));
    }
    const c = this.db.prepare("SELECT (SELECT COUNT(*) FROM settled) AS ns, (SELECT COUNT(*) FROM outbox) AS no, (SELECT COUNT(DISTINCT request_id) FROM settled) AS nd").get() as any;
    const B = (x: any) => new M.BigNumber(x);
    return S5.AuditEnd(this.initCore, storedCore, st, B(c.ns), B(c.no), B(c.nd)) === true;
  }
  commit(input: unknown): CommitResult {
    // (1) the decoder (K1), unchanged from sink.ts. It can only refuse.
    const token = decodeToken(input);
    if (typeof token === "string") return { status: "rejected", reason: token };
    if (this.halted !== null) return { status: "rejected", reason: "sink halted: " + this.halted };
    const { M, cv } = this, b = token.body;
    const tokenText = input as string, tokenSha256 = sha256hex(tokenText);
    const sigOk = this.verified(token);
    const tok = M.Shell.ShellToken.create_ShellToken(
      new M.BigNumber(b.specLockSha256 === this.cfg.specLockSha256 ? 1 : 0), new M.BigNumber(b.checkerSha256 === this.cfg.checkerSha256 ? 2 : 0),
      cv.text(b.requestId), cv.charge(b.post), cv.intent(b.intent), cv.text(""));
    try {
      this.db.exec("BEGIN IMMEDIATE");
      const stored = this.storedBlob();
      // (iv) the writer guard: a foreign change -> full re-audit (schema, meta, AuditV5); false -> HALT.
      if (this.dataVersion() !== this.dv || this.headOf(stored) !== this.head) {
        this.reaudits++;
        let ok = false;
        try { ok = this.fullAudit(stored); } catch { ok = false; }
        if (!ok) {
          this.halted = "re-audit (schema, initial charge, AuditV5) false after another writer changed the store";
          this.db.exec("ROLLBACK");
          return { status: "rejected", reason: "sink halted: " + this.halted };
        }
        this.mark(stored);
      }
      // (i) constant state: the stored charge and ONE indexed lookup. (unchanged from v4)
      const charge = stored === undefined ? M.F.Charge.Default() : (() => { const v = JSON.parse(stored); return cv.charge(must(isState(v), v, "state")); })();
      const preOk = stored !== undefined && sha256hex(stored) === b.preStateSha256;   // A4'
      const prior = this.db.prepare("SELECT token_sha256 FROM settled WHERE request_id = ?").get(b.requestId) as { token_sha256: string } | undefined;
      // THE DECISION: one call of the compiled core.
      const q = M.Shell6.__default.StepQ6(charge, tok, sigOk, preOk, prior !== undefined);
      if (q.is_Commit) {
        // exactly the StepQ result (Apply): state := newCharge; settled += addId; outbox += intent.
        const rid = cv.back(q.dtor_addId), next = canon(cv.backCharge(q.dtor_newCharge));
        this.db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, ?, ?)").run(rid, tokenText, tokenSha256);
        this.db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run(rid, canon(cv.backIntent(q.dtor_intent)));
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
  // COPIED from sink.ts unchanged. Offline audit; not part of the commit decision.
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
      if (token.body.requestId !== row.request_id) problems.push(`row ${row.seq}: request id`);
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
