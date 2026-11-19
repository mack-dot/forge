// MUTANT md_emit_before_ledger (c19 attack input; edited copy of fix-f08a21c1). NOT a fix.
// Slice 1 (F2.2): the outbound refund dispatcher. It stands between the outbox and the external effect.
// It trusts NOTHING in the database. Before each run it applies the sink's store audit (h1, core/store.ts; see
// flushLocked). Before each effect it checks, with the public key only:
//   1. the settled row for the outbox row holds a token in canonical form with the pinned ids;
//   2. the Ed25519 signature of the issuer verifies for exactly that token body;
//   3. the outbox intent and request id are the signed ones;
//   4. chain: the token's pre-state hash is the post-state hash of the previous claimed row (first: the pinned
//      initial state hash);
//   5. the request id is not in the dispatcher's own append-only ledger.
//
// LEDGER (h-dispatch, red team C-ATT-17/18). The ledger is a file OUTSIDE the database. Each line is one JSON object:
//   intent   {kind:"intent", n, requestId, tokenSha256, preStateSha256, postStateSha256, intentSha256, rowHead, run, pid}
//            appended and synced BEFORE the effect of store row n. `run` is a random 128-bit nonce of this run.
//   done     {kind:"done", n, requestId, run}      appended and synced AFTER emit() returned.
//   failed   {kind:"failed", n, requestId, run, error}   appended (best effort) when emit() threw; then the run stops.
//   resolved {kind:"resolved", n, requestId, outcome:"sent"|"retry", note}   an operator decision (resolveInDoubt).
// CLAIM RULE: the FIRST intent line for row n (after the last "retry" decision for n) is THE claim of n. A run emits
// row n only if, on a RE-READ of the ledger after its own intent line was synced, the claim of n carries its own run
// nonce. Any later intent line for n must describe the same row (a lost race); it is never emitted. So two runs that
// overlap (a removed lock, a stale view) never both emit one row, and never both emit one request id (ids are unique
// over claims). This rests on assumption APPEND-ATOMIC (below), NOT on the lock.
// DELIVERY POLICY: AT MOST ONCE by the dispatcher. A claim without "done" (a crash, a slow run, a throwing emit:
// "failed") is IN DOUBT: it is never counted as dispatched; every run reports it in `refused` (reason "in doubt: ...")
// and in `inDoubt`. Only an operator decision ends that: resolveInDoubt(id, "sent") counts it as dispatched;
// resolveInDoubt(id, "retry") lets the NEXT run claim and emit it again: AT LEAST ONCE, on the operator's word
// (assumption RECEIVER-RECONCILED). resolveInDoubt refuses while the claiming process is alive on this host.
// NOT POSSIBLE without an idempotent receiver (assumption, named IDEMPOTENT-RECEIVER-ABSENT): exactly-once. A crash
// between the effect and the "done" line leaves a claim in doubt whose effect DID leave; a crash (or a throw) before
// the effect leaves one whose effect did NOT leave; the ledger cannot tell them apart. The operator must ask the
// receiver. If the operator answers "retry" for an effect that left, the receiver gets it twice.
//
// LOCK (owned; C-ATT-17). One run at a time: flush() creates <resolved ledger path>.lock exclusively ("wx") and writes
// {pid, run, host, startedAt} into it. A lock whose pid is dead on THIS host is taken over automatically (C-HOST-02;
// assumption SINGLE-HOST-PID: the pid check is meaningful only on the host named in the lock; another host's lock
// and an unreadable lock are never taken over). Before each claim the run re-reads the lock: if the file is gone or names another run,
// the run STOPS (alarm; nothing more sent). At the end it removes the lock ONLY if the file still names its own run.
// The lock is for order and liveness only; safety is the claim rule. Assumptions: LOCK-LOCAL (exclusive create is
// atomic: a local file system, not NFS); the release (read, compare, unlink) is not atomic: if a person removes the
// lock and a new run creates one in that window, the old run may remove the new lock; the claim rule still holds.
// Not chosen: an OS-level lock (flock/fcntl): Node has no flock; a SQLite file lock is an fcntl lock on an INODE, and a
// person who removes that file gives the next run a new inode and a second lock (the same defect).
// The ledger path is resolved first (the ledger file is created empty if it is missing), so a symbolic link to the
// ledger file or to a folder above it gives the same lock. NOT covered: a hard link to the ledger file.
// OPERATOR STEP after a crash (a stale lock): (1) nothing, if the dead run was on this host (automatic takeover);
// else remove <ledger>.lock; this cannot cause a duplicate, also if the run still lives (it stops at its next lock
// check, or loses its next claim); (2) run flush(): the crashed claim appears in `inDoubt`; (3) ask the receiver; call resolveInDoubt(id, "sent") or resolveInDoubt(id, "retry"). Step (3) with
// "retry" is the ONLY step that can cause a second effect, and only if the receiver's answer was wrong.
//
// ROLLBACK (C-ATT-19). The dispatcher is a row-log witness of the sink: every claim records the store's row-log head
// after its row (rowHead) and the token hash; the store must still EXTEND every claimed row, or the run stops (a rollback
// or rewrite of the sink's store). It does NOT detect an OLDER LEDGER (a restored backup of the ledger, or of the ledger
// and the database together): the rows after the restored ledger look exactly like rows not yet dispatched, and they
// are emitted again. Detected without an outside anchor: a ledger restored WITHOUT the dispatch witness file
// <resolved database path>.dispatch-witness.json (see writeWitness: it binds the store to one ledger path and keeps a
// copy of the last claim). NOT detected: a restore of the ledger and the witness together. Only an outside anchor
// detects that: cfg.ledgerFloor = {n, rowHead}, the `ledgerHead` of an earlier
// result kept on another host or medium; the ledger must reach row n with that rowHead, else the run stops. Without it:
// assumption LEDGER-MONOTONE (the ledger file is never replaced by an older copy) and, for the database, ANCHOR-MONOTONE.
// h1: a missing or empty ledger is an ERROR when the store has committed rows, unless cfg.newLedgerH0 is the store's
// registered h_0 (an explicit new ledger). (Before h1 a lost ledger sent everything again: h-anchor probe, control E.)
// Row types (C-ATT-20): the dispatcher never skips an outbox row. A row whose request_id is not TEXT (or holds U+0000)
// is refused under its exact bytes with a "dispatcher alarm" reason; it is never counted as dispatched.
// SHORT WRITES (C-ATT-22): every ledger line is written by a loop (a short write is continued; 0 bytes or an error stops
// the run BEFORE the emit) and synced; a claim is emitted only after the re-read finds the COMPLETE line (ending in 0x0A).
// Bytes after the last 0x0A are an incomplete record: never emitted; the next run cuts them off under its lock and keeps
// them in <ledger>.torn-<run> (result.tornTailCut). A complete line that does not parse is an alarm ("not one chain").
// Limit: a torn tail left by a run that RACES this one is not cut; the next line then merges with it and every later run
// stops (fail closed; a person must repair). A store BELOW the ledger (power loss, no F_FULLFSYNC in the sink) stops the
// run (the witness check above): never treated as new work.
// Ledger format: lines without `kind` (the h1 format before h-dispatch) are refused ("not one chain"); no migration.
// APPEND-ATOMIC: one write() of one line in O_APPEND mode is not interleaved with another, and a reader that starts
// after the writer's fsync returned sees the line and every line before it (local POSIX file system; TESTED-UNPROVED).
// NOT proved. Assumed and not checked: the ledger file, this process and the pinned configuration are
// out of the attacker's reach; the issuer's key is not leaked.
// Known limit (U428, case D14): if the issuer signs two transitions for one pre-state and an attacker
// can write the database file WITHOUT the key, the dispatcher can send the one that the sink did not commit. h1: the
// append-only triggers stop that swap through SQL; a writer who disables or drops the triggers and recomputes the
// (unkeyed) row-log chain is not detected here: the store audit accepts any authorized, signed transition.
import { createPublicKey, randomBytes, verify, KeyObject } from "node:crypto";
import { closeSync, existsSync, fsyncSync, ftruncateSync, openSync, readFileSync, realpathSync, renameSync, unlinkSync, writeSync } from "node:fs";
import { hostname } from "node:os";
import { DatabaseSync } from "node:sqlite";
import { Intent, canon, isState, isToken, sha256hex, signatureBytes, signedBytes } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/ts/refund-finality/encoding";
import { AuditedRow, StoreAuditor, conv, loadCore, readMeta, validInitial } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/ts/refund-finality/core/store";

