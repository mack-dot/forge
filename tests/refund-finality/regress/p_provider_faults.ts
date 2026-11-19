// Provider-anchor POSITIVE CONTROL: faults that are NOT a double-payment attack. Expected PASS in every mode and anchor.
// (1) crash before the money moved for r1: the adapter retries (retries 1) with the same key: r1 moves money once.
// (2) a refusal for r2: the adapter throws; the dispatcher run stops; r2 is not in `emitted`; the adapter journal says
//     refused; no money moved for r2 (the record is truthful). (3) A later run sends r3 and reports r2 "in doubt" (claim
//     rule of the dispatcher at 370ff65c: a person must resolve it). PASS also requires the journal to match the
//     provider's movements. Usage and exit codes: p_lib.ts.
import { readFileSync } from "node:fs";
import { argv, guard, moneyCheck, positiveVerdict, world } from "./p_lib";
guard(() => {
  const { root, mode, anchor } = argv();
  const S0 = { chargeId: "ch_pf", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, anchor, S0, { retries: 1 });
  const r1 = w.refund("r1", "300"); w.provider.inject("r1", "crash_before_money");
  const f1 = w.flush();
  const r2 = w.refund("r2", "300"); w.provider.inject("r2", "refuse");
  const r3 = w.refund("r3", "300");
  const f2 = w.flush(); const f3 = w.flush();
  const journal = readFileSync(w.journalPath, "utf8").trim().split("\n").map(l => JSON.parse(l));
  const final = new Map<string, string>(); for (const j of journal) final.set(j.requestId, j.outcome);
  const m = moneyCheck(w.provider, S0.chargeId, S0.original);
  const moved = new Set(w.provider.movements().map(x => x.key)); w.stop();
  const truthful = [...final].every(([rid, out]) => (out === "paid" || out === "replayed") === moved.has(rid)) &&
    final.get("r2") === "refused:refused" && !moved.has("r2");
  const ok = r1.status === "committed" && r2.status === "committed" && r3.status === "committed" &&
    f1.emitted.join() === "r1" && f2.error !== "" && f3.emitted.join() === "r3" && f3.refused.some(x => x.startsWith("r2: in doubt"));
  positiveVerdict(m.noDouble && m.withinCharge && truthful && ok, { test: "p_provider_faults", mode, anchor, f1, f2, f3, journal: [...final], money: m });
});
