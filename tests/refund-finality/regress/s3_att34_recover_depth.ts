// Regression C-ATT-34 (h-sink3): Sink.recover skipped its "at most one row" check when the live file failed its audit. A
// FILE writer without the key changed one byte of r3's token hash (the live file fails the audit) and planted a hot journal
// whose playback is the file after r1 (a TWO-row rollback): recover reported "recovered"; acknowledged r2 and r3 were gone.
// THE RULE (sink.ts Sink.recover, step 5): success only when the step ESTABLISHES that no acknowledged commit is lost:
// (i) "before" (the file without the journal) passes the audit and "after" is "before" or "before" minus its last row; or
// (ii) cfg.outsideHead is given and "after" EQUALS outsideHead.committed or outsideHead.pending. Else: refuse.
// Cases (PASS conditions):
//   deep        the attack above, no anchor: refused; the real file and journal unchanged.
//   deep-stale  the same with cfg.expectedHead = the head after r1 (expectedHead only bounds from below): refused.
//   deep-fresh  the same with cfg.outsideHead.committed = the head after r3: refused (and the files unchanged).
//   authorised  rule (ii): cfg.outsideHead.committed = the head after r1 (the host says only r1 was acknowledged): recovered
//               to exactly that head (INFORMATION on the rule; part of the verdict because the rule is stated).
//   torn        an honest crash whose live file is unreadable (stand-in: the unfinished commit r3 in the file, made to fail
//               the audit) and a journal back to the file after r2. Without an anchor: refused (the stated cost). With
//               cfg.outsideHead {committed: head after r2, pending: head after r3}: recovered to the head after r2.
//   one-row     an honest one-row crash with a valid live file (rule (i)), no anchor: recovered (unchanged behaviour).
// FAILS on the unfixed tree (deep and deep-stale are "recovered").
// Usage: node --import tsx tests/refund-finality/regress/s3_att34_recover_depth.ts <treeRoot> [<compiledIssuerModule>]
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { argv, guard, hostile, kit, makeJournal, st, tempDir, verdict } from "./s_lib";

const full = (e: unknown): string => String((e as Error)?.message ?? e);
guard((() => {
  const { root } = argv();
  const K = kit(root);
  const out: any = {};
  let pass = true;
  const rec = (name: string, ok: boolean, d: any) => { out[name] = { ...d, ok }; if (!ok) pass = false; };
  const R1 = K.tok(K.S0, "r1", "100"), R2 = K.tok(st("900"), "r2", "200"), R3 = K.tok(st("700"), "r3", "300");
  const open = (db: string, extra: any = {}): any => { try { return new K.SK.Sink(db, { ...K.cfg, ...extra }); } catch (e) { return "REFUSED: " + full(e); } };
  const journalTo = (live: Buffer, img: Buffer) => { const pg = live.readUInt16BE(16), n = Math.max(live.length, img.length) / pg, t = Buffer.alloc(n * pg); img.copy(t); return makeJournal(t); };
  // History r1, r2, r3; the files after r1 and after r2; the heads.
  const hist = () => {
    const dir = tempDir(), db = join(dir, "sink.sqlite");
    const s = open(db); if (typeof s === "string") throw new Error(s);
    s.init(K.S0);
    s.commit(R1); const f1 = readFileSync(db), h1 = s.head();
    s.commit(R2); const f2 = readFileSync(db), h2 = s.head();
    s.commit(R3); const h3 = s.head(); s.close();
    return { dir, db, f1, f2, h1, h2, h3 };
  };
  const recover = (db: string, extra: any = {}) => { try { const r = K.SK.Sink.recover(db, { ...K.cfg, ...extra }, db + ".op.log"); return { ok: r.reason, after: r.after }; } catch (e) { return { refused: full(e) }; } };
  const servedHead = (db: string, extra: any = {}) => { const a = open(db, extra); if (typeof a === "string") return a; const h = a.head(); a.close(); return h; };
  const attack = () => {
    const H = hist();
    const ed = hostile(H.db, d => { d.exec("UPDATE settled SET token_sha256 = '" + "0".repeat(64) + "' WHERE request_id = 'r3'"); });
    writeFileSync(H.db + "-journal", journalTo(readFileSync(H.db), H.f1));
    return { ...H, ed, live: readFileSync(H.db), journal: readFileSync(H.db + "-journal") };
  };
  const unchanged = (A: any) => readFileSync(A.db).equals(A.live) && existsSync(A.db + "-journal") && readFileSync(A.db + "-journal").equals(A.journal);
  { const A = attack(); const r = recover(A.db); rec("deep", A.ed === "ok" && "refused" in r && unchanged(A), { r }); }
  { const A = attack(); const r = recover(A.db, { expectedHead: A.h1 }); rec("deep-stale", "refused" in r && unchanged(A), { r }); }
  { const A = attack(); const r = recover(A.db, { outsideHead: { committed: A.h3 } }); rec("deep-fresh", "refused" in r && unchanged(A), { r }); }
  { const A = attack(); const r = recover(A.db, { outsideHead: { committed: A.h1 } }); const h = servedHead(A.db, { outsideHead: { committed: A.h1 } });
    rec("authorised", "ok" in r && typeof h !== "string" && h.count === 1 && h.chainHash === A.h1.chainHash, { r, served: h }); }
  { // torn: the unfinished commit r3 is in the live file, which fails the audit; the journal restores the file after r2
    const H = hist();
    const ed = hostile(H.db, d => { d.exec("UPDATE settled SET token_sha256 = '" + "f".repeat(64) + "' WHERE request_id = 'r3'"); });
    const jr = journalTo(readFileSync(H.db), H.f2); writeFileSync(H.db + "-journal", jr);
    const live = readFileSync(H.db);
    const r0 = recover(H.db);
    const stay = readFileSync(H.db).equals(live) && existsSync(H.db + "-journal");
    const oh = { outsideHead: { committed: H.h2, pending: H.h3 } };
    const r1 = recover(H.db, oh); const h = servedHead(H.db, oh);
    rec("torn", ed === "ok" && "refused" in r0 && /head before the rollback is unknown/.test(r0.refused!) && stay && "ok" in r1 && typeof h !== "string" && h.count === 2 && h.chainHash === H.h2.chainHash,
      { noAnchor: r0, withOutside: r1, served: h });
  }
  { // one-row: a valid live file holding r3, the journal back to the file after r2 (an honest crash after the db write)
    const H = hist();
    writeFileSync(H.db + "-journal", journalTo(readFileSync(H.db), H.f2));
    const r = recover(H.db); const h = servedHead(H.db);
    rec("one-row", "ok" in r && typeof h !== "string" && h.count === 2 && h.chainHash === H.h2.chainHash, { r, served: h });
  }
  verdict(pass, out);
})());
