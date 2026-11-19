// a4: raw file write that bypasses SQLite locking and KEEPS the file change counter (header bytes 24..27 and
// 92..95). Attacker: database file writer, no key. Question: does the writer guard (data_version + head) see it?
// Sequence: genesis snapshot; r1 400 committed; attacker writes the genesis bytes over the file (same inode) but
// with the current change counter; then: (1) host reads sink state; (2) dispatcher flush; (3) honest r2 300 against
// the state the sink reports; (4) dispatcher flush; (5) restart.
// Exit 1 = the guard did not re-audit (reaudits 0) AND the sink and the file disagree after the raw write (the
// sink served a state that is not the file's state). 0 otherwise. 3 = harness error. This is an OBSERVATION test.
import { copyFileSync, openSync, readFileSync, writeSync, closeSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { setup, Sink, S0 } from "./common";
const [work] = process.argv.slice(2);
const fileState = (db: string) => { const ro = new DatabaseSync(db, { readOnly: true }); const s = (ro.prepare("SELECT blob FROM state WHERE id=1").get() as any)?.blob; const n = (ro.prepare("SELECT COUNT(*) AS n FROM settled").get() as any).n; ro.close(); return { s: s && JSON.parse(s).remaining, n }; };
(async () => {
  const h = await setup(work);
  const log: any = {};
  const sink = new Sink(h.db, h.cfg); sink.init(S0);
  const genesis = join(work, "genesis.copy"); copyFileSync(h.db, genesis);
  log.c1 = sink.commit(await h.mint(S0, "r1", "400"));
  const cur = readFileSync(h.db), g = Buffer.from(readFileSync(genesis));
  log.sizes = [cur.length, g.length];
  cur.copy(g, 24, 24, 28); cur.copy(g, 92, 92, 96);           // keep the change counter and version-valid-for
  const fd = openSync(h.db, "r+"); writeSync(fd, g, 0, g.length, 0); closeSync(fd);
  log.fileAfterRaw = fileState(h.db);
  log.sinkSees = JSON.parse(sink.stateBlob()).remaining;
  log.f1 = h.flush().emitted.length;
  try { log.c2 = sink.commit(await h.mint(JSON.parse(sink.stateBlob()), "r2", "300")); } catch (e) { log.c2 = String(e); }
  log.reaudits = sink.reaudits;
  log.fileAfterC2 = fileState(h.db);
  log.f2 = h.flush(); log.f2 = { emitted: log.f2.emitted.map((e: any) => e.requestId), refused: log.f2.refused };
  sink.close();
  try { new Sink(h.db, h.cfg).close(); log.restart = "serves"; } catch (e) { log.restart = String((e as Error).message); }
  try { const x = new DatabaseSync(h.db); log.integrity = (x.prepare("PRAGMA integrity_check").all() as any[]).map(r => r.integrity_check); x.close(); } catch (e) { log.integrity = String(e); }
  log.paid = h.paid();
  h.stop();
  console.log(JSON.stringify(log));
  process.exit(log.reaudits === 0 && String(log.sinkSees) !== String(log.fileAfterRaw.s) ? 1 : 0);
})().catch(e => { console.error(String(e && e.stack)); process.exit(3); });
