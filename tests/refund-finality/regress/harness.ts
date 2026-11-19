// Shared harness of the refund-finality regressions (night shift 2026-11-19, task h-regress). A TEST, not a proof.
// The sink and the dispatcher under test are loaded BY PATH, so one regression file runs unchanged against the
// merged sink, the v6 draft and the hardened sink. Only their public interface is used:
//   new Sink(path, cfg), sink.init(state), sink.commit(tokenText), sink.close();
//   new Dispatcher(dbPath, ledgerPath, dcfg, emit), dispatcher.flush().
// The sink config always carries `initialState` (required by the v6 draft; an extra key for the merged sink).
// Durable state is read with raw SQL from the tables `state`, `settled` and `outbox` of the merged schema; the
// hostile-writer regressions change those tables with raw SQL from a second connection (the database writer).
// Keys: one TEST Ed25519 key pair, generated in this process. The FAULTY SIGNER is modelled by signing an
// arbitrary token body with that trusted key (no minter is used for a bad token). Canonical bytes come from the
// encoding.ts next to the sink under test (or the path given with --encoding).
// Determinism: fixed ids and amounts, no clock, no network, no randomness except the key (no result depends on
// the key bytes). Every regression gets a fresh directory under the system temp directory; it is removed at exit.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";

export type State = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export type Intent = { chargeId: string; requestId: string; amount: string; reason: string };
export type Outcome = { ok: boolean; reason: string };
export type Regression = { id: string; kind: "attack" | "control" | "limit"; title: string; run: (h: Harness) => Outcome };
export type Effect = { requestId: string; intent: Intent };
// Optional anchor adapter (runner argument expectedHeadMode = path of a module that exports these two functions).
// capture(h, dbPath): the external expected head, taken from an honest store; apply(cfg, head): the sink config
// that carries it. The adapter is the only place that knows the hardened sink's field name.
export type AnchorAdapter = { capture: (h: Harness, dbPath: string) => unknown; apply: (cfg: any, head: unknown) => any };

export const MERGED_DDL = `CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY CHECK (id = 1), blob TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS settled(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE,
        token TEXT NOT NULL, token_sha256 TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS outbox(seq INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT NOT NULL UNIQUE, intent TEXT NOT NULL);`;

const temps: string[] = [];
process.on("exit", () => { for (const d of temps) { try { rmSync(d, { recursive: true, force: true }); } catch { /* best effort */ } } });

