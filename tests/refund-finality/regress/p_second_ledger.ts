// Provider-anchor regression for C-HOST-05 (orch-C/c11-host/h7_relative_ledger.sh): a second dispatcher ledger for the same
// database (a relative ledger path started from another working directory). Case 1: the plain config (the h1 rule and the
// witness). Case 2: the config also carries newLedgerH0 = the store's h_0 (C-ATT-28: an operator who once declared a new
// ledger and left the field in place). At 370ff65c the dispatch witness binds the store to the first ledger and stops both
// cases ("CONTROL DOES NOT BITE" for mode c, anchor none). The biting C-ATT-28 form (ledger AND witness lost) is
// p_att28_new_ledger.ts. Usage and exit codes: p_lib.ts.
import { join } from "node:path";
import { argv, attackVerdict, guard, moneyCheck, setupFail, world } from "./p_lib";
guard(() => {
  const { root, mode, anchor } = argv();
  const S0 = { chargeId: "ch_ps", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, anchor, S0);
  const r1 = w.refund("r1", "400"); const r2 = w.refund("r2", "500");
  const fA = w.flush();
  const setup = r1.status === "committed" && r2.status === "committed" && fA.error === "" && fA.emitted.length === 2;
  if (!setup) setupFail({ r1, r2, fA });
  w.atAttack();
  const plain = w.flush(join(w.dir, "cwdB-ledger.jsonl"));
  const declared = w.flush(join(w.dir, "cwdC-ledger.jsonl"), { newLedgerH0: w.genesis });
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  attackVerdict(mode, anchor, m.noDouble && m.withinCharge, w.events, { test: "p_second_ledger", plainSecondLedger: plain, declaredNewLedger: declared, money: m });
});
