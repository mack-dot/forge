// Shared helper of the p3_*.ts regressions (night shift 2026-11-19, task h-provider3). A TEST with a FAKE provider, not a proof.
// Usage of every p3_*.ts file (pinned Node 24.3.0 first in PATH):
//   [P_ADAPTER=v1] node --import tsx tests/refund-finality/regress/p3_<name>.ts <treeRoot> [<case>]
// P_ADAPTER=v1 runs the FROZEN old adapter (key = request id, any answer accepted): the CONTROL. It must give exit 1.
// Exit codes: 0 SAFE, 1 NOT STOPPED (money or record wrong), 3 harness error, 4 usage.
// TRUTH (the red team's clib.ts truth, kept, plus three checks; nothing removed):
//   T1 no provider key moved money twice; T2 no EFFECT (store, charge, request id) moved money twice;
//   T3 per charge the money moved <= the charge;
//   T4 every refund that a dispatcher run reported EMITTED with a non-zero amount has exactly one provider movement with
//      the key the adapter sends for it, on its charge, of its amount;
//   T5 the adapter journal: every "paid" or "replayed" line names a provider movement (refundId) with the line's key,
//      charge and amount; every "refused:*" line names a key under which NO money moved (a refusal is before money);
//   T6 (only where the test asks) a legitimate committed refund is not left unpaid (false rejection).
// It reads effects, money moved and the adapter journal only; never the dispatcher's ledger lines.
import { existsSync, readFileSync } from "node:fs";
import { ADAPTER, effectMoves, effectOf } from "./p_lib";

export type Emitted = { chargeId: string; requestId: string; amount: string; key: string };
export function emittedOf(w: any, f: { emitted: string[] }): Emitted[] {
  const rows = w.outboxIntents();
  return f.emitted.map((id: string) => { const r = rows.find((x: any) => x.requestId === id);
    return { chargeId: r.intent.chargeId, requestId: id, amount: r.intent.amount, key: w.keyOf(id, r.intent.amount) }; });
}
// The journal lines; a v1 line has no call side: it is filled from the committed row AT READ TIME (read before a restore).
export function journalOf(w: any): any[] {
  const lines = existsSync(w.journalPath) ? readFileSync(w.journalPath, "utf8").trim().split("\n").filter(Boolean).map(l => JSON.parse(l)) : [];
  const rows = w.outboxIntents();
  return lines.map((j: any) => { const row = rows.find((x: any) => x.requestId === j.requestId);
    return { ...j, chargeId: j.chargeId ?? row?.intent.chargeId, amount: j.amount ?? row?.intent.amount, effect: w.effectId(j.requestId) }; });
}
export function truth(movements: any[], emitted: Emitted[], charges: Record<string, string>, journals: { lines: any[] }[]): string[] {
  const problems: string[] = [];
  const perKey: Record<string, number> = {};
  for (const m of movements) perKey[m.key] = (perKey[m.key] ?? 0) + 1;
  for (const [k, n] of Object.entries(perKey)) if (n > 1) problems.push("T1 key " + k.slice(0, 16) + " moved money " + n + " times");
  for (const [e, n] of Object.entries(effectMoves(movements))) if (n > 1) problems.push("T2 effect " + e.slice(-40) + " moved money " + n + " times");
  for (const [c, amt] of Object.entries(charges)) {
    const t = movements.filter(m => m.chargeId === c).reduce((x, m) => x + BigInt(m.amount), 0n);
    if (t > BigInt(amt)) problems.push("T3 charge " + c + " moved " + t + " > " + amt);
  }
  for (const e of emitted) {
    if (e.amount === "0") continue;
    const ok = movements.filter(m => m.key === e.key && m.chargeId === e.chargeId && m.amount === e.amount);
    if (ok.length !== 1) problems.push("T4 reported paid: " + e.chargeId + "/" + e.requestId.slice(0, 20) + " " + e.amount +
      "; provider movements for that key: " + JSON.stringify(movements.filter(m => m.key === e.key).map(m => m.chargeId + ":" + m.amount)));
  }
  for (const { lines } of journals) {
    for (const j of lines) {
      const o = String(j.outcome);
      if (o === "paid" || o === "replayed") {
        const m = movements.find(x => x.refundId === j.refundId);
        if (m === undefined || effectOf(m.refundId) !== j.effect || m.chargeId !== j.chargeId || m.amount !== j.amount)
          problems.push("T5 journal says " + o + " for " + j.chargeId + "/" + j.requestId + " " + j.amount + "; provider movement " +
            JSON.stringify(m ? { ...m, effect: effectOf(m.refundId).slice(-30) } : null));
      } else if (o.startsWith("refused:") && o !== "refused:inconsistent-effect") {
        if (movements.some(x => effectOf(x.refundId) === j.effect)) problems.push("T5 journal says " + o + " for " + j.requestId + " but money moved for that effect");
      }
    }
  }
  return problems;
}
export function verdict(label: string, problems: string[], detail: unknown): never {
  console.log(JSON.stringify(detail));
  console.log(label + " adapter=" + ADAPTER + " env=" + JSON.stringify(Object.fromEntries(Object.entries(process.env).filter(([k]) => k.startsWith("P_")))));
  if (problems.length > 0) { console.log("NOT STOPPED: " + problems.join(" ; ")); process.exit(1); }
  console.log("SAFE"); process.exit(0);
}
export function root(): string {
  const r = process.argv[2];
  if (!r) { console.error("usage: p3_<name>.ts <treeRoot> [case]"); process.exit(4); }
  return r;
}
