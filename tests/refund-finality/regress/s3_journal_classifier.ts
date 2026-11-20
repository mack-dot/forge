// Regression C-ATT-33 (h-sink3), part 1: the rollback-journal classifier (core/store.ts classifyJournal) against the SQLite
// of this Node. For each generated journal next to a small database in DELETE mode, SQLite opens the database and reads it
// (its hot-journal test runs at that first shared lock). Observed: IGNORED = the journal is still there, byte-equal, and
// the database file is byte-equal; else SQLite ACTED (it deleted the journal and/or changed the database).
// PASS: for every case, classifier "not-hot" <=> SQLite IGNORED, and classifier "hot" <=> SQLite ACTED. The cases: zero
// length; zero first byte with many tails (all zero, random, the magic after the zero byte, a zeroed header before valid
// records); a valid header with records (a real rollback), with nRec 0 and a smaller initial size (a truncation), with
// nRec 0 and the same size; a non-zero first byte with random bytes; short files; an empty database (H3). Also H2: a
// magic journal while another connection holds RESERVED is IGNORED by a reader (the classifier cannot see locks; the
// removal step holds RESERVED itself) - reported, part of the verdict as "SQLite ignores under RESERVED".
// FAILS on the unfixed tree: there is no classifier (classifyJournal is missing).
// Usage: node --import tsx tests/refund-finality/regress/s3_journal_classifier.ts <treeRoot> [<compiledIssuerModule>]
import { randomBytes } from "node:crypto";
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { argv, guard, load, makeJournal, tempDir, verdict } from "./s_lib";

