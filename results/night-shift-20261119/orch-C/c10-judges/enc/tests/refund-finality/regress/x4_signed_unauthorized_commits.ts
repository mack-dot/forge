// X4 SIGNED BUT UNAUTHORIZED TOKEN. Attack class: an effect that the approved refund relation does not authorize.
// Evidence: unsure U555, U557; results/night-shift-20261119/orch-B/d-v6sink/ts/conformance_v6.ts and
// orch-B/r-v6/ts/rv6_cases.ts (cases 61, 7, 8, 9, 10).
// Assumption: a trusted but FAULTY signer signs a well-formed token for the stored pre-state whose transition the
// approved relation (spec/refund/protocol.md) does not authorize. Relies on the owner's B-10 decision (the stored
// charge governs) and on the still OPEN rule POST-RULE (an authorized refund decreases `remaining` by the amount
// and changes nothing else) for cases b, c and e.
// Cases (each in its own fresh store ch_1, original 1000, remaining 1000):
//   a amount 1001 > remaining (post remaining 0); b post sets refundEnabled false; c post remaining 950 for amount
//   100; d unapproved reason "goodwill"; e intent amount 100 while post keeps remaining 1000.
// EXPECTED SAFE OUTCOME per store: the outbox stays empty, the dispatcher emits nothing, the stored state is the
// initial state. Liveness part: an honest refund (rq_ok, 100) delivered afterwards is emitted exactly once.
// Unsafe on the merged sink: every case commits and is dispatched (case a: 1001 out of a charge of 1000).
import { Harness, Regression, fail, pass, standalone } from "./harness";

export const regression: Regression = {
  id: "X4-signed-unauthorized", kind: "attack", title: "signed tokens outside the approved relation",
  run(h: Harness) {
    const S0 = h.st("ch_1", "1000", "1000");
    const cases: [string, string][] = [
      ["a-amount-above-remaining", h.sign(S0, "rq_a", { ...S0, remaining: "0" }, h.intent("ch_1", "rq_a", "1001"))],
      ["b-post-disables-refunds", h.sign(S0, "rq_b", { ...h.dec(S0, "100"), refundEnabled: false }, h.intent("ch_1", "rq_b", "100"))],
      ["c-post-remaining-wrong", h.sign(S0, "rq_c", h.dec(S0, "50"), h.intent("ch_1", "rq_c", "100"))],
      ["d-unapproved-reason", h.honest(S0, "rq_d", "100", "goodwill")],
      ["e-post-unchanged", h.sign(S0, "rq_e", S0, h.intent("ch_1", "rq_e", "100"))],
    ];
    const bad: string[] = [], dead: string[] = [], notes: string[] = [];
    for (const [name, text] of cases) {
      const { db, sink } = h.newStore(name, S0);
      const r = h.commit(sink, text);
      const unchanged = h.E.canon(h.stored(db)) === h.E.canon(S0);
      const okR = h.commit(sink, h.honest(h.stored(db)!, "rq_ok", "100"));
      const f = h.flush(db, S0, name + ".ledger.jsonl");      // one ledger per store
      const badEff = f.effects.filter(e => e.intent.requestId !== "rq_ok").length;
      const badOut = h.outbox(db).filter(o => o.intent.requestId !== "rq_ok").length;
      const okEff = f.effects.filter(e => e.intent.requestId === "rq_ok").length;
      notes.push(`${name}:${r}/ok=${okR}/eff=${badEff}+${okEff}`);
      if (badEff > 0 || badOut > 0 || !unchanged) bad.push(name);
      else if (okEff !== 1) dead.push(name);
    }
    const why = notes.join(" ");
    if (bad.length > 0) return fail("UNAUTHORIZED EFFECT in " + bad.join(",") + ": " + why);
    return dead.length > 0 ? fail("honest refund not dispatched exactly once in " + dead.join(",") + ": " + why) : pass(why);
  },
};
if (require.main === module) standalone([regression], process.argv);
