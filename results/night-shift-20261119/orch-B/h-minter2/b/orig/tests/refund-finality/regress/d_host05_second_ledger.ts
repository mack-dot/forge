// Regression C-HOST-05 (a second ledger for one store: 2000 on 1000; attacker: none). r1 and r2 commit and are
// dispatched with ledger A. A later run names ANOTHER ledger file B for the same store (for example a relative path
// resolved from another working directory), with cfg.newLedgerH0 still set (as a host keeps its configuration).
// SAFE: no request id is emitted twice; the total is at most 1000. FAILS on the unfixed dispatcher (the second ledger
// sends r1 and r2 again). Usage and exit codes: d_lib.ts.
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { argv, dups, guard, total, verdict, world } from "./d_lib";
guard((async () => {
  const { root, core } = argv();
  const S0 = { chargeId: "ch_dh05", original: "1000", remaining: "1000", refundEnabled: true };
  const w = await world(root, core, S0);
  const t1 = await w.mint(S0, "r1", "400"); w.commit(t1.text);
  const t2 = await w.mint(t1.post, "r2", "600"); w.commit(t2.text);
  const first = w.flush();
  mkdirSync(join(w.dir, "other"));
  let second = "";
  try { second = JSON.stringify(w.flush(undefined, join(w.dir, "other", "ledger.jsonl"))); } catch (e) { second = "stopped: " + (e as Error).message; }
  w.stop();
  const ids = w.effects.map(e => e.requestId);
  verdict(first.emitted.length === 2 && dups(ids).length === 0 && total(w.effects) <= 1000, { effects: ids, total: total(w.effects), second: second.slice(0, 200) });
})());
