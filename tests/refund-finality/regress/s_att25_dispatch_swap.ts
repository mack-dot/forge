// C-ATT-25 (D14 class): a FILE writer without the key swaps a committed row that the dispatcher ledger has not claimed
// yet (r2, 100) for the other signed transition on the same pre-state (r2b, 300; normal under the per-request minter
// rule) and recomputes the unkeyed chain. The dispatcher's ledger witnesses claimed rows only, so the swap passes it.
// Required: with the outside head (cfg.expectedHead = the sink's committed head, from result.head) the dispatcher sends
// no row that the anchored chain does not contain.
// Cases: anchored  = expectedHead = head after r2 (count 3): r2b must NOT be sent (alarm or refusal; nothing sent).
//        unanchored = expectedHead = head after z (count 2; r2 committed but not yet anchored by the host): the row
//                     after the head (r2b after the swap) must NOT be sent.
//        none       = no expectedHead: INFORMATION only (the stated limit; not part of the verdict).
// Positive controls (no swap): with expectedHead = the current head every committed row is sent once (zero included);
// with expectedHead = an earlier head, only the rows up to it are sent, the others later.
// PASS: anchored and unanchored send no r2b, and the controls hold.
// Usage: node --import tsx tests/refund-finality/regress/s_att25_dispatch_swap.ts <treeRoot> [<compiledIssuerModule>]
import { join } from "node:path";
import { argv, guard, hostile, kit, st, tempDir, verdict } from "./s_lib";

guard((() => {
  const { root } = argv();
  const K = kit(root);
  const out: any = {};
  let pass = true;
  const build = () => {
    const dir = tempDir(), db = join(dir, "sink.sqlite"), ledger = join(dir, "ledger.jsonl");
    const s = K.open(db); if (typeof s === "string") throw new Error(s);
    s.init(K.S0);
    const r1 = s.commit(K.tok(K.S0, "r1", "600")), f1 = K.flush(db, ledger, { expectedHead: r1.head });
    const z = s.commit(K.tok(st("400"), "z", "0")), f2 = K.flush(db, ledger, { expectedHead: z.head });
    const R2 = K.tok(st("400"), "r2", "100"), R2B = K.tok(st("400"), "r2b", "300");
    const r2 = s.commit(R2);
    s.close();
    return { db, ledger, heads: [r1.head, z.head, r2.head], statuses: [r1.status, z.status, r2.status], f: [f1.emitted, f2.emitted], R2B };
  };
  for (const kase of ["anchored", "unanchored", "none"]) {
    const w = build();
    const swap = hostile(w.db, d => {
      d.prepare("UPDATE settled SET request_id = 'r2b', token = ? WHERE request_id = 'r2'").run(w.R2B);
      d.prepare("UPDATE outbox SET request_id = 'r2b', intent = ? WHERE request_id = 'r2'").run(K.intentOf(w.R2B));
    }, { linkOf: K.SK.linkOf, sha: K.E.sha256hex });
    const anchor = kase === "anchored" ? w.heads[2] : kase === "unanchored" ? w.heads[1] : undefined;
    const f = K.flush(w.db, w.ledger, anchor === undefined ? {} : { expectedHead: anchor });
    const sentSwap = f.emitted.includes("r2b");
    const ok = w.statuses.every(x => x === "committed") && w.heads.every(h => h !== undefined) && swap === "ok" && !sentSwap;
    out[kase] = { statuses: w.statuses, headsReturned: w.heads.map(h => h === undefined ? null : h.count), swap, flush: f, ok };
    if (kase !== "none" && !ok) pass = false;
  }
  { // positive controls
    const w = build();
    const all = K.flush(w.db, w.ledger, { expectedHead: w.heads[2] });
    const w2 = build();
    const early = K.flush(w2.db, w2.ledger, { expectedHead: w2.heads[1] }), later = K.flush(w2.db, w2.ledger, { expectedHead: w2.heads[2] });
    const ok = JSON.stringify(w.f) === JSON.stringify([["r1"], ["z"]]) && JSON.stringify(all.emitted) === JSON.stringify(["r2"]) && all.alarm === undefined &&
      early.emitted.length === 0 && early.alarm === undefined && JSON.stringify(later.emitted) === JSON.stringify(["r2"]);
    out.controls = { firstFlushes: w.f, all, early, later, ok };
    if (!ok) pass = false;
  }
  verdict(pass, out);
})());
