// Regression C-HOST-02 (a killed run left the lock; the only recovery was the unsafe manual step) and the stale-lock
// recovery of C-ATT-17. A dispatcher process is killed (SIGKILL) right after its effect for r1 left. No person acts.
// SAFE: the next run on this host proceeds without a manual step (the dead owner's lock is taken over), reports r1 under
// its own id as refused/in doubt (never counted as dispatched, never sent again), and emits r2 once. Then a person
// confirms with the receiver that r1 arrived and records "sent": a further run emits nothing and refuses nothing.
// FAILS on the unfixed dispatcher (every later run stops at the lock). Usage and exit codes: d_lib.ts.
import { spawn } from "node:child_process";
import { existsSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { argv, dups, guard, verdict, world } from "./d_lib";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_dh02", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "400"); w.commit(t1.text);
  const t2 = await w.mint(t1.post, "r2", "100"); w.commit(t2.text);
  const effects = join(w.dir, "effects.jsonl"), dcfgFile = join(w.dir, "dcfg.json");
  writeFileSync(effects, ""); writeFileSync(dcfgFile, JSON.stringify(w.dcfg));
  const signal = await new Promise<string | null>(res => {
    const p = spawn(process.execPath, ["--no-warnings", "--import", "tsx", join(__dirname, "d_child.ts"), root, w.db, w.ledger, dcfgFile, effects, "K", "r1", w.dir, "die"], { stdio: "ignore" });
    p.on("exit", (_c, s) => res(s));
  });
  const lockLeft = existsSync(realpathSync(w.ledger) + ".lock");
  const fileIds = () => readFileSync(effects, "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l).requestId as string);
  const emit = (e: { requestId: string; intent: string }) => { w.effects.push(e); writeFileSync(effects, readFileSync(effects, "utf8") + JSON.stringify({ by: "next", ...e }) + "\n"); };
  let r: any = null, stopped = "";
  try { r = w.flush(emit); } catch (e) { stopped = (e as Error).message; }
  let after: any = null, resolved = "";
  if (r !== null) {
    try { w.dispatcher().resolveInDoubt("r1", "sent", "receiver has r1 (test)"); resolved = "sent"; after = w.flush(emit); } catch (e) { resolved = "failed: " + (e as Error).message; }
  }
  w.stop();
  const ids = fileIds();
  const pass = signal === "SIGKILL" && lockLeft && r !== null && r.refused.some((x: any) => x.requestId === "r1") && r.alreadyDispatched === 0 &&
    r.emitted.map((e: any) => e.requestId).join() === "r2" && after !== null && after.emitted.length === 0 && after.refused.length === 0 &&
    after.alreadyDispatched === 2 && dups(ids).length === 0;
  verdict(pass, { signal, lockLeft, effects: ids, next: r && { emitted: r.emitted.map((e: any) => e.requestId), refused: r.refused.map((x: any) => x.requestId), already: r.alreadyDispatched },
    stopped: stopped.slice(0, 120), resolved: resolved.slice(0, 120), after: after && { emitted: after.emitted.length, refused: after.refused.length, already: after.alreadyDispatched } });
})());
