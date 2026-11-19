// Regression C-ATT-33 (h-sink3), part 2: an honest crash BEFORE COMMIT leaves a NOT-HOT -journal (zero first byte: SQLite
// writes the magic only at the journal sync). SQLite ignores it; the h-sink2 sink refused to start and Sink.recover refused
// too ("the journal is still present after the rollback"): an intact store could never be served (false rejection).
// The documented restart path: start; if refused, Sink.recover; start. Cases (PASS conditions):
//   onhead      a CHILD process commits r2 and SIGKILLs itself inside cfg.onHead (inside the write transaction, before
//               COMMIT; one deterministic kill): the restart path serves; head = the head before r2; audit clean; the
//               host's retry of r2 then commits, and a zero-amount refund commits.
//   zero512     a 512-byte all-zero -journal (also what a party that can only create a file plants): served, head unchanged.
//   zerolen     a zero-length -journal: served, head unchanged.
//   hotplanted  C-ATT-21 stays closed: a planted HOT journal (playback = the file after r1, a TWO-row rollback): the start
//               refuses (class "hot"), Sink.recover refuses, the store file is unchanged.
//   badstore    a not-hot journal next to a store that fails the audit (a file writer changed a token hash): Sink.recover
//               refuses and the journal stays (the step never removes a journal unless the store and head are proved
//               unchanged).
//   outside     a not-hot journal and cfg.outsideHead naming another head: Sink.recover refuses.
// FAILS on the unfixed tree (onhead, zero512, zerolen are not served).
// Usage: node --import tsx tests/refund-finality/regress/s3_att33_crash_journal.ts <treeRoot> [<compiledIssuerModule>]
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { argv, guard, hostile, kit, makeJournal, st, tempDir, verdict } from "./s_lib";

