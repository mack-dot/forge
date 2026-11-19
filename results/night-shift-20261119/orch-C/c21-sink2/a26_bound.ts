// C-ATT-26 re-check on 88ae6cbf: legal refunds with the LONGEST legal texts must COMMIT and DISPATCH (no false rejection).
// Each case: a fresh store whose initial charge id is `cid`; one token (requestId `rid`, amount, reason) signed with a
// throwaway key; commit; a replay; dispatch (new ledger); the emitted intent must be the signed intent; restart serves.
// Usage: a26_bound.ts <work>. Exit 1 = some legal case is refused or not dispatched (false rejection); 0 = all pass.
import { join } from "node:path";
import { kit, out, short, E } from "./lib";
const [work] = process.argv.slice(2);
const MAX = "9223372036854775807";
const rep = (c: string) => c.repeat(Math.floor(256 / c.length));
const cases: { name: string; cid: string; rid: string; reason: string; amount: string; original: string }[] = [];
cases.push({ name: "U+0001 x256 both, longest reason, 19-digit amount", cid: rep("\u0001"), rid: rep("\u0001"), reason: "service_not_delivered", amount: MAX, original: MAX });
cases.push({ name: "U+0001 x256 both, zero amount", cid: rep("\u0001"), rid: rep("\u0001"), reason: "service_not_delivered", amount: "0", original: MAX });
cases.push({ name: "astral x128 both", cid: rep("\u{1F600}"), rid: rep("\u{10FFFF}"), reason: "service_not_delivered", amount: MAX, original: MAX });
cases.push({ name: "mixed U+0001/astral", cid: rep("\u0001\u{1F600}"), rid: rep("\u{1F600}\u0001"), reason: "returned_item", amount: "1", original: MAX });
for (let c = 1; c < 0x20; c++) cases.push({ name: "ctrl U+" + c.toString(16).padStart(4, "0"), cid: rep(String.fromCharCode(c)), rid: rep(String.fromCharCode(c)), reason: "service_not_delivered", amount: MAX, original: MAX });
for (const ch of ["\u007f", "\u0085", " ", " ", "\"", "\\", "/", "￿", "﻿", "￾", "é", "'", "%", "_", "*", "[", "?"])
  cases.push({ name: "char " + JSON.stringify(ch), cid: rep(ch), rid: rep(ch), reason: "duplicate_charge", amount: MAX, original: MAX });
const bad: any[] = [];
let ok = 0;
cases.forEach((c, i) => {
  const s0 = { chargeId: c.cid, original: c.original, remaining: c.original, refundEnabled: true };
  const K = kit(join(work, "c" + i), s0);
  const r: any = { name: c.name };
  try {
    const sink: any = K.open();
    if (typeof sink === "string") { r.open = sink; bad.push(r); return; }
    sink.init(s0);
    const t = K.tok(s0, c.rid, c.amount, c.reason);
    r.tokenLen = t.length; r.intentLen = E.canon(JSON.parse(t).body.intent).length;
    r.commit = sink.commit(t).status; r.replay = sink.commit(t).status; sink.close();
    r.flush = K.flush({ newLedgerH0: K.h0 });
    const em = K.effects[0];
    r.emittedOk = K.effects.length === 1 && em.intent === E.canon(JSON.parse(t).body.intent) && em.requestId === c.rid;
    const re: any = K.open(); r.restart = typeof re === "string" ? re : "serves"; if (typeof re !== "string") re.close();
    if (r.commit === "committed" && r.replay === "replayed" && r.emittedOk && r.restart === "serves") ok++; else bad.push(r);
  } catch (e) { r.err = short(e); bad.push(r); }
});
out({ cases: cases.length, ok, bad: bad.slice(0, 6) });
process.exit(bad.length === 0 ? 0 : 1);
