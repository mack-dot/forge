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
//   THREE OUTCOMES (kind "limit"; red-team finding C-JUDGE-02: a limit test must accept the safe outcome):
//     without an anchor: the sink refuses to start or refuses to settle rq_2 again = SAFE (PASS); the sink settles
//       rq_2 again = the stated limit (KNOWN-LIMIT); anything else (a second effect for rq_2, a refused honest
//       setup, a crash of the judge's child) = FAIL;
//     with an anchor adapter (runner argument expectedHeadMode): refusing = PASS; settling rq_2 again = FAIL.
//   In every mode the dispatcher emits rq_2 at most once (its ledger is outside the database).
// Both cases run with two writer strengths (harness.ts twoWriters): a write that the database refuses is the safe
// outcome for the writer that keeps the schema; the verdict then comes from the writer that drops the triggers.
import { AnchorAdapter, Harness, Regression, WriterMode, fail, knownLimit, pass, twoWriters } from "./harness";

export const regressionZ1: Regression = {
  id: "X6-Z1-zero-row-deleted-recommitted", kind: "attack", title: "deleted zero-amount row committed again",
  run: (h: Harness) => twoWriters(h, "X6-Z1", async (h: Harness, mode: WriterMode) => {
    const S0 = h.st("ch_1", "1000", "1000"), S1 = h.dec(S0, "100");
    const { db, sink } = await h.newStore("z1", S0);
    const tz1 = h.honest(S1, "rq_z1", "0", "duplicate_charge");
    const cs = [await h.commit(sink, h.honest(S0, "rq_1", "100")), await h.commit(sink, tz1), await h.commit(sink, h.honest(S1, "rq_z2", "0", "duplicate_charge"))];
    const f1 = await h.flush(db, S0);
    await h.close(sink);
    if (cs.some(c => c !== "committed")) return fail("setup: honest commits refused: " + cs.join(","));
    h.write(db, d => d.exec("DELETE FROM settled WHERE request_id = 'rq_z1'; DELETE FROM outbox WHERE request_id = 'rq_z1'"), mode);
    await h.restart();                                   // a process restart of the sink
    const { sink: s2, error } = await h.openSink(db, h.cfg(S0));
    let r = "sink refused to start (" + error.slice(0, 60) + ")";
    if (s2 !== null) { r = await h.commit(s2, tz1); await h.close(s2); }
    const f2 = await h.flush(db, S0);
    const again = h.outbox(db).filter(o => o.request_id === "rq_z1").length;
    const eff = [...f1.effects, ...f2.effects].filter(e => e.intent.requestId === "rq_z1").length;
    const why = `honest=${cs.join(",")} redelivery=${r} outbox(rq_z1)=${again} effects(rq_z1)=${eff}`;
    return again > 0 || eff > 1 ? fail("RE-SETTLED AFTER DELETION: " + why) : pass(why);
  }),
};
export const regressionP1: Regression = {
  id: "X6-P1-prefix-rollback", kind: "limit", title: "rollback to a valid earlier prefix",
  run: (h: Harness) => twoWriters(h, "X6-P1", async (h: Harness, mode: WriterMode) => {
    const S0 = h.st("ch_1", "1000", "1000"), S1 = h.dec(S0, "100");
    const { db, sink } = await h.newStore("p1", S0);
    const t2 = h.honest(S1, "rq_2", "50");
    const cs = [await h.commit(sink, h.honest(S0, "rq_1", "100")), await h.commit(sink, t2)];
    const f1 = await h.flush(db, S0);
    await h.close(sink);
    if (cs.some(c => c !== "committed")) return fail("setup: honest commits refused: " + cs.join(","));
    const adapter: AnchorAdapter | null = h.anchor;
    const head = adapter ? adapter.capture(h, db) : undefined;
    h.write(db, d => {
      d.exec("DELETE FROM settled WHERE request_id = 'rq_2'; DELETE FROM outbox WHERE request_id = 'rq_2'");
      d.prepare("UPDATE state SET blob = ? WHERE id = 1").run(h.E.canon(S1));
    }, mode);
    await h.restart();
    const cfg = adapter ? adapter.apply(h.cfg(S0), head) : h.cfg(S0);
    const { sink: s2, error } = await h.openSink(db, cfg);
    let r = "not delivered";
    if (s2 !== null) { r = await h.commit(s2, t2); await h.close(s2); }
    const f2 = await h.flush(db, S0);
    const resettled = h.outbox(db).some(o => o.request_id === "rq_2");
    const eff = [...f1.effects, ...f2.effects].filter(e => e.intent.requestId === "rq_2").length;
    const why = `mode=${adapter ? "anchored" : "no-anchor"} honest=${cs.join(",")} started=${s2 !== null}${s2 ? "" : " (" + error.slice(0, 50) + ")"} redelivery=${r} resettled=${resettled} effects(rq_2)=${eff}`;
    if (eff > 1) return fail("DUPLICATE EFFECT: " + why);
    if (!resettled) return pass("SAFE: the rollback is refused or rq_2 is not settled again: " + why);
    return adapter ? fail("ROLLBACK ACCEPTED WITH AN ANCHOR: " + why) : knownLimit("documented limit holds (no anchor; rq_2 settled again, emitted at most once): " + why);
  }),
};
