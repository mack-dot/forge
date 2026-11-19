// F2: a crash (SIGKILL) or a concurrent open during the FIRST open of a fresh file. sink.ts line 107 runs the
// four CREATE statements of DDL as separate autocommit statements when sqlite_schema is empty. A file with only
// some of the tables is then refused by the schema check (line 176) for ever: no code path creates the rest.
// Mode "state": build the exact on-disk state of a kill between statement 1 and 2 (only the meta table), then open.
// Mode "kill <n>": n times: fresh file; child constructs a Sink; parent SIGKILLs it after a random delay; then a
//   fresh process opens the file with the same honest config. Counts bricked files.
// Mode "race <n>": n times: two children open one fresh file at once; counts refusals of an honest opener.
// Exit 1 = defect present (an honest store that is refused); 0 = safe.
import { spawn, execFileSync } from "node:child_process";
import { mkdirSync, rmSync, existsSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { generateKeyPairSync } from "node:crypto";
import { EVID, S0, Sink } from "./lib";
const work = join(EVID, "work/t2"); rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
const pem = generateKeyPairSync("ed25519").publicKey.export({ type: "spki", format: "pem" });
const ids = { publicKeyPem: pem, specLockSha256: "a".repeat(64), checkerSha256: "b".repeat(64) };
const tryOpen = (p: string): string => { try { const s = new Sink(p, { ...ids, initialState: S0 }); s.init(S0); s.close(); return "ok"; } catch (e) { return String((e as Error).message); } };
const child = (p: string) => spawn(process.execPath, ["--import", "tsx", join(EVID, "t2_child_open.ts"), p, JSON.stringify(ids)], { stdio: ["ignore", "pipe", "ignore"] });
const [mode, nArg] = process.argv.slice(2); const n = Number(nArg ?? 20);
(async () => {
  if (mode === "state") {
    const p = join(work, "partial.sqlite"); const db = new DatabaseSync(p);
    db.exec("CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT NOT NULL);"); db.close();   // = DDL statement 1 only
    const r1 = tryOpen(p), r2 = tryOpen(p);
    console.log(JSON.stringify({ open1: r1, open2: r2 }));
    process.exit(r1 !== "ok" && r2 !== "ok" ? 1 : 0);
  }
  let bricked = 0, killedMid = 0, refused = 0; const reasons: string[] = [];
  for (let i = 0; i < n; i++) {
    const p = join(work, `f${i}.sqlite`);
    if (mode === "kill") {
      const c = child(p); const delay = Math.random() * 12;
      await new Promise<void>(res => c.stdout.on("data", d => { if (String(d).includes("go")) { const t = process.hrtime.bigint(); while (Number(process.hrtime.bigint() - t) / 1e6 < delay); c.kill("SIGKILL"); res(); } }));
      await new Promise(res => c.on("exit", res));
      if (!existsSync(p)) continue;
      const db = new DatabaseSync(p); const k = (db.prepare("SELECT COUNT(*) AS n FROM sqlite_schema").get() as any).n; db.close();
      if (k > 0 && k < 8) killedMid++;
      const r = tryOpen(p); if (r !== "ok") { bricked++; reasons.push(`kill ${i} (delay ${delay.toFixed(2)} ms, ${k} schema rows): ` + r); }
    } else {
      const a = child(p), b = child(p); const outs: string[] = [];
      for (const c of [a, b]) c.stdout.on("data", d => outs.push(String(d)));
      await Promise.all([a, b].map(c => new Promise(res => c.on("exit", res))));
      const ref = outs.join("").split("\n").filter(l => l.startsWith("REFUSED"));
      if (ref.length > 0) { refused++; reasons.push(`race ${i}: ` + ref.join(" | ")); }
      if (tryOpen(p) !== "ok") bricked++;
    }
  }
  console.log(JSON.stringify({ mode, n, killedMidDDL: killedMid, honestOpenerRefused: refused, bricked, reasons: reasons.slice(0, 5) }));
  rmSync(work, { recursive: true, force: true });
  process.exit(bricked > 0 || refused > 0 ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
