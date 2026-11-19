// C-ATT-24 re-attack on 88ae6cbf: the RUNNING sink, an OLD/middle row changed behind it; does it commit a second effect
// for one request id? Attacker: database writer without the key (SQL with triggers dropped; or create-only -journal).
// History: r1 600, z 0, r2 100 committed by one running sink. Then the tamper; then the host retries the victim id.
// Usage: a24_map.ts <work> <mode>
//  sqlrename : rename OLD row r1 -> r1x (token+intent texts edited, chain recomputed). Retry r1.
//  midswap   : swap MIDDLE row z for zq (another signed zero-amount token on the same pre-state; same post, so the head
//              row r2 stays byte-identical: guard values unchanged). Chain recomputed. Retry z.
//  jmidswap  : midswap delivered as a planted -journal (attacker never opens the database); change counter of the
//              journal image set equal to the live file (data_version guard may miss). Retry z.
//  jrename   : sqlrename delivered as a planted -journal with the live change counter. Retry r1.
//  rawkeep   : midswap written as raw pages into the live file with bytes 24..39 and 92..99 kept (change counter, page
//              count, freelist): the data_version guard and the page cache may not see it. Retry z; then r3; restart.
//  control   : no tamper; retry r1 (must be rejected), new zero z2 (must commit).
// Exit 1 = a second commit for one request id (defect); 0 = safe (retry not committed); 3 = harness error.
import { copyFileSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { kit, hostile, swapRow, makeJournal, out, short, st, ids, recomputeChain } from "./lib";
const [work, mode] = process.argv.slice(2);
const K = kit(work);
const L: any = { mode };
let sink: any = K.open(); sink.init(K.cfg.initialState);
const S0 = st(sink);
L.c1 = sink.commit(K.tok(S0, "r1", "600")).status;
const S1 = st(sink);
const zt = K.tok(S1, "z", "0"), zq = K.tok(S1, "zq", "0");
L.c2 = sink.commit(zt).status;
L.c3 = sink.commit(K.tok(st(sink), "r2", "100")).status;
L.headBefore = sink.head();
const renameEdit = (d: DatabaseSync) => {
  const t = (d.prepare("SELECT token FROM settled WHERE request_id = 'r1'").get() as any).token as string;
  const i = (d.prepare("SELECT intent FROM outbox WHERE request_id = 'r1'").get() as any).intent as string;
  d.prepare("UPDATE settled SET request_id = 'r1x', token = ? WHERE request_id = 'r1'").run(t.split('"requestId":"r1"').join('"requestId":"r1x"'));
  d.prepare("UPDATE outbox SET request_id = 'r1x', intent = ? WHERE request_id = 'r1'").run(i.split('"requestId":"r1"').join('"requestId":"r1x"'));
};
const viaJournal = (edit: (d: DatabaseSync) => void) => {
  // attacker's own copy (read access to the file), edited, made into a journal; the live file is never written.
  const live = readFileSync(K.db);
  const cp = join(work, "copy.sqlite"); writeFileSync(cp, live);
  L.copyEdit = hostile(cp, edit, true);
  const img = readFileSync(cp);
  const page = img.readUInt16BE(16), n = Math.max(img.length, live.length) / page;
  const target = Buffer.alloc(n * page); img.copy(target);
  live.copy(target, 24, 24, 28);                       // keep the live file change counter (bytes 24..27)
  live.copy(target, 92, 92, 100);                      // and version-valid-for / SQLite version number
  writeFileSync(K.db + "-journal", makeJournal(target));
};
let victim = "r1";
if (mode === "sqlrename") L.applied = hostile(K.db, renameEdit, true);
else if (mode === "midswap") { L.applied = hostile(K.db, swapRow("z", zq), true); victim = "z"; }
else if (mode === "jmidswap") { viaJournal(swapRow("z", zq)); victim = "z"; L.applied = "journal planted"; }
else if (mode === "jrename") { viaJournal(renameEdit); L.applied = "journal planted"; }
else if (mode === "rawkeep") {   // raw page write into the LIVE file, bytes 24..39 and 92..99 kept (no lock taken)
  const live = readFileSync(K.db), cp = join(work, "copy.sqlite"); writeFileSync(cp, live);
  L.copyEdit = hostile(cp, swapRow("z", zq), true);
  const img = Buffer.from(readFileSync(cp)); live.copy(img, 24, 24, 40); live.copy(img, 92, 92, 100);
  L.sizes = [live.length, img.length]; writeFileSync(K.db, img); victim = "z"; L.applied = "raw pages written, header counters kept";
}
else if (mode === "control") { L.applied = "none"; }
else { console.error("unknown mode"); process.exit(3); }
const cur = (() => { try { return st(sink); } catch (e) { return null; } })();
const retry = victim === "z" ? K.tok(cur ?? S1, "z", "0") : K.tok(cur ?? S1, "r1", "100");
const r = sink.commit(retry);
L.retry = r; L.reaudits = sink.reaudits;
if (mode === "rawkeep") { L.r3 = sink.commit(K.tok(st(sink), "r3", "50")); L.reauditsAfterR3 = sink.reaudits; L.audit = sink.audit(); }
if (mode === "control") L.z2 = sink.commit(K.tok(st(sink), "z2", "0")).status;
try { L.outbox = ids(K.db); } catch (e) { L.outbox = short(e); }
sink.close();
const re = K.open(); L.restart = typeof re === "string" ? re : "serves"; if (typeof re !== "string") re.close();
const defect = r.status === "committed";
L.defect = defect; out(L);
if (mode === "control" && (L.c1 !== "committed" || L.c2 !== "committed" || L.c3 !== "committed" || L.z2 !== "committed")) process.exit(3);
process.exit(defect ? 1 : 0);
