// a1_retry_restore.ts <treeRoot> <issuer.cjs> <mode>
// C-ATT-19 variant: a LONE ledger restore (witness current) of a backup taken BETWEEN an operator's
// resolveInDoubt(retry) and the re-claim run. The witness keeps only {n=maxN, rowHead}; a re-claim keeps n and rowHead,
// so the witness and cfg.ledgerFloor both match the older ledger. The slot is "retry" again -> the next run emits AGAIN.
// mode "attack": restore the ledger only; "floor": also pass ledgerFloor = ledgerHead of the run that sent it;
// "control": no restore. Exit 1 = some request id emitted twice (defect), 0 = safe.
import { copyFileSync } from "node:fs";
import { join } from "node:path";
// h-sink3 copy: the d_lib import was the absolute path of C's fix-f08a21c1 extraction; now the tree under test (H3_ROOT)
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { argv, dups, guard, total, verdict, world } = require(process.env.H3_ROOT + "/tests/refund-finality/regress/d_lib");
const mode = process.argv[4] ?? "attack";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_a1", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "600"); w.commit(t1.text);
  const log: string[] = [];
  try { w.flush(e => { if (e.requestId === "r1") throw new Error("adapter: connection refused (nothing sent)"); w.effects.push(e); }); } catch (e) { log.push("run1 threw: " + (e as Error).message); }
  w.dispatcher().resolveInDoubt("r1", "retry", "receiver has no r1");      // honest operator: receiver has nothing
  const bk = join(w.dir, "ledger.backup"); copyFileSync(w.ledger, bk);       // nightly backup of the ledger file only
  const r2 = w.flush(); log.push("run2 emitted " + JSON.stringify(r2.emitted.map((e: any) => e.requestId)) + " head " + JSON.stringify(r2.ledgerHead));
  if (mode !== "control") { copyFileSync(bk, w.ledger); log.push("ledger restored from backup (witness untouched)"); }
  let r3: any;
  try { r3 = w.flush(undefined, w.ledger, mode === "floor" ? { ...w.dcfg, ledgerFloor: r2.ledgerHead } : w.dcfg); log.push("run3 emitted " + JSON.stringify(r3.emitted.map((e: any) => e.requestId))); }
  catch (e) { log.push("run3 stopped: " + (e as Error).message.slice(0, 200)); }
  w.stop();
  const ids = w.effects.map(e => e.requestId);
  verdict(dups(ids).length === 0 && total(w.effects) <= 1000, { mode, log, effects: ids, total: total(w.effects) });
})());
