// c15-storage helper. Target modules from the read-only target-v6 checkout. Throwaway Ed25519 key (fresh minter process).
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
export const ROOT = "<SCRATCH>/redteam-C/target-v6";
export const CORE = "<REPO>/results/night-shift-20261119/orch-B/d-minter/build/issuebytes2.cjs";
export const EV = "<REPO>/results/night-shift-20261119/orch-C/c15-storage";
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const E = require(join(ROOT, "ts/refund-finality/encoding.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const { Sink } = require(join(ROOT, "ts/refund-finality/sink.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const { Dispatcher } = require(join(ROOT, "ts/refund-finality/dispatcher.ts"));
export const S0 = { chargeId: "ch_c15", original: "1000", remaining: "1000", refundEnabled: true };
export type Fixture = { cfg: any; dcfg: any; tokens: { rid: string; amount: string; text: string }[] };
// A chain of tokens r1..rN (each on the post-state of the previous one); amounts given. Cached in fixture.json.
export async function fixture(amounts = ["100", "200", "0", "150", "50", "0", "100"]): Promise<Fixture> {
  const f = join(EV, "fixture.json");
  if (existsSync(f)) { const x = JSON.parse(readFileSync(f, "utf8")); if (x.tokens.length === amounts.length) return x; }
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { MinterClient, propose } = require(join(ROOT, "ts/refund-finality/proposer.ts"));
  const m = await MinterClient.start(ROOT, CORE, join(ROOT, "spec/refund/spec.lock"), "off");
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const tokens: Fixture["tokens"] = []; let pre: any = S0;
  for (let i = 0; i < amounts.length; i++) {
    const rid = "r" + (i + 1);
    const a = await m.mint(pre, propose(pre, { requestId: rid, amount: amounts[i], reason: "duplicate_charge" }));
    if (!a.ok) throw new Error("mint refused: " + a.reason);
    tokens.push({ rid, amount: amounts[i], text: E.tokenText(a.token) }); pre = a.token.body.post;
  }
  m.stop();
  const x = { cfg: { ...ids, initialState: S0 }, dcfg: { ...ids, initialStateSha256: E.stateSha256(S0) }, tokens };
  writeFileSync(f, JSON.stringify(x)); return x;
}
export function fresh(dir: string) { rmSync(dir, { recursive: true, force: true }); mkdirSync(dir, { recursive: true }); }
export function openSink(path: string, fx: Fixture) { return new Sink(path, fx.cfg); }
export function tryOpen(path: string, fx: Fixture): { sink: any; err: string | null } {
  try { return { sink: new Sink(path, fx.cfg), err: null }; } catch (e) { return { sink: null, err: String((e as Error).message) }; }
}
export function settledIds(s: any): string[] { return s.settled().map((r: any) => r.request_id); }
