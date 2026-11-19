// POSITIVE CONTROLS of the regression runner. They must PASS on every sink, the merged one included. A sink that
// rejects everything passes every "at most" assertion of the attack regressions; these controls make it FAIL.
// Zero-amount refunds are legitimate (spec/refund/protocol.md: "Zero is a legitimate authorization").
// Assertions are on durable state and effects: outbox rows and dispatcher emissions.
import { Harness, Regression, fail, pass, standalone } from "./harness";

const once = (h: Harness, db: string, ids: string[], amounts: string[], effects: { requestId: string; intent: any }[]): string | null => {
  const ob = h.outbox(db);
  for (let i = 0; i < ids.length; i++) {
    const o = ob.filter(x => x.request_id === ids[i] && x.intent.requestId === ids[i] && x.intent.amount === amounts[i]).length;
    const e = effects.filter(x => x.intent.requestId === ids[i] && x.intent.amount === amounts[i]).length;
    if (o !== 1 || e !== 1) return `${ids[i]}: outbox=${o} effects=${e} (want 1 and 1)`;
  }
  return ob.length === ids.length && effects.length === ids.length ? null : `outbox=${ob.length} effects=${effects.length} (want ${ids.length})`;
};

export const controls: Regression[] = [
  { id: "C1-honest-refund", kind: "control", title: "an honest refund commits once and dispatches once",
    run(h) { const S0 = h.st("ch_1", "1000", "1000"); const { db, sink } = h.newStore("c1", S0);
      const r = h.commit(sink, h.honest(S0, "rq_1", "100")); const f = h.flush(db, S0); const f2 = h.flush(db, S0);
      const bad = once(h, db, ["rq_1"], ["100"], [...f.effects, ...f2.effects]);
      return bad ? fail(`commit=${r} ${bad}`) : pass(`commit=${r}; one outbox row; one effect over two flushes`); } },
  { id: "C2-zero-amount-refund", kind: "control", title: "a zero-amount refund commits and dispatches once",
    run(h) { const S0 = h.st("ch_1", "1000", "1000"); const { db, sink } = h.newStore("c2", S0);
      const r = h.commit(sink, h.honest(S0, "rq_z", "0", "duplicate_charge")); const f = h.flush(db, S0);
      const bad = once(h, db, ["rq_z"], ["0"], f.effects);
      return bad ? fail(`commit=${r} ${bad}`) : pass(`commit=${r}; one zero-valued intent emitted`); } },
  { id: "C3-two-zero-refunds", kind: "control", title: "two zero-amount refunds with distinct request ids both commit",
    run(h) { const S0 = h.st("ch_1", "1000", "1000"); const { db, sink } = h.newStore("c3", S0);
      const r1 = h.commit(sink, h.honest(S0, "rq_z1", "0", "duplicate_charge"));
      const r2 = h.commit(sink, h.honest(h.stored(db)!, "rq_z2", "0", "service_not_delivered")); const f = h.flush(db, S0);
      const bad = once(h, db, ["rq_z1", "rq_z2"], ["0", "0"], f.effects);
      return bad ? fail(`commits=${r1},${r2} ${bad}`) : pass(`commits=${r1},${r2}; two zero-valued effects`); } },
  { id: "C4-replay-rejected", kind: "control", title: "a replay is not a second effect",
    run(h) { const S0 = h.st("ch_1", "1000", "1000"); const { db, sink } = h.newStore("c4", S0);
      const t = h.honest(S0, "rq_1", "100"); const r1 = h.commit(sink, t); const f1 = h.flush(db, S0);
      const r2 = h.commit(sink, t); const f2 = h.flush(db, S0);
      const bad = once(h, db, ["rq_1"], ["100"], [...f1.effects, ...f2.effects]);
      if (r2 === "committed") return fail(`replay answered committed (${r1} then ${r2})`);
      return bad ? fail(`first=${r1} replay=${r2} ${bad}`) : pass(`first=${r1} replay=${r2}; one effect`); } },
  { id: "C5-largest-refund", kind: "control", title: "amount == remaining commits",
    run(h) { const S0 = h.st("ch_1", "1000", "1000"); const { db, sink } = h.newStore("c5", S0);
      const r1 = h.commit(sink, h.honest(S0, "rq_1", "250")); const S1 = h.stored(db)!;
      const r2 = h.commit(sink, h.honest(S1, "rq_all", S1.remaining, "service_not_delivered")); const f = h.flush(db, S0);
      const bad = once(h, db, ["rq_1", "rq_all"], ["250", "750"], f.effects);
      const rem = h.stored(db)?.remaining;
      return bad || rem !== "0" ? fail(`commits=${r1},${r2} remaining=${rem} ${bad ?? ""}`) : pass(`commits=${r1},${r2}; remaining 0; two effects`); } },
];
if (require.main === module) standalone(controls, process.argv);
