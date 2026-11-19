// C-ATT-17 / C-ATT-18 re-run on 88ae6cbf (dispatcher = f08a21c1 + expectedHead). DETERMINISTIC: a blocking emit waits on
// control files (dchild.ts); SIGSTOP/SIGCONT where stated. Attacker: NONE (an honest operator follows the documented steps).
// History: r1 400, r2 300, r3 200 committed; nothing dispatched. Dispatcher cfg: newLedgerH0 + expectedHead = head.
// Usage: d17_lock.ts <work> <mode>
//  theft      : A blocks in emit(r1); operator removes the lock; B blocks in emit(r2); A resumes (must stop at r2);
//               operator removes the lock again; C runs; B resumes. (C-ATT-17 'three', with the claim rule.)
//  stop-retry : A blocks in emit(r1) BEFORE the effect leaves; SIGSTOP A; operator removes the lock; B runs (r1 in doubt);
//               operator asks the receiver ("not received": true at that moment) and calls resolveInDoubt(r1, retry);
//               SIGCONT A, A sends r1; D runs.
//  throw      : A's emit(r1) throws before sending; B runs; operator resolveInDoubt(r1, retry); C runs.
//  control    : one run, no block.
// Exit 1 = some request id has two effects, or the total exceeds 1000, or (throw) r1 is lost without being reported in
// doubt; 0 = safe; 3 = harness error.
import { spawn, ChildProcess } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, realpathSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { kit, out, st } from "./lib";
const [work, mode] = process.argv.slice(2);
const K = kit(work);
const L: any = { mode, steps: [] as any[] };
const s: any = K.open(); s.init(K.cfg.initialState);
for (const [r, a] of [["r1", "400"], ["r2", "300"], ["r3", "200"]]) s.commit(K.tok(st(s), r, a));
const head = s.head(); s.close();
const ctl = join(work, "ctl"); mkdirSync(ctl);
writeFileSync(join(work, "dcfg.json"), JSON.stringify({ ...K.dcfg, newLedgerH0: K.h0, expectedHead: head }));
writeFileSync(join(work, "effects.jsonl"), "");
const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));
const run = (name: string, extra: string[] = []): { p: ChildProcess; done: Promise<string> } => {
  const p = spawn(process.execPath, ["--no-warnings", "--import", "tsx", join(__dirname, "dchild.ts"), work, name, ...extra], { stdio: ["ignore", "pipe", "pipe"] });
  let o = ""; p.stdout!.on("data", c => (o += c)); p.stderr!.on("data", c => (o += c));
  return { p, done: new Promise(r => p.on("exit", () => r(o.trim().slice(0, 400)))) };
};
const waitFile = async (f: string) => { for (let i = 0; i < 1500 && !existsSync(f); i++) await sleep(20); if (!existsSync(f)) throw new Error("timeout waiting " + f); };
const lockPath = () => realpathSync(K.ledger) + ".lock";
const removeLock = () => { try { unlinkSync(lockPath()); L.steps.push("operator removed lock"); } catch { L.steps.push("no lock to remove"); } };
const block = (n: string, r: string) => writeFileSync(join(ctl, "block-" + n + "-" + r), "");
const go = (n: string, r: string) => writeFileSync(join(ctl, "go-" + n + "-" + r), "");
(async () => {
  if (mode === "control") { L.steps.push(await run("A").done); }
  else if (mode === "theft") {
    block("A", "r1"); block("B", "r2");
    const A = run("A"); await waitFile(join(ctl, "at-A-r1")); removeLock();
    const B = run("B"); await waitFile(join(ctl, "at-B-r2"));
    go("A", "r1"); L.steps.push(await A.done);
    removeLock();
    L.steps.push(await run("C").done);
    go("B", "r2"); L.steps.push(await B.done);
    L.steps.push(await run("D").done);
  } else if (mode === "stop-retry") {
    block("A", "r1");
    const A = run("A"); await waitFile(join(ctl, "at-A-r1"));
    A.p.kill("SIGSTOP"); L.steps.push("A stopped");
    removeLock();
    L.steps.push(await run("B").done);
    const R = await run("OP", ["resolve", "r1", "retry"]).done; L.steps.push(R);
    A.p.kill("SIGCONT"); go("A", "r1"); L.steps.push(await A.done);
    L.steps.push(await run("D").done);
  } else if (mode === "throw") {
    writeFileSync(join(ctl, "throw-A-r1"), "");
    L.steps.push(await run("A").done);
    const B = await run("B").done; L.steps.push(B);
    L.reportedInDoubt = /"inDoubt":\["r1"\]/.test(B);
    L.steps.push(await run("OP", ["resolve", "r1", "retry"]).done);
    L.steps.push(await run("C").done);
  }
  const effs = readFileSync(join(work, "effects.jsonl"), "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l));
  L.effects = effs.map((e: any) => e.by + ":" + e.rid);
  const ids = effs.map((e: any) => e.rid), total = effs.reduce((a: number, e: any) => a + Number(e.amount), 0);
  L.total = total;
  let defect = new Set(ids).size !== ids.length || total > 1000;
  if (mode === "throw") defect = defect || !L.reportedInDoubt || ids.filter((x: string) => x === "r1").length !== 1;
  L.defect = defect; out(L);
  process.exit(defect ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
