// Shared harness of the refund-finality regressions (task h-regress; process model and trusted encoding: task
// h-judges, night shift 2026-11-19). A TEST, not a proof.
// PROCESS MODEL. This harness runs in the PARENT (the judge). It never loads the sink or the dispatcher under test.
// Each regression gets its own CHILD process (worker.ts, through remote.ts) that loads the two modules BY PATH and
// runs only the operations asked for: new Sink(path, cfg), sink.init(state), sink.commit(tokenText), sink.close(),
// new Dispatcher(db, ledger, dcfg, emit).flush(). The parent holds the keys, builds and signs every token, reads the
// DATABASE FILES ITSELF (node:sqlite, read-only), reads the dispatcher ledger file itself, and decides PASS/FAIL.
// A restart of the sink can be a new Sink instance in the same child (reopen) or a NEW CHILD PROCESS (restart()).
// TRUSTED ENCODING. Canonical bytes, signed bytes and hashes come from the encoding.ts of the tree that this judge
// lives in (../../../ts/refund-finality/encoding), never from the encoding.ts next to the sink under test.
// Keys: one TEST Ed25519 key pair and one FOREIGN test key pair, generated in the parent. A FAULTY SIGNER is
// modelled by signing an arbitrary token body with the trusted test key.
// The sink config always carries `initialState`. The dispatcher config carries `newLedgerH0` when the sink module
// exports genesisOf (capability check in the child; the hardened sink needs it to start a new ledger).
// HOSTILE WRITER (two strengths). write(db, f, "keep"): a second connection that keeps the schema; if the database
// aborts the write (triggers, CHECK), WriteRefused is thrown. write(db, f, "drop"): the stronger writer drops every
// trigger, sets PRAGMA ignore_check_constraints, writes, and restores the trigger text (same schema text after).
// Durable state is read from the tables `state` (blob), `settled` (request_id) and `outbox` (request_id, intent).
// EFFECTS (h-judges2): the effects of a flush are the records that the PARENT's receiver got (remote.ts); the child
// never reports them. The ledger is read by the parent with a tolerant parser (ledgerLineIds in remote.ts).
// CHAIN-VALID WRITER (h-judges2, red-team blind spot md_ignore_sig): appendRow() appends a settled row (and its outbox
// row and state change) with the row-log chain RECOMPUTED by the trusted chain function of this tree (genesisOf and
// linkOf, ../../../ts/refund-finality/core/store; the chain is unkeyed and public). A row written so differs from a
// row that the sink wrote only in what the writer chose to put in the token.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";
import * as TE from "../../../ts/refund-finality/encoding";
import * as TSTORE from "../../../ts/refund-finality/core/store";
import { Received, Remote, ledgerLineIds } from "./remote";

export type State = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export type Intent = { chargeId: string; requestId: string; amount: string; reason: string };
export type Outcome = { ok: boolean; reason: string; limit?: boolean };
// kind "limit": three outcomes. ok && !limit = SAFE (PASS); ok && limit = the stated unsafe limit holds (KNOWN-LIMIT);
// !ok = FAIL. Kinds "attack", "control", "integrity": ok = PASS, !ok = FAIL.
export type Regression = { id: string; kind: "attack" | "control" | "limit" | "integrity"; title: string; run: (h: Harness) => Promise<Outcome> };
export type Effect = Received & { intent: Intent };
export type AnchorAdapter = { capture: (h: Harness, dbPath: string) => unknown; apply: (cfg: any, head: unknown) => any };
export type WriterMode = "keep" | "drop";
export class WriteRefused extends Error {}

export const MERGED_DDL = `CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE,
        token TEXT NOT NULL, token_sha256 TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE, intent TEXT NOT NULL);`;
export const TRUSTED_ENCODING_PATH = resolve(__dirname, "../../../ts/refund-finality/encoding.ts");
// The trusted row-log chain of this tree (the formula is in core/store.ts; the same bytes as the anchor design).
export const trustedLinkOf = (prev: string, token: string, intent: string): string => TSTORE.linkOf(prev, token, intent);

