// h-provider3 regression for red team C-ATT-41 (key scope; attacker: none). One store per charge, so request ids are
// unique only per store; the provider scopes keys per ACCOUNT. Two stores share ONE provider account (shared state file):
// store A (ch_A 1000) commits r1 600; store B (ch_B 1000) commits z0 0 and r1 300; both dispatch. Provider replay mode
// <case> = first (default: a reused key returns the FIRST result whatever the parameters) | error (param_mismatch).
// Old adapter (P_ADAPTER=v1): key "r1" for both -> B's r1 300 is reported paid on A's 600 movement: exit 1.
// New adapter: the keys differ (charge and amount are in the key) -> both paid once; z0 makes no call: exit 0.
// Usage and exit codes: p3_lib.ts.
import { emittedOf, journalOf, root, truth, verdict } from "./p3_lib";
import { guard, world } from "./p_lib";
guard(() => {
  const tree = root(), replay = (process.argv[3] ?? "first") as "first" | "error";
  if (replay !== "first" && replay !== "error") { console.error("case: first|error"); process.exit(4); }
  const A = world(tree, "b", "none", { chargeId: "ch_A", original: "1000", remaining: "1000", refundEnabled: true }, { providerOptions: { replay } });
  const B = world(tree, "b", "none", { chargeId: "ch_B", original: "1000", remaining: "1000", refundEnabled: true }, { providerPath: A.providerPath });
  const ra = A.refund("r1", "600"), fa = A.flush();
  const rz = B.refund("z0", "0"), rb = B.refund("r1", "300"), fb = B.flush(), fb2 = B.flush();
  const em = [...emittedOf(A, fa), ...emittedOf(B, fb)];
  const mv = A.provider.movements();
  const problems = truth(mv, em, { ch_A: "1000", ch_B: "1000" }, [{ w: A, lines: journalOf(A) }, { w: B, lines: journalOf(B) }]);
  const setup = [ra.status, rz.status, rb.status].every(s => s === "committed");
  if (!setup) { console.error("SETUP FAILED"); process.exit(3); }
  // T6: both legitimate refunds must be paid (with the new key nothing collides).
  if (!fb.emitted.includes("r1")) problems.push("T6 ch_B/r1 300 committed but not paid: " + JSON.stringify(fb2.refused));
  if (!fb.emitted.includes("z0")) problems.push("T6 ch_B/z0 0 not emitted");
  const calls = A.provider.calls(); A.stop(); B.stop();
  verdict("p3_scope_collide " + replay, problems, { fa, fb, fb2, emitted: em.map(e => e.chargeId + "/" + e.requestId + ":" + e.amount), providerCalls: calls,
    movements: mv.map(m => m.key.slice(0, 12) + "@" + m.chargeId + ":" + m.amount) });
});
