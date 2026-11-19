// C-ATT-21: a party that can only CREATE <db>-journal or <db>-wal next to the database (it read the file earlier) gets a
// prefix rollback or a row swap that the start-up audit accepts; user_version and other header content passed even with
// the anchor. Required: refuse at open, BEFORE the first SQLite lock, when a companion file exists; check user_version and
// application_id; an explicit operator step (Sink.recover) for an honest crash, which logs the head before and after.
// History of every case: r1 (100), r2 (200), z (0) acknowledged; the attacker's earlier read is the file after r1.
// Cases (PASS conditions):
//   journal-restart  planted -journal (rollback to r1); restart -> REFUSED; the store file is unchanged (r1, r2, z).
//   wal-restart      planted -wal that swaps z for x (another signed zero-amount token on z's pre-state) -> REFUSED.
//   header           a FILE writer sets user_version = 77 (no row change) -> restart REFUSED, also with expectedHead.
//   running-single   a running sink with cfg.outsideHead; -journal planted -> the next commit halts BEFORE its lock and
//                    names the file; the store file is unchanged.
//   recover-honest   the state an honest crash leaves (the file holds the unfinished commit r3; the journal restores the
//                    file before it): restart REFUSED; Sink.recover applies it (before 4, after 3, rolledBack 1, one log
//                    line); then the sink starts at 3 and the host's retry of r3 commits.
//   recover-attack   a planted journal that rolls back TWO rows: Sink.recover refuses, the real files are unchanged.
//   recover-anchor   the same crash state, but the outside head names r3 as COMMITTED (acknowledged): Sink.recover
//                    refuses the rollback of r3; the journal stays.
// Usage: node --import tsx tests/refund-finality/regress/s_att21_planted_files.ts <treeRoot> [<compiledIssuerModule>]
import { copyFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { argv, guard, ids, kit, makeJournal, short, st, tempDir, verdict } from "./s_lib";

guard((() => {
  const { root } = argv();
  const K = kit(root);
  const out: any = {};
  let pass = true;
  const R1 = K.tok(K.S0, "r1", "100"), R2 = K.tok(st("900"), "r2", "200"), Z = K.tok(st("700"), "z", "0"), X = K.tok(st("700"), "x", "0"), R3 = K.tok(st("700"), "r3", "50");
  const base = (extra: any = {}) => {
    const dir = tempDir(), db = join(dir, "sink.sqlite");
    const s = K.open(db, extra); if (typeof s === "string") throw new Error(s);
    s.init(K.S0);
    const h1 = s.commit(R1); const earlier = readFileSync(db);
    const rest = [R2, Z].map(t => s.commit(t));
    return { dir, db, s, earlier, statuses: [h1.status, ...rest.map(r => r.status)], head: s.head() };
  };
  const rec = (name: string, ok: boolean, d: any) => { out[name] = { ...d, ok }; if (!ok) pass = false; };
  const started = (x: any) => typeof x !== "string";
  { // journal-restart
    const b = base(); b.s.close();
    writeFileSync(b.db + "-journal", makeJournal(b.earlier));
    const x = K.open(b.db); const st1 = started(x); if (st1) x.close();
    const after = (() => { const c = join(b.dir, "copy.sqlite"); copyFileSync(b.db, c); return ids(c); })();
    rec("journal-restart", b.statuses.every(v => v === "committed") && !st1 && JSON.stringify(after) === '["r1","r2","z"]', { restart: st1 ? "STARTED" : x, fileIds: after });
  }
  { // wal-restart: the attacker's own copy in WAL mode with the swap inside its WAL; the -wal file is planted
    const b = base(); b.s.close();
    const own = join(b.dir, "own.sqlite"); copyFileSync(b.db, own);
    const w = new DatabaseSync(own); w.exec("PRAGMA journal_mode = WAL; PRAGMA wal_autocheckpoint = 0");
    const trig = w.prepare("SELECT name, sql FROM sqlite_schema WHERE type = 'trigger'").all() as any[];
    w.exec("BEGIN"); for (const t of trig) w.exec(`DROP TRIGGER ${t.name}`);
    const prev = (w.prepare("SELECT self FROM outbox WHERE seq = 2").get() as any).self, self = K.SK.linkOf(prev, X, K.intentOf(X));
    w.prepare("UPDATE settled SET request_id = 'x', token = ?, token_sha256 = ?, self = ? WHERE seq = 3").run(X, K.E.sha256hex(X), self);
    w.prepare("UPDATE outbox SET request_id = 'x', intent = ?, self = ? WHERE seq = 3").run(K.intentOf(X), self);
    for (const t of trig) w.exec(t.sql); w.exec("COMMIT");
    writeFileSync(b.db + "-wal", readFileSync(own + "-wal")); w.close();
    const x = K.open(b.db); const st1 = started(x); let served: string[] = [];
    if (st1) { served = x.settled().map((r: any) => r.request_id); x.close(); }
    rec("wal-restart", !st1, { restart: st1 ? "STARTED ids " + served.join(",") : x });
  }
  { // header: user_version through SQLite by a file writer (no row change)
    const b = base(); const head = b.head; b.s.close();
    const d = new DatabaseSync(b.db); d.exec("PRAGMA user_version = 77"); d.close();
    const x = K.open(b.db), y = K.open(b.db, { expectedHead: head });
    const a = started(x), c = started(y); if (a) x.close(); if (c) y.close();
    rec("header", !a && !c, { restart: a ? "STARTED" : x, restartWithHead: c ? "STARTED" : y });
  }
  { // running-single
    const g0 = { count: 0, chainHash: K.genesis };
    const dir = tempDir(), db = join(dir, "sink.sqlite");
    const anchor: any = { committed: g0 };
    const s = K.open(db, { outsideHead: anchor });
    let r: any = {};
    if (!started(s)) r.err = s;
    else {
      s.init(K.S0);
      const c1 = s.commit(R1); const earlier = readFileSync(db); const c2 = s.commit(R2), c3 = s.commit(Z);
      r.statuses = [c1.status, c2.status, c3.status];
      writeFileSync(db + "-journal", makeJournal(earlier));
      const n = s.commit(R3); r.next = n.status + ": " + String(n.reason).slice(0, 600); s.close();
      const c = join(dir, "copy.sqlite"); copyFileSync(db, c); r.fileIds = ids(c);
    }
    rec("running-single", r.err === undefined && /sink halted/.test(r.next) && /journal/.test(r.next) && JSON.stringify(r.fileIds) === '["r1","r2","z"]', r);
  }
  const recover = (db: string, extra: any, log: string) => { try { return K.SK.Sink.recover(db, { ...K.cfg, ...extra }, log); } catch (e) { return "REFUSED: " + short(e); } };
  { // recover-honest: the file holds the unfinished commit r3 (4 rows); the journal restores the file with 3 rows
    const b = base(); const s3 = readFileSync(b.db); const r3 = b.s.commit(R3); b.s.close();
    writeFileSync(b.db + "-journal", makeJournal(s3));
    const x = K.open(b.db); const st1 = started(x); if (st1) x.close();
    const log = join(b.dir, "recover.log");
    const rep: any = typeof K.SK.Sink.recover === "function" ? recover(b.db, {}, log) : "no Sink.recover";
    const y = K.open(b.db); const st2 = started(y); let retry = "-", count = -1;
    if (st2) { count = y.head().count; retry = y.commit(R3).status; y.close(); }
    const lines = existsSync(log) ? readFileSync(log, "utf8").trim().split("\n").length : 0;
    rec("recover-honest", r3.status === "committed" && !st1 && typeof rep === "object" && rep.applied === true && rep.rolledBack === 1 && rep.before.count === 4 &&
      rep.after.count === 3 && lines === 1 && st2 && count === 3 && retry === "committed", { restartBefore: st1 ? "STARTED" : x, report: rep, restartAfter: st2 ? "STARTED" : y, count, retry, logLines: lines });
  }
  { // recover-attack: rollback of two rows
    const b = base(); b.s.close();
    writeFileSync(b.db + "-journal", makeJournal(b.earlier));
    const dbBytes = readFileSync(b.db), jBytes = readFileSync(b.db + "-journal");
    const log = join(b.dir, "recover.log");
    const rep: any = typeof K.SK.Sink.recover === "function" ? recover(b.db, {}, log) : "no Sink.recover";
    const unchanged = readFileSync(b.db).equals(dbBytes) && existsSync(b.db + "-journal") && readFileSync(b.db + "-journal").equals(jBytes);
    rec("recover-attack", typeof rep === "string" && rep.startsWith("REFUSED") && unchanged && existsSync(log), { report: rep, filesUnchanged: unchanged });
  }
  { // recover-anchor: the outside head names r3 as committed; a journal that removes r3 is refused
    const b = base(); const s3 = readFileSync(b.db); const r3 = b.s.commit(R3); b.s.close();
    writeFileSync(b.db + "-journal", makeJournal(s3));
    const log = join(b.dir, "recover.log");
    const rep: any = typeof K.SK.Sink.recover === "function" && r3.head ? recover(b.db, { outsideHead: { committed: r3.head } }, log) : "no Sink.recover or no head";
    rec("recover-anchor", typeof rep === "string" && rep.startsWith("REFUSED") && existsSync(b.db + "-journal") && r3.head !== undefined, { report: rep });
  }
  verdict(pass, out);
})());
