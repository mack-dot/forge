// C-ATT-28 regression (orch-C/ATTACKS.md; orch-C/c16-hsink/hledger.ts lost-policy): a config that keeps cfg.newLedgerH0 =
// h_0 set on EVERY run (the host cannot tell a first run from a lost ledger). r1 400 and r2 500 committed and dispatched.
// Then <case>:
//   ledger          : the ledger file is lost (deleted); the dispatch witness stays. A later run with an empty ledger.
//   ledger+witness  : the ledger file AND the dispatch witness are lost (a lost dispatcher folder, or a person who removes
//                     the witness "to bind a new ledger"); the store is intact. A later run with an empty ledger.
// Two dispatcher runs after the loss. Expected: "ledger": the witness stops it; "ledger+witness": nothing local stops it
// without the ledger floor; then only the provider key can. Usage: p_att28_new_ledger.ts <tree> <mode> <anchor> <case>.
import { rmSync } from "node:fs";
import { argv, attackVerdict, guard, moneyCheck, setupFail, world } from "./p_lib";
guard(() => {
  const { root, mode, anchor, rest } = argv();
  const kase = rest[0];
  if (kase !== "ledger" && kase !== "ledger+witness") { console.error("case must be ledger or ledger+witness"); process.exit(4); }
  const S0 = { chargeId: "ch_28", original: "1000", remaining: "1000", refundEnabled: true };
  const w = world(root, mode, anchor, S0, { keepNewLedgerH0: true });
  const r1 = w.refund("r1", "400"); const r2 = w.refund("r2", "500");
  const f1 = w.flush();
  const setup = r1.status === "committed" && r2.status === "committed" && f1.error === "" && f1.emitted.join() === "r1,r2";
  if (!setup) setupFail({ r1, r2, f1 });
  w.atAttack();
  const witness = w.db + ".dispatch-witness.json";
  rmSync(w.ledger, { force: true });
  if (kase === "ledger+witness") rmSync(witness, { force: true });
  const after = [w.flush(), w.flush()];
  const m = moneyCheck(w.provider, S0.chargeId, S0.original); w.stop();
  attackVerdict(mode, anchor, m.noDouble && m.withinCharge, w.events, { test: "p_att28_new_ledger", case: kase, after, money: m });
});
