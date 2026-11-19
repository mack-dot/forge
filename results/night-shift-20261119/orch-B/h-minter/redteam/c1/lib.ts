// c1-concurrency helper: paths into the read-only target-v6 checkout; throwaway minter keys only.
import { join } from "node:path";
export const ROOT = "<REPO>/results/night-shift-20261119/orch-B/h-minter/tree-v6";
export const CORE = "<REPO>/results/night-shift-20261119/orch-B/h-minter/build/issueonce.cjs";
export const SPEC = join(ROOT, "spec/refund/spec.lock");
export const EVID = "<REPO>/results/night-shift-20261119/orch-B/h-minter/redteam/c1";
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const E = require(join(ROOT, "ts/refund-finality/encoding.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const { Sink } = require(join(ROOT, "ts/refund-finality/sink.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const { Dispatcher } = require(join(ROOT, "ts/refund-finality/dispatcher.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const { MinterClient, propose } = require(join(ROOT, "ts/refund-finality/proposer.ts"));
export const S0 = { chargeId: "ch_c1", original: "1000", remaining: "1000", refundEnabled: true };
export async function minter(single: "on" | "off") {
  const m = await MinterClient.start(ROOT, CORE, SPEC, single);
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const mint = async (pre: any, rid: string, amount: string): Promise<{ ok: boolean; text?: string; reason?: string }> => {
    const a = await m.mint(pre, propose(pre, { requestId: rid, amount, reason: "duplicate_charge" }));
    return a.ok ? { ok: true, text: E.tokenText(a.token) } : { ok: false, reason: a.reason };
  };
  return { m, ids, mint };
}
