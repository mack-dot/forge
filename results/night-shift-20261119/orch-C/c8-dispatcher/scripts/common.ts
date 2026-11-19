// c8-dispatcher helper: throwaway minter process (fresh Ed25519 key), sink, dispatcher of the target-v6 checkout.
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
export const ROOT = "<SCRATCH>/redteam-C/target-v6";
export const CORE = "<REPO>/results/night-shift-20261119/orch-B/d-minter/build/issuebytes2.cjs";
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const E = require(join(ROOT, "ts/refund-finality/encoding.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const { Sink } = require(join(ROOT, "ts/refund-finality/sink.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const { Dispatcher } = require(join(ROOT, "ts/refund-finality/dispatcher.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { MinterClient, propose } = require(join(ROOT, "ts/refund-finality/proposer.ts"));
export const S0 = { chargeId: "ch_c8", original: "1000", remaining: "1000", refundEnabled: true };
export async function startMinter(singleUse: "on" | "off" = "off") {
  const m = await MinterClient.start(ROOT, CORE, join(ROOT, "spec/refund/spec.lock"), singleUse);
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const mint = async (pre: any, rid: string, amount: string): Promise<string> => {
    const a = await m.mint(pre, propose(pre, { requestId: rid, amount, reason: "duplicate_charge" }));
    if (!a.ok) throw new Error("mint refused: " + a.reason); return E.tokenText(a.token);
  };
  return { m, ids, mint };
}
export function world(work: string, ids: any) {
  rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const db = join(work, "sink.sqlite"), ledger = join(work, "dispatch-ledger.jsonl");
  const cfg = { ...ids, initialState: S0 };
  const dcfg = { ...ids, initialStateSha256: E.stateSha256(S0) };
  writeFileSync(join(work, "dcfg.json"), JSON.stringify(dcfg));
  const effects: any[] = [];
  const flush = (emit?: (e: any, i: any) => void, ledgerPath = ledger) =>
    new Dispatcher(db, ledgerPath, dcfg, emit ?? ((e: any) => effects.push(e))).flush();
  const sink = new Sink(db, cfg); sink.init(S0);
  return { db, ledger, cfg, dcfg, effects, flush, sink, state: () => JSON.parse(sink.stateBlob()) };
}
export const sum = (effects: any[]) => effects.reduce((s, e) => s + Number(JSON.parse(e.intent).amount), 0);
