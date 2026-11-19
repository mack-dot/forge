// COPY of orch-C/c25-provider/clib.ts (h-provider3). ONE adaptation: an emitted refund carries the key that the adapter of the
// tree sends for it (w.keyOf(id, amount) when the tree has it; else the bare request id, as before); truth() compares with
// that key. The checks themselves are unchanged.
// c25-provider shared helper: install realprov.ts, then load B's p_lib (unchanged) and give a TRUTH check.
// TRUTH (stricter than B's moneyCheck): for every refund that a dispatcher run reported EMITTED (= the system says it
// left), the provider must hold exactly one movement with that request id's key, on that charge, of that amount; no key
// moves money twice; per charge the money moved <= the charge. Zero amounts: no movement expected.
// Exit 1 = money wrong (paid twice, paid above the original, or reported paid but not paid as booked). 0 = money right.
import { resolve } from "node:path";
import { rmSync } from "node:fs";
if (process.env.RP_SHARED) rmSync(process.env.RP_SHARED, { force: true });   // a fresh shared account per run
import { install } from "./realprov";
export const root = resolve(process.argv[2]);
install(root);
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const P = require(resolve(root, "tests/refund-finality/regress/p_lib.ts"));
export type Emitted = { chargeId: string; requestId: string; amount: string; key: string };
export function emittedOf(w: any, f: { emitted: string[] }): Emitted[] {
  const rows = w.outboxIntents();
  return f.emitted.map((id: string) => { const r = rows.find((x: any) => x.requestId === id); return { chargeId: r.intent.chargeId, requestId: id, amount: r.intent.amount, key: typeof w.keyOf === "function" ? w.keyOf(id, r.intent.amount) : id }; });
}
export function truth(movements: any[], emitted: Emitted[], charges: Record<string, string>, keyOf = (id: string, e?: Emitted) => e?.key ?? id) {
  const problems: string[] = [];
  const perKey: Record<string, number> = {};
  for (const m of movements) perKey[m.key] = (perKey[m.key] ?? 0) + 1;
  for (const [k, n] of Object.entries(perKey)) if (n > 1) problems.push("key " + k + " moved money " + n + " times");
  for (const [c, amt] of Object.entries(charges)) {
    const t = movements.filter(m => m.chargeId === c).reduce((x, m) => x + BigInt(m.amount), 0n);
    if (t > BigInt(amt)) problems.push("charge " + c + " moved " + t + " > " + amt);
  }
  for (const e of emitted) {
    if (e.amount === "0") continue;
    const ok = movements.filter(m => m.key === keyOf(e.requestId, e) && m.chargeId === e.chargeId && m.amount === e.amount);
    if (ok.length !== 1) problems.push("reported paid: " + e.chargeId + "/" + e.requestId.slice(0, 20) + " " + e.amount + "; provider movements for that key: " +
      JSON.stringify(movements.filter(m => m.key === keyOf(e.requestId, e)).map(m => m.chargeId + ":" + m.amount)));
  }
  return problems;
}
export function verdict(label: string, problems: string[], detail: unknown): never {
  console.log(JSON.stringify(detail));
  console.log(label + " env=" + JSON.stringify(Object.fromEntries(Object.entries(process.env).filter(([k]) => k.startsWith("RP_")))));
  if (problems.length > 0) { console.log("MONEY WRONG: " + problems.join(" ; ")); process.exit(1); }
  console.log("MONEY RIGHT"); process.exit(0);
}
