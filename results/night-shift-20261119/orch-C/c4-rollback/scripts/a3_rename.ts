// a3: file replacement by rename while the sink holds the database open. Attacker: write access to the
// database DIRECTORY (rename), no key, no config. The sink keeps the old inode. Expected (safe): the sink notices
// the replaced file before it acknowledges a commit (halt or re-audit of the file at the path). Actual: see log.
// Sequence: genesis snapshot; r1 400 committed; attacker renames a copy of genesis over the path; honest r2 300
// committed against the sink's state (remaining 600); dispatcher (opens the path) flushes; sink restarts.
// Exit 1 = defect present: r2 acknowledged "committed" with no re-audit, and r2 is absent from the file the
// dispatcher and the restarted sink read, and the restarted sink serves. 0 = safe. 3 = harness error.
import { copyFileSync, renameSync, statSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { setup, Sink, S0 } from "./common";
const [work] = process.argv.slice(2);
(async () => {
  const h = await setup(work);
  const log: any = {};
  const sink = new Sink(h.db, h.cfg); sink.init(S0);
  const genesis = join(work, "genesis.copy"); copyFileSync(h.db, genesis);
  log.c1 = sink.commit(await h.mint(S0, "r1", "400"));
  log.inodeBefore = statSync(h.db).ino;
  renameSync(genesis, h.db);                                   // atomic replace; sink keeps the old inode
  log.inodeAfter = statSync(h.db).ino;
  const pre = JSON.parse(sink.stateBlob());                    // the sink still reads its old inode
  log.preSeen = pre.remaining;
  log.c2 = sink.commit(await h.mint(pre, "r2", "300"));
  log.reaudits = sink.reaudits;
  const f = h.flush(); log.f = { emitted: f.emitted.map((e: any) => e.requestId), refused: f.refused };
  const ro = new DatabaseSync(h.db, { readOnly: true });
  log.rowsAtPath = (ro.prepare("SELECT request_id FROM settled ORDER BY seq").all() as any[]).map(r => r.request_id); ro.close();
  sink.close();
  try { const s2 = new Sink(h.db, h.cfg); log.restart = "serves"; log.restartState = JSON.parse(s2.stateBlob() ?? "null"); s2.close(); }
  catch (e) { log.restart = String((e as Error).message); }
  h.stop();
  console.log(JSON.stringify(log));
  const defect = log.c2.status === "committed" && log.reaudits === 0 && !log.rowsAtPath.includes("r2") && log.restart === "serves";
  process.exit(defect ? 1 : 0);
})().catch(e => { console.error(String(e && e.stack)); process.exit(3); });
