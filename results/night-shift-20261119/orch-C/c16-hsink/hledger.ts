// C-ATT-13 / C-ATT-19 ported to the h1 dispatcher. Usage: hledger.ts <work> <mode>
//   lost-strict : r1 600 dispatched; ledger file lost; the host runs the dispatcher WITHOUT newLedgerH0.
//   lost-policy : same, but the host follows the only rule it can automate: "pass newLedgerH0 when the ledger is
//                 missing or empty" (it cannot tell a first run from a lost ledger). Also = a host that leaves it set.
//   older       : r1 400 dispatched; backup of the ledger; r2 400, r3 100 dispatched; the backup is restored.
// Attacker: none (operator loses or restores the ledger) or a writer of the ledger file. No key; the sink store is intact.
// Exit 1 = total external refunds > original 1000 (defect present); 0 = safe; 3 = harness error.
import { copyFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { setup, out, S0 } from "./h";
const [work, mode] = process.argv.slice(2);
(async () => {
  const h = await setup(work); const L: any = { mode };
  const sink: any = h.open(); sink.init(S0); const st = () => JSON.parse(sink.stateBlob());
  const firstRun = (p?: string) => h.flush({ newLedger: true, ledgerPath: p });
  if (mode === "older") {
    L.c1 = sink.commit(await h.mint(S0, "r1", "400")).status; L.f1 = firstRun();
    copyFileSync(h.ledger, join(work, "ledger.backup"));
    L.c2 = sink.commit(await h.mint(st(), "r2", "400")).status; L.c3 = sink.commit(await h.mint(st(), "r3", "100")).status; L.f2 = h.flush();
    copyFileSync(join(work, "ledger.backup"), h.ledger); L.f3 = h.flush();
  } else {
    L.c1 = sink.commit(await h.mint(S0, "r1", "600")).status; L.f1 = firstRun();
    rmSync(h.ledger);
    L.f2 = mode === "lost-policy" ? firstRun() : h.flush();
  }
  sink.close(); h.stop();
  L.paid = h.paid(); L.effects = h.effects.map((e: any) => e.requestId); out(L);
  process.exit(L.paid > 1000 ? 1 : 0);
})().catch(e => { console.error(String(e && e.stack)); process.exit(3); });
