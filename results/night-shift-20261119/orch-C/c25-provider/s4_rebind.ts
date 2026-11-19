// c25 S4: same key, OTHER parameters after a restore. usage: s4_rebind.ts <tree> <anchor none|full>
// Full snapshot of the local files right after init (genesis). r1 600 committed and paid. The operator restores the
// snapshot (attacker: operator restore; a database writer without the key who rolls the store back has the same
// effect on the sink, C-ATT-12). The host then REUSES request id r1 for a different honest refund of 100, then refunds
// the stale remaining (r2 900). Provider switches: RP_REPLAY (error|first), RP_CEIL (1|0).
// Exit 1 = money wrong (clib.ts truth).
import { P, emittedOf, truth, verdict, root } from "./clib";
const anchor = process.argv[3] ?? "none";
const S0 = { chargeId: "ch_rb", original: "1000", remaining: "1000", refundEnabled: true };
const w = P.world(root, "a", anchor, S0);
w.snapshotAll();
const r1 = w.refund("r1", "600"); const f1 = w.flush();
const em = emittedOf(w, f1);
w.restoreAll();
const r1b = w.refund("r1", "100"); const f2 = w.flush(); em.push(...emittedOf(w, f2));
const stale = w.state()?.remaining ?? "0";
const r2 = w.refund("r2", stale); const f3 = w.flush(); em.push(...emittedOf(w, f3));
const local = w.state()?.remaining ?? "(no sink)";
const mv = w.provider.movements();
const paid = mv.reduce((t: bigint, m: any) => t + BigInt(m.amount), 0n);
console.log("books: remaining " + local + " (refunded " + (local === "(no sink)" ? "?" : 1000n - BigInt(local)) + "); provider moved " + paid);
verdict("s4 " + anchor, truth(mv, em, { ch_rb: "1000" }), { r1: r1.status, r1b: r1b.status, r2: [stale, r2.status], f1, f2, f3, sink: w.sinkRefusal() || "up", movements: mv.map((m: any) => m.key + ":" + m.amount) });
