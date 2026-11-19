// a2_lock_race.ts <treeRoot> <issuer.cjs> <mode: remove|deadpid>
// C-ATT-17 ported to the new API. Four dispatcher PROCESSES, deterministic by control files (no timing guess):
// A emits r1, then PAUSES after its lock check and before writing its intent line for r2 (stale view of r2).
// The operator frees A's lock (remove: unlinks it; deadpid: rewrites it to name a dead pid, so B takes it over).
// B claims and emits r2, r3, then PAUSES after its owner check and before unlinking its lock (the non-atomic release).
// The operator removes B's lock; r4 commits; C takes the lock, claims r4 and PAUSES inside emit(r4).
// B resumes: its release unlinks C's lock. D starts with NO operator step. A resumes (writes its r2 intent), C resumes.
// Exit 1 = a request id emitted twice or total > 1000 (defect); 0 = safe.
import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, realpathSync, unlinkSync, writeFileSync } from "node:fs";
import { hostname } from "node:os";
import { join } from "node:path";
import { procs } from "./c_lib";
import { argv, dups, guard, total, verdict, world } from "<SCRATCH>/redteam-C/fix-f08a21c1/tests/refund-finality/regress/d_lib";
const mode = process.argv[4] ?? "remove";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_a2", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const ctl = join(w.dir, "ctl"), effects = join(w.dir, "effects.jsonl"), dcfgFile = join(w.dir, "dcfg.json");
  mkdirSync(ctl); writeFileSync(effects, ""); writeFileSync(dcfgFile, JSON.stringify(w.dcfg));
  const P = procs(root, w, ctl, effects, dcfgFile), log: string[] = [];
  const t1 = await w.mint(S0, "r1", "300"), t2 = await w.mint(t1.post, "r2", "300"), t3 = await w.mint(t2.post, "r3", "300"), t4 = await w.mint(t3.post, "r4", "100");
  for (const t of [t1, t2, t3]) w.commit(t.text);
  const lock = () => realpathSync(w.ledger) + ".lock";
  const A = P.start("A", "preclaim:r2"); await P.at("A", "preclaim_r2");
  if (mode === "remove") { unlinkSync(lock()); log.push("operator removed A's lock"); }
  else { const dead = spawnSync("/usr/bin/true").pid; const o = JSON.parse(readFileSync(lock(), "utf8"));
    writeFileSync(lock(), JSON.stringify({ ...o, pid: dead, host: hostname() })); log.push("A's lock now names dead pid " + dead); }
  const B = P.start("B", "prerelease"); await P.at("B", "prerelease");
  unlinkSync(lock()); log.push("operator removed B's lock");
  w.commit(t4.text);
  const C = P.start("C", "emit:r4"); await P.at("C", "emit_r4");
  P.go("B", "prerelease"); log.push("B: " + await B);
  let lockNow = "none"; try { lockNow = readFileSync(lock(), "utf8"); } catch { /* gone */ }
  log.push("lock after B's release: " + lockNow.slice(0, 60));
  log.push("D: " + await P.start("D", ""));
  P.go("A", "preclaim_r2"); log.push("A: " + await A);
  P.go("C", "emit_r4"); log.push("C: " + await C);
  log.push("E (after all): " + await P.start("E", ""));
  w.stop();
  const eff = P.effs(), ids = eff.map((e: any) => e.requestId);
  verdict(dups(ids).length === 0 && total(eff) <= 1000, { mode, log, effects: eff.map((e: any) => e.by + ":" + e.requestId), total: total(eff), duplicates: dups(ids) });
})());
