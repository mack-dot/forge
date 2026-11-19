// Provider-anchor regression: a provider timeout AFTER the money moved (the caller sees an error).
// Phase 1 (immediate retry): r1 400; the adapter retries once with the same key and parameters inside the same emit.
// Phase 2 (delayed retry): r2 400 times out; the adapter does not retry (retries 0); the dispatcher run stops with an
// error; its ledger already holds r2 (line before effect), so no later run re-emits r2. A person reconciles: calls the
// adapter again with the outbox row of r2. In modes d-a and d-b this happens AFTER the key retention window.
// SAFE: no request id moves money twice and money moved <= the charge. Usage and exit codes: p_lib.ts.
import { argv, guard, moneyCheck, verdict, world } from "./p_lib";
guard(() => {
  const { root, mode } = argv();
  const S0 = { chargeId: "ch_pt", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, S0, { retries: 1 });
  const r1 = w.refund("r1", "400");
  w.provider.inject("r1", "timeout_after_money");
  const f1 = w.flush();
  const r2 = w.refund("r2", "400");
  w.provider.inject("r2", "timeout_after_money");
  w.setRetries(0);
  const f2 = w.flush();
  const f3 = w.flush();                     // the dispatcher alone does not send r2 again
  w.atAttack();
  const row = w.outboxIntents().find(r => r.requestId === "r2")!;
  let reconcile = "returned";
  try { w.emit({ requestId: row.requestId, intent: w.E.canon(row.intent) }, row.intent); } catch (e) { reconcile = "threw: " + (e as Error).message; }
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  const setup = r1.status === "committed" && r2.status === "committed" && f2.error !== "" && f3.emitted.length === 0;
  if (!setup) { console.error(JSON.stringify({ r1, r2, f1, f2, f3 })); process.exit(3); }
  verdict(m.noDouble && m.withinCharge && f1.error === "" , { mode, phase1: f1, phase2: f2, rerun: f3, reconcile, money: m });
});
