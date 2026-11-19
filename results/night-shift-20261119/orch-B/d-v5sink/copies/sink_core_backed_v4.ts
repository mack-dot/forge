// d-v3sink2 (night shift 2026-11-19, Orchestrator B). A DRAFT PROPOSAL. NOT repository code. NOT approved.
// Copy of d-v3sink/sink_core_backed_v3.ts, changed (v4). The same exported interface as ts/refund-finality/sink.ts,
// plus the optional config field initialState (needed only for a store that an older sink created).
// The DECISION of commit() is the value of the compiled ShellCoreV4.StepQ (dafny/ShellCoreV4.dfy). StepQAgrees:
// Apply(core, StepQ(core.charge, t, sigOk, preOk, t.requestId in core.settled)) == ShellCoreV3.StepP(core, ...).
// Changes against v3:
//  (i)   commit(): inside ONE BEGIN IMMEDIATE: the state row and ONE indexed SELECT on settled.request_id
//        (UNIQUE: index sqlite_autoindex_settled_1) give charge and alreadySettled; StepQ decides; the shell writes
//        exactly the StepQ result (state := newCharge; settled += addId; outbox += intent) or nothing.
//  (ii)  no load of the settled set or the outbox on commit (no Dafny set, no Dafny sequence of the outbox).
//  (iii) the start-up audit streams the outbox rows (seq order) through the compiled AuditStep (constant state)
//        and ends with AuditEnd, which binds the stored chargeId to the INITIAL charge id: the shell reads the
//        initial state text from meta 'initial_state' (written by init() of v4) or cfg.initialState, and refuses
//        unless its SHA-256 equals meta 'initial_state_sha256'. The sink refuses to start when the audit is false.
//  (iv)  no core option: there is no way to skip the audit.
//  (v)   a per-commit writer guard (inside the transaction): PRAGMA data_version (changes when ANOTHER connection
//        committed) and the head (SHA-256 of the state text, MAX(seq) of settled, MAX(seq) of outbox) recorded by
//        this sink after its own last transaction. On a mismatch the sink runs the streaming audit again before it
//        decides; when the audit is false the sink HALTS (it rejects every later commit). See WRITER GUARD below.
// TypeScript does only: the decoder (K1, copied from sink.ts), the Ed25519 call (sigOk, A5), preOk = hash compare
// (A4'), the SQL reads and writes, and the value conversion. NOT proved: this file, the Dafny JS compiler and
// runtime, bignumber.js, SQLite, Node, OpenSSL, SHA-256, Ed25519.
// WRITER GUARD: it detects (a) any commit by another SQLite connection between two transactions of this sink
// (data_version), (b) any change of the state text and any new settled/outbox row with a higher seq (head). On a
// detection it does not refuse at once: it re-audits (an honest other writer, e.g. the unchanged sink with an honest
// token, is allowed: case D1). It does NOT detect: a rollback of the whole file to an earlier state (after a
// restart, or in place when data_version and the head look unchanged; D-d: needs an external anchor); a
// self-consistent foreign row set that passes the audit (the audit checks GoodV3 and the binding, not the
// signatures or the chain: audit() does that offline); a change made while this sink is not running that
// passes the start-up audit; an edit of the file outside SQLite that keeps the header change counter and the head.
import { createPublicKey, verify, KeyObject } from "node:crypto";
import { DatabaseSync } from "node:sqlite";
import { ChargeState, Intent, Token, canon, isIntent, isState, isToken, sha256hex, signatureBytes, signedBytes } from "../../../../ts/refund-finality/encoding";

const MAX_TOKEN_TEXT = 8192;

export type SinkConfig = { publicKeyPem: string; specLockSha256: string; checkerSha256: string; initialState?: ChargeState };
export type CommitResult = { status: "committed" | "replayed" | "rejected"; reason?: string };
export type OutboxRow = { seq: number; request_id: string; intent: string };

