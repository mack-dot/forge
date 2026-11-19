// Attack 1b: other planted side files. Attacker: creates files in the database's directory; reads the database file.
// wal        - db in rollback mode; plant <db>-wal (made by SQLite itself on the attacker's own copy) [+ no -shm]
// walshm     - same plus a junk <db>-shm
// dirjournal - <db>-journal is a DIRECTORY        rojournal - a valid journal with mode 0444
// junk       - <db>-journal holds 4096 random bytes (first byte non-zero)
// jinwal     - db switched to WAL by the operator; plant a valid -journal (prefix rollback) -> ignored?
// dispro     - valid planted journal, then the DISPATCHER (read-only) runs first
// exit 1 = defect: forged content served (wal*, jinwal), or the store never starts again / sink refuses legitimate refunds
//          after the attacker's file is REMOVED (DoS that outlives the planted file); 0 = safe.
import { chmodSync, copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { fixture, fresh, EV, tryOpen, settledIds, Dispatcher } from "./common15";
import { makeJournal } from "./journal";
const mode = process.argv[2] ?? "wal";
(async () => {
  const fx = await fixture(); const T = (i: number) => fx.tokens[i].text;
  const W = join(EV, "work", "s2-" + mode); fresh(W);
  const db = join(W, "sink.sqlite"), ledger = join(W, "ledger.jsonl"), out: any = { mode };
  const effects: any[] = []; const flush = () => new Dispatcher(db, ledger, fx.dcfg, (e: any) => effects.push(e)).flush();
  let s = tryOpen(db, fx).sink; s.init(fx.cfg.initialState);
  out.c1 = s.commit(T(0)).status; const earlier = readFileSync(db);
  out.c2 = s.commit(T(1)).status; out.c3 = s.commit(T(2)).status; s.close();
  if (mode === "jinwal") { const w = new DatabaseSync(db); out.jm = (w.prepare("PRAGMA journal_mode=WAL").get() as any).journal_mode; w.close();
    const o0 = tryOpen(db, fx); out.walModeStartError = o0.err; o0.sink?.close(); }
  if (mode === "wal" || mode === "walshm") {
    const own = join(W, "own", "copy.sqlite"); mkdirSync(join(W, "own")); copyFileSync(db, own);
    try { execFileSync(process.execPath, ["--import", "tsx", join(EV, "walchild.ts"), own], { stdio: "ignore" }); } catch { /* SIGKILL */ }
    out.ownWalBytes = existsSync(own + "-wal") ? readFileSync(own + "-wal").length : -1;
    writeFileSync(db + "-wal", readFileSync(own + "-wal"));
    if (mode === "walshm") writeFileSync(db + "-shm", Buffer.alloc(32768, 0x5a));
  }
  if (mode === "dirjournal") mkdirSync(db + "-journal");
  if (mode === "rojournal" || mode === "jinwal" || mode === "dispro") { writeFileSync(db + "-journal", makeJournal(earlier)); if (mode === "rojournal") chmodSync(db + "-journal", 0o444); }
  if (mode === "junk") { const b = Buffer.alloc(4096); for (let i = 0; i < b.length; i++) b[i] = (i * 2654435761 >>> 13) & 255; b[0] = 0x41; writeFileSync(db + "-journal", b); }
  if (mode === "dispro") { try { out.flushFirst = flush(); } catch (e) { out.flushFirst = "throws: " + (e as Error).message; } out.journalAfterFlush = existsSync(db + "-journal"); }
  const o = tryOpen(db, fx); out.startWithPlant = o.err ?? "ok";
  if (o.sink) { out.ids = settledIds(o.sink); out.uv = (o.sink as any).db.prepare("PRAGMA user_version").get().user_version;
    out.jm = (o.sink as any).db.prepare("PRAGMA journal_mode").get().journal_mode;
    out.c3_again = o.sink.commit(T(2)).status; out.c4 = o.sink.commit(T(3)); out.idsEnd = settledIds(o.sink); o.sink.close(); }
  // remove the planted file(s) and check the store starts and serves (P3)
  for (const f of ["-journal", "-wal", "-shm"]) if (existsSync(db + f)) { try { chmodSync(db + f, 0o644); } catch {} rmSync(db + f, { recursive: true, force: true }); }
  const p = tryOpen(db, fx); out.startAfterRemoval = p.err ?? "ok";
  if (p.sink) { out.idsAfterRemoval = settledIds(p.sink); out.c5 = p.sink.commit(T(4)).status; p.sink.close(); }
  try { out.flushEnd = flush(); } catch (e) { out.flushEnd = "throws: " + (e as Error).message; }
  out.effects = effects.map((e: any) => e.requestId);
  let defect = false;
  if (mode === "wal" || mode === "walshm") defect = out.startWithPlant === "ok" && out.c3_again === "committed";
  if (mode === "jinwal") defect = out.startWithPlant === "ok" && Array.isArray(out.ids) && !out.ids.includes("r2");
  if (["dirjournal", "rojournal", "junk", "dispro"].includes(mode)) defect = out.startAfterRemoval !== "ok" || (Array.isArray(out.ids) && !out.ids.includes("r2") && mode !== "dispro");
  console.log(JSON.stringify(out));
  console.log(defect ? "DEFECT" : "SAFE"); process.exit(defect ? 1 : 0);
})();
