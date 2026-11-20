// Provider-anchor POSITIVE CONTROL: zero-amount refunds and an honest flow stay legitimate end to end
// (spec/refund/protocol.md), in every provider mode and with every anchor setting.
// z1 0, z2 0, r1 100, run; r2 200, z3 0, run; a run with nothing new; a sink restart (the host passes its outside head
// when the anchor has one); z4 0, r3 50, run. All commit, every row is emitted exactly once, and the adapter makes NO
// provider call for a zero amount (the fake provider refuses zero, as many real providers do; "zero-recorded" journal
// line). PASS: 7 emitted once each, 3 provider calls, 3 movements (350), 4 zero-recorded lines, no refusal by any layer.
// Usage and exit codes: p_lib.ts.
import { readFileSync } from "node:fs";
import { argv, guard, moneyCheck, positiveVerdict, world } from "./p_lib";
guard(() => {
  const { root, mode, anchor } = argv();
  const S0 = { chargeId: "ch_pz", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, anchor, S0);
  const c1 = [w.refund("z1", "0").status, w.refund("z2", "0").status, w.refund("r1", "100").status];
  const f1 = w.flush();
  const c2 = [w.refund("r2", "200").status, w.refund("z3", "0").status];
  const f2 = w.flush(); const f3 = w.flush();
  w.reopen();
  const up = w.sinkUp();
  const c3 = [w.refund("z4", "0").status, w.refund("r3", "50").status];
  const f4 = w.flush();
  const zero = readFileSync(w.journalPath, "utf8").trim().split("\n").map(l => JSON.parse(l)).filter(j => j.outcome === "zero-recorded").length;
  const calls = w.provider.calls();
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  const emitted = [...f1.emitted, ...f2.emitted, ...f3.emitted, ...f4.emitted];
  const ok = [...c1, ...c2, ...c3].every(s => s === "committed") && up && [f1, f2, f3, f4].every(f => f.error === "" && f.refused.length === 0) &&
    emitted.join() === "z1,z2,r1,r2,z3,z4,r3" && calls === 3 && zero === 4 && m.total === "350" && w.events.length === 0;
  positiveVerdict(ok && m.noDouble && m.withinCharge, { test: "p_zero_amount", mode, anchor, commits: [...c1, ...c2, ...c3], sinkRestart: up, emitted, providerCalls: calls,
    zeroRecorded: zero, events: w.events, money: m });
});
