// d-v3sink (night shift 2026-11-19, Orchestrator B): a copy of d-corebacked/sink_core_backed.ts with core "v3"
// (ShellCoreV3.StepP: request-id check AND charge-id check of SinkCoreV3; dafny/ShellCoreV3.dfy) and a start-up
// audit: with core "v3" the constructor runs the compiled ShellCoreV3.AuditStart on the loaded store and REFUSES
// to serve when it is false (deployment precondition GoodStart of SinkCoreV3). Core "v3" is the default here.
// d-corebacked (night shift 2026-11-19, Orchestrator B). A DRAFT PROPOSAL. NOT repository code. NOT approved.
// The same exported interface as ts/refund-finality/sink.ts. The DECISION of commit() (commit or reject,
// the reason class, the next state, the outbox entry) is the value of the Dafny-compiled function
// ShellCore*.StepP (dafny/inputs/sink/ShellCoreReqId.dfy; StepPAgrees proves StepP == SinkCoreReqId.Step
// when preOk is the value compare). TypeScript does only:
//   (1) parse and canonical decode of the token text (the unproved decoder K1; copied from sink.ts);
//   (2) the Ed25519 call that gives the boolean sigOk (A5);
//   (3) the load of the stored state, the settled ids and the outbox inside ONE BEGIN IMMEDIATE transaction;
//   (4) the conversion to core values, including the boolean preOk = (SHA-256 of the stored text equals the
//       token's preStateSha256) (A4' in ShellCoreReqId.dfy: the token carries only the hash);
//   (5) the write of exactly the core's result, then COMMIT; ROLLBACK on any exception.
// init(), storedBlob(), stateBlob(), settled(), outbox(), audit() and close() are COPIED from sink.ts
// unchanged (they are not part of the commit decision). NOT proved: this file, the Dafny JS compiler and
// runtime, bignumber.js, SQLite, Node, OpenSSL, SHA-256, Ed25519.
import { createPublicKey, verify, KeyObject } from "node:crypto";
import { DatabaseSync } from "node:sqlite";
import { ChargeState, Intent, Token, canon, isIntent, isState, isToken, sha256hex, signatureBytes, signedBytes } from "../../../../ts/refund-finality/encoding";

const MAX_TOKEN_TEXT = 8192;

export type SinkConfig = { publicKeyPem: string; specLockSha256: string; checkerSha256: string; core?: "v3" | "reqid" | "orig" };
export type CommitResult = { status: "committed" | "replayed" | "rejected"; reason?: string };
export type OutboxRow = { seq: number; request_id: string; intent: string };

// ---- the compiled core (built by dafny build --target js through the lock script; see build/)
const CORE_FILES = { v3: __dirname + "/build/shellcore-v3.cjs", reqid: __dirname + "/build/shellcore-reqid.cjs", orig: __dirname + "/build/shellcore-orig.cjs" };
type CoreMod = { Shell: any; C: any; F: any; R: any; rt: any; BigNumber: any };
// eslint-disable-next-line @typescript-eslint/no-require-imports
const loadCore = (v: "v3" | "reqid" | "orig"): CoreMod => require(CORE_FILES[v]);