export class Harness {
  readonly Sink: any; readonly Dispatcher: any; readonly E: any; readonly anchor: AnchorAdapter | null;
  private readonly keys = generateKeyPairSync("ed25519");
  readonly publicKeyPem: string;
  readonly specLockSha256: string; readonly checkerSha256: string;
  private open: any[] = [];
  dir = "";
  constructor(sinkPath: string, dispatcherPath: string, encodingPath: string, anchorPath: string | null) {
    /* eslint-disable @typescript-eslint/no-require-imports */
    this.Sink = require(resolve(sinkPath)).Sink;
    this.Dispatcher = require(resolve(dispatcherPath)).Dispatcher;
    this.E = require(resolve(encodingPath));
    this.anchor = anchorPath ? require(resolve(anchorPath)) as AnchorAdapter : null;
    /* eslint-enable @typescript-eslint/no-require-imports */
    if (typeof this.Sink !== "function" || typeof this.Dispatcher !== "function") throw new Error("module does not export Sink / Dispatcher");
    this.publicKeyPem = this.keys.publicKey.export({ type: "spki", format: "pem" }) as string;
    this.specLockSha256 = this.E.sha256hex("h-regress test spec lock");
    this.checkerSha256 = this.E.sha256hex("h-regress test checker");
  }
  // ---- per-regression lifecycle
  begin(id: string): void { this.dir = mkdtempSync(join(tmpdir(), "forge-regress-" + id.replace(/[^A-Za-z0-9]/g, "_") + "-")); temps.push(this.dir); }
  end(): void {
    for (const s of this.open) { try { s.close(); } catch { /* already closed */ } }
    this.open = [];
    try { rmSync(this.dir, { recursive: true, force: true }); } catch { /* removed at exit */ }
  }
  path(name: string): string { return join(this.dir, name); }
  // ---- values
  st(chargeId: string, original: string, remaining: string, refundEnabled = true): State { return { chargeId, original, remaining, refundEnabled }; }
  dec(s: State, amount: string): State { return { ...s, remaining: (BigInt(s.remaining) - BigInt(amount)).toString() }; }
  intent(chargeId: string, requestId: string, amount: string, reason = "returned_item"): Intent { return { chargeId, requestId, amount, reason }; }
  cfg(initial: State): any { return { publicKeyPem: this.publicKeyPem, specLockSha256: this.specLockSha256, checkerSha256: this.checkerSha256, initialState: initial }; }
  dcfg(initial: State): any { return { publicKeyPem: this.publicKeyPem, specLockSha256: this.specLockSha256, checkerSha256: this.checkerSha256, initialStateSha256: this.E.stateSha256(initial) }; }
  // ---- tokens. sign(): the trusted key signs ANY body (a faulty signer). honest(): the body that an honest issuer
  // would sign for an authorized request on the pre-state `pre` (post = pre with remaining decreased by amount).
  sign(pre: State, requestId: string, post: State, intent: Intent): string {
    const body = { domain: this.E.DOMAIN, specLockSha256: this.specLockSha256, checkerSha256: this.checkerSha256,
      preStateSha256: this.E.stateSha256(pre), requestId, post, intent };
    return this.E.canon({ body, signature: sign(null, this.E.signedBytes(body), this.keys.privateKey).toString("base64") });
  }
  honest(pre: State, requestId: string, amount: string, reason = "returned_item"): string {
    return this.sign(pre, requestId, this.dec(pre, amount), this.intent(pre.chargeId, requestId, amount, reason));
  }
  // ---- the sink under test. openSink returns null when the sink refuses to start (that refusal is recorded).
  openSink(dbPath: string, cfg: any): { sink: any | null; error: string } {
    try { const sink = new this.Sink(dbPath, cfg); this.open.push(sink); return { sink, error: "" }; }
    catch (e) { return { sink: null, error: String((e as Error)?.message ?? e).slice(0, 160) }; }
  }
  // A fresh store for `initial`: open, init. Throws if the sink under test cannot even do that (a harness fault).
  newStore(name: string, initial: State, cfg?: any): { db: string; sink: any } {
    const db = this.path(name + ".sqlite");
    const { sink, error } = this.openSink(db, cfg ?? this.cfg(initial));
    if (sink === null) throw new Error("fresh store refused: " + error);
    sink.init(initial);
    return { db, sink };
  }
  commit(sink: any, text: string): string {
    try { const r = sink.commit(text); return String(r?.status ?? "no status"); }
    catch (e) { return "threw: " + String((e as Error)?.message ?? e).slice(0, 80); }
  }
  close(sink: any): void { try { sink?.close(); } catch { /* closed */ } this.open = this.open.filter(s => s !== sink); }
  // ---- the dispatcher under test. Effects are collected by the emit callback, so effects sent before a later
  // error still count. A thrown error (e.g. a refused ledger) is reported in `error`.
  flush(dbPath: string, initial: State, ledgerName = "ledger.jsonl"): { effects: Effect[]; error: string } {
    const effects: Effect[] = [];
    let error = "";
    try {
      const d = new this.Dispatcher(dbPath, this.path(ledgerName), this.dcfg(initial),
        (e: any, i: any) => effects.push({ requestId: String(e?.requestId), intent: { ...i } }));
      d.flush();
    } catch (e) { error = String((e as Error)?.message ?? e).slice(0, 120); }
    return { effects, error };
  }
  // ---- durable state, read with raw SQL (read only)
  raw<X>(dbPath: string, f: (db: DatabaseSync) => X): X { const db = new DatabaseSync(dbPath); try { return f(db); } finally { db.close(); } }
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
  // A second connection that writes the database file (the hostile database writer; it has no key).
  foreign(dbPath: string, f: (db: DatabaseSync) => void): void { this.raw(dbPath, f); }
}

export const sum = (xs: string[]): bigint => xs.reduce((a, x) => a + BigInt(x), 0n);
export const pass = (reason: string): Outcome => ({ ok: true, reason });
export const fail = (reason: string): Outcome => ({ ok: false, reason });

// Runs a list of regressions, one fresh temp directory each. Prints `PASS|FAIL id: reason`. Returns the fail count.
export function runAll(h: Harness, list: Regression[]): number {
  let fails = 0;
  for (const r of list) {
    h.begin(r.id);
    let o: Outcome;
    try { o = r.run(h); } catch (e) { o = fail("regression threw: " + String((e as Error)?.message ?? e).slice(0, 160)); }
    h.end();
    if (!o.ok) fails++;
    // A regression of kind "limit" records an UNSAFE outcome that is a stated, unfixed limit (for example a rollback
    // without an outside anchor). When the limit still holds, the line says KNOWN-LIMIT, never PASS: a reader of the
    // lines must not take an unsafe outcome for a pass (red team note on X6-P1). The exit code does not count it as
    // a failure, because nothing regressed.
    const word = !o.ok ? "FAIL" : (r.kind === "limit" && o.reason.startsWith("documented limit holds") ? "KNOWN-LIMIT" : "PASS");
    console.log(`${word} ${r.id}: ${o.reason}`);
  }
  return fails;
}

// Standalone use of one regression file: node --import tsx <file> <sink.ts> <dispatcher.ts> [anchor adapter]
export function standalone(list: Regression[], argv: string[]): void {
  if (argv.length < 4) { console.error("usage: <regression file> <sink module> <dispatcher module> [anchor adapter]"); process.exit(2); }
  const sinkPath = resolve(argv[2]);
  const h = new Harness(sinkPath, argv[3], join(sinkPath, "..", "encoding.ts"), argv[4] && argv[4] !== "none" ? argv[4] : null);
  process.exit(runAll(h, list) === 0 ? 0 : 1);
}
