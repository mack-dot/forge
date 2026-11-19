// C-ATT-21 re-attack on 88ae6cbf (planted files, schema cookie, Sink.recover).
// History: r1 100, r2 200, r3 300 committed and acknowledged (head count 3). snap1 = the file after r1.
// Usage: a21_files.ts <work> <mode> [N]
//  dispjournal  : a create-only party plants a HOT journal (playback = snap1) while no sink runs; the read-only dispatcher
//                 flushes (r2, r3 not yet dispatched). Exit 1 if the dispatcher applies it (file changed) or sends from it.
//  recover-one  : planted hot journal rolling back exactly ONE acknowledged row (r3); operator runs Sink.recover (no
//                 anchor). B: stated limit. Exit 1 if recover accepts.
//  recover-deep : class-c writer: makes the live file fail the audit (one byte of r3's token_sha256 via SQL, triggers
//                 dropped/re-created) AND plants a hot journal = snap1 (a TWO-row rollback). Sink.recover (no anchor;
//                 also with expectedHead = head after r1). Exit 1 if recover applies a rollback of more than one row.
//  cookie       : SQL writer drops ALL triggers and sets PRAGMA schema_version back to its old value while the sink runs;
//                 then a raw commit attempt by the writer of a forged row. Exit 1 if the running sink commits anything
//                 after that or a restart serves the trigger-less schema.
//  window <N>   : a SECOND PROCESS toggles a hot journal (playback = snap1) in and out of <db>-journal in a tight loop while
//                 this process restarts the sink N times (N <= 150). Exit 1 if a start passes the pre-lock check and serves
//                 a rolled-back store (head count < 3). Also reports the same with cfg.outsideHead = fresh head.
import { spawn } from "node:child_process";
import { copyFileSync, existsSync, readFileSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { kit, hostile, makeJournal, out, short, st, ids, Sink } from "./lib";
const [work, mode, nArg, child] = process.argv.slice(2);
if (child === "toggler") {   // second process: plants and removes the journal as fast as it can, until <work>/stop exists
  const buf = readFileSync(join(work, "j.bin")), dst = join(work, "sink.sqlite-journal"), tmp = join(work, "j.tmp");
  let n = 0;
  while (!existsSync(join(work, "stop"))) {
    writeFileSync(tmp, buf); renameSync(tmp, dst); n++;
    for (let i = 0; i < 200; i++) { /* short present window */ }
    try { unlinkSync(dst); } catch { /* applied and deleted by SQLite */ }
    for (let i = 0; i < 2000; i++) { /* absent window */ }
  }
  writeFileSync(join(work, "toggles"), String(n)); process.exit(0);
}
const K = kit(work);
const L: any = { mode };
const s: any = K.open(); s.init(K.cfg.initialState);
L.c1 = s.commit(K.tok(st(s), "r1", "100")).status; const h1 = s.head();
const snap1 = join(work, "snap1.sqlite"); copyFileSync(K.db, snap1);
L.c2 = s.commit(K.tok(st(s), "r2", "200")).status;
const snap2 = join(work, "snap2.sqlite"); copyFileSync(K.db, snap2);
L.c3 = s.commit(K.tok(st(s), "r3", "300")).status; const h3 = s.head();
L.f1 = K.flush({ newLedgerH0: K.h0, expectedHead: h1 });   // r1 dispatched only
const journalTo = (p: string) => { const live = readFileSync(K.db), img = readFileSync(p), pg = live.readUInt16BE(16);
  const n = Math.max(live.length, img.length) / pg, t = Buffer.alloc(n * pg); img.copy(t); return makeJournal(t); };
(async () => {
  let defect = false;
  if (mode === "dispjournal") {
    s.close(); const before = readFileSync(K.db);
    writeFileSync(K.db + "-journal", journalTo(snap1));
    L.flush = K.flush({});
    L.fileChanged = !before.equals(readFileSync(K.db)); L.journalLeft = existsSync(K.db + "-journal");
    L.effects = K.effects.map((e: any) => e.requestId);
    defect = L.fileChanged || L.effects.length > 1 && L.effects.slice(1).join() !== "r2,r3";
  } else if (mode === "recover-one" || mode === "recover-deep") {
    s.close();
    if (mode === "recover-deep") {
      L.applied = hostile(K.db, d => { d.exec("UPDATE settled SET token_sha256 = '" + "0".repeat(64) + "' WHERE request_id = 'r3'"); }, false);
      writeFileSync(K.db + "-journal", journalTo(snap1));
    } else writeFileSync(K.db + "-journal", journalTo(snap2));
    const bak = join(work, "bak.sqlite"), bakj = join(work, "bak.sqlite-journal");
    copyFileSync(K.db, bak); copyFileSync(K.db + "-journal", bakj);
    try { L.recover = Sink.recover(K.db, K.cfg, join(work, "op.log")); } catch (e) { L.recover = short(e); }
    const a: any = K.open(); L.start = typeof a === "string" ? a.slice(0, 140) : { head: a.head().count }; if (typeof a !== "string") a.close();
    L.outbox = ids(K.db);
    if (mode === "recover-deep") {   // again with the h1 anchor field expectedHead = head after r1
      copyFileSync(bak, K.db); copyFileSync(bakj, K.db + "-journal");
      try { L.recoverWithStaleAnchor = Sink.recover(K.db, { ...K.cfg, expectedHead: h1 }, join(work, "op2.log")); } catch (e) { L.recoverWithStaleAnchor = short(e); }
      copyFileSync(bak, K.db); copyFileSync(bakj, K.db + "-journal");
      try { L.recoverWithOutside = Sink.recover(K.db, { ...K.cfg, outsideHead: { committed: h3 } }, join(work, "op3.log")); } catch (e) { L.recoverWithOutside = short(e); }
    }
    const rb = typeof L.recover === "object" && L.recover.applied;
    defect = mode === "recover-one" ? rb : (rb && L.outbox.length < 2);
  } else if (mode === "cookie") {
    const d = new DatabaseSync(K.db); d.exec("PRAGMA busy_timeout = 10000");
    const cookie = Number((d.prepare("PRAGMA schema_version").get() as any).schema_version);
    const trig = d.prepare("SELECT name FROM sqlite_schema WHERE type = 'trigger'").all() as any[];
    d.exec("BEGIN IMMEDIATE"); for (const t of trig) d.exec("DROP TRIGGER " + t.name); d.exec("COMMIT");
    d.exec("PRAGMA schema_version = " + cookie);
    L.cookie = [cookie, Number((d.prepare("PRAGMA schema_version").get() as any).schema_version)];
    d.close();
    L.next = s.commit(K.tok(st(s), "r4", "50")); L.reaudits = s.reaudits; s.close();
    const a: any = K.open(); L.restart = typeof a === "string" ? a.slice(0, 140) : "serves"; if (typeof a !== "string") a.close();
    defect = L.next.status === "committed" || L.restart === "serves";
  } else if (mode === "window") {
    s.close();
    const N = Math.min(150, Number(nArg ?? 100));
    writeFileSync(join(work, "j.bin"), journalTo(snap1));
    const good = join(work, "good.sqlite"); copyFileSync(K.db, good);
    const c = spawn(process.execPath, ["--no-warnings", "--import", "tsx", __filename, work, "window", "0", "toggler"], { stdio: "ignore" });
    await new Promise(r => setTimeout(r, 1500));
    let refusedPre = 0, served = 0, rolled = 0, otherErr = 0, rolledOutside = 0; const ex: string[] = [];
    for (let i = 0; i < N; i++) {
      const anchorMode = i % 2 === 1;
      const a: any = K.open(anchorMode ? { outsideHead: { committed: h3 } } : {});
      if (typeof a === "string") {
        if (/companion file/.test(a)) refusedPre++; else { otherErr++; if (ex.length < 3) ex.push(a.slice(0, 160)); }
      } else {
        served++; const h = a.head().count; a.close();
        if (h < 3) { if (anchorMode) rolledOutside++; else rolled++; }
      }
      // restore the honest file if SQLite applied the journal (the attacker's playback); never while serving
      if (!readFileSync(K.db).equals(readFileSync(good))) { L.appliedAt = L.appliedAt ?? i; copyFileSync(good, K.db); }
    }
    writeFileSync(join(work, "stop"), ""); await new Promise(r => c.on("exit", r));
    L.window = { N, refusedPre, served, rolled, rolledOutside, otherErr, ex, toggles: readFileSync(join(work, "toggles"), "utf8") };
    try { unlinkSync(K.db + "-journal"); } catch { /* none */ }
    defect = rolled > 0;
  }
  L.defect = defect; out(L);
  process.exit(defect ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
