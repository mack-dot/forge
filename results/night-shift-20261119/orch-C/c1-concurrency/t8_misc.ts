// (a) init race: two Sink objects opened on one fresh file before either init(); both init(); commits from both.
// (b) journal mode switched to WAL by another opener WHILE two sinks are open; commits continue; restart ok.
// (c) torn last ledger line (crash inside writeSync): flush must emit nothing (fail closed).
// Exit 1 = a safety or false-rejection defect; 0 = safe.
import { appendFileSync, mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { Dispatcher, E, EVID, S0, Sink, minter } from "./lib";
(async () => {
  const work = join(EVID, "work/t8"); rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const { m, ids, mint } = await minter("off"); const cfg = { ...ids, initialState: S0 }; const db = join(work, "s.sqlite");
  const A = new Sink(db, cfg), B = new Sink(db, cfg); A.init(S0); B.init(S0);
  const r: any = {};
  const t1 = (await mint(S0, "i1", "10")).text!; r.b1 = B.commit(t1); r.a1 = A.commit(t1);
  const s1 = JSON.parse(A.stateBlob()); const t2 = (await mint(s1, "i2", "0")).text!; r.a2 = A.commit(t2);
  { const d = new DatabaseSync(db); r.jm = (d.prepare("PRAGMA journal_mode=WAL").get() as any).journal_mode; d.close(); }
  const t3 = (await mint(JSON.parse(B.stateBlob()), "i3", "20")).text!; r.b3 = B.commit(t3); r.a3 = A.commit(t3);
  r.audit = A.audit(); A.close(); B.close();
  try { new Sink(db, cfg).close(); r.restart = "ok"; } catch (e) { r.restart = String((e as Error).message); }
  const okA = r.b1.status === "committed" && r.a1.status === "replayed" && r.a2.status === "committed" && r.b3.status === "committed" && r.a3.status === "replayed" && r.audit.length === 0 && r.restart === "ok";
  // (c)
  const ledger = join(work, "ledger.jsonl"); const dcfg = { ...ids, initialStateSha256: E.stateSha256(S0) }; const em: string[] = [];
  const first = new Dispatcher(db, ledger, dcfg, () => {}).flush(); // writes 3 lines
  rmSync(ledger); const lines: string[] = [];
  // rebuild: keep line 1 only, plus half of line 2 (torn)
  const d2 = new Dispatcher(db, join(work, "l2.jsonl"), dcfg, () => {}); d2.flush();
  const full = require("node:fs").readFileSync(join(work, "l2.jsonl"), "utf8").split("\n");
  appendFileSync(ledger, full[0] + "\n" + full[1].slice(0, 30));
  let c: string; try { new Dispatcher(db, ledger, dcfg, (e: any) => em.push(e.requestId)).flush(); c = "no error"; } catch (e) { c = String((e as Error).message); }
  r.torn = { firstEmitted: first.emitted.length, afterTorn: c, emitted: em, lockLeft: require("node:fs").existsSync(ledger + ".lock") };
  console.log(JSON.stringify(r));
  m.stop();
  process.exit(okA && em.length === 0 ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
