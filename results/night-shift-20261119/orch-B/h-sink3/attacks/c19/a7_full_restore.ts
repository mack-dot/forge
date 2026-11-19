// a7_full_restore.ts <root> <issuer.cjs> <mode: nofloor|floor>
// C-ATT-19, the variant B leaves open: the WHOLE folder (store, ledger, dispatch witness) is restored from a backup taken
// after r1; the host retries r2 with the same token (the sink commits it again: no sink anchor). nofloor: no outside
// anchor. floor: cfg.ledgerFloor = the ledgerHead of the run that sent r2. Exit 1 = r2 emitted twice.
import { copyFileSync, existsSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { join } from "node:path";
// h-sink3 copy: the d_lib import was the absolute path of C's fix-f08a21c1 extraction; now the tree under test (H3_ROOT)
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { argv, dups, guard, total, verdict, world } = require(process.env.H3_ROOT + "/tests/refund-finality/regress/d_lib");
const mode = process.argv[4] ?? "nofloor";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_a7", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "300"); w.commit(t1.text); w.flush(); w.closeSink();
  const bk = join(w.dir, "bk"); mkdirSync(bk);
  const files = () => readdirSync(w.dir).filter(f => f !== "bk" && !/-(wal|shm|journal)$/.test(f) && !f.endsWith(".lock"));
  for (const f of files()) copyFileSync(join(w.dir, f), join(bk, f));
  w.reopen(); const t2 = await w.mint(t1.post, "r2", "600"); w.commit(t2.text);
  const r = w.flush(); w.closeSink();
  for (const f of files()) if (!existsSync(join(bk, f))) rmSync(join(w.dir, f));
  for (const f of readdirSync(bk)) copyFileSync(join(bk, f), join(w.dir, f));
  w.reopen(); const again = w.commit(t2.text);
  let last = ""; try { last = JSON.stringify(w.flush(undefined, w.ledger, mode === "floor" ? { ...w.dcfg, ledgerFloor: r.ledgerHead } : w.dcfg).emitted); } catch (e) { last = "stopped: " + (e as Error).message.slice(0, 120); }
  w.stop();
  const ids = w.effects.map(e => e.requestId);
  verdict(dups(ids).length === 0 && total(w.effects) <= 1000, { mode, recommit: again, last, effects: ids, total: total(w.effects) });
})());
