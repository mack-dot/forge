// C-ATT-26 (FALSE REJECTION): no legitimate commit that encoding.ts allows may be refused by a CHECK. A text of 256 UTF-16
// units of U+0001 escapes to 1538 JSON characters; the h1 bound 2048 on the stored intent refused ids of 200 x U+0001.
// Cases (each: init, commits, restart, first dispatcher run): the red team's inputs (orch-C/c16-hsink/hbound.ts:
// ctrl-both-200, ctrl-both-256) and the MAXIMAL legitimate intent (both ids 256 x U+0001, the longest approved reason
// "service_not_delivered", amount 2^63 - 1 = the whole charge), then a zero-amount refund on remaining 0, then a replay.
// PASS: every commit is "committed" (the replay "replayed"), the restart serves, the dispatcher emits every row.
// Usage: node --import tsx tests/refund-finality/regress/s_att26_long_intent.ts <treeRoot> [<compiledIssuerModule>]
import { join } from "node:path";
import { argv, guard, kit, short, st, tempDir, verdict } from "./s_lib";

guard((() => {
  const { root } = argv();
  const M = "9223372036854775807", C = "\u0001";
  const cases: { name: string; cid: string; steps: [string, string, string][] }[] = [
    { name: "ctrl-both-200", cid: C.repeat(200), steps: [[C.repeat(200), "5", "duplicate_charge"]] },
    { name: "ctrl-both-256", cid: C.repeat(256), steps: [[C.repeat(256), "5", "duplicate_charge"]] },
    { name: "maximal-intent", cid: C.repeat(256), steps: [[C.repeat(256), M, "service_not_delivered"], [C.repeat(255) + "z", "0", "service_not_delivered"]] },
  ];
  const out: any[] = [];
  let pass = true;
  for (const c of cases) {
    const original = c.name === "maximal-intent" ? M : "1000";
    const S0 = st(original, c.cid, original), K = kit(root, S0);
    const dir = tempDir(), db = join(dir, "sink.sqlite"), ledger = join(dir, "ledger.jsonl");
    const r: any = { name: c.name, commits: [] as string[] };
    try {
      const s = K.open(db); if (typeof s === "string") throw new Error(s);
      s.init(S0);
      let pre = S0, first = "";
      for (const [rid, amt, reason] of c.steps) {
        const t = K.tok(pre, rid, amt, reason); if (first === "") first = t;
        const x = s.commit(t); r.commits.push(x.status + (x.reason ? ": " + String(x.reason).slice(0, 100) : ""));
        if (x.status === "committed") pre = K.postOf(t);
        r.intentChars = Math.max(r.intentChars ?? 0, [...K.intentOf(t)].length);
      }
      r.replay = s.commit(first).status;
      s.close();
      const s2 = K.open(db); r.restart = typeof s2 === "string" ? s2 : "serves"; if (typeof s2 !== "string") s2.close();
      const f = K.flush(db, ledger); r.flush = f.alarm ?? { emitted: f.emitted.length, refused: f.refused };
      r.ok = r.commits.every((x: string) => x === "committed") && r.replay === "replayed" && r.restart === "serves" && f.alarm === undefined && f.emitted.length === c.steps.length;
    } catch (e) { r.err = short(e); r.ok = false; }
    if (!r.ok) pass = false;
    out.push(r);
  }
  verdict(pass, out);
})());
