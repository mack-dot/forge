// Provider-anchor regression for C-HOST-05 (orch-C/c11-host/h7_relative_ledger.sh): a second dispatcher ledger for the
// same database (a relative ledger path started from another working directory). Case 1: the plain config. At e65f9ec8
// the h1 rule stops a NEW empty ledger on a store with committed rows (alarm; nothing sent). Case 2: the config also
// carries newLedgerH0 = the store's h_0 (an operator who once declared a new ledger and left the field in place): the
// second ledger is accepted and every committed refund is emitted again. SAFE: no request id moves money twice and
// money moved <= the charge. Usage and exit codes: p_lib.ts.
import { join } from "node:path";
import { argv, guard, moneyCheck, verdict, world } from "./p_lib";
guard(() => {
  const { root, mode } = argv();
  const S0 = { chargeId: "ch_ps", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, S0);
  const r1 = w.refund("r1", "400"); const r2 = w.refund("r2", "500");
  const fA = w.flush();
  w.atAttack();
  const plain = w.flush(join(w.dir, "cwdB-ledger.jsonl"));
  const declared = w.flush(join(w.dir, "cwdC-ledger.jsonl"), { newLedgerH0: w.genesis });
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  const setup = r1.status === "committed" && r2.status === "committed" && fA.error === "" && fA.emitted.length === 2;
  if (!setup) { console.error(JSON.stringify({ r1, r2, fA })); process.exit(3); }
  verdict(m.noDouble && m.withinCharge, { mode, plainSecondLedger: plain, declaredNewLedger: declared, money: m });
});
