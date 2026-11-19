// Provider-anchor POSITIVE CONTROL: zero-amount refunds stay legitimate end to end (spec/refund/protocol.md).
// z1 0, z2 0, then r1 100 on one charge: all commit, all are emitted. The adapter makes NO provider call for a zero
// amount (the fake provider refuses zero, as many real providers do) and writes a "zero-recorded" journal line.
// SAFE: 3 emitted, exactly 1 provider call and 1 movement (r1 100), 2 zero-recorded lines. Usage and exit codes: p_lib.ts.
import { readFileSync } from "node:fs";
import { argv, guard, moneyCheck, verdict, world } from "./p_lib";
guard(() => {
  const { root, mode } = argv();
  const S0 = { chargeId: "ch_pz", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, S0);
  const c = [w.refund("z1", "0").status, w.refund("z2", "0").status, w.refund("r1", "100").status];
  const f = w.flush();
  const zero = readFileSync(w.journalPath, "utf8").trim().split("\n").map(l => JSON.parse(l)).filter(j => j.outcome === "zero-recorded").length;
  const calls = w.provider.calls();
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  const ok = c.every(s => s === "committed") && f.error === "" && f.emitted.join() === "z1,z2,r1" && calls === 1 && zero === 2 && m.total === "100";
  verdict(ok && m.noDouble && m.withinCharge, { mode, commits: c, flush: f, providerCalls: calls, zeroRecorded: zero, money: m });
});
