// Regression C-ATT-17, the claim rule WITHOUT the lock's help. Run A blocks inside emit(r1). A person removes A's
// lock; run B runs to the end (it emits r2). Then A's old lock file comes back with A's own content (a person restores
// it from a copy; this also models the unavoidable window between A's lock check and A's next ledger line). A resumes:
// its lock check passes, its in-memory view still lists r2 as pending.
// SAFE: r2 is emitted once (B's claim was first; A must not send it). FAILS on the unfixed dispatcher (A sends r2 again).
// In one process (nested runs). Usage and exit codes: d_lib.ts.
import { readFileSync, realpathSync, unlinkSync, writeFileSync } from "node:fs";
import { argv, dups, guard, total, verdict, world } from "./d_lib";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_d17b", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "400"); w.commit(t1.text);
  const t2 = await w.mint(t1.post, "r2", "400"); w.commit(t2.text);
  const lockOf = () => realpathSync(w.ledger) + ".lock";
  let inner = "", outer = "";
  const A = w.dispatcher(e => {
    w.effects.push(e);
    if (e.requestId !== "r1") return;
    const lock = lockOf(), saved = readFileSync(lock);             // A's own lock content
    unlinkSync(lock);                              // a person removes it as stale
    try { inner = JSON.stringify(w.flush()); } catch (err) { inner = "B stopped: " + (err as Error).message; }
    writeFileSync(lock, saved);                    // A's lock comes back
  });
  try { outer = JSON.stringify(A.flush()); } catch (err) { outer = "A stopped: " + (err as Error).message; }
  w.stop();
  const ids = w.effects.map(e => e.requestId);
  verdict(dups(ids).length === 0 && total(w.effects) <= 1000, { effects: ids, total: total(w.effects), B: inner.slice(0, 300), A: outer.slice(0, 300) });
})());
