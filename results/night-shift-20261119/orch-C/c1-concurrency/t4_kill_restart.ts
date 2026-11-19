// P1/P3/P4 under SIGKILL: a child commits a chain of 12 tokens (amounts 0 and >0); the parent SIGKILLs it at a random
// time; then restart (new Sink), audit, client retry of every token: committed ones must answer "replayed", the
// first uncommitted one must commit; the store must hold committed >= acknowledged. Mode "wal": another opener sets
// journal_mode=WAL first. Exit 1 = defect present; 0 = safe.
import { spawn } from "node:child_process";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { E, EVID, S0, Sink, minter, propose } from "./lib";
const [nArg, mode] = process.argv.slice(2); const n = Number(nArg ?? 30);
(async () => {
  const work = join(EVID, "work/t4"); rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const { m, ids, mint } = await minter("off");
  const cfg = { ...ids, initialState: S0 };
  let pre: any = S0; const toks: string[] = [];
  const amounts = ["0", "50", "0", "0", "100", "1", "0", "200", "0", "300", "0", "349"];   // sum 1000 = original
  for (let i = 0; i < amounts.length; i++) { const t = await mint(pre, `k${i}`, amounts[i]); toks.push(t.text!); pre = JSON.parse(t.text!).body.post; }
  m.stop();
  const tf = join(work, "toks.json"); writeFileSync(tf, JSON.stringify(toks));
  let bad = 0; const notes: string[] = []; const hist: Record<string, number> = {};
  for (let it = 0; it < n; it++) {
    const db = join(work, `s${it}.sqlite`);
    { const s = new Sink(db, cfg); s.init(S0); s.close(); }
    if (mode === "wal") { const d = new DatabaseSync(db); d.exec("PRAGMA journal_mode=WAL"); d.close(); }
    const c = spawn(process.execPath, ["--import", "tsx", join(EVID, "t4_child.ts"), db, JSON.stringify(ids), tf], { stdio: ["ignore", "pipe", "ignore"] });
    let acked = -1, started = false; const delay = Math.random() * 40;
    c.stdout.on("data", d => { for (const l of String(d).split("\n")) { if (l === "go" && !started) { started = true; setTimeout(() => c.kill("SIGKILL"), delay); } const mm = /^ack (\d+) committed/.exec(l); if (mm) acked = Number(mm[1]); } });
    await new Promise(res => c.on("exit", res));
    let s: any; try { s = new Sink(db, cfg); } catch (e) { bad++; notes.push(`it ${it}: restart refused: ${(e as Error).message}`); continue; }
    const rows = s.settled().length; hist[rows] = (hist[rows] ?? 0) + 1;
    const audit = s.audit();
    if (audit.length) { bad++; notes.push(`it ${it}: audit ${audit}`); }
    if (rows < acked + 1) { bad++; notes.push(`it ${it}: acknowledged ${acked + 1} but store has ${rows}`); }
    if (rows > acked + 2) { bad++; notes.push(`it ${it}: store has ${rows} > acknowledged+1 (${acked + 1})`); }
    for (let i = 0; i < toks.length; i++) {
      const r = s.commit(toks[i]);
      const want = i < rows ? "replayed" : "committed";
      if (r.status !== want) { bad++; notes.push(`it ${it}: retry token ${i} (rows ${rows}): ${JSON.stringify(r)} want ${want}`); break; }
    }
    if (s.stateBlob() !== E.canon({ ...S0, remaining: "0" })) { bad++; notes.push(`it ${it}: final state ${s.stateBlob()}`); }
    s.close(); rmSync(db, { force: true }); rmSync(db + "-wal", { force: true }); rmSync(db + "-shm", { force: true });
  }
  console.log(JSON.stringify({ n, mode: mode ?? "rollback-journal", bad, rowsAtKillHistogram: hist, notes: notes.slice(0, 5) }));
  process.exit(bad === 0 ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
