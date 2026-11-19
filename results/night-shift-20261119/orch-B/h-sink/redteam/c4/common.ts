// c4-rollback helper: throwaway minter process (fresh Ed25519 key), sink, dispatcher of the target-v6 checkout.
// Usage from a script: const h = await setup(workDir); ... h.stop();
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
export const ROOT = "<REPO>/results/night-shift-20261119/orch-B/h-sink/tree";
export const CORE = "<REPO>/results/night-shift-20261119/orch-B/d-minter/build/issuebytes2.cjs";
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const E = require(join(ROOT, "ts/refund-finality/encoding.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const { Sink } = require(join(ROOT, "ts/refund-finality/sink.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const { Dispatcher } = require(join(ROOT, "ts/refund-finality/dispatcher.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { MinterClient, propose } = require(join(ROOT, "ts/refund-finality/proposer.ts"));
export const S0 = { chargeId: "ch_c4", original: "1000", remaining: "1000", refundEnabled: true };

export async function setup(work: string, singleUse: "on" | "off" = "off") {
  rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const m = await MinterClient.start(ROOT, CORE, join(ROOT, "spec/refund/spec.lock"), singleUse);
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const db = join(work, "sink.sqlite"), ledger = join(work, "ledger.jsonl");
  const cfg = { ...ids, initialState: S0 };
  // h-sink adaptation (one line): the hardened dispatcher needs an explicit new-ledger h_0 for a ledger that does not exist yet.
  const dcfg = { ...ids, initialStateSha256: E.stateSha256(S0), newLedgerH0: require(join(ROOT, "ts/refund-finality/sink.ts")).genesisOf(E.canon(S0), ids.specLockSha256, ids.checkerSha256, ids.publicKeyPem) };
  const effects: any[] = [];
  const mint = async (pre: any, rid: string, amount: string): Promise<string> => {
    const a = await m.mint(pre, propose(pre, { requestId: rid, amount, reason: "duplicate_charge" }));
    if (!a.ok) throw new Error("mint refused: " + a.reason); return E.tokenText(a.token);
  };
  // h-sink adaptation: the hardened dispatcher STOPS with a thrown alarm; report it as a refusal of everything (nothing emitted).
  const flush = (ledgerPath = ledger) => { try { return new Dispatcher(db, ledgerPath, dcfg, (e: any) => effects.push(e)).flush(); }
    catch (e) { return { emitted: [], refused: [{ seq: 0, requestId: "*", reason: "ALARM: " + String((e as Error).message).slice(0, 120) }], alreadyDispatched: 0 }; } };
  const paid = () => effects.reduce((s, e) => s + Number(JSON.parse(e.intent).amount), 0);
  return { m, ids, db, ledger, cfg, dcfg, effects, mint, flush, paid, stop: () => m.stop() };
}
