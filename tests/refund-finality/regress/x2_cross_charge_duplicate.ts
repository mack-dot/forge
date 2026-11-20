// X2 CROSS-CHARGE DUPLICATE. Attack class: duplicate effect for one charge and one request id across two stores.
// Evidence: unsure U534; results/night-shift-20261119/orch-B/r-reqid/dafny/inputs/sink/Attack.dfy (lemma
// CrossChargeWithReqIdPatch); orch-B/b-integrate/controls (M3-no-chargeid-check).
// Assumption: a trusted but FAULTY signer signs, for charge ch_1's pre-state, a token whose intent names charge
// ch_2 (post = pre, so ch_1's balance does not move). It is delivered to ch_1's store. No database writer.
// Steps: store A (ch_1, 100) gets the faulty token for rq_x; store B (ch_2, 50) gets the honest token for rq_x
// (amount 50); each store's dispatcher flushes with its own ledger.
// EXPECTED SAFE OUTCOME: across both stores' dispatchers at most one effect names (ch_2, rq_x) and the sum of the
// amounts emitted for ch_2 is at most ch_2's original 50; store A's outbox holds no intent naming ch_2.
// Liveness part: B's honest refund is emitted exactly once.
// Unsafe outcome on the merged sink: two effects for (ch_2, rq_x), 100 in total for a charge of 50.
import { Harness, Regression, fail, pass, sum } from "./harness";

export const regression: Regression = {
  id: "X2-cross-charge", kind: "attack", title: "intent for charge B committed in charge A's store",
  async run(h: Harness) {
    const C0 = h.st("ch_1", "100", "100"), C2 = h.st("ch_2", "50", "50");
    const A = await h.newStore("a", C0), B = await h.newStore("b", C2);
    const rA = await h.commit(A.sink, h.sign(C0, "rq_x", C0, h.intent("ch_2", "rq_x", "50", "duplicate_charge")));
    const rB = await h.commit(B.sink, h.honest(C2, "rq_x", "50", "duplicate_charge"));
    const fA = await h.flush(A.db, C0, "ledger-a.jsonl"), fB = await h.flush(B.db, C2, "ledger-b.jsonl");
    const ch2 = [...fA.effects, ...fB.effects].filter(e => e.intent.chargeId === "ch_2");
    const dup = ch2.filter(e => e.intent.requestId === "rq_x").length;
    const total = sum(ch2.map(e => e.intent.amount));
    const aForeign = h.outbox(A.db).filter(o => o.intent.chargeId !== "ch_1").length;
    const why = `A=${rA} B=${rB} effects(ch_2,rq_x)=${dup} emitted(ch_2)=${total} A.outbox(foreign)=${aForeign}`;
    if (dup > 1 || total > 50n || aForeign > 0) return fail("CROSS-CHARGE: " + why);
    if (fB.effects.length !== 1) return fail("B's honest refund not dispatched exactly once: " + why);
    return pass(why);
  },
};
// X2b FOREIGN POST-STATE LOCKS THE STORE (Attack.dfy lemmas ForeignPostLocksStore, ForeignPostWitness).
// Assumption: a FAULTY signer signs for ch_1's pre-state a token whose post-state is charge ch_2's state.
// EXPECTED SAFE OUTCOME: store A still holds charge ch_1 after the delivery, and a later honest ch_1 refund
// (rq_h, 10) is emitted exactly once. Unsafe on the merged sink: A holds ch_2's state; no ch_1 token commits again.
export const regressionB: Regression = {
  id: "X2b-foreign-post-locks-store", kind: "attack", title: "post-state of another charge committed",
  async run(h: Harness) {
    const C0 = h.st("ch_1", "100", "100"), C2 = h.st("ch_2", "50", "50");
    const A = await h.newStore("a", C0);
    const r1 = await h.commit(A.sink, h.sign(C0, "rq_y", C2, h.intent("ch_1", "rq_y", "0", "duplicate_charge")));
    const storedId = h.stored(A.db)?.chargeId;
    const r2 = await h.commit(A.sink, h.honest(C0, "rq_h", "10"));
    const f = await h.flush(A.db, C0);
    const hEff = f.effects.filter(e => e.intent.requestId === "rq_h").length;
    const why = `foreign=${r1} storedChargeId=${storedId} honest=${r2} effects(rq_h)=${hEff}`;
    if (storedId !== "ch_1") return fail("STORE NOW HOLDS ANOTHER CHARGE: " + why);
    if (hEff !== 1) return fail("honest ch_1 refund not dispatched exactly once: " + why);
    return pass(why);
  },
};
