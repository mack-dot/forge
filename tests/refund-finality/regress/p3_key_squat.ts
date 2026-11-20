// h-provider3 regression for red team C-ATT-44 (another party on the same provider account sends a key first).
// usage: p3_key_squat.ts <tree> [literal|derived] [first|error]
// literal: the other party sends key "r1" (the bare request id; ids are not secret), amount 1, on ch_A, before the honest
//          r1 600 is dispatched. derived: the other party knows h_0 and sends the NEW adapter's key for (ch_A, r1, 600)
//          with amount 1 (worst case: the key is not secret either).
// Old adapter, literal: r1 600 reported paid, the customer got 1: exit 1. New adapter, literal: the key differs, r1 600 is
// paid: exit 0. New adapter, derived: the replayed answer (amount 1) differs from the call: ALARM, r1 not reported paid,
// IN DOUBT (liveness loss, printed): exit 0. Usage and exit codes: p3_lib.ts.
import { emittedOf, journalOf, root, truth, verdict } from "./p3_lib";
import { guard, world } from "./p_lib";
guard(() => {
  const tree = root(), kase = process.argv[3] ?? "literal", replay = (process.argv[4] ?? "first") as "first" | "error";
  if (!["literal", "derived"].includes(kase) || !["first", "error"].includes(replay)) { console.error("usage: <tree> [literal|derived] [first|error]"); process.exit(4); }
  const A = world(tree, "b", "none", { chargeId: "ch_A", original: "1000", remaining: "1000", refundEnabled: true }, { providerOptions: { replay } });
  const ra = A.refund("r1", "600");
  const squatKey = kase === "literal" ? "r1" : A.keyOf("r1", "600");
  let squat = "moved 1";
  try { A.provider.refund({ key: squatKey, chargeId: "ch_A", amount: "1", reason: "x" }); } catch (e) { squat = (e as Error).message; }
  const fa = A.flush(), fa2 = A.flush();
  const em = emittedOf(A, fa), mv = A.provider.movements();
  const problems = truth(mv, em, { ch_A: "1000" }, [{ w: A, lines: journalOf(A) }]);
  if (ra.status !== "committed") { console.error("SETUP FAILED"); process.exit(3); }
  if (!fa.emitted.includes("r1")) console.log("LIVENESS: ch_A/r1 600 committed, not paid, in doubt: " + JSON.stringify(fa2.refused) + "; journal: " + JSON.stringify(journalOf(A).map(j => j.outcome)));
  A.stop();
  verdict("p3_key_squat " + kase + " " + replay, problems, { squat, fa, emitted: em.map(e => e.requestId + ":" + e.amount), movements: mv.map(m => m.key.slice(0, 12) + ":" + m.amount) });
});
