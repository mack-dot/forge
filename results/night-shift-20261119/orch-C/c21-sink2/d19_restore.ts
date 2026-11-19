// C-ATT-19 / C-ATT-28 re-check on 88ae6cbf (dispatcher unchanged from f08a21c1 except expectedHead). Attacker: none (an
// operator restores a backup, or loses files). History: r1 400 committed+dispatched; BACKUP of db, ledger, witness;
// r2 300, r3 200 committed+dispatched (outside committed head = count 3; ledgerHead kept by nobody).
// Usage: d19_restore.ts <work> <mode>
//  lw          : ledger AND witness restored from the backup; store current; dispatcher with expectedHead = fresh head.
//  all         : db, ledger, witness restored; host retries r2, r3 with the SAME tokens on a sink WITHOUT anchor; dispatcher
//                WITH expectedHead = fresh head (the re-committed rows are byte-identical: same head).
//  all-outside : same restore; the host's sink uses cfg.outsideHead = fresh committed head (B's freshness rule).
//  lost-ledger : the ledger file is deleted (witness kept); the host leaves newLedgerH0 set.
//  lost-both   : ledger and witness deleted; newLedgerH0 set.
// Exit 1 = some request id is emitted twice or the total exceeds 1000 (defect); 0 = safe.
import { copyFileSync, existsSync, mkdirSync, rmSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { kit, out, st } from "./lib";
const [work, mode] = process.argv.slice(2);
const K = kit(work);
const L: any = { mode };
const W = K.db + ".dispatch-witness.json";
let s: any = K.open(); s.init(K.cfg.initialState);
L.c1 = s.commit(K.tok(st(s), "r1", "400")).status;
L.f1 = K.flush({ newLedgerH0: K.h0, expectedHead: s.head() });
s.close();
const bk = join(work, "bk"); mkdirSync(bk);
for (const f of [K.db, K.ledger, W]) copyFileSync(f, join(bk, f.split("/").pop()!));
s = K.open();
const t2 = K.tok(st(s), "r2", "300"); L.c2 = s.commit(t2).status;
const t3 = K.tok(st(s), "r3", "200"); L.c3 = s.commit(t3).status;
const fresh = s.head(); s.close();
L.f2 = K.flush({ expectedHead: fresh });
const restore = (files: string[]) => { for (const f of files) copyFileSync(join(bk, f.split("/").pop()!), f); };
if (mode === "lw") { restore([K.ledger, W]); L.f3 = K.flush({ expectedHead: fresh }); }
if (mode === "all" || mode === "all-outside") {
  restore([K.db, K.ledger, W]);
  const a: any = mode === "all" ? K.open() : K.open({ outsideHead: { committed: fresh } });
  L.restart = typeof a === "string" ? a.slice(0, 120) : "serves";
  if (typeof a !== "string") { L.re2 = a.commit(t2).status; L.re3 = a.commit(t3).status; L.sameHead = JSON.stringify(a.head()) === JSON.stringify(fresh); a.close(); }
  L.f3 = K.flush({ expectedHead: fresh });
}
if (mode === "lost-ledger") { unlinkSync(K.ledger); L.f3 = K.flush({ newLedgerH0: K.h0, expectedHead: fresh }); }
if (mode === "lost-both") { unlinkSync(K.ledger); unlinkSync(W); L.f3 = K.flush({ newLedgerH0: K.h0, expectedHead: fresh }); }
const effs = K.effects.map((e: any) => e.requestId);
L.effects = effs; L.paid = K.paid();
const defect = new Set(effs).size !== effs.length || L.paid > 1000;
L.defect = defect; out(L);
process.exit(defect ? 1 : 0);
