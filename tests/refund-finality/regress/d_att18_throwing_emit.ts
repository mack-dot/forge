// Regression C-ATT-18 (a lost effect looked like a sent one). The payment adapter (emit) throws for r1 BEFORE it sends
// anything. SAFE, part 1: no later run counts r1 as dispatched; every later run reports r1 under its own id (refused or
// in doubt) until a person decides. FAILS on the unfixed dispatcher (the retry counts r1 in alreadyDispatched, silently).
// Part 2 (the recovery, only when part 1 holds): the person asks the receiver (it has nothing) and calls
// resolveInDoubt("r1", "retry"); the next run emits r1 exactly once; a further run emits nothing. Total <= 1000.
// Usage and exit codes: d_lib.ts.
import { argv, dups, guard, total, verdict, world } from "./d_lib";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_d18", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "400"); w.commit(t1.text);
  const t2 = await w.mint(t1.post, "r2", "100"); w.commit(t2.text);
  let run1 = "";
  try { run1 = JSON.stringify(w.flush(e => { if (e.requestId === "r1") throw new Error("adapter: connection refused (nothing sent)"); w.effects.push(e); })); }
  catch (err) { run1 = "threw: " + (err as Error).message; }
  const r2 = w.flush(), r3 = w.flush();
  const reported = (r: any) => r.refused.some((x: any) => x.requestId === "r1");
  const part1 = !w.effects.some(e => e.requestId === "r1") && reported(r2) && reported(r3) && r3.alreadyDispatched === 1;
  let part2 = false, recovery = "not tried (part 1 failed)";
  if (part1) {
    const d = w.dispatcher();
    if (typeof d.resolveInDoubt !== "function") recovery = "no resolveInDoubt";
    else {
      d.resolveInDoubt("r1", "retry", "receiver has no r1 (test)");
      const r4 = w.flush(), r5 = w.flush();
      const ids = w.effects.map(e => e.requestId);
      part2 = dups(ids).length === 0 && ids.includes("r1") && r5.emitted.length === 0 && r5.refused.length === 0 && r5.alreadyDispatched === 2 && total(w.effects) <= 1000;
      recovery = JSON.stringify({ r4: r4.emitted.map((e: any) => e.requestId), r5: { emitted: r5.emitted.length, refused: r5.refused.length, already: r5.alreadyDispatched }, ids });
    }
  }
  w.stop();
  verdict(part1 && part2, { run1: run1.slice(0, 200), run2: { refused: r2.refused.map((x: any) => x.requestId), already: r2.alreadyDispatched },
    run3: { refused: r3.refused.map((x: any) => x.requestId), already: r3.alreadyDispatched }, part1, recovery });
})());
