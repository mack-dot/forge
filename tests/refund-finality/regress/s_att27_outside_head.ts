// C-ATT-27: nothing refreshed the outside head, so a STALE anchor let a later zero-row deletion through. Required: an
// explicit interface that gives the host each new head before the commit is acknowledged, and a start rule that refuses
// a store that is not exactly the persisted head. The host here follows the FRESHNESS RULE of sink.ts:
//   onHead(next)  -> persist anchor.pending = next (called inside the write transaction, before the SQLite COMMIT);
//   commit() returns {status: "committed", head} -> persist anchor.committed = head, clear pending, THEN acknowledge;
//   next start: cfg.outsideHead = {committed, pending}; the dispatcher gets expectedHead = committed.
// Cases (PASS conditions):
//   z1del   r1 (100), z (0), r2 (100) through the interface; sink closed; a FILE writer deletes z and recomputes the chain;
//           restart with the persisted outsideHead -> REFUSED; the dispatcher with expectedHead = committed sends nothing.
//   crash-a onHead throws for r3 (the host could not persist): r3 is rejected, the store is unchanged; restart with
//           {committed: head after r2, pending: the value onHead got} -> STARTED at the committed head.
//   crash-b the COMMIT happened but the host did not promote pending (store = pending) -> STARTED at pending.
//   single  a running sink with outsideHead; another writer appends a validly signed next row -> the next commit halts.
//   stale   INFORMATION only: the legacy cfg.expectedHead = the head after r1 still lets the deletion through (the
//           stated limit of an anchor that the host does not refresh; not part of the verdict).
// Controls: zero-amount refunds and a replay commit/replay through the interface.
// Usage: node --import tsx tests/refund-finality/regress/s_att27_outside_head.ts <treeRoot> [<compiledIssuerModule>]
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { argv, guard, hostile, kit, short, st, tempDir, verdict } from "./s_lib";

