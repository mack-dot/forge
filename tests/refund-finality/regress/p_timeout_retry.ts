// Provider-anchor regression: a provider timeout AFTER the money moved (the caller sees an error).
// Phase 1 (immediate retry): r1 400; the adapter retries once with the same key and parameters inside the same emit.
// Phase 2 (delayed retry): r2 400 times out; the adapter does not retry (retries 0); the dispatcher run stops with an
// error; its ledger already holds the claim of r2 (line before effect), so later runs report r2 "in doubt" and never
// re-emit it. A person reconciles: calls the adapter again with the outbox row of r2 (the receiver was not asked first).
// In modes d-a and d-b this happens AFTER the key retention window. No restore: the local anchor plays no part.
// SAFE: no request id moves money twice and money moved <= the charge. Usage and exit codes: p_lib.ts.
import { argv, attackVerdict, guard, moneyCheck, setupFail, world } from "./p_lib";
guard(() => {
  const { root, mode, anchor } = argv();
  const S0 = { chargeId: "ch_pt", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, anchor, S0, { retries: 1 });
  const r1 = w.refund("r1", "400");
  w.provider.inject(w.keyOf("r1", "400"), "timeout_after_money");   // h-provider3: the key the adapter sends
  const f1 = w.flush();
  const r2 = w.refund("r2", "400");
  w.provider.inject(w.keyOf("r2", "400"), "timeout_after_money");
  w.setRetries(0);
  const f2 = w.flush();
  const f3 = w.flush();                     // the dispatcher alone does not send r2 again (in doubt)
  const setup = r1.status === "committed" && r2.status === "committed" && f2.error !== "" && f3.emitted.length === 0;
  if (!setup) setupFail({ r1, r2, f1, f2, f3 });
  w.atAttack();
  const row = w.outboxIntents().find(r => r.requestId === "r2")!;
  let reconcile = "returned";
  try { w.emit({ requestId: row.requestId, intent: w.E.canon(row.intent) }, row.intent); } catch (e) { reconcile = "threw: " + (e as Error).message; }
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  attackVerdict(mode, anchor, m.noDouble && m.withinCharge && f1.error === "", w.events, { test: "p_timeout_retry", phase1: f1, phase2: f2, rerun: f3, reconcile, money: m });
});
