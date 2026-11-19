// C-ATT-23 re-attack on 88ae6cbf: hard links and a REPLACED inode (copy, edit, rename over the path).
// Attacker: a party that can create/rename files in the database directory and write its own copy (DIR-EXCLUSIVE broken)
// = class c file writer. History: r1 600, z 0, r2 100 committed (r1, z dispatched).
// Usage: a23_inode.ts <work> <mode>
//  hardlink   : a second hard link exists; sink start and dispatcher must refuse. Exit 1 if either serves.
//  swap-run   : while the sink runs, the writer copies the file, deletes zero row z in the COPY (chain recomputed), and
//               renames the copy over the path. Sink's next commit; dispatcher (no anchor / with expectedHead). Exit 1 if
//               the running sink commits into either inode after the swap.
//  swap-commit: the swap happens INSIDE a commit (between the sink's per-write file check and its COMMIT; made
//               deterministic with the host's onHead hook, standing in for a slow outside-head store). The commit is
//               acknowledged; then the sink keeps running. Exit 1 if an ACKNOWLEDGED commit is missing from the file at the
//               path while the sink reports no problem at acknowledgement time; reports restarts with and without anchor.
import { copyFileSync, linkSync, renameSync } from "node:fs";
import { join } from "node:path";
import { kit, hostile, delRow, out, st, ids } from "./lib";
const [work, mode] = process.argv.slice(2);
const K = kit(work);
const L: any = { mode };
let swapNow = false;
const swap = () => { const cp = join(work, "copy.sqlite"); copyFileSync(K.db, cp); L.copyEdit = hostile(cp, delRow("z"), true); renameSync(cp, K.db); };
const sink: any = K.open({ onHead: () => { if (swapNow) { swapNow = false; swap(); L.swappedInOnHead = true; } } });
sink.init(K.cfg.initialState);
L.c1 = sink.commit(K.tok(st(sink), "r1", "600")).status;
L.f1 = K.flush({ newLedgerH0: K.h0 });
L.c2 = sink.commit(K.tok(st(sink), "z", "0")).status; L.f2 = K.flush();
L.c3 = sink.commit(K.tok(st(sink), "r2", "100")).status; const head3 = sink.head();
let defect = false;
if (mode === "hardlink") {
  sink.close(); linkSync(K.db, join(work, "second-name.sqlite"));
  const a: any = K.open(); L.start = typeof a === "string" ? a.slice(0, 120) : "serves"; if (typeof a !== "string") a.close();
  L.flush = K.flush();
  defect = L.start === "serves" || !("alarm" in L.flush);
} else if (mode === "swap-run") {
  swap();
  L.next = sink.commit(K.tok(st(sink), "r3", "50"));
  L.retryZ = sink.commit(K.tok(st(sink), "z", "0"));
  L.flushNoAnchor = K.flush(); L.flushAnchor = K.flush({ expectedHead: head3 });
  L.outbox = ids(K.db); sink.close();
  defect = L.next.status === "committed" || L.retryZ.status === "committed";
} else if (mode === "swap-commit") {
  swapNow = true;
  const r = sink.commit(K.tok(st(sink), "r3", "50")); L.r3 = r;
  L.afterAck = sink.commit(K.tok(st(sink), "r4", "10"));
  sink.close();
  L.outboxAtPath = ids(K.db);
  const a: any = K.open(); L.restartNoAnchor = typeof a === "string" ? a.slice(0, 120) : { head: a.head().count };
  if (typeof a !== "string") { L.retryZOnRestart = a.commit(K.tok(st(a), "z", "0")).status; a.close(); }
  const b: any = K.open({ outsideHead: { committed: r.head ?? head3 } }); L.restartOutside = typeof b === "string" ? b.slice(0, 120) : { head: b.head().count }; if (typeof b !== "string") b.close();
  L.flush = K.flush(); L.effects = K.effects.map((e: any) => e.requestId);
  defect = r.status === "committed" && !L.outboxAtPath.includes("r3");
}
L.defect = defect; out(L);
process.exit(defect ? 1 : 0);
