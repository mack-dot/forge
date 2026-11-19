// Dispatcher flush() in a loop (this process) while a sink in another process commits 150 chained tokens.
// Checks: no request id emitted twice; every committed row emitted at the end; count flush errors (SQLITE_BUSY:
// dispatcher.ts opens the database without a busy_timeout). Mode "wal": WAL set by another opener first.
// Exit 1 = a double send or a lost effect (a safety defect); errors alone are reported, exit 0.
import { spawn } from "node:child_process";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { Dispatcher, E, EVID, S0, Sink, minter } from "./lib";
const mode = process.argv[2];
(async () => {
  const work = join(EVID, "work/t6"); rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const { m, ids, mint } = await minter("off");
  const db = join(work, "s.sqlite"); { const s = new Sink(db, { ...ids, initialState: S0 }); s.init(S0); s.close(); }
  if (mode === "wal") { const d = new DatabaseSync(db); d.exec("PRAGMA journal_mode=WAL"); d.close(); }
  let pre: any = S0; const toks: string[] = [];
  for (let i = 0; i < 150; i++) { const t = await mint(pre, `w${i}`, i % 3 === 0 ? "0" : "5"); toks.push(t.text!); pre = JSON.parse(t.text!).body.post; }
  m.stop(); const tf = join(work, "toks.json"); writeFileSync(tf, JSON.stringify(toks));
  const c = spawn(process.execPath, ["--import", "tsx", join(EVID, "t4_child.ts"), db, JSON.stringify(ids), tf], { stdio: ["ignore", "pipe", "ignore"] });
  let done = false; c.on("exit", () => { done = true; });
  const effects: string[] = []; const errs: Record<string, number> = {}; let flushes = 0;
  const dcfg = { ...ids, initialStateSha256: E.stateSha256(S0) };
  const flush = () => { flushes++; try { new Dispatcher(db, join(work, "ledger.jsonl"), dcfg, (e: any) => effects.push(e.requestId)).flush(); } catch (e) { const k = String((e as Error).message).slice(0, 60); errs[k] = (errs[k] ?? 0) + 1; } };
  while (!done) { flush(); await new Promise(r => setTimeout(r, 2)); }
  flush();
  const dup = effects.filter((r, i) => effects.indexOf(r) !== i);
  const s = new Sink(db, { ...ids, initialState: S0 }); const committed = s.outbox().length; s.close();
  console.log(JSON.stringify({ mode: mode ?? "rollback-journal", flushes, committed, emitted: effects.length, duplicates: dup, flushErrors: errs }));
  process.exit(dup.length === 0 && effects.length === committed ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