guard((() => {
  const { root } = argv();
  const K = kit(root);
  const out: any = {};
  let pass = true;
  const g0 = { count: 0, chainHash: K.genesis };
  // The host: an anchor record kept "outside" (here: a JS object; a real host writes it to another medium atomically).
  const host = (db: string) => {
    const anchor: any = { committed: g0 };
    let failNext = false;
    const opts = () => ({ outsideHead: { committed: anchor.committed, ...(anchor.pending ? { pending: anchor.pending } : {}) },
      onHead: (h: any) => { if (failNext) { failNext = false; throw new Error("anchor store unavailable"); } anchor.pending = h; } });
    let s = K.open(db, opts());
    const commit = (t: string) => {
      const r = s.commit(t);
      if (r.status === "committed") { if (r.head === undefined) throw new Error("interface missing: no head in the commit result"); anchor.committed = r.head; delete anchor.pending; }
      return r;
    };
    return { anchor, get sink() { return s; }, open: () => { s = K.open(db, opts()); return s; }, commit, failOnce: () => { failNext = true; }, opts };
  };
  const R1 = K.tok(K.S0, "r1", "100"), Z = K.tok(st("900"), "z", "0"), R2 = K.tok(st("900"), "r2", "100"), R3 = K.tok(st("800"), "r3", "50");
  { // z1del
    const dir = tempDir(), db = join(dir, "sink.sqlite"), ledger = join(dir, "ledger.jsonl");
    const h = host(db);
    let c: string[] = [], err = "";
    try {
      if (typeof h.sink === "string") throw new Error(h.sink);
      h.sink.init(K.S0);
      c = [R1, Z, R2].map(t => h.commit(t).status);
      const replay = h.sink.commit(Z).status; c.push(replay);
      h.sink.close();
    } catch (e) { err = short(e); }
    const del = hostile(db, d => d.exec("DELETE FROM settled WHERE request_id = 'z'; DELETE FROM outbox WHERE request_id = 'z'; UPDATE settled SET seq = seq - 1 WHERE seq > 2; UPDATE outbox SET seq = seq - 1 WHERE seq > 2;"),
      { linkOf: K.SK.linkOf, sha: K.E.sha256hex });
    const again = h.open(), started = typeof again !== "string";
    let retry = "-";
    if (started) { retry = again.commit(K.tok(st("800"), "z", "0")).status; again.close(); }
    const f = K.flush(db, ledger, { expectedHead: h.anchor.committed });
    const ok = err === "" && JSON.stringify(c) === JSON.stringify(["committed", "committed", "committed", "replayed"]) && h.anchor.committed.count === 3 &&
      del === "ok" && !started && f.emitted.length === 0;
    out.z1del = { err, commits: c, anchor: h.anchor.committed.count, del, restart: started ? "STARTED" : again, retry, flush: f, ok };
    if (!ok) pass = false;
  }
  { // stale (information only)
    const dir = tempDir(), db = join(dir, "sink.sqlite");
    const s = K.open(db); s.init(K.S0);
    const h1 = s.commit(R1).head; s.commit(Z); s.commit(R2); s.close();
    hostile(db, d => d.exec("DELETE FROM settled WHERE request_id = 'z'; DELETE FROM outbox WHERE request_id = 'z'; UPDATE settled SET seq = seq - 1 WHERE seq > 2; UPDATE outbox SET seq = seq - 1 WHERE seq > 2;"),
      { linkOf: K.SK.linkOf, sha: K.E.sha256hex });
    const again = h1 === undefined ? "no head returned" : K.open(db, { expectedHead: h1 });
    out.staleInformation = { restartWithStaleExpectedHead: typeof again === "string" ? again : "STARTED (stated limit: a stale anchor protects only rows up to its count)" };
    if (typeof again !== "string") again.close();
  }
  { // crash-a and crash-b
    const dir = tempDir(), db = join(dir, "sink.sqlite");
    const h = host(db);
    let r: any = {}, err = "";
    try {
      if (typeof h.sink === "string") throw new Error(h.sink);
      h.sink.init(K.S0);
      [R1, Z, R2].forEach(t => h.commit(t));
      const committedBefore = h.anchor.committed;
      h.failOnce();
      const x = h.commit(R3);
      r.r3 = x.status + ": " + String(x.reason).slice(0, 80);
      r.storeCount = h.sink.head().count;
      h.sink.close();
      const pendingFromFailedCall = h.anchor.pending;     // undefined: the throwing onHead did not persist
      // crash-a: the host persisted pending, then the process died before the COMMIT (same store state as above).
      h.anchor.pending = { count: 4, chainHash: K.SK.linkOf(committedBefore.chainHash, R3, K.intentOf(R3)) };
      const a = h.open(); r.crashA = typeof a === "string" ? a : "STARTED count=" + a.head().count;
      // crash-b: now r3 commits (pending persisted by onHead), but the host "dies" before promoting it.
      if (typeof a !== "string") {
        const before = { ...h.anchor.committed };
        const y = a.commit(R3); r.r3again = y.status; a.close();
        h.anchor.committed = before;                     // the promotion was lost
        const b = h.open(); r.crashB = typeof b === "string" ? b : "STARTED count=" + b.head().count; if (typeof b !== "string") b.close();
      }
      r.pendingFromFailedCall = pendingFromFailedCall ?? null;
    } catch (e) { err = short(e); }
    const ok = err === "" && /^rejected/.test(r.r3) && r.storeCount === 3 && r.crashA === "STARTED count=3" && r.r3again === "committed" && r.crashB === "STARTED count=4";
    out.crash = { err, ...r, ok };
    if (!ok) pass = false;
  }
  { // single writer: a foreign append (validly signed: a key holder) halts the running sink in outsideHead mode
    const dir = tempDir(), db = join(dir, "sink.sqlite");
    const h = host(db);
    let r: any = {}, err = "";
    try {
      if (typeof h.sink === "string") throw new Error(h.sink);
      h.sink.init(K.S0); [R1, Z].forEach(t => h.commit(t));
      const d = new DatabaseSync(db);
      const last = d.prepare("SELECT self FROM outbox ORDER BY seq DESC LIMIT 1").get() as any;
      d.exec("PRAGMA busy_timeout = 5000; BEGIN IMMEDIATE");
      d.prepare("INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (3, 'r2', ?, ?, ?, ?)").run(R2, K.E.sha256hex(R2), last.self, K.SK.linkOf(last.self, R2, K.intentOf(R2)));
      d.exec("COMMIT"); d.close();
      const x = h.sink.commit(R3); r.next = x.status + ": " + String(x.reason).slice(0, 100);
      h.sink.close();
    } catch (e) { err = short(e); }
    const ok = err === "" && /sink halted/.test(r.next);
    out.single = { err, ...r, ok };
    if (!ok) pass = false;
  }
  verdict(pass, out);
})());
