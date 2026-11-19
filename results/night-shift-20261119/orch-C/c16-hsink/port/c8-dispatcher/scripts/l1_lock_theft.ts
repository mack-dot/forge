// Lead 1: the lock has no owner. Usage: l1_lock_theft.ts <work> two|three|control
//  two:     A blocks inside emit(r1) (slow payment); an operator removes the lock as stale (documented step);
//           B runs; A resumes. Both A and B emit r2.
//  three:   A blocks in emit(r1); operator removes the lock ONCE; r2, r3 commit; B blocks in emit(r2);
//           A ends and its finally removes B's lock; C starts with NO operator step; C and B both emit r3.
//  control: same as two without the operator step: B must stop on the lock.
// Exit 1 = some request id emitted twice or total above the original amount (defect). Exit 0 = safe.
import { spawn } from "node:child_process";
import { existsSync, readFileSync, realpathSync, unlinkSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { startMinter, world, sum } from "./common";
const [work, mode] = process.argv.slice(2);
const child = (w: any, name: string, block: string, ctl: string) => new Promise<string>(res => {
  const p = spawn(process.execPath, ["--import", "tsx", join(__dirname, "dchild.ts"), w.db, w.ledger, join(work, "dcfg.json"), join(work, "effects.jsonl"), name, block, ctl], { env: process.env });
  let out = ""; p.stdout.on("data", d => out += d); p.stderr.on("data", d => process.stderr.write(d)); p.on("exit", () => res(out.trim()));
});
const waitFile = async (f: string) => { const t = Date.now(); while (!existsSync(f)) { if (Date.now() - t > 60000) throw new Error("timeout " + f); await new Promise(r => setTimeout(r, 10)); } };
(async () => {
  const { m, ids, mint } = await startMinter("off");
  const w = world(work, ids); const ctl = join(work, "ctl"); mkdirSync(ctl);
  writeFileSync(join(work, "effects.jsonl"), "");
  const log: string[] = [];
  const amt = mode === "three" ? "300" : "400";
  log.push("r1 " + w.sink.commit(await mint(w.state(), "r1", amt)).status);
  if (mode !== "three") log.push("r2 " + w.sink.commit(await mint(w.state(), "r2", amt)).status);
  const lockPath = () => realpathSync(w.ledger) + ".lock";
  const A = child(w, "A", "r1", ctl); await waitFile(join(ctl, "A-blocked"));
  log.push("A blocked in emit(r1); lock present: " + existsSync(lockPath()));
  if (mode !== "control") { unlinkSync(lockPath()); log.push("operator removed the lock as stale"); }
  if (mode === "three") {
    log.push("r2 " + w.sink.commit(await mint(w.state(), "r2", amt)).status);
    log.push("r3 " + w.sink.commit(await mint(w.state(), "r3", amt)).status);
    const B = child(w, "B", "r2", ctl); await waitFile(join(ctl, "B-blocked")); log.push("B blocked in emit(r2)");
    writeFileSync(join(ctl, "A-go"), ""); log.push("A: " + await A);
    log.push("after A ended, lock present (B is still running): " + existsSync(lockPath()));
    log.push("C (no operator step): " + await child(w, "C", "-", ctl));
    writeFileSync(join(ctl, "B-go"), ""); log.push("B: " + await B);
  } else {
    log.push("B: " + await child(w, "B", "-", ctl));
    writeFileSync(join(ctl, "A-go"), ""); log.push("A: " + await A);
    if (mode === "control") log.push("B2 after A: " + await child(w, "B2", "-", ctl));
  }
  m.stop(); w.sink.close();
  const eff = readFileSync(join(work, "effects.jsonl"), "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l));
  const ids2 = eff.map(e => e.requestId); const dup = ids2.filter((x, i) => ids2.indexOf(x) !== i);
  log.push("effects: " + eff.map(e => e.by + ":" + e.requestId).join(" ") + "; total " + sum(eff) + " of 1000; duplicate ids: " + JSON.stringify(dup));
  let later = ""; try { later = JSON.stringify(w.flush()); } catch (e) { later = "stopped: " + (e as Error).message; }
  log.push("next run on the ledger: " + later);
  console.log(log.join("\n"));
  process.exit(dup.length > 0 || sum(eff) > 1000 ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
