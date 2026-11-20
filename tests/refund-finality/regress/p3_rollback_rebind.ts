// h-provider3 regression for red team C-ATT-42 (rollback plus a reused request id). Full snapshot of the local files
// after init; r1 600 committed and paid; the operator restores the snapshot; the host REUSES r1 for an honest refund of
// 100; then it refunds the stale remaining (r2 900). Provider: replay first (default case) or error; ceiling ON.
// usage: p3_rollback_rebind.ts <tree> [first|error] [none|full]
// Old adapter: r1 100 is reported paid on the 600 movement (T4/T5): exit 1.
// New adapter (owner decision D-3: the amount is in the key): r1 100 is a NEW key -> the provider pays 100 as a new
// refund -> request id r1 moved money twice (T2) with anchor none: exit 1 (the booking itself is now true). Layer 1
// (anchor full) refuses the restored store: exit 0. Measurement P_KEY=noamount: the key repeats, the answer check
// raises an ALARM: exit 0 also with anchor none. Usage and exit codes: p3_lib.ts.
import { emittedOf, journalOf, root, truth, verdict } from "./p3_lib";
import { guard, world } from "./p_lib";
guard(() => {
  const tree = root(), replay = (process.argv[3] ?? "first") as "first" | "error", anchor = (process.argv[4] ?? "none") as "none" | "full";
  if (!["first", "error"].includes(replay) || !["none", "full"].includes(anchor)) { console.error("usage: <tree> [first|error] [none|full]"); process.exit(4); }
  const S0 = { chargeId: "ch_rb", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(tree, "b", anchor, S0, { providerOptions: { replay } });
  w.snapshotAll();
  const r1 = w.refund("r1", "600"); const f1 = w.flush();
  if (r1.status !== "committed" || f1.emitted.join() !== "r1") { console.error("SETUP FAILED " + JSON.stringify({ r1, f1 })); process.exit(3); }
  const em = emittedOf(w, f1);
  const j1 = journalOf(w);                    // the journal before the restore (the restore brings back the old journal)
  w.restoreAll();
  const r1b = w.refund("r1", "100"); const f2 = w.flush(); em.push(...emittedOf(w, f2));
  const stale = w.state()?.remaining ?? "0";
  const r2 = w.refund("r2", stale); const f3 = w.flush(); const f4 = w.flush(); em.push(...emittedOf(w, f3), ...emittedOf(w, f4));
  const mv = w.provider.movements();
  const problems = truth(mv, em, { ch_rb: "1000" }, [{ w, lines: [...j1, ...journalOf(w)] }]);
  const local = w.state()?.remaining ?? "(no sink)";
  const booking = problems.filter(p => p.startsWith("T4") || p.startsWith("T5"));
  console.log("booking check (T4,T5; C-ATT-42 proper): " + (booking.length === 0 ? "TRUE" : "WRONG"));
  console.log("books: remaining " + local + "; provider moved " + mv.reduce((t, m) => t + BigInt(m.amount), 0n));
  w.stop();
  verdict("p3_rollback_rebind " + replay + " " + anchor, problems, { r1b: r1b.status, r2: [stale, r2.status], f2, f3, f4, sink: w.sinkRefusal() || "up",
    journal: journalOf(w).map(j => j.requestId + ":" + j.outcome), movements: mv.map(m => m.key.slice(0, 12) + ":" + m.amount) });
});
