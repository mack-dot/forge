// Regression C-ATT-19 (an OLDER ledger re-emits; the rollback class). r1 is dispatched; a backup of the folder is
// taken; r2, r3 commit and are dispatched. Then:
//   case L: only the ledger file is restored from the backup (database current).
//   case F: the whole folder is restored (database, ledger, every other file in it), the host retries r2 and r3 with the
//           SAME tokens (the sink commits them again: no sink anchor), and the dispatcher config carries the outside
//           anchor cfg.ledgerFloor = the ledgerHead of the run that sent r2, r3 (kept on another medium).
// SAFE: in both cases no request id is emitted twice and the total is at most 1000. FAILS on the unfixed dispatcher
// (both cases emit r2, r3 again: 1400 of 1000). NOT covered (stated limit): case F WITHOUT an outside anchor.
// Usage and exit codes: d_lib.ts.
import { copyFileSync, existsSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { argv, dups, guard, total, verdict, world } from "./d_lib";
const S0 = { chargeId: "ch_d19", original: "1000", remaining: "1000", refundEnabled: true };
async function one(root: string, core: string, kase: "L" | "F") {
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "400"); w.commit(t1.text); w.flush();
  w.closeSink();
  const bk = join(w.dir, "backup"); mkdirSync(bk);
  const files = () => readdirSync(w.dir).filter(f => f !== "backup" && f !== "ctl" && !/-(wal|shm|journal)$/.test(f) && !f.endsWith(".lock"));
  for (const f of files()) copyFileSync(join(w.dir, f), join(bk, f));
  w.reopen();
  const t2 = await w.mint(t1.post, "r2", "400"); w.commit(t2.text);
  const t3 = await w.mint(t2.post, "r3", "100"); w.commit(t3.text);
  const r = w.flush();
  const anchor = r.ledgerHead;                       // kept outside (undefined on the unfixed dispatcher)
  w.closeSink();
  if (kase === "L") copyFileSync(join(bk, "ledger.jsonl"), w.ledger);
  else {
    for (const f of files()) if (!existsSync(join(bk, f))) rmSync(join(w.dir, f));
    for (const f of readdirSync(bk)) copyFileSync(join(bk, f), join(w.dir, f));
    for (const x of ["-wal", "-shm", "-journal"]) if (existsSync(w.db + x)) rmSync(w.db + x);
  }
  w.reopen();
  if (kase === "F") { w.commit(t2.text); w.commit(t3.text); }
  let last = "";
  try { last = JSON.stringify(w.flush(undefined, w.ledger, kase === "F" ? { ...w.dcfg, ledgerFloor: anchor } : w.dcfg)); } catch (e) { last = "stopped: " + (e as Error).message; }
  w.stop();
  const ids = w.effects.map(e => e.requestId);
  return { ok: dups(ids).length === 0 && total(w.effects) <= 1000, ids, total: total(w.effects), last: last.slice(0, 200) };
}
guard((async () => {
  const { root, core } = argv();
  const L = await one(root, core, "L"), F = await one(root, core, "F");
  verdict(L.ok && F.ok, { caseL: L, caseF: F });
})());