// newLedgerH0 (optional): the registered h_0 of the store (sink.ts genesisOf). A missing or empty ledger is an ERROR when
// the store holds committed rows, unless this field equals the store's h_0 (an explicit "new ledger").
// ledgerFloor (optional): an outside anchor of the LEDGER (an earlier result's ledgerHead): the ledger must hold the claim
// of row n with that rowHead. Detects a restored (older) ledger only when it comes from outside the ledger's medium.
export type LedgerHead = { n: number; rowHead: string };
export type DispatcherConfig = { publicKeyPem: string; specLockSha256: string; checkerSha256: string; initialStateSha256: string; newLedgerH0?: string; ledgerFloor?: LedgerHead };
export type Effect = { requestId: string; intent: string };
export type FlushResult = { emitted: Effect[]; refused: { seq: number; requestId: string; reason: string }[]; alreadyDispatched: number;
  inDoubt?: string[]; ledgerHead?: LedgerHead; staleLockTakenOver?: { pid: number; run: string }; tornTailCut?: string };
type ClaimFields = { n: number; requestId: string; tokenSha256: string; preStateSha256: string; postStateSha256: string; intentSha256: string; rowHead: string };
type IntentLine = ClaimFields & { kind: "intent"; run: string; pid: number };
type Slot = { claim: IntentLine; status: "pending" | "done" | "failed" | "sent" | "retry"; superseded: string[] };
type Ledger = { slots: Map<number, Slot>; ids: Set<string>; maxN: number; tail: string; tailAt: number };

