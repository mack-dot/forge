// X5 HOSTILE DATABASE WRITER. Attack class: a writer of the database file (WITHOUT the signing key) changes the
// store under a running sink.
// Evidence: unsure U554; results/night-shift-20261119/orch-B/r-repairs/attack_v4.ts (S1, S2) and
// r-repairs/logs/attack_v4.1.log.
// Assumption: another process can write the SQLite file (raw SQL from a second connection). The signer is honest:
// it signs for the state that the sink has stored (it reads the store).
// X5a balance reset: rq_1 refunds 1000 of 1000; the writer resets `remaining` to 1000; the honest issuer then signs
//   rq_2 for 1000 on that stored state.
//   EXPECTED SAFE OUTCOME: the sum of the outbox intent amounts is at most the original 1000, AND the sum of the
//   emitted amounts is at most 1000. Unsafe on the merged sink: the outbox holds 2000 for a charge of 1000 (the
//   merged dispatcher's chain check still stops the second effect: the unsafe part is the durable state).
// X5b outbox rewrite: rq_1 refunds 100; the writer rewrites rq_1's outbox amount to 1; the issuer signs rq_2.
//   EXPECTED SAFE OUTCOME: every emitted intent equals a signed intent, AND the sink does not settle rq_2 on top of
//   a store whose outbox row differs from its signed intent (while the rewritten row is present, rq_2 has no outbox
//   row). Unsafe on the merged sink: rq_2 is settled on the tampered store.
import { Harness, Regression, fail, pass, standalone, sum } from "./harness";

export const regressionA: Regression = {
  id: "X5a-hostile-balance-reset", kind: "attack", title: "writer resets the balance, second full refund",
  run(h: Harness) {
    const S0 = h.st("ch_1", "1000", "1000");
    const { db, sink } = h.newStore("x5a", S0);
    const c1 = h.commit(sink, h.honest(S0, "rq_1", "1000"));
    const f1 = h.flush(db, S0);
    h.foreign(db, d => { d.prepare("UPDATE state SET blob = ? WHERE id = 1").run(h.E.canon(S0)); });
    const cur = h.stored(db)!;
    const c2 = h.commit(sink, h.honest(cur, "rq_2", cur.remaining));
    const f2 = h.flush(db, S0);
    const out = sum(h.outbox(db).map(o => o.intent.amount));
    const eff = sum([...f1.effects, ...f2.effects].map(e => e.intent.amount));
    const why = `rq_1=${c1} rq_2=${c2} outboxTotal=${out} emittedTotal=${eff} original=1000`;
    if (c1 !== "committed") return fail("setup: honest rq_1 refused: " + why);
    return out > 1000n || eff > 1000n ? fail("OVER-REFUND: " + why) : pass(why);
  },
};
export const regressionB: Regression = {
  id: "X5b-hostile-outbox-rewrite", kind: "attack", title: "writer rewrites an outbox amount, sink goes on",
  run(h: Harness) {
    const S0 = h.st("ch_1", "1000", "1000");
    const { db, sink } = h.newStore("x5b", S0);
    const t1 = h.honest(S0, "rq_1", "100");
    const c1 = h.commit(sink, t1);
    h.foreign(db, d => { d.prepare("UPDATE outbox SET intent = ? WHERE request_id = 'rq_1'").run(h.E.canon(h.intent("ch_1", "rq_1", "1"))); });
    const cur = h.stored(db)!;
    const t2 = h.honest(cur, "rq_2", "100");
    const c2 = h.commit(sink, t2);
    const f = h.flush(db, S0);
    const signed = new Set([h.intent("ch_1", "rq_1", "100"), h.intent("ch_1", "rq_2", "100")].map(i => h.E.canon(i)));
    const foreignEff = f.effects.filter(e => !signed.has(h.E.canon(e.intent))).length;
    const ob = h.outbox(db);
    const tampered = ob.some(o => o.request_id === "rq_1" && o.intent.amount !== "100");
    const settledOnTamper = tampered && ob.some(o => o.request_id === "rq_2");
    const why = `rq_1=${c1} rq_2=${c2} unsignedEffects=${foreignEff} rewrittenRowPresent=${tampered} rq_2SettledOnIt=${settledOnTamper}`;
    if (c1 !== "committed") return fail("setup: honest rq_1 refused: " + why);
    return foreignEff > 0 || settledOnTamper ? fail("TAMPERED STORE EXTENDED: " + why) : pass(why);
  },
};
if (require.main === module) standalone([regressionA, regressionB], process.argv);
