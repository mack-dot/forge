// X6 ROW DELETION BY A DATABASE WRITER. Evidence: unsure U565; results/night-shift-20261119/orch-B/r-v5/ts/attack_rv5.ts
// (Z1-middle-zero-row-deleted, P1-prefix-rollback-last-row).
// Assumption: a writer of the database file WITHOUT the signing key; the sink is restarted after the change.
// X6-Z1 zero-amount row deletion, then re-commit. Honest store: rq_1 (100), rq_z1 (0), rq_z2 (0), all dispatched.
//   The writer deletes rq_z1's settled and outbox rows (a zero row does not move the balance, so the chain of
//   states stays valid). After a restart the same rq_z1 token is delivered again.
//   EXPECTED SAFE OUTCOME: rq_z1 is not settled a second time (at the end the outbox holds no rq_z1 row) and the
//   dispatcher emits rq_z1 at most once in total. Refusing to start or to commit is safe.
//   Unsafe: merged sink AND the v6 draft (the review's finding F1): rq_z1 is settled again.
// X6-P1 prefix rollback (a STATED LIMIT, not fixable inside the database). Honest store: rq_1 (100), rq_2 (50),
//   dispatched. The writer deletes rq_2's rows and restores the state before rq_2: a valid earlier prefix.
//   DOCUMENTED BEHAVIOUR asserted here: WITHOUT an external expected head the sink starts on the rolled-back store;
//   WITH one (runner argument expectedHeadMode = an anchor adapter module) the sink refuses to start or refuses to
//   settle rq_2 again. In both modes the dispatcher emits rq_2 at most once (its ledger is outside the database).
import { AnchorAdapter, Harness, Regression, fail, pass, standalone } from "./harness";

export const regressionZ1: Regression = {
  id: "X6-Z1-zero-row-deleted-recommitted", kind: "attack", title: "deleted zero-amount row committed again",
  run(h: Harness) {
    const S0 = h.st("ch_1", "1000", "1000"), S1 = h.dec(S0, "100");
    const { db, sink } = h.newStore("z1", S0);
    const tz1 = h.honest(S1, "rq_z1", "0", "duplicate_charge");
    const cs = [h.commit(sink, h.honest(S0, "rq_1", "100")), h.commit(sink, tz1), h.commit(sink, h.honest(S1, "rq_z2", "0", "duplicate_charge"))];
    const f1 = h.flush(db, S0);
    h.close(sink);
    h.foreign(db, d => d.exec("DELETE FROM settled WHERE request_id = 'rq_z1'; DELETE FROM outbox WHERE request_id = 'rq_z1'"));
    const { sink: s2, error } = h.openSink(db, h.cfg(S0));
    let r = "sink refused to start (" + error.slice(0, 60) + ")";
    if (s2 !== null) { r = h.commit(s2, tz1); h.close(s2); }
    const f2 = h.flush(db, S0);
    const again = h.outbox(db).filter(o => o.request_id === "rq_z1").length;
    const eff = [...f1.effects, ...f2.effects].filter(e => e.intent.requestId === "rq_z1").length;
    const why = `honest=${cs.join(",")} redelivery=${r} outbox(rq_z1)=${again} effects(rq_z1)=${eff}`;
    if (cs.some(c => c !== "committed")) return fail("setup: honest commits refused: " + why);
    return again > 0 || eff > 1 ? fail("RE-SETTLED AFTER DELETION: " + why) : pass(why);
  },
};
export const regressionP1: Regression = {
  id: "X6-P1-prefix-rollback", kind: "limit", title: "rollback to a valid earlier prefix",
  run(h: Harness) {
    const S0 = h.st("ch_1", "1000", "1000"), S1 = h.dec(S0, "100");
    const { db, sink } = h.newStore("p1", S0);
    const t2 = h.honest(S1, "rq_2", "50");
    const cs = [h.commit(sink, h.honest(S0, "rq_1", "100")), h.commit(sink, t2)];
    const f1 = h.flush(db, S0);
    h.close(sink);
    const adapter: AnchorAdapter | null = h.anchor;
    const head = adapter ? adapter.capture(h, db) : undefined;
    h.foreign(db, d => {
      d.exec("DELETE FROM settled WHERE request_id = 'rq_2'; DELETE FROM outbox WHERE request_id = 'rq_2'");
      d.prepare("UPDATE state SET blob = ? WHERE id = 1").run(h.E.canon(S1));
    });
    const cfg = adapter ? adapter.apply(h.cfg(S0), head) : h.cfg(S0);
    const { sink: s2, error } = h.openSink(db, cfg);
    let r = "not delivered";
    if (s2 !== null) { r = h.commit(s2, t2); h.close(s2); }
    const f2 = h.flush(db, S0);
    const resettled = h.outbox(db).some(o => o.request_id === "rq_2");
    const eff = [...f1.effects, ...f2.effects].filter(e => e.intent.requestId === "rq_2").length;
    const why = `mode=${adapter ? "anchored" : "no-anchor"} honest=${cs.join(",")} started=${s2 !== null}${s2 ? "" : " (" + error.slice(0, 50) + ")"} redelivery=${r} resettled=${resettled} effects(rq_2)=${eff}`;
    if (cs.some(c => c !== "committed")) return fail("setup: honest commits refused: " + why);
    if (eff > 1) return fail("DUPLICATE EFFECT: " + why);
    if (!adapter) return s2 !== null ? pass("documented limit holds: " + why) : fail("differs from the documented limit (refused without an anchor): " + why);
    return s2 === null || !resettled ? pass("anchor refuses the rollback: " + why) : fail("ROLLBACK ACCEPTED WITH AN ANCHOR: " + why);
  },
};
if (require.main === module) standalone([regressionZ1, regressionP1], process.argv);
