// c25 S5: the request id is LEGAL for encoding.ts (<= 256 UTF-16 units, no U+0000, no lone surrogate; "" allowed) but
// is not a usable idempotency key at a real provider (header value: printable ASCII, a length limit such as 255,
// an empty value = no key). usage: s5_keytext.ts <tree> <long|nonascii|ctrl|prefix|empty>   Attacker: none (honest ids).
//   long:     id of 256 ASCII chars; then r_next 100.     nonascii: id "remboursé-1"; then r_next.   ctrl: id "a\u0001b".
//   prefix:   two ids of 256 chars sharing the first 255 (RP_KEYPOLICY=truncate: a client that cuts the key).
//   empty:    id "" (RP_EMPTYKEY=nokey); the dispatcher's first send "times out after money", the adapter retries once.
// Exit 1 = money wrong (clib.ts truth). A legal refund that is never paid and blocks the refunds behind it is printed
// as FALSE REJECTION (exit 0 for money; the rules count a false rejection as a defect: see the printed line).
import { P, emittedOf, truth, verdict, root } from "./clib";
const kase = process.argv[3];
const S0 = { chargeId: "ch_kt", original: "1000", remaining: "1000", refundEnabled: true };
const w = P.world(root, "a", "none", S0, { retries: 1 });
const ids: Record<string, string[]> = { long: ["x".repeat(256), "r_next"], nonascii: ["remboursé-1", "r_next"], ctrl: ["a\u0001b", "r_next"],
  prefix: ["p".repeat(255) + "1", "p".repeat(255) + "2"], empty: ["", "r_next"] };
if (!ids[kase]) { console.error("usage"); process.exit(4); }
const [i1, i2] = ids[kase];
const c1 = w.refund(i1, "300");
if (kase === "empty") w.provider.inject("", "timeout_after_money");
const f1 = w.flush();
const c2 = w.refund(i2, "100"); const f2 = w.flush();
const em = [...emittedOf(w, f1), ...emittedOf(w, f2)];
const keyOf = (id: string) => (process.env.RP_KEYPOLICY === "truncate" ? id.slice(0, Number(process.env.RP_KEYMAX ?? "255")) : id);
const mv = w.provider.movements();
const committed = [c1.status, c2.status];
const paidIds = new Set(em.map(e => e.requestId));
if (committed.every(s => s === "committed") && (!paidIds.has(i1) || !paidIds.has(i2)))
  console.log("FALSE REJECTION: legal committed refund(s) not paid: " + [i1, i2].filter(i => !paidIds.has(i)).map(i => JSON.stringify(i.slice(0, 12)) + "(len " + i.length + ")").join(", ") +
    "; f1.error=" + f1.error + "; f2.refused=" + JSON.stringify(f2.refused));
const p = truth(mv, em, { ch_kt: "1000" }, kase === "empty" ? (id: string) => mv.find((m: any) => m.key.startsWith("<nokey>"))?.key ?? id : keyOf);
if (kase === "empty") { const n = mv.filter((m: any) => m.key.startsWith("<nokey>")).length; if (n > 1) p.push("empty key: " + n + " movements for one refund"); }
verdict("s5 " + kase, p, { committed, f1, f2, movements: mv.map((m: any) => m.key.slice(0, 12) + ":" + m.amount) });
