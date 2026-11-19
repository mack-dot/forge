// a8_paths.ts <root> <issuer.cjs> <mode>
// The dispatch witness is keyed by the database PATH STRING (realpath + suffix) and stores the ledger path STRING.
// link:  a hard link of the store in another folder + a new ledger; cfg.newLedgerH0 set (as d_lib, suite.ts and B's CLI
//        configs do). Exit 1 = r1 emitted twice (defect; C-HOST-05/C-ATT-28 class through a second database name).
// case:  the SAME ledger file spelled in another letter case (APFS is case-insensitive; Node's realpathSync keeps the case).
// firm:  the SAME ledger file spelled through the /System/Volumes/Data firmlink.
//        For case/firm: exit 1 = the honest second run is refused (false rejection), 0 = it runs (emits r2 once).
import { linkSync, mkdirSync } from "node:fs";
import { join } from "node:path";
// h-sink3 copy: the d_lib import was the absolute path of C's fix-f08a21c1 extraction; now the tree under test (H3_ROOT)
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { argv, dups, guard, verdict, world } = require(process.env.H3_ROOT + "/tests/refund-finality/regress/d_lib");
const mode = process.argv[4] ?? "link";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_a8", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "700"); w.commit(t1.text);
  const r1 = w.flush(); const log: string[] = ["run1 emitted " + r1.emitted.map((e: any) => e.requestId)];
  let second: any = null, err = "";
  if (mode === "link") {
    w.closeSink();
    const d2 = join(w.dir, "other"); mkdirSync(d2); const alias = join(d2, "store.sqlite"); linkSync(w.db, alias);
    try { second = new w.L.Dispatcher(alias, join(d2, "ledger.jsonl"), w.dcfg, (e: any) => w.effects.push(e)).flush(); } catch (e) { err = (e as Error).message; }
  } else {
    const t2 = await w.mint(t1.post, "r2", "200"); w.commit(t2.text);
    const led = mode === "case" ? w.ledger.replace(/ledger\.jsonl$/, "LEDGER.JSONL") : "/System/Volumes/Data" + w.ledger;
    try { second = w.flush(undefined, led); } catch (e) { err = (e as Error).message; }
  }
  log.push("run2 " + (second ? "emitted " + second.emitted.map((e: any) => e.requestId) + " refused " + second.refused.length : "stopped: " + err.slice(0, 160)));
  w.stop();
  const ids = w.effects.map((e: any) => e.requestId);
  const pass = mode === "link" ? dups(ids).length === 0 : (second !== null && ids.filter((x: string) => x === "r2").length === 1);
  verdict(pass, { mode, log, effects: ids });
})());
