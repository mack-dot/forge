// X1 REQUEST-ID MISMATCH DUPLICATE. Attack class: duplicate effect for one request id.
// Evidence: unsure U530, U534; results/night-shift-20261119/orch-B/d-reqid/dafny/inputs/sink/Contrast.dfy (lemmas
// UnpatchedGap, UnpatchedBreaksGood) and d-reqid/ts/single_runs.ts.
// Assumption that makes the attack possible: a trusted but FAULTY (or compromised) signer signs a body whose
// requestId (rq_body) differs from its intent's requestId (rq_victim). No database writer is needed.
// Steps: deliver the faulty token; then deliver the honest token for rq_victim on the then stored state; flush.
// EXPECTED SAFE OUTCOME (durable state and effects):
//   the outbox holds at most one intent with requestId rq_victim, AND the dispatcher emits at most one effect whose
//   intent has requestId rq_victim. Liveness part: the honest token for rq_victim gives exactly one such effect.
// Unsafe outcome seen on the merged sink and dispatcher: two outbox intents and two effects for rq_victim.
import { Harness, Regression, fail, pass, standalone } from "./harness";

export const regression: Regression = {
  id: "X1-reqid-mismatch", kind: "attack", title: "body request id differs from intent request id",
  run(h: Harness) {
    const S0 = h.st("ch_1", "1000", "1000");
    const { db, sink } = h.newStore("x1", S0);
    const bad = h.sign(S0, "rq_body", h.dec(S0, "100"), h.intent("ch_1", "rq_victim", "100"));
    const r1 = h.commit(sink, bad);
    const cur = h.stored(db)!;                                   // the honest issuer signs for the stored state
    const r2 = h.commit(sink, h.honest(cur, "rq_victim", "100"));
    const { effects, error } = h.flush(db, S0);
    const ob = h.outbox(db).filter(o => o.intent.requestId === "rq_victim").length;
    const ef = effects.filter(e => e.intent.requestId === "rq_victim").length;
    const why = `faulty=${r1} honest=${r2} outbox(rq_victim)=${ob} effects(rq_victim)=${ef}${error ? " dispatcherError=" + error : ""}`;
    if (ob > 1 || ef > 1) return fail("DUPLICATE: " + why);
    if (ef !== 1) return fail("honest refund not dispatched exactly once: " + why);
    return pass(why);
  },
};
if (require.main === module) standalone([regression], process.argv);