const HEX64 = /^[0-9a-f]{64}$/, RUN = /^[0-9a-f]{32}$/;
const NOT_CHAIN = "dispatcher ledger is not one chain";
const CLAIM_KEYS: (keyof ClaimFields)[] = ["n", "requestId", "tokenSha256", "preStateSha256", "postStateSha256", "intentSha256", "rowHead"];
const sameRow = (a: ClaimFields, b: ClaimFields): boolean => CLAIM_KEYS.every(k => a[k] === b[k]);
const alive = (pid: number): boolean => {
  if (pid === process.pid) return true;
  try { process.kill(pid, 0); return true; } catch (error) { return (error as NodeJS.ErrnoException).code === "EPERM"; }
};

export class Dispatcher {
  private readonly key: KeyObject;
  private readonly M = loadCore();
  private readonly cv = conv(this.M);
  private readonly run = randomBytes(16).toString("hex");   // this run's nonce: in the lock and in its claims
  private lockPath = "";
  private tookOver: { pid: number; run: string; host: string } | null = null;   // a dead owner's lock taken over (C-HOST-02)
  constructor(private readonly dbPath: string, private readonly ledgerPath: string, private readonly cfg: DispatcherConfig,
              private readonly emit: (effect: Effect, intent: Intent) => void) {
    this.key = createPublicKey(cfg.publicKeyPem);
  }
  // Reads the whole ledger and checks it. Fails closed: any line out of the rules above stops the run.
  private ledger(): Ledger {
    const slots = new Map<number, Slot>(), ids = new Set<string>();
    let maxN = 0;
    const bytes = existsSync(this.ledgerPath) ? readFileSync(this.ledgerPath) : Buffer.alloc(0);
    // C-ATT-22: only lines that END with 0x0A count. Bytes after the last 0x0A are an incomplete record (a short write,
    // a crash inside a write): never confirmed, so never emitted (claimAndEmit emits only after a complete line is re-read).
    const tailAt = bytes.lastIndexOf(0x0a) + 1;
    const text = bytes.subarray(0, tailAt).toString("utf8"), tail = bytes.subarray(tailAt).toString("utf8");
    for (const raw of text.split("\n").filter(l => l.length > 0)) {
      let e: any;
      try { e = JSON.parse(raw); } catch { throw new Error(NOT_CHAIN); }
      if (e === null || typeof e !== "object" || !Number.isSafeInteger(e.n) || e.n < 1 || typeof e.requestId !== "string") throw new Error(NOT_CHAIN);
      const s = slots.get(e.n);
      if (e.kind === "intent") {
        if (!HEX64.test(e.tokenSha256) || !HEX64.test(e.preStateSha256) || !HEX64.test(e.postStateSha256) || !HEX64.test(e.intentSha256) ||
            !HEX64.test(e.rowHead) || typeof e.run !== "string" || !RUN.test(e.run) || !Number.isSafeInteger(e.pid)) throw new Error(NOT_CHAIN);
        if (s === undefined) {
          const pre = e.n === 1 ? this.cfg.initialStateSha256 : slots.get(e.n - 1)?.claim.postStateSha256;
          if (e.n !== maxN + 1 || e.preStateSha256 !== pre || ids.has(e.requestId)) throw new Error(NOT_CHAIN);
          slots.set(e.n, { claim: e as IntentLine, status: "pending", superseded: [] }); ids.add(e.requestId); maxN = e.n;
        } else {
          if (!sameRow(e, s.claim)) throw new Error(NOT_CHAIN);           // a lost race or a re-claim: the same row only
          if (s.status === "retry") { s.claim = e as IntentLine; s.status = "pending"; }   // the re-claim after "retry"
        }
      } else if (e.kind === "done" || e.kind === "failed") {
        if (s === undefined || e.requestId !== s.claim.requestId || typeof e.run !== "string") throw new Error(NOT_CHAIN);
        if (e.run !== s.claim.run) {
          if (s.superseded.includes(e.run)) throw new Error("dispatcher alarm: request id " + e.requestId + " was resolved as \"retry\" but the run that claimed it first reports " + e.kind + "; the effect may have left twice; a person must reconcile");
          throw new Error(NOT_CHAIN);
        }
        if (e.kind === "done") { if (s.status !== "pending" && s.status !== "sent") throw new Error(NOT_CHAIN); s.status = "done"; }
        else { if (s.status !== "pending") throw new Error(NOT_CHAIN); s.status = "failed"; }
      } else if (e.kind === "resolved") {
        if (s === undefined || e.requestId !== s.claim.requestId || (s.status !== "pending" && s.status !== "failed") ||
            (e.outcome !== "sent" && e.outcome !== "retry")) throw new Error(NOT_CHAIN);
        if (e.outcome === "retry") s.superseded.push(s.claim.run);
        s.status = e.outcome;
      } else throw new Error(NOT_CHAIN);
    }
    return { slots, ids, maxN, tail, tailAt };
  }
  // C-ATT-22: a write loop; a short write is continued, a write of 0 bytes or an error stops the run BEFORE any emit.
  private append(line: object): void {
    const data = Buffer.from(JSON.stringify(line) + "\n", "utf8");
    const fd = openSync(this.ledgerPath, "a");
    try {
      for (let off = 0; off < data.length;) {
        const k = writeSync(fd, data, off, data.length - off);
        if (!(k > 0)) throw new Error("dispatcher ledger write wrote 0 bytes (disk full?); nothing sent for this line");
        off += k;
      }
      fsyncSync(fd);
    } finally { closeSync(fd); }
  }
  // C-ATT-22: an incomplete last record is cut off (under this run's lock) and kept in <ledger>.torn-<run> as evidence.
  private cutTornTail(L: Ledger): string {
    if (L.tail.length === 0) return "";
    if (this.lockOwner() !== this.run) throw new Error("dispatcher alarm: lock lost before the ledger repair");
    const keep = this.ledgerPath + ".torn-" + this.run;
    const fk = openSync(keep, "wx");
    try { writeSync(fk, L.tail); fsyncSync(fk); } finally { closeSync(fk); }
    const fd = openSync(this.ledgerPath, "r+");
    try { ftruncateSync(fd, L.tailAt); fsyncSync(fd); } finally { closeSync(fd); }
    return keep;
  }
  private lockOwner(): string | null {
    try { const o = JSON.parse(readFileSync(this.lockPath, "utf8")); return typeof o?.run === "string" ? o.run : null; } catch { return null; }
  }
  private acquire(): void {
    closeSync(openSync(this.ledgerPath, "a"));   // (a missing ledger is judged in flushLocked: no lines = a NEW ledger)
    this.lockPath = realpathSync(this.ledgerPath) + ".lock";
    let fd: number;
    try { fd = openSync(this.lockPath, "wx"); } catch {
      // C-HOST-02: a lock whose owner process is dead on THIS host is taken over (no manual step). The lock is moved
      // away by rename (atomic: one taker), re-read, and deleted only if it still names the dead run; else put back.
      // Safety does not depend on this step (claim rule); a wrong takeover only lets two runs race for claims.
      const held = this.readLock(this.lockPath);
      if (held === null || held.host !== hostname() || alive(held.pid)) throw new Error("dispatcher lock is held: another run is active, or a stopped run left the lock file" + (held === null ? " (unreadable lock file: a person must check and remove it)" : " (pid " + held.pid + " on " + held.host + ")"));
      const moved = this.lockPath + ".stale-" + this.run;
      try { renameSync(this.lockPath, moved); } catch { throw new Error("dispatcher lock is held: another run took it over first"); }
      const again = this.readLock(moved);
      if (again === null || again.run !== held.run) { try { renameSync(moved, this.lockPath); } catch { /* best effort */ } throw new Error("dispatcher lock is held: the lock changed during takeover"); }
      unlinkSync(moved);
      this.tookOver = held;
      try { fd = openSync(this.lockPath, "wx"); } catch { throw new Error("dispatcher lock is held: another run took it over first"); }
    }
    try { writeSync(fd, JSON.stringify({ pid: process.pid, run: this.run, host: hostname(), startedAt: new Date().toISOString() })); fsyncSync(fd); } finally { closeSync(fd); }
  }
  private readLock(path: string): { pid: number; run: string; host: string } | null {
    try { const o = JSON.parse(readFileSync(path, "utf8"));
      return Number.isSafeInteger(o?.pid) && typeof o.run === "string" && typeof o.host === "string" ? { pid: o.pid, run: o.run, host: o.host } : null; } catch { return null; }
  }
  // The dispatch witness (C-HOST-05, C-ATT-19): <resolved database path>.dispatch-witness.json = {ledger, n, rowHead}.
  // It binds the store to ONE ledger file (resolved path) and keeps a second copy of the ledger's last claim. A run
  // stops if the store is bound to another ledger (a relative path from another directory, a second ledger, also with
  // cfg.newLedgerH0 still set) or if the ledger does not reach the witness's claim (a ledger restored WITHOUT the
  // witness). A restore of both files together is NOT detected (LEDGER-MONOTONE). Removing the witness file is the
  // explicit operator step to bind a new ledger; the newLedgerH0 rule then applies.
  private witnessPath(): string { return realpathSync(this.dbPath) + ".dispatch-witness.json"; }
  private readWitness(): { ledger: string; n: number; rowHead: string } | null {
    const p = this.witnessPath();
    if (!existsSync(p)) return null;
    let w: any;
    try { w = JSON.parse(readFileSync(p, "utf8")); } catch { w = null; }
    if (w === null || typeof w.ledger !== "string" || !Number.isSafeInteger(w.n) || w.n < 0 || (w.n > 0 && !HEX64.test(w.rowHead))) {
      throw new Error("dispatcher alarm: the dispatch witness " + p + " is unreadable; a person must check it");
    }
    return w;
  }
  private writeWitness(L: Ledger): void {
    const p = this.witnessPath(), tmp = p + ".tmp-" + this.run;
    const w = { ledger: realpathSync(this.ledgerPath), n: L.maxN, rowHead: L.maxN > 0 ? L.slots.get(L.maxN)!.claim.rowHead : "" };
    const fd = openSync(tmp, "w");
    try { writeSync(fd, JSON.stringify(w)); fsyncSync(fd); } finally { closeSync(fd); }
    renameSync(tmp, p);
  }
  private release(): void {
    if (this.lockOwner() === this.run) { try { unlinkSync(this.lockPath); } catch { /* gone */ } }
  }
  private check(row: { seq: number; request_id: string; intent: string }, tokenText: string | undefined, head: string):
      { ok: true; line: ClaimFields; intent: Intent } | { ok: false; reason: string } {
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
    return { ok: true, intent: body.intent, line: { n: row.seq, requestId: body.requestId, tokenSha256: sha256hex(tokenText), preStateSha256: head,
      postStateSha256: sha256hex(canon(body.post)), intentSha256: sha256hex(row.intent), rowHead: "" } };
  }
  flush(): FlushResult {
    this.acquire();
    try { return this.flushLocked(); } finally { this.release(); }
  }
  // The operator's decision for a claim in doubt (see the header). "sent": the receiver has the effect; it counts as
  // dispatched. "retry": the receiver does NOT have it; the next run claims and emits it again (at least once).
  // Refused while a lock is held, while the claiming process is alive on this host, or when the id is not in doubt.
  resolveInDoubt(requestId: string, outcome: "sent" | "retry", note: string): void {
    if (outcome !== "sent" && outcome !== "retry") throw new Error("outcome must be sent or retry");
    this.acquire();
    try {
      const L = this.ledger();
      const slot = [...L.slots.values()].find(s => s.claim.requestId === requestId);
      if (slot === undefined || (slot.status !== "pending" && slot.status !== "failed")) throw new Error("request id " + requestId + " is not in doubt");
      if (slot.claim.pid !== process.pid && alive(slot.claim.pid)) throw new Error("the process that claimed " + requestId + " (pid " + slot.claim.pid + ") is alive; wait for it to end");
      this.append({ kind: "resolved", n: slot.claim.n, requestId, outcome, note: String(note) });
    } finally { this.release(); }
  }
  // Claim, re-read, emit, done (see the header).
  private claimAndEmit(line: ClaimFields, effect: Effect, intent: Intent): void {
    if (this.lockOwner() !== this.run) throw new Error("dispatcher alarm: this run's lock was removed or replaced while it ran; it stops before row " + line.n + " (nothing more sent)");
    const fields = Object.fromEntries(CLAIM_KEYS.map(k => [k, line[k]]));
    this.emit(effect, intent);
    this.append({ kind: "intent", ...fields, run: this.run, pid: process.pid });
    const now = this.ledger(), claim = now.slots.get(line.n);
    if (claim === undefined || claim.claim.run !== this.run || claim.status !== "pending") {
      throw new Error("dispatcher alarm: another run claimed row " + line.n + " (" + line.requestId + ") first; this run stops and does not send it");
    }
    this.writeWitness(now);
    try { /* moved before the claim */ } catch (error) {
      try { this.append({ kind: "failed", n: line.n, requestId: line.requestId, run: this.run, error: String((error as Error)?.message ?? error).slice(0, 200) }); } catch { /* the claim stays in doubt */ }
      throw error;
    }
    this.append({ kind: "done", n: line.n, requestId: line.requestId, run: this.run });
  }
  // h1 (C-ATT-06): before any effect, the dispatcher applies the SAME store audit as the sink (core/store.ts): schema
  // text, integrity_check, meta (its initial charge must hash to the pinned initialStateSha256), and the compiled
  // ShellCoreV5 fold over every stored commit (signature, ids, bindings, replayed pre-state, the approved relation on the
  // REPLAYED charge), the row-log chain and AuditEnd. If the store audit is false, NOTHING is emitted in this run and every
  // pending row is refused. Then rows go out in seq order; the first row that fails the per-row check (incl. the ledger
  // chain) stops the run. So "no signing hypothesis" (AuditV5SoundRelativeToSuppliedInitial) also covers DISPATCHED effects:
  // same compiled function, TESTED here, not separately proved for this file.
  private flushLocked(): FlushResult {
    const L0 = this.ledger();
    const torn = this.cutTornTail(L0);
    const L = torn === "" ? L0 : this.ledger();
    const db = new DatabaseSync(this.dbPath, { readOnly: true });
    const result: FlushResult = { emitted: [], refused: [], alreadyDispatched: 0, inDoubt: [] };
    const isDone = (rid: string): boolean => [...L.slots.values()].some(s => s.claim.requestId === rid && (s.status === "done" || s.status === "sent"));
    try {
      db.exec("BEGIN");
      // C-ATT-20: every outbox row, by exact type and bytes; nothing is filtered out.
      const listed = db.prepare("SELECT seq, typeof(request_id) AS t, hex(request_id) AS h FROM outbox NOT INDEXED ORDER BY seq").all() as { seq: number; t: string; h: string }[];
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
      const bad = (r: { t: string; h: string }): string =>
        r.t !== "text" ? "dispatcher alarm: outbox request_id is stored as " + r.t + ", not text" : Buffer.from(r.h, "hex").includes(0) ? "dispatcher alarm: outbox request_id holds U+0000" : "";
      const idOf = (r: { h: string }): string => Buffer.from(r.h, "hex").toString("utf8");
      if (why !== "") {
        for (const r of listed) {
          const rid = idOf(r), alarm = bad(r);
          if (alarm === "" && isDone(rid)) result.alreadyDispatched++;
          else result.refused.push({ seq: r.seq, requestId: rid, reason: alarm !== "" ? alarm + "; store audit failed: " + why : "store audit failed: " + why });
        }
        return result;
      }
      if (listed.length !== audited.length || listed.some((r, i) => bad(r) !== "" || r.seq !== audited[i].seq || idOf(r) !== audited[i].requestId)) {
        throw new Error("dispatcher alarm: the outbox listing does not match the audited rows (row type or bytes); nothing sent");
      }
      // C-HOST-05 / C-ATT-19: the dispatch witness next to the store (see writeWitness). Checked BEFORE the newLedgerH0 rule,
      // so a store that is bound to a ledger never starts a second one, also with cfg.newLedgerH0 still set.
      const wit = this.readWitness();
      if (wit !== null && wit.ledger !== realpathSync(this.ledgerPath)) {
        throw new Error("dispatcher alarm: the store is bound to the ledger " + wit.ledger + ", not to " + realpathSync(this.ledgerPath) + "; nothing sent");
      }
      if (wit !== null && wit.n > 0 && L.slots.get(wit.n)?.claim.rowHead !== wit.rowHead) {
        throw new Error("dispatcher alarm: the ledger does not reach the dispatch witness (row " + wit.n + "); an older or another ledger (restored backup?); nothing sent");
      }
      // The dispatcher as the row-log witness (h-anchor design, point 2): the store must still EXTEND every claimed row.
      if (L.maxN === 0 && audited.length > 0 && this.cfg.newLedgerH0 !== genesis) {
        throw new Error("dispatcher alarm: the ledger is missing or empty but the store holds " + audited.length + " committed rows; a new ledger needs cfg.newLedgerH0 = the store's registered h_0");
      }
      if (audited.length < L.maxN || [...L.slots.values()].some(s => { const a = audited[s.claim.n - 1];
        return a.self !== s.claim.rowHead || a.requestId !== s.claim.requestId || a.tokenSha256 !== s.claim.tokenSha256; })) {
        throw new Error("dispatcher alarm: the sink's rows 1.." + L.maxN + " do not chain to the ledger's claims (rollback or rewrite of the sink's store); nothing sent");
      }
      // C-ATT-19: the outside anchor of the ledger, if the operator keeps one.
      const floor = this.cfg.ledgerFloor;
      if (floor !== undefined && (!Number.isSafeInteger(floor.n) || floor.n < 1 || L.slots.get(floor.n)?.claim.rowHead !== floor.rowHead)) {
        throw new Error("dispatcher alarm: the ledger does not reach the outside anchor (row " + floor.n + "); an older ledger (restored backup?); nothing sent");
      }
      if (wit === null) this.writeWitness(L);   // the first run binds the store to this ledger
      if (torn !== "") result.tornTailCut = torn;
      if (this.tookOver !== null) result.staleLockTakenOver = { pid: this.tookOver.pid, run: this.tookOver.run };
      let head = L.maxN === 0 ? this.cfg.initialStateSha256 : L.slots.get(L.maxN)!.claim.postStateSha256;
      let stop = "";
      for (const r of audited) {
        const slot = L.slots.get(r.seq);
        if (slot !== undefined) {
          if (slot.status === "done" || slot.status === "sent") { result.alreadyDispatched++; continue; }
          if (slot.status === "pending" || slot.status === "failed") {
            result.inDoubt!.push(r.requestId);
            result.refused.push({ seq: r.seq, requestId: r.requestId, reason: "in doubt: claimed by run " + slot.claim.run + " (pid " + slot.claim.pid + ") " +
              (slot.status === "failed" ? "and its emit threw" : "without a done line") + "; not counted as dispatched; a person must ask the receiver and call resolveInDoubt" });
            continue;
          }
          // "retry": the operator says the receiver does not have it. Claim it again (at least once, on that word).
          if (stop !== "") { result.refused.push({ seq: r.seq, requestId: r.requestId, reason: stop }); continue; }
          const verdict = this.check({ seq: r.seq, request_id: r.requestId, intent: r.intent }, r.token, slot.claim.preStateSha256);
          if (!verdict.ok || !sameRow({ ...verdict.line, rowHead: r.self }, slot.claim)) {
            const reason = verdict.ok ? "retry: the row is not the claimed row" : verdict.reason;
            result.refused.push({ seq: r.seq, requestId: r.requestId, reason }); stop = "an earlier row was refused: " + reason; continue;
          }
          const effect = { requestId: r.requestId, intent: r.intent };
          this.claimAndEmit(slot.claim, effect, verdict.intent);
          result.emitted.push(effect);
          continue;
        }
        if (L.ids.has(r.requestId)) throw new Error("dispatcher alarm: request id " + r.requestId + " is in the ledger but at another row; nothing more sent");
        if (stop !== "") { result.refused.push({ seq: r.seq, requestId: r.requestId, reason: stop }); continue; }
        const verdict = this.check({ seq: r.seq, request_id: r.requestId, intent: r.intent }, r.token, head);
        if (!verdict.ok) { result.refused.push({ seq: r.seq, requestId: r.requestId, reason: verdict.reason }); stop = "an earlier row was refused: " + verdict.reason; continue; }
        verdict.line.rowHead = r.self;
        const effect = { requestId: r.requestId, intent: r.intent };
        this.claimAndEmit(verdict.line, effect, verdict.intent);   // the external effect: after the claim, before "done"
        head = verdict.line.postStateSha256;
        result.emitted.push(effect);
      }
      const last = this.ledger();
      if (last.maxN > 0) result.ledgerHead = { n: last.maxN, rowHead: last.slots.get(last.maxN)!.claim.rowHead };
    } finally { try { db.exec("ROLLBACK"); } catch { /* none */ } db.close(); }
    return result;
  }
}
