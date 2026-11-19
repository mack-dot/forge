// c16 hbound: LEGITIMATE boundary refunds through the REAL h1 sink API (honest minter, memory off): init, commit,
// restart, first dispatcher run. Every case is valid by encoding.ts (text: <= 256 UTF-16 units, no U+0000, no lone
// surrogate) and by the spec (AllowedReason, 0 <= amount <= remaining <= original <= MaxMoney = 2^63-1).
// Usage: hbound.ts <work> [case]   Exit 1 = a legitimate refund is refused somewhere (FALSE REJECTION); 0 = all pass.
import { join } from "node:path";
import { setup, out } from "./h";
const [work, only] = process.argv.slice(2);
const M = "9223372036854775807";
const C1 = "\u0001";
type Case = { name: string; s0: any; steps: [string, string][] };   // [requestId, amount]
const st = (c: string, o: string, r: string) => ({ chargeId: c, original: o, remaining: r, refundEnabled: true });
const cases: Case[] = [
  { name: "plain", s0: st("ch_b", "1000", "1000"), steps: [["r1", "100"]] },
  { name: "maxmoney-full", s0: st("ch_m", M, M), steps: [["r1", M]] },
  { name: "maxmoney-1-then-rest", s0: st("ch_m", M, M), steps: [["r1", "1"], ["r2", "9223372036854775806"], ["r3", "0"]] },
  { name: "zero-at-remaining-0", s0: st("ch_z", "500", "0"), steps: [["r1", "0"], ["r2", "0"]] },
  { name: "amount-eq-remaining", s0: st("ch_e", "1000", "400"), steps: [["r1", "400"]] },
  { name: "astral-256-units", s0: st("ch_a", "1000", "1000"), steps: [["\u{1F600}".repeat(128), "1"]] },
  { name: "short-escapes", s0: st("ch_\b\f\n\r\t\"\\/", "1000", "1000"), steps: [["r\b\f\n\r\t\"\\/\u007f  ﻿", "1"]] },
  { name: "dots-dollar-brackets", s0: st("$.a[0]", "1000", "1000"), steps: [["$.body.requestId", "1"], ["a.b[\"c\"]", "2"]] },
  { name: "ctrl-chargeId-256", s0: st(C1.repeat(256), "1000", "1000"), steps: [["r1", "5"]] },
  { name: "ctrl-requestId-256", s0: st("ch_c", "1000", "1000"), steps: [[C1.repeat(256), "5"]] },
  { name: "ctrl-both-200", s0: st(C1.repeat(200), "1000", "1000"), steps: [[C1.repeat(200), "5"]] },
  { name: "ctrl-both-256", s0: st(C1.repeat(256), "1000", "1000"), steps: [[C1.repeat(256), "5"]] },
];
(async () => {
  const res: any[] = []; let bad = 0;
  for (const c of cases) {
    if (only && c.name !== only) continue;
    const h = await setup(join(work, c.name), c.s0); const r: any = { name: c.name };
    try {
      const s: any = h.open(); if (typeof s === "string") throw new Error("open: " + s);
      try { s.init(c.s0); r.init = "ok"; } catch (e) { r.init = "REFUSED " + String((e as Error).message).slice(0, 160); }
      r.commits = [];
      for (const [rid, amt] of c.steps) {
        let v: any; try { v = s.commit(await h.mint(JSON.parse(s.stateBlob()), rid, amt)); } catch (e) { v = { status: "ERR", reason: String((e as Error).message).slice(0, 160) }; }
        r.commits.push(v.status + (v.reason ? ": " + String(v.reason).slice(0, 160) : ""));
      }
      s.close();
      const s2: any = h.open(); r.restart = typeof s2 === "string" ? s2 : "serves"; if (typeof s2 !== "string") s2.close();
      const f: any = h.flush({ newLedger: true }); r.flush = f.alarm ?? { emitted: f.emitted.length, refused: f.refused };
      const ok = r.init === "ok" && r.commits.every((x: string) => x === "committed") && r.restart === "serves" && !f.alarm && f.emitted.length === c.steps.length;
      r.ok = ok; if (!ok) bad++;
    } catch (e) { r.err = String((e as Error).message).slice(0, 200); bad++; }
    h.stop(); res.push(r); out(r);
  }
  out({ cases: res.length, falseRejections: bad });
  process.exit(bad > 0 ? 1 : 0);
})().catch(e => { console.error(String(e && e.stack)); process.exit(3); });