const full = (e: unknown): string => String((e as Error)?.message ?? e);   // never cut a reason before it is searched
const [, , , mode, childDb, childTok] = process.argv;
if (mode === "--child") {
  // The child: the same sink config (from the file), one commit, SIGKILL inside onHead (before COMMIT).
  guard((() => {
    const { root } = argv();
    const K = kit(root); void K;
    const cfg = JSON.parse(readFileSync(childDb + ".cfg.json", "utf8"));
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
    const s = new Sink(childDb, { ...cfg, onHead: () => process.kill(process.pid, "SIGKILL") });
    s.commit(readFileSync(childTok, "utf8"));
    process.exit(4);   // not reached: the kill comes first
  })());
} else guard((() => {
  const { root } = argv();
  const K = kit(root);
  const out: any = {};
  let pass = true;
  const rec = (name: string, ok: boolean, d: any) => { out[name] = { ...d, ok }; if (!ok) pass = false; };
  const R1 = K.tok(K.S0, "r1", "100"), R2 = K.tok(st("900"), "r2", "200"), Z = K.tok(st("700"), "z", "0");
  const base = () => {
    const dir = tempDir(), db = join(dir, "sink.sqlite");
    const s = K.open(db); if (typeof s === "string") throw new Error(s);
    s.init(K.S0); const c1 = s.commit(R1).status; const after1 = readFileSync(db); const head = s.head(); s.close();
    return { dir, db, c1, after1, head };
  };
  // The documented restart path.
  const open = (db: string, extra: any = {}): any => { try { return new K.SK.Sink(db, { ...K.cfg, ...extra }); } catch (e) { return "REFUSED: " + full(e); } };
  const restart = (db: string, extra: any = {}) => {
    const r: any = {};
    let a = open(db, extra); r.start1 = typeof a === "string" ? a : "serves";
    if (typeof a === "string") {
      try { const rep = K.SK.Sink.recover(db, { ...K.cfg, ...extra }, join(db + ".op.log")); r.recover = rep.reason; r.journalClass = rep.journalClass; }
      catch (e) { r.recover = full(e); }
      a = open(db, extra); r.start2 = typeof a === "string" ? a : "serves";
    }
    r.served = typeof a !== "string";
    if (r.served) { r.audit = a.audit(); r.head = a.head(); }
    return { r, sink: r.served ? a : null };
  };
  { // onhead: a real child process killed inside the write transaction
    const b = base();
    writeFileSync(b.db + ".cfg.json", JSON.stringify(K.cfg)); writeFileSync(b.db + ".r2.tok", R2);
    const c = spawnSync(process.execPath, ["--no-warnings", "--import", "tsx", __filename, root, "--child", b.db, b.db + ".r2.tok"], { encoding: "utf8", timeout: 60000 });
    const jFirst = existsSync(b.db + "-journal") ? readFileSync(b.db + "-journal").subarray(0, 8).toString("hex") : "none";
    const { r, sink } = restart(b.db);
    let retry = "", zero = "";
    if (sink) { retry = sink.commit(R2).status; zero = sink.commit(Z).status; sink.close(); }
    rec("onhead", c.signal === "SIGKILL" && jFirst === "0000000000000000" && r.served && r.audit.length === 0 && r.head.count === 1 && r.head.chainHash === b.head.chainHash &&
      retry === "committed" && zero === "committed" && !existsSync(b.db + "-journal"),
      { child: { signal: c.signal, status: c.status, err: (c.stderr ?? "").slice(-300) }, journalFirst8: jFirst, ...r, retry, zero });
  }
  for (const [name, bytes] of [["zero512", Buffer.alloc(512)], ["zerolen", Buffer.alloc(0)]] as [string, Buffer][]) {
    const b = base();
    writeFileSync(b.db + "-journal", bytes);
    const { r, sink } = restart(b.db);
    let zero = ""; if (sink) { zero = sink.commit(K.tok(st("900"), "z" + name, "0")).status; sink.close(); }
    rec(name, r.served && r.head.count === 1 && r.head.chainHash === b.head.chainHash && r.audit.length === 0 && zero === "committed" &&
      /companion file/.test(r.start1) && /not-hot/.test(r.start1), { ...r, zero });
  }
  { // hotplanted: C-ATT-21 stays closed
    const dir = tempDir(), db = join(dir, "sink.sqlite");
    const s = open(db); s.init(K.S0); s.commit(R1); const early = readFileSync(db); s.commit(R2); s.commit(Z); s.close();
    const live = readFileSync(db), pg = live.readUInt16BE(16), t = Buffer.alloc(Math.max(live.length, early.length)); early.copy(t);
    writeFileSync(db + "-journal", makeJournal(t.subarray(0, Math.ceil(t.length / pg) * pg)));
    const x = open(db); const startRefused = typeof x === "string"; if (!startRefused) x.close();
    let rv = ""; try { rv = K.SK.Sink.recover(db, K.cfg, db + ".op.log").reason; } catch (e) { rv = full(e); }
    const unchanged = readFileSync(db).equals(live) && existsSync(db + "-journal");
    rec("hotplanted", startRefused && /journal class: hot/.test(x as string) && /refuses/.test(rv) && unchanged, { start: startRefused ? x : "STARTED", recover: rv, unchanged });
  }
  { // badstore: a not-hot journal next to a store that fails the audit
    const b = base();
    const ed = hostile(b.db, d => { d.exec("UPDATE settled SET token_sha256 = '" + "0".repeat(64) + "' WHERE seq = 1"); });
    writeFileSync(b.db + "-journal", Buffer.alloc(512));
    let rv = ""; try { rv = K.SK.Sink.recover(b.db, K.cfg, b.db + ".op.log").reason; } catch (e) { rv = full(e); }
    rec("badstore", ed === "ok" && /refuses/.test(rv) && existsSync(b.db + "-journal"), { edit: ed, recover: rv, journalLeft: existsSync(b.db + "-journal") });
  }
  { // outside: a not-hot journal and an outside head that names another head
    const b = base();
    writeFileSync(b.db + "-journal", Buffer.alloc(512));
    const copy = join(b.dir, "c.sqlite"); copyFileSync(b.db, copy);
    let rv = ""; try { rv = K.SK.Sink.recover(b.db, { ...K.cfg, outsideHead: { committed: { count: 0, chainHash: K.genesis } } }, b.db + ".op.log").reason; } catch (e) { rv = full(e); }
    rec("outside", /refuses/.test(rv) && existsSync(b.db + "-journal") && readFileSync(b.db).equals(readFileSync(copy)), { recover: rv });
  }
  verdict(pass, out);
})());
