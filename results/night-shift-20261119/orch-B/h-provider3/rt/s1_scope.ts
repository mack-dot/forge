// COPY of orch-C/c25-provider/s1_scope.ts (h-provider3), unchanged below this line.
// c25 S1: idempotency-key SCOPE. One sink per charge (State has one chargeId), so request ids are unique only per
// store; the provider scopes keys per ACCOUNT. usage: s1_scope.ts <tree> <collide|squat>   (needs RP_SHARED=<file>)
// collide: honest. Sink A (ch_A 1000) commits r1 600; sink B (ch_B 1000) commits r1 300; both dispatch to one account.
//          Attacker: none.
// squat:   another party with API access to the same provider account sends ONE refund call with key "r1", amount 1,
//          on ch_A, before the honest r1 600 is dispatched (request ids are not secret). Attacker: another party on
//          the same provider account (it could also refund directly; the new effect is on the RECORD).
// Exit 1 = money wrong (see clib.ts truth). Liveness (committed refund never paid, not reported paid) is printed.
import { P, emittedOf, truth, verdict, root } from "./clib";
const kase = process.argv[3];
if (kase !== "collide" && kase !== "squat") { console.error("usage"); process.exit(4); }
const A = P.world(root, "a", "none", { chargeId: "ch_A", original: "1000", remaining: "1000", refundEnabled: true });
const ra = A.refund("r1", "600");
if (kase === "squat") { try { A.provider.refund({ key: "r1", chargeId: "ch_A", amount: "1", reason: "x" }); } catch (e) { console.log("squat call: " + (e as Error).message); } }
const fa = A.flush();
const em = emittedOf(A, fa);
const charges: Record<string, string> = { ch_A: "1000" };
let rb: any = null, fb: any = null, fb2: any = null;
if (kase === "collide") {
  const B = P.world(root, "a", "none", { chargeId: "ch_B", original: "1000", remaining: "1000", refundEnabled: true });
  rb = B.refund("r1", "300"); fb = B.flush(); fb2 = B.flush(); em.push(...emittedOf(B, fb)); charges.ch_B = "1000";
}
const fa2 = A.flush();
const movements = A.provider.movements();
const problems = truth(movements, em, charges);
const live = kase === "collide" ? (fb.emitted.length === 0 ? "LIVENESS: ch_B/r1 300 committed, never paid, run 2: " + JSON.stringify(fb2.refused) : "") :
  (fa.emitted.length === 0 ? "LIVENESS: ch_A/r1 600 committed, never paid, run 2: " + JSON.stringify(fa2.refused) : "");
if (live) console.log(live);
verdict("s1 " + kase, problems, { ra: ra.status, rb: rb?.status, fa, fb, emitted: em, movements: movements.map((m: any) => m.key + "@" + m.chargeId + ":" + m.amount) });
