// a3_indoubt.ts <treeRoot> <issuer.cjs> <mode: kill|alive|throwlate>
// C-ATT-18 ported. kill: A's effect for r1 LEAVES, then A is SIGKILLed before "done"; later runs (one takes over A's
//   dead lock) must never emit r1 again and never count it as dispatched; r2 must still go out once.
// alive: A's effect for r1 left and A is SIGSTOPped inside emit (alive, frozen); the operator removes the lock and calls
//   resolveInDoubt(r1, "retry") -> must be REFUSED (claimant alive); a run must not emit r1.
// Exit 1 = r1 emitted twice, or r1 counted as dispatched without a decision, or a retry accepted while A lives.
import { mkdirSync, realpathSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { procs } from "./c_lib";
import { argv, dups, guard, verdict, world } from "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/tests/refund-finality/regress/d_lib";
const mode = process.argv[4] ?? "kill";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_a3", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const ctl = join(w.dir, "ctl"), effects = join(w.dir, "effects.jsonl"), dcfgFile = join(w.dir, "dcfg.json");
  mkdirSync(ctl); writeFileSync(effects, ""); writeFileSync(dcfgFile, JSON.stringify(w.dcfg));
  const P = procs(root, w, ctl, effects, dcfgFile), log: string[] = [];
  const t1 = await w.mint(S0, "r1", "600"), t2 = await w.mint(t1.post, "r2", "400");
  w.commit(t1.text); w.commit(t2.text);
  let bad = false;
  if (mode === "kill") {
    log.push("A: " + await P.start("A", "kill:r1"));
    const b = JSON.parse(await P.start("B", "")); log.push("B: " + JSON.stringify(b));
    const c = JSON.parse(await P.start("C", "")); log.push("C: " + JSON.stringify(c));
    bad = !(b.inDoubt ?? []).includes("r1") || !(c.inDoubt ?? []).includes("r1") || (c.emitted ?? []).length !== 0;
  } else {
    const A = P.start("A", "emit:r1"); await P.at("A", "emit_r1");
    const pid = P.running.get("A")!.pid; process.kill(pid, "SIGSTOP"); log.push("A stopped (SIGSTOP) inside emit after the effect");
    unlinkSync(realpathSync(w.ledger) + ".lock"); log.push("operator removed the lock");
    try { w.dispatcher().resolveInDoubt("r1", "retry", "operator guess"); log.push("resolve retry ACCEPTED"); bad = true; }
    catch (e) { log.push("resolve refused: " + (e as Error).message.slice(0, 120)); }
    log.push("B: " + await P.start("B", ""));
    process.kill(pid, "SIGCONT"); P.go("A", "emit_r1"); log.push("A: " + await A);
    log.push("C: " + await P.start("C", ""));
  }
  w.stop();
  const ids = P.effs().map((e: any) => e.requestId);
  verdict(!bad && dups(ids).length === 0, { mode, log, effects: ids });
})());
