// Positive controls of the dispatcher (honest behaviour; attacker: none). Must PASS on the fixed and on the unfixed tree.
//  P1: two zero-amount refunds and one positive refund: each is emitted exactly once (zero is a legitimate refund:
//      spec/refund/protocol.md); a second run emits nothing and refuses nothing.
//  P2: a lock held by a LIVE process (this one) stops a run; nothing is emitted; after the lock is gone, a later
//      zero-amount refund is emitted exactly once.
// Usage and exit codes: d_lib.ts.
import { randomBytes } from "node:crypto";
import { realpathSync, unlinkSync, writeFileSync } from "node:fs";
import { hostname } from "node:os";
import { argv, dups, guard, verdict, world } from "./d_lib";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_dpos", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const z1 = await w.mint(S0, "rq_z1", "0"); const c1 = w.commit(z1.text);
  const z2 = await w.mint(z1.post, "rq_z2", "0"); const c2 = w.commit(z2.text);
  const p1 = await w.mint(z2.post, "rq_p1", "100"); const c3 = w.commit(p1.text);
  const f1 = w.flush(), f2 = w.flush();
  const P1 = c1 === "committed" && c2 === "committed" && c3 === "committed" && f1.emitted.length === 3 && f1.refused.length === 0 &&
    f2.emitted.length === 0 && f2.refused.length === 0 && f2.alreadyDispatched === 3;
  const z3 = await w.mint(p1.post, "rq_z3", "0"); const c4 = w.commit(z3.text);
  const lock = realpathSync(w.ledger) + ".lock";
  writeFileSync(lock, JSON.stringify({ pid: process.pid, run: randomBytes(16).toString("hex"), host: hostname(), startedAt: new Date().toISOString() }));
  const before = w.effects.length; let held = "";
  try { w.flush(); } catch (e) { held = (e as Error).message; }
  const stoppedClean = held.startsWith("dispatcher lock is held") && w.effects.length === before;
  unlinkSync(lock);
  const f3 = w.flush();
  w.stop();
  const ids = w.effects.map(e => e.requestId);
  const P2 = c4 === "committed" && stoppedClean && f3.emitted.length === 1 && f3.emitted[0].requestId === "rq_z3" && f3.refused.length === 0;
  verdict(P1 && P2 && dups(ids).length === 0 && ids.length === 4, { P1, P2, effects: ids, held: held.slice(0, 80) });
})());
