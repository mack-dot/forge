// C-ATT-25 re-attack on 88ae6cbf: the dispatcher's cfg.expectedHead. Attacker: database writer without the key.
// History: r1 600 (dispatched), z 0 (dispatched), r2 100 committed NOT dispatched; alt r2b 300 signed on r2's pre-state.
// Usage: a25_anchor.ts <work> <mode>
//  d14-none   : swap r2 -> r2b, chain recomputed; dispatcher WITHOUT expectedHead (B: stated limit).
//  d14-head   : same; dispatcher expectedHead = committed head (count 3).
//  d14-stale  : same; dispatcher expectedHead = stale head (count 2): row 3 must stay beyond.
//  boundary   : swap at exactly the anchor row (anchor count 3 = the swapped row).
//  stale-eq   : a further commit r3 (count 4) by the sink; the writer rolls the store back to count 2 (deletes r2, r3) and
//               appends r2b (so head count 3 != anchor); dispatcher anchor = count 2 (stale, equal to the rollback base).
//  stale-roll : the writer rolls back to EXACTLY the stale anchor (count 2: r2 deleted); then appends nothing. Anchor
//               count 2. Then the host's sink (outsideHead committed count 3) restarts: must refuse.
//  midrun     : writer swaps r2 -> r2b DURING the dispatcher's emit of an earlier row (per-row vs once check).
// Exit 1 = an uncommitted transition (r2b) is emitted, or a committed one is emitted beyond the anchor (defect); 0 = safe.
import { kit, hostile, swapRow, delRow, out, st, ids, E, Dispatcher } from "./lib";
import { DatabaseSync } from "node:sqlite";
const [work, mode] = process.argv.slice(2);
const K = kit(work);
const L: any = { mode };
const sink: any = K.open(); sink.init(K.cfg.initialState);
L.c1 = sink.commit(K.tok(st(sink), "r1", "600")).status;
L.f1 = K.flush({ newLedgerH0: K.h0 });
L.c2 = sink.commit(K.tok(st(sink), "z", "0")).status;
L.f2 = K.flush();
const stale = sink.head();
const pre3 = st(sink);
const r2 = K.tok(pre3, "r2", "100"), r2b = K.tok(pre3, "r2b", "300");
L.c3 = sink.commit(r2).status;
const head = sink.head();
let anchor: any = head;
if (mode === "d14-none") anchor = undefined;
if (mode === "d14-stale") anchor = stale;
if (mode === "midrun") {
  // r2 not yet dispatched; one more honest commit so that a dispatcher run emits r2 first, then the swap targets r3.
  const pre4 = st(sink); const r3 = K.tok(pre4, "r3", "50"), r3b = K.tok(pre4, "r3b", "350");
  L.c4 = sink.commit(r3).status; anchor = sink.head(); sink.close();
  let swapped = "";
  const effects: any[] = [];
  const d = new Dispatcher(K.db, K.ledger, { ...K.dcfg, expectedHead: anchor }, (e: any) => {
    effects.push(e);
    if (swapped === "") swapped = hostile(K.db, swapRow("r3", r3b), true);   // during the first emit
  });
  try { const f = d.flush(); L.flush = { emitted: f.emitted.map((e: any) => e.requestId), refused: f.refused.map((r: any) => r.requestId + ":" + r.reason.slice(0, 60)) }; } catch (e) { L.flush = String(e); }
  L.swapped = swapped; L.effects = effects.map(e => e.requestId); L.outbox = ids(K.db);
  L.after = K.flush({ expectedHead: anchor });
  const defect = effects.some(e => e.requestId === "r3b") || K.effects.some((e: any) => e.requestId === "r3b");
  L.defect = defect; out(L); process.exit(defect ? 1 : 0);
}
sink.close();
let applied = "";
if (mode.startsWith("d14") || mode === "boundary") applied = hostile(K.db, swapRow("r2", r2b), true);
if (mode === "stale-eq") {
  const s2: any = K.open(); L.c4 = s2.commit(K.tok(st(s2), "r3", "50")).status; s2.close();
  applied = hostile(K.db, d => { delRow("r3")(d); delRow("r2")(d);
    const b = JSON.parse(r2b).body;
    d.prepare("INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (3, ?, ?, ?, ?, ?)").run("r2b", r2b, "0".repeat(64), "0".repeat(64), "0".repeat(64));
    d.prepare("INSERT INTO outbox(seq, request_id, intent, prev, self) VALUES (3, ?, ?, ?, ?)").run("r2b", E.canon(b.intent), "0".repeat(64), "0".repeat(64));
  }, true);
  anchor = stale;
}
if (mode === "stale-roll") { applied = hostile(K.db, delRow("r2"), true); anchor = stale; }
L.applied = applied; L.outbox = ids(K.db); L.anchor = anchor ? anchor.count : "none";
L.flush = K.flush(anchor ? { expectedHead: anchor } : {});
L.effects = K.effects.map((e: any) => e.requestId); L.paid = K.paid();
if (mode === "stale-roll" || mode === "stale-eq") {
  const s = K.open({ outsideHead: { committed: head } }); L.sinkRestartOutside = typeof s === "string" ? s.slice(0, 160) : "serves"; if (typeof s !== "string") s.close();
}
const defect = K.effects.some((e: any) => e.requestId === "r2b");
L.defect = defect; out(L);
process.exit(defect ? 1 : 0);