// ---- the compiled core (dafny build --target js through the lock script; see build/ and logs/)
const CORE_FILE = __dirname + "/build/shellcore-v4.cjs";
type CoreMod = { Shell4: any; Shell: any; C: any; F: any; R: any; rt: any; BigNumber: any };
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
// A loaded value that does not decode stops the transaction (an exception: fail-closed, no write).
function must<X>(ok: boolean, x: X, what: string): X { if (!ok) throw new Error("stored " + what + " does not decode"); return x; }

export class Sink {
  private readonly db: DatabaseSync;
  private readonly key: KeyObject;
  private readonly M: CoreMod;
  private readonly cv: ReturnType<typeof conv>;
  private dv = -1;                 // PRAGMA data_version after this sink's last transaction
  private head = "";               // the head after this sink's last transaction
  private halted: string | null = null;
  public reaudits = 0;             // number of guard-triggered re-audits (for tests)
  constructor(path: string, private readonly cfg: SinkConfig) {
    this.db = new DatabaseSync(path);
    this.db.exec("PRAGMA busy_timeout = 30000");
    this.db.exec(`CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE,
        token TEXT NOT NULL, token_sha256 TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE, intent TEXT NOT NULL);`);
    this.key = createPublicKey(cfg.publicKeyPem);
    this.M = loadCore();
    this.cv = conv(this.M);
    // The start-up audit (streaming; compiled AuditStep/AuditEnd decide). No option skips it.
    let ok = false, why = "";
    try {
      this.db.exec("BEGIN IMMEDIATE");
      const stored = this.storedBlob();
      ok = this.auditStream(stored);
      this.mark(stored);
      this.db.exec("ROLLBACK");
    } catch (error) {
      try { this.db.exec("ROLLBACK"); } catch { /* no open transaction */ }
      why = ": " + String((error as Error).message);
    }
    if (!ok) {
      this.db.close();
      throw new Error("v4 sink refuses to serve: streaming start-up audit (AuditEnd, bound to the initial charge id) is false" + why);
    }
  }
  // COPIED from sink.ts, plus ONE meta row 'initial_state' (the initial state text; the binding reads it).
  init(state: ChargeState): void {
    if (!isState(state)) throw new Error("initial state shape");
    const blob = canon(state);
    this.db.exec("BEGIN IMMEDIATE");
    try {
      if (this.db.prepare("SELECT 1 AS x FROM state WHERE id = 1").get() === undefined) {
        this.db.prepare("INSERT INTO state(id, blob) VALUES (1, ?)").run(blob);
        this.db.prepare("INSERT INTO meta(k, v) VALUES ('initial_state_sha256', ?)").run(sha256hex(blob));
        this.db.prepare("INSERT INTO meta(k, v) VALUES ('initial_state', ?)").run(blob);
      }
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
  // The initial charge id (the binding's parameter): from the initial state text whose SHA-256 is in meta.
  private initialChargeId(): string {
    const h = (this.db.prepare("SELECT v FROM meta WHERE k = 'initial_state_sha256'").get() as { v: string } | undefined)?.v;
    if (h === undefined) throw new Error("no meta initial_state_sha256");
    const blob = (this.db.prepare("SELECT v FROM meta WHERE k = 'initial_state'").get() as { v: string } | undefined)?.v
      ?? (this.cfg.initialState !== undefined ? canon(this.cfg.initialState) : undefined);
    if (blob === undefined) throw new Error("no initial state text (meta 'initial_state' or cfg.initialState)");
    if (sha256hex(blob) !== h) throw new Error("initial state text does not match meta initial_state_sha256");
    const v = JSON.parse(blob);
    return must(isState(v), v, "initial state").chargeId;
  }
  // (iii) the streaming audit. One pass over the outbox in seq order; per row: decode, ONE indexed lookup, AuditStep.
  // Then COUNT(DISTINCT) of settled ids (A-DB2) and the outbox request-id distinctness (A-DB3), then AuditEnd.
  private auditStream(stored: string | undefined): boolean {
    const { M, cv } = this, S4 = M.Shell4.__default;
    const charge = stored === undefined ? M.F.Charge.Default() : (() => { const v = JSON.parse(stored); return cv.charge(must(isState(v), v, "state")); })();
    const initId = stored === undefined ? charge.dtor_chargeId : cv.text(this.initialChargeId());
    const cid = charge.dtor_chargeId, hitQ = this.db.prepare("SELECT 1 AS x FROM settled WHERE request_id = ?");
    let st = S4.AInit();
    for (const row of this.db.prepare("SELECT request_id, intent FROM outbox ORDER BY seq").iterate() as Iterable<{ request_id: string; intent: string }>) {
      const v = JSON.parse(row.intent);
      must(isIntent(v), v, "intent");
      // The column must be the intent's request id (then column distinctness == intent distinctness: A-DB3).
      if (v.requestId !== row.request_id) throw new Error("outbox request_id column is not its intent's request id");
      st = S4.AuditStep(cid, st, M.Shell4.ARow.create_ARow(cv.intent(v), hitQ.get(v.requestId) !== undefined));
    }
    const nSettled = (this.db.prepare("SELECT COUNT(DISTINCT request_id) AS n FROM settled").get() as any).n;
    const distinct = (this.db.prepare("SELECT COUNT(*) = COUNT(DISTINCT request_id) AS d FROM outbox").get() as any).d === 1;
    return S4.AuditEnd(charge, initId, st, new M.BigNumber(nSettled), distinct) === true;
  }
  commit(input: unknown): CommitResult {
    // (1) the decoder (K1), unchanged from sink.ts. It can only refuse.
    if (typeof input !== "string") return { status: "rejected", reason: "token is not a text" };
    if (input.length > MAX_TOKEN_TEXT) return { status: "rejected", reason: "token shape" };
    let token: unknown;
    try { token = JSON.parse(input); } catch { return { status: "rejected", reason: "token shape" }; }
    if (!isToken(token)) return { status: "rejected", reason: "token shape" };
    if (canon(token) !== input) return { status: "rejected", reason: "token text is not canonical" };
    if (this.halted !== null) return { status: "rejected", reason: "sink halted: " + this.halted };
    const { M, cv } = this, b = token.body;
    const tokenText = input, tokenSha256 = sha256hex(tokenText);
    const sigOk = this.verified(token);
    const tok = M.Shell.ShellToken.create_ShellToken(
      new M.BigNumber(b.specLockSha256 === this.cfg.specLockSha256 ? 1 : 0), new M.BigNumber(b.checkerSha256 === this.cfg.checkerSha256 ? 2 : 0),
      cv.text(b.requestId), cv.charge(b.post), cv.intent(b.intent), cv.text(""));
    try {
      this.db.exec("BEGIN IMMEDIATE");
      const stored = this.storedBlob();
      // (v) the writer guard.
      if (this.dataVersion() !== this.dv || this.headOf(stored) !== this.head) {
        this.reaudits++;
        if (!this.auditStream(stored)) {
          this.halted = "audit false after another writer changed the store";
          this.db.exec("ROLLBACK");
          return { status: "rejected", reason: "sink halted: " + this.halted };
        }
        this.mark(stored);
      }
      // (i) constant state: the stored charge and ONE indexed lookup.
      const charge = stored === undefined ? M.F.Charge.Default() : (() => { const v = JSON.parse(stored); return cv.charge(must(isState(v), v, "state")); })();
      const preOk = stored !== undefined && sha256hex(stored) === b.preStateSha256;   // A4'
      const prior = this.db.prepare("SELECT token_sha256 FROM settled WHERE request_id = ?").get(b.requestId) as { token_sha256: string } | undefined;
      // THE DECISION: one call of the compiled core.
      const q = M.Shell4.__default.StepQ(charge, tok, sigOk, preOk, prior !== undefined);
      if (q.is_Commit) {
        // exactly the StepQ result (Apply): state := newCharge; settled += addId; outbox += intent.
        const rid = cv.back(q.dtor_addId), next = canon(cv.backCharge(q.dtor_newCharge));
        this.db.prepare("UPDATE state SET blob = ? WHERE id = 1").run(next);
        this.db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, ?, ?)").run(rid, tokenText, tokenSha256);
        this.db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run(rid, canon(cv.backIntent(q.dtor_intent)));
        this.mark(next);
        this.db.exec("COMMIT");
        return { status: "committed" };
      }
      this.db.exec("ROLLBACK");
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