type SinkRef = { handle: number };
export class Harness {
  readonly E = TE;
  readonly anchor: AnchorAdapter | null;
  private readonly keys = generateKeyPairSync("ed25519");
  readonly foreignKeys = generateKeyPairSync("ed25519");
  readonly publicKeyPem: string;
  readonly specLockSha256 = TE.sha256hex("h-regress test spec lock");
  readonly checkerSha256 = TE.sha256hex("h-regress test checker");
  remote!: Remote;
  caps: { loadError: string; hasSink: boolean; hasDispatcher: boolean; hasGenesisOf: boolean; graph: string[]; encodingModules: string[] } =
    { loadError: "", hasSink: false, hasDispatcher: false, hasGenesisOf: false, graph: [], encodingModules: [] };
  // Effect-channel faults of every child of this regression (remote.ts); a non-empty list makes the regression FAIL.
  readonly channelProblems: string[] = [];
  dir = "";
  private open = new Set<number>();
  constructor(readonly sinkPath: string, readonly dispatcherPath: string, anchorPath: string | null) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    this.anchor = anchorPath ? require(resolve(anchorPath)) as AnchorAdapter : null;
    this.publicKeyPem = this.keys.publicKey.export({ type: "spki", format: "pem" }) as string;
  }
  // ---- per-regression lifecycle: a fresh directory and a fresh child process
  async begin(id: string): Promise<void> {
    this.dir = mkdtempSync(join(tmpdir(), "forge-regress-" + id.replace(/[^A-Za-z0-9]/g, "_") + "-"));
    await this.startChild();
  }
  private async startChild(): Promise<void> {
    this.remote = new Remote(this.sinkPath, this.dispatcherPath);
    await this.remote.ready;
    this.caps = await this.remote.call("hello");
    if (!this.caps.hasSink) throw new Error("module under test does not export Sink: " + this.caps.loadError);
  }
  private async stopChild(): Promise<void> {
    const r = this.remote; if (!r) return;
    try { await r.stop(); } catch { /* gone */ }
    for (const p of r.problems.splice(0)) this.channelProblems.push(p);
  }
  // A PROCESS restart: the child is killed (no close) and a new child loads the modules again.
  async restart(): Promise<void> { await this.stopChild(); this.open.clear(); await this.startChild(); }
  async end(): Promise<void> {
    await this.stopChild();
    try { rmSync(this.dir, { recursive: true, force: true }); } catch { /* best effort */ }
  }
  path(name: string): string { return join(this.dir, name); }
  // ---- values
  st(chargeId: string, original: string, remaining: string, refundEnabled = true): State { return { chargeId, original, remaining, refundEnabled }; }
  dec(s: State, amount: string): State { return { ...s, remaining: (BigInt(s.remaining) - BigInt(amount)).toString() }; }
  intent(chargeId: string, requestId: string, amount: string, reason = "returned_item"): Intent { return { chargeId, requestId, amount, reason }; }
  cfg(initial: State): any { return { publicKeyPem: this.publicKeyPem, specLockSha256: this.specLockSha256, checkerSha256: this.checkerSha256, initialState: initial }; }
  async dcfg(initial: State): Promise<any> {
    const base: any = { publicKeyPem: this.publicKeyPem, specLockSha256: this.specLockSha256, checkerSha256: this.checkerSha256, initialStateSha256: TE.stateSha256(initial) };
    if (this.caps.hasGenesisOf) base.newLedgerH0 = await this.remote.call("genesis", { initText: TE.canon(initial), lock: this.specLockSha256, checker: this.checkerSha256, pem: this.publicKeyPem });
    return base;
  }
  // ---- tokens (trusted encoding). body(): the body; signBody(): sign a body (key: trusted by default).
  body(pre: State, requestId: string, post: State, intent: Intent): TE.TokenBody {
    return { domain: TE.DOMAIN, specLockSha256: this.specLockSha256, checkerSha256: this.checkerSha256, preStateSha256: TE.stateSha256(pre), requestId, post, intent };
  }
  signBody(body: TE.TokenBody, foreign = false, bytes?: Buffer): string {
    const key = foreign ? this.foreignKeys.privateKey : this.keys.privateKey;
    return TE.canon({ body, signature: sign(null, bytes ?? TE.signedBytes(body), key).toString("base64") });
  }
  sign(pre: State, requestId: string, post: State, intent: Intent): string { return this.signBody(this.body(pre, requestId, post, intent)); }
  honest(pre: State, requestId: string, amount: string, reason = "returned_item"): string {
    return this.sign(pre, requestId, this.dec(pre, amount), this.intent(pre.chargeId, requestId, amount, reason));
  }
  // ---- the sink under test (in the child). openSink returns null when the sink refuses to start.
  async openSink(dbPath: string, cfg: any): Promise<{ sink: SinkRef | null; error: string }> {
    const r = await this.remote.call<{ handle: number; error: string }>("open", { db: dbPath, cfg });
    if (!r.handle) return { sink: null, error: r.error };
    this.open.add(r.handle); return { sink: { handle: r.handle }, error: "" };
  }
  async newStore(name: string, initial: State, cfg?: any): Promise<{ db: string; sink: SinkRef }> {
    const db = this.path(name + ".sqlite");
    const { sink, error } = await this.openSink(db, cfg ?? this.cfg(initial));
    if (sink === null) throw new Error("fresh store refused: " + error);
    const i = await this.remote.call<{ error: string }>("init", { handle: sink.handle, state: initial });
    if (i.error) throw new Error("init refused: " + i.error);
    return { db, sink };
  }
  // The status word that the CHILD reports. Only the status-word cases (K4) use it for a verdict; every other
  // verdict reads durable state.
  async commit(sink: SinkRef | null, text: string): Promise<string> {
    if (sink === null) return "no sink";
    const r = await this.remote.call<{ status: string; reason?: string }>("commit", { handle: sink.handle, text });
    return r.status === "threw" ? "threw: " + String(r.reason).slice(0, 80) : r.status;
  }
  async close(sink: SinkRef | null): Promise<void> { if (sink) { this.open.delete(sink.handle); await this.remote.call("close", { handle: sink.handle }); } }
  // ---- the dispatcher under test (in the child). failAt: the emit with that index gets a failing ACK from the parent.
  // The effects are the records that the parent's receiver got during this flush (remote.ts); failAt: the record
  // with that index gets a failing ACK (the parent decides), so that emit call throws.
  async flush(dbPath: string, initial: State, ledgerName = "ledger.jsonl", failAt?: number): Promise<{ effects: Effect[]; error: string }> {
    if (!this.caps.hasDispatcher) return { effects: [], error: "no dispatcher module loaded" };
    const r = await this.remote.flush({ db: dbPath, ledger: this.path(ledgerName), dcfg: await this.dcfg(initial) }, failAt);
    return { effects: r.effects.map(e => ({ ...e, intent: e.intent as Intent })), error: r.error };
  }
  // Request ids named by the ledger lines (tolerant parser; any line that names the id counts).
  ledgerIds(ledgerName = "ledger.jsonl"): string[] { return ledgerLineIds(this.path(ledgerName)).flat(); }
  // ---- durable state, read by the PARENT with its own read-only connection
  raw<X>(dbPath: string, f: (db: DatabaseSync) => X): X { const db = new DatabaseSync(dbPath, { readOnly: true }); try { return f(db); } finally { db.close(); } }
  outbox(dbPath: string): { request_id: string; intent: Intent }[] {
    return this.raw(dbPath, db => (db.prepare("SELECT request_id, intent FROM outbox ORDER BY seq").all() as any[])
      .map(r => ({ request_id: String(r.request_id), intent: JSON.parse(String(r.intent)) as Intent })));
  }
  settledIds(dbPath: string): string[] {
    return this.raw(dbPath, db => (db.prepare("SELECT request_id FROM settled ORDER BY seq").all() as any[]).map(r => String(r.request_id)));
  }
  stored(dbPath: string): State | null {
    return this.raw(dbPath, db => { const r = db.prepare("SELECT blob FROM state WHERE id = 1").get() as any; return r ? JSON.parse(String(r.blob)) as State : null; });
  }
  // ---- the hostile database writer (no key)
  write(dbPath: string, f: (db: DatabaseSync) => void, mode: WriterMode): void {
    const db = new DatabaseSync(dbPath);
    try {
      db.exec("PRAGMA busy_timeout = 5000");
      if (mode === "keep") {
        try { db.exec("BEGIN IMMEDIATE"); f(db); db.exec("COMMIT"); }
        catch (e) { try { db.exec("ROLLBACK"); } catch { /* none */ } throw new WriteRefused(String((e as Error).message).slice(0, 120)); }
        return;
      }
      const trig = db.prepare("SELECT name, sql FROM sqlite_schema WHERE type = 'trigger' ORDER BY name").all() as { name: string; sql: string }[];
      db.exec("PRAGMA ignore_check_constraints = ON");
      db.exec("BEGIN IMMEDIATE");
      try {
        for (const t of trig) db.exec(`DROP TRIGGER "${t.name.replace(/"/g, '""')}"`);
        f(db);
        for (const t of trig) db.exec(t.sql);
        db.exec("COMMIT");
      } catch (e) { try { db.exec("ROLLBACK"); } catch { /* none */ } throw new WriteRefused("even with triggers dropped: " + String((e as Error).message).slice(0, 100)); }
    } finally { db.close(); }
  }
  // INSERT for the hostile writer into a table whose schema may have more NOT NULL columns than the merged one (the
  // hardened sink: prev, self). Missing NOT NULL columns without a default get: prev = the last row's self (if the
  // table has `self`), any other = SHA-256 of a fixed text. The writer has no key and no sink code.
  insertRow(db: DatabaseSync, table: string, values: Record<string, string>): void {
    const cols = db.prepare(`PRAGMA table_info(${table})`).all() as { name: string; notnull: number; dflt_value: unknown; pk: number }[];
    const v: Record<string, string | null> = { ...values };
    const hasSelf = cols.some(c => c.name === "self");
    for (const c of cols) {
      if (c.name in v || c.pk || !c.notnull || c.dflt_value !== null) continue;
      if (c.name === "prev" && hasSelf) v.prev = ((db.prepare(`SELECT self FROM ${table} ORDER BY seq DESC LIMIT 1`).get() as any)?.self ?? TE.sha256hex("h-judges writer"));
      else v[c.name] = TE.sha256hex("h-judges writer " + c.name);
    }
    const names = Object.keys(v);
    db.prepare(`INSERT INTO ${table}(${names.join(", ")}) VALUES (${names.map(() => "?").join(", ")})`).run(...names.map(n => v[n]));
  }
  // CHAIN-VALID WRITER (see the header). Appends the token `tok` as the next settled row. Hardened schema (columns
  // prev, self): seq = the next position, prev = genesis (meta) or the self of the last outbox row, self =
  // trustedLinkOf(prev, token, intent text); the outbox row and the state change are written by the store's own
  // trigger when it exists (writer "keep"), or by the writer (writer "drop": triggers dropped and restored). Merged
  // schema (no chain): settled row, outbox row, state blob. The intent text is canon(body.intent) (the token is canonical,
  // so it equals json_extract(token, '$.body.intent')).
  appendRow(dbPath: string, tok: string, mode: WriterMode): void {
    const b = JSON.parse(tok).body, intentText = TE.canon(b.intent), rid = String(b.requestId);
    this.write(dbPath, d => {
      const cols = (t: string) => (d.prepare(`PRAGMA table_info(${t})`).all() as { name: string }[]).map(c => c.name);
      const sc = cols("settled"), stc = cols("state");
      if (sc.includes("self")) {
        const seq = Number((d.prepare("SELECT coalesce(max(seq), 0) AS m FROM settled").get() as any).m) + 1;
        const prev = seq === 1 ? String((d.prepare("SELECT genesis FROM meta").get() as any).genesis)
          : String((d.prepare("SELECT self FROM outbox WHERE seq = ?").get(seq - 1) as any)?.self);
        const self = trustedLinkOf(prev, tok, intentText);
        d.prepare("INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (?, ?, ?, ?, ?, ?)").run(seq, rid, tok, TE.sha256hex(tok), prev, self);
        if (!d.prepare("SELECT 1 AS x FROM outbox WHERE seq = ?").get(seq))
          d.prepare("INSERT INTO outbox(seq, request_id, intent, prev, self) VALUES (?, ?, ?, ?, ?)").run(seq, rid, intentText, prev, self);
        const s = d.prepare("SELECT * FROM state WHERE id = 1").get() as any;
        if (Number(s.seq) !== seq) {
          d.prepare("UPDATE state SET blob = ?, seq = ?, refunded = refunded + ? WHERE id = 1").run(TE.canon(b.post), seq, BigInt(b.intent.amount));
        }
      } else {
        this.insertRow(d, "settled", { request_id: rid, token: tok, token_sha256: TE.sha256hex(tok) });
        if ((d.prepare("SELECT COUNT(*) AS n FROM outbox WHERE request_id = ?").get(rid) as any).n === 0) this.insertRow(d, "outbox", { request_id: rid, intent: intentText });
        if (stc.includes("blob")) d.prepare("UPDATE state SET blob = ? WHERE id = 1").run(TE.canon(b.post));
      }
    }, mode);
  }
  // Database file for the legacy fixture (X3): created by the parent in the merged format.
  create(dbPath: string, f: (db: DatabaseSync) => void): void { const db = new DatabaseSync(dbPath); try { f(db); } finally { db.close(); } }
}

