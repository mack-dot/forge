// Regression C-ATT-17 (lock without owner; attacker: none). Three dispatcher processes, one operator step:
// A blocks inside emit(r1) (a slow payment call); a person removes the lock as stale; r2, r3 commit; B blocks inside
// emit(r2); A ends (the unfixed finally removed B's lock); C starts with NO operator step; B resumes.
// SAFE: no request id is emitted twice and the total is at most the original (1000). FAILS on the unfixed dispatcher
// (C and B both emit r3; 1200 of 1000). Usage and exit codes: d_lib.ts.
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, realpathSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { argv, dups, guard, total, verdict, world } from "./d_lib";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_d17", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const ctl = join(w.dir, "ctl"), effects = join(w.dir, "effects.jsonl"), dcfgFile = join(w.dir, "dcfg.json");
  mkdirSync(ctl); writeFileSync(effects, ""); writeFileSync(dcfgFile, JSON.stringify(w.dcfg));
  const child = (name: string, block: string) => new Promise<string>(res => {
    const p = spawn(process.execPath, ["--no-warnings", "--import", "tsx", join(__dirname, "d_child.ts"), root, w.db, w.ledger, dcfgFile, effects, name, block, ctl, "block"],
      { stdio: ["ignore", "pipe", "ignore"] });
    let out = ""; p.stdout.on("data", d => { out += d; }); p.on("exit", () => res(out.trim()));
  });
  const waitFile = async (f: string) => { const t = Date.now(); while (!existsSync(f)) { if (Date.now() - t > 60000) throw new Error("timeout " + f); await new Promise(r => setTimeout(r, 10)); } };
  const log: string[] = [];
  const t1 = await w.mint(S0, "r1", "300"); log.push("r1 " + w.commit(t1.text));
  const t2 = await w.mint(t1.post, "r2", "300"), t3 = await w.mint(t2.post, "r3", "300");
  const A = child("A", "r1"); await waitFile(join(ctl, "A-blocked"));
  unlinkSync(realpathSync(w.ledger) + ".lock"); log.push("operator removed the lock");
  log.push("r2 " + w.commit(t2.text), "r3 " + w.commit(t3.text));
  const B = child("B", "r2"); await waitFile(join(ctl, "B-blocked"));
  writeFileSync(join(ctl, "A-go"), ""); log.push("A: " + await A);
  log.push("C: " + await child("C", "-"));
  writeFileSync(join(ctl, "B-go"), ""); log.push("B: " + await B);
  w.stop();
  const eff = readFileSync(effects, "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l));
  const ids = eff.map(e => e.requestId);
  verdict(dups(ids).length === 0 && total(eff) <= 1000, { log, effects: eff.map(e => e.by + ":" + e.requestId), total: total(eff), duplicates: dups(ids) });
})());