// ---- (4) conversion between TypeScript values and core values. Pure maps; no branch on content.
const conv = (M: CoreMod) => {
  const T = (s: string) => M.rt.Seq.UnicodeFromString(s);
  const N = (s: string) => new M.BigNumber(s);
  const S = (x: any): string => x.toVerbatimString(false);
  const D = (n: any): string => n.toFixed();
  return {
    charge: (s: ChargeState) => M.F.Charge.create_Charge(T(s.chargeId), N(s.original), N(s.remaining), s.refundEnabled),
    intent: (i: Intent) => M.R.RefundIntent.create_Intent(T(i.chargeId), T(i.requestId), N(i.amount), T(i.reason)),
    text: T,
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
  constructor(path: string, private readonly cfg: SinkConfig) {
    this.db = new DatabaseSync(path);
    this.db.exec("PRAGMA busy_timeout = 30000");
    this.db.exec(`CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE,
        token TEXT NOT NULL, token_sha256 TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE, intent TEXT NOT NULL);`);
    this.key = createPublicKey(cfg.publicKeyPem);
    this.M = loadCore(cfg.core ?? "v3");
    this.cv = conv(this.M);
    // v3: the start-up audit. The compiled AuditStart decides; the shell only loads the store and refuses.
    if ((cfg.core ?? "v3") === "v3") {
      let ok = false, why = "";
      try {
        this.db.exec("BEGIN IMMEDIATE");
        ok = this.M.Shell.__default.AuditStart(this.loadCore().core) === true;
        this.db.exec("ROLLBACK");
      } catch (error) {
        try { this.db.exec("ROLLBACK"); } catch { /* no open transaction */ }
        why = ": " + String((error as Error).message);
      }
      if (!ok) {
        this.db.close();
        throw new Error("v3 sink refuses to serve: start-up audit AuditStart is false on the stored state (deployment precondition GoodStart)" + why);
      }
    }
  }
  // COPIED from sink.ts.
  init(state: ChargeState): void {
    if (!isState(state)) throw new Error("initial state shape");
    const blob = canon(state);
    this.db.exec("BEGIN IMMEDIATE");
    try {
      if (this.db.prepare("SELECT 1 AS x FROM state WHERE id = 1").get() === undefined) {
        this.db.prepare("INSERT INTO state(id, blob) VALUES (1, ?)").run(blob);
        this.db.prepare("INSERT INTO meta(k, v) VALUES ('initial_state_sha256', ?)").run(sha256hex(blob));
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
  // (3) the stored state as a core value, read inside the open transaction.
  private loadCore(): { core: any; stored: string | undefined } {
    const { M, cv } = this;
    const stored = this.storedBlob();
    const charge = stored === undefined ? M.F.Charge.Default() : (() => { const v = JSON.parse(stored); return cv.charge(must(isState(v), v, "state")); })();
    const ids = (this.db.prepare("SELECT request_id FROM settled").all() as { request_id: string }[]).map(r => cv.text(r.request_id));
    const outbox = this.outbox().map(r => { const v = JSON.parse(r.intent); return cv.intent(must(isIntent(v), v, "intent")); });
    return { core: M.C.Core.create_Core(charge, M.rt.Set.fromElements(...ids), M.rt.Seq.of(...outbox)), stored };
  }
  commit(input: unknown): CommitResult {
    // (1) the decoder (K1), unchanged from sink.ts. It can only refuse.
    if (typeof input !== "string") return { status: "rejected", reason: "token is not a text" };
    if (input.length > MAX_TOKEN_TEXT) return { status: "rejected", reason: "token shape" };
    let token: unknown;
    try { token = JSON.parse(input); } catch { return { status: "rejected", reason: "token shape" }; }
    if (!isToken(token)) return { status: "rejected", reason: "token shape" };
    if (canon(token) !== input) return { status: "rejected", reason: "token text is not canonical" };
    const { M, cv } = this, b = token.body;
    const tokenText = input, tokenSha256 = sha256hex(tokenText);
    // (2) and (4): the core's inputs. The pinned-id compares become the core's ids 1 and 2 (or 0).
    const sigOk = this.verified(token);
    const tok = M.Shell.ShellToken.create_ShellToken(
      new M.BigNumber(b.specLockSha256 === this.cfg.specLockSha256 ? 1 : 0), new M.BigNumber(b.checkerSha256 === this.cfg.checkerSha256 ? 2 : 0),
      cv.text(b.requestId), cv.charge(b.post), cv.intent(b.intent), cv.text(""));
    try {
      this.db.exec("BEGIN IMMEDIATE");
      const { core, stored } = this.loadCore();
      const preOk = stored !== undefined && sha256hex(stored) === b.preStateSha256;   // A4'
      // THE DECISION: one call of the compiled core.
      const r = M.Shell.__default.StepP(core, tok, sigOk, preOk);
      if (r.dtor_out.is_Committed) {
        // (5) exactly the core's result (StepPShape: charge := post; settled += {requestId}; outbox += [intent]).
        const next = r.dtor_core, added = next.dtor_outbox.slice(core.dtor_outbox.length);
        this.db.prepare("UPDATE state SET blob = ? WHERE id = 1").run(canon(this.cv.backCharge(next.dtor_charge)));
        this.db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, ?, ?)").run(b.requestId, tokenText, tokenSha256);
        for (const i of added) this.db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run(b.requestId, canon(this.cv.backIntent(i)));
        this.db.exec("COMMIT");
        return { status: "committed" };
      }
      // Rejected: StepPShape says the core is unchanged, so nothing is written.
      const prior = this.db.prepare("SELECT token_sha256 FROM settled WHERE request_id = ?").get(b.requestId) as { token_sha256: string } | undefined;
      this.db.exec("ROLLBACK");
      return this.label(r.dtor_out.dtor_why, prior?.token_sha256 === tokenSha256, stored === undefined, b.specLockSha256 === this.cfg.specLockSha256);
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
