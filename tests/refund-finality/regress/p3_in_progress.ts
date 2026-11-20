// h-provider3 regression for the worker report "in progress" (red team summary item 5b; attacker: none).
// Phase 1: r1 300; the provider moves the money and answers in_progress (twice); the adapter has no retry (retries 0).
//   Required: the journal never says "refused" for r1 (money moved); the dispatcher reports r1 in doubt; no "paid" line.
// Phase 2: r2 200; the provider moves the money and answers in_progress once; the adapter retries once with the same key
//   and gets the replayed result: "replayed" (paid before), r2 emitted.
// Phase 3: a person reconciles r1 later (calls the adapter with the outbox row; the key is no longer in progress):
//   the provider replays the first result: "replayed"; no second movement.
// Old adapter: in_progress is not in its retry list -> "refused:in_progress" while money moved (T5): exit 1.
// New adapter: exit 0. Usage and exit codes: p3_lib.ts.
import { journalOf, root, truth, verdict } from "./p3_lib";
import { guard, world } from "./p_lib";
guard(() => {
  const tree = root();
  const w = world(tree, "b", "none", { chargeId: "ch_ip", original: "1000", remaining: "1000", refundEnabled: true }, { retries: 0 });
  const c1 = w.refund("r1", "300"); w.provider.inject(w.keyOf("r1", "300"), "in_progress_after_money", 2);
  const f1 = w.flush();
  const c2 = w.refund("r2", "200"); w.provider.inject(w.keyOf("r2", "200"), "in_progress_after_money", 1); w.setRetries(1);
  const f2 = w.flush();
  if (c1.status !== "committed" || c2.status !== "committed") { console.error("SETUP FAILED"); process.exit(3); }
  const problems: string[] = [];
  const j1 = journalOf(w).filter(j => j.requestId === "r1").map(j => String(j.outcome));
  if (j1.some(o => o.startsWith("refused") || o === "paid" || o === "replayed")) problems.push("r1 journal before reconcile: " + j1.join(","));
  if (!f2.refused.some(x => x.startsWith("r1: in doubt"))) problems.push("dispatcher does not report r1 in doubt: " + JSON.stringify(f2.refused));
  if (!f2.emitted.includes("r2")) problems.push("r2 not emitted after its retry: " + JSON.stringify(f2));
  // Phase 3: reconcile r1 (w.provider still answers in_progress once more for r1 -> the adapter has 1 retry).
  const row = w.outboxIntents().find(r => r.requestId === "r1")!;
  let rec = "returned"; try { w.emit({ requestId: "r1", intent: w.E.canon(row.intent) }, row.intent); } catch (e) { rec = "threw: " + (e as Error).message; }
  const mv = w.provider.movements();
  const em = f2.emitted.includes("r2") ? [{ chargeId: "ch_ip", requestId: "r2", amount: "200", key: w.keyOf("r2", "200") }] : [];
  problems.push(...truth(mv, em, { ch_ip: "1000" }, [{ w, lines: journalOf(w) }]));
  const jr1 = journalOf(w).filter(j => j.requestId === "r1").map(j => String(j.outcome));
  if (rec !== "returned" || jr1[jr1.length - 1] !== "replayed") problems.push("r1 reconcile: " + rec.slice(0, 120) + " journal " + jr1.join(","));
  w.stop();
  verdict("p3_in_progress", problems, { f1, f2, reconcile: rec, journal: journalOf(w).map(j => j.requestId + ":" + j.outcome), movements: mv.map(m => m.key.slice(0, 12) + ":" + m.amount) });
});