export const sum = (xs: string[]): bigint => xs.reduce((a, x) => a + BigInt(x), 0n);
export const pass = (reason: string): Outcome => ({ ok: true, reason });
export const fail = (reason: string): Outcome => ({ ok: false, reason });
export const knownLimit = (reason: string): Outcome => ({ ok: true, limit: true, reason });

// A hostile-writer regression in two strengths. The scenario runs first with the writer that keeps the schema.
// If the database refuses that write, the refusal is the SAFE outcome for that writer, and the scenario runs again
// (fresh directory, fresh child) with the writer that drops and restores the triggers; that run gives the verdict.
export async function twoWriters(h: Harness, id: string, scenario: (h: Harness, mode: WriterMode) => Promise<Outcome>): Promise<Outcome> {
  try { return await scenario(h, "keep"); }
  catch (e) {
    if (!(e instanceof WriteRefused)) throw e;
    const weak = "keep-schema writer: write refused by the database (" + e.message.slice(0, 60) + ")";
    await h.end(); await h.begin(id + "-drop");
    try { const o = await scenario(h, "drop"); return { ...o, reason: weak + "; drop-triggers writer: " + o.reason }; }
    catch (e2) { if (e2 instanceof WriteRefused) return pass(weak + "; drop-triggers writer: " + e2.message); throw e2; }
  }
}