guard((() => {
  const { root } = argv();
  const L = load(root);
  const classify = L.ST.classifyJournal;
  if (typeof classify !== "function") verdict(false, { error: "core/store.ts has no classifyJournal (unfixed tree)" });
  const dir = tempDir(), base = join(dir, "base.sqlite");
  { // a database of several pages; an earlier image for real rollbacks
    const d = new DatabaseSync(base); d.exec("PRAGMA journal_mode = DELETE; PRAGMA page_size = 4096; CREATE TABLE t(x TEXT)");
    for (let i = 0; i < 20; i++) d.prepare("INSERT INTO t VALUES (?)").run("row" + i + "-".repeat(400)); d.close();
  }
  const early = readFileSync(base);
  { const d = new DatabaseSync(base); for (let i = 20; i < 40; i++) d.prepare("INSERT INTO t VALUES (?)").run("row" + i + "-".repeat(400)); d.close(); }
  const img = readFileSync(base);
  const page = img.readUInt16BE(16), pages = img.length / page;
  const hdr = (nRec: number, initPages: number, sector = 512, magic = true): Buffer => {
    const h = Buffer.alloc(sector);
    if (magic) Buffer.from("d9d505f920a163d7", "hex").copy(h, 0);
    h.writeUInt32BE(nRec >>> 0, 8); h.writeUInt32BE(0x11223344, 12); h.writeUInt32BE(initPages, 16); h.writeUInt32BE(sector, 20); h.writeUInt32BE(page, 24);
    return h;
  };
  const padded = (b: Buffer) => { const t = Buffer.alloc(img.length); b.copy(t); return t; };
  const cases: { name: string; j: Buffer; db?: Buffer }[] = [];
  cases.push({ name: "zero-length", j: Buffer.alloc(0) });
  for (const n of [1, 27, 28, 511, 512, 4096, 8192]) cases.push({ name: "all-zero-" + n, j: Buffer.alloc(n) });
  for (let i = 0; i < 60; i++) { const n = 1 + (randomBytes(2).readUInt16BE(0) % 9000), j = randomBytes(n); j[0] = 0; cases.push({ name: "zero-first-random-" + i, j }); }
  { const j = Buffer.from(makeJournal(padded(early))); j[0] = 0; cases.push({ name: "zero-first-then-magic-rest+records", j }); }
  { const j = Buffer.from(makeJournal(padded(early))); j.fill(0, 0, 28); cases.push({ name: "zeroed-header-before-valid-records", j }); }
  { const j = Buffer.from(makeJournal(padded(early))); j.fill(0, 0, 8); cases.push({ name: "zeroed-magic-only", j }); }
  cases.push({ name: "valid-rollback-to-early", j: makeJournal(padded(early)) });
  cases.push({ name: "magic-nrec0-same-size", j: hdr(0, pages) });
  cases.push({ name: "magic-nrec0-truncate", j: hdr(0, Math.max(1, pages - 5)) });
  cases.push({ name: "magic-nrec-ffffffff", j: Buffer.concat([hdr(0xffffffff, pages), Buffer.alloc(page + 8)]) });
  for (let i = 0; i < 60; i++) { const n = 1 + (randomBytes(2).readUInt16BE(0) % 9000), j = randomBytes(n); if (j[0] === 0) j[0] = 1 + (i % 255); cases.push({ name: "nonzero-first-random-" + i, j }); }
  for (const n of [1, 7, 8, 27]) { const j = Buffer.from("d9d505f920a163d7d9d505f920a163d7d9d505f920a163d7d9", "hex").subarray(0, n); cases.push({ name: "short-magic-" + n, j }); }
  for (let b = 1; b < 256; b += 17) cases.push({ name: "single-byte-" + b, j: Buffer.from([b]) });
  cases.push({ name: "empty-db-zero-journal", j: Buffer.alloc(512), db: Buffer.alloc(0) });
  cases.push({ name: "empty-db-magic-journal", j: hdr(0, 1), db: Buffer.alloc(0) });
  const rows: any[] = [];
  let agree = 0, disagree = 0;
  for (const c of cases) {
    const p = join(dir, "c.sqlite");
    rmSync(p, { force: true }); rmSync(p + "-journal", { force: true });
    const dbBytes = c.db ?? img;
    writeFileSync(p, dbBytes); writeFileSync(p + "-journal", c.j);
    const k = classify(p).kind;
    let err = "";
    try { const d = new DatabaseSync(p); try { d.prepare("SELECT count(*) AS n FROM sqlite_schema").get(); } finally { d.close(); } } catch (e) { err = String((e as Error).message); }
    const jLeft = existsSync(p + "-journal") && readFileSync(p + "-journal").equals(c.j);
    const dbSame = readFileSync(p).equals(dbBytes);
    const sqlite = jLeft && dbSame ? "ignored" : "acted";
    const ok = (k === "not-hot") === (sqlite === "ignored");
    if (ok) agree++; else disagree++;
    if (!ok || rows.length < 12 || !c.name.includes("random")) rows.push({ name: c.name, size: c.j.length, cls: k, sqlite, journalLeft: existsSync(p + "-journal"), dbSame, err: err.slice(0, 80), ok });
  }
  // H2: a reader while another connection holds RESERVED ignores even a valid hot journal.
  let h2 = "";
  {
    const p = join(dir, "h2.sqlite"); rmSync(p, { force: true }); rmSync(p + "-journal", { force: true });
    writeFileSync(p, img);
    const a = new DatabaseSync(p); a.exec("BEGIN IMMEDIATE");
    const j = makeJournal(padded(early)); writeFileSync(p + "-journal", j);
    let err = "";
    try { const b = new DatabaseSync(p); try { b.exec("PRAGMA busy_timeout = 0"); b.prepare("SELECT count(*) AS n FROM t").get(); } finally { b.close(); } } catch (e) { err = String((e as Error).message); }
    const ignored = existsSync(p + "-journal") && readFileSync(p + "-journal").equals(j) && readFileSync(p).equals(img);
    a.exec("ROLLBACK"); a.close();
    h2 = (ignored ? "ignored" : "acted") + (err ? " (" + err.slice(0, 60) + ")" : "");
  }
  verdict(disagree === 0 && cases.length >= 150 && h2.startsWith("ignored"), { cases: cases.length, agree, disagree, h2ReaderUnderReserved: h2, rows });
})());
