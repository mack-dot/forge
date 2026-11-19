// Shared helper of the provider-anchor regressions p_*.ts (night shift 2026-11-19, task h-provider). A TEST, not a proof.
// Usage of every p_*.ts file (pinned Node 24.3.0 first in PATH):
//   node --import tsx tests/refund-finality/regress/p_<name>.ts <treeRoot> <mode>
// <treeRoot>: the checkout whose ts/refund-finality/{sink,dispatcher,encoding}.ts are under test.
// <mode>: the fake provider mode: a | b | c | d-a | d-b (tests/refund-finality/provider/fake_provider.ts).
//   d-a and d-b: the provider forgets a key after RETENTION ticks; the regression advances the clock past it at the
//   moment of the attack (a restore or a delayed retry happens AFTER the window).
// Exit 0: SAFE (no request id moved money twice AND the money moved per charge <= the charge amount AND the
// regression's own conditions). Exit 1: DEFECT. Exit 2: usage. Exit 3: the harness broke.
// Mode c (no idempotency, no ceiling) is the CONTROL: an attack regression must exit 1 in mode c.
// Tokens: a TEST Ed25519 key made in this process signs the body that an honest issuer would sign for the given
// pre-state (the model of tests/refund-finality/regress/harness.ts honest()). No minter process. No network.
import { generateKeyPairSync, sign } from "node:crypto";
import { copyFileSync, existsSync, mkdtempSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { FakeProvider, ProviderMode, MODES, optionsOf } from "../provider/fake_provider";
import { makeEmit } from "../provider/emit_adapter";

export const RETENTION = 24;
export type State = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export function argv(): { root: string; mode: ProviderMode } {
  const [root, mode] = process.argv.slice(2);
  if (!root || !MODES.includes(mode as ProviderMode)) { console.error("usage: p_<name>.ts <treeRoot> a|b|c|d-a|d-b"); process.exit(2); }
  return { root: resolve(root), mode: mode as ProviderMode };
}
const temps: string[] = [];
process.on("exit", () => { for (const d of temps) { try { rmSync(d, { recursive: true, force: true }); } catch { /* best effort */ } } });

/* eslint-disable @typescript-eslint/no-require-imports */
export function world(root: string, mode: ProviderMode, S0: State, opts: { retries?: number } = {}) {
  const E = require(join(root, "ts/refund-finality/encoding.ts"));
  const { Sink, genesisOf } = require(join(root, "ts/refund-finality/sink.ts"));
  const { Dispatcher } = require(join(root, "ts/refund-finality/dispatcher.ts"));
  const dir = mkdtempSync(join(tmpdir(), "forge-p-")); temps.push(dir);
  const keys = generateKeyPairSync("ed25519");
  const ids = { publicKeyPem: keys.publicKey.export({ type: "spki", format: "pem" }) as string,
    specLockSha256: E.sha256hex("h-provider test spec lock"), checkerSha256: E.sha256hex("h-provider test checker") };
  const cfg = { ...ids, initialState: S0 };
  const dcfg: any = { ...ids, initialStateSha256: E.stateSha256(S0) };
  const genesis: string = genesisOf(E.canon(S0), ids.specLockSha256, ids.checkerSha256, ids.publicKeyPem);
  const db = join(dir, "sink.sqlite"), ledger = join(dir, "dispatch-ledger.jsonl"), journalPath = join(dir, "adapter-journal.jsonl");
  const provider = FakeProvider.create(join(dir, "provider-state.json"), optionsOf(mode, RETENTION), { [S0.chargeId]: S0.original });
  let sink = new Sink(db, cfg); sink.init(S0);
  let retries = opts.retries ?? 0;
  const emit = makeEmit(provider, { get retries() { return retries; }, journalPath } as any);
  const token = (pre: State, requestId: string, amount: string, reason = "returned_item"): string => {
    const post = { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
    const body = { domain: E.DOMAIN, ...{ specLockSha256: ids.specLockSha256, checkerSha256: ids.checkerSha256 },
      preStateSha256: E.stateSha256(pre), requestId, post, intent: { chargeId: pre.chargeId, requestId, amount, reason } };
    return E.canon({ body, signature: sign(null, E.signedBytes(body), keys.privateKey).toString("base64") });
  };
  const state = (): State => JSON.parse(sink.stateBlob());
  const commitText = (text: string): string => { try { return String(sink.commit(text).status); } catch (e) { return "threw: " + (e as Error).message; } };
  // An honest refund on the CURRENT stored state (the issuer signs whatever pre-state the store supplies).
  const refund = (requestId: string, amount: string): { text: string; status: string } => {
    const text = token(state(), requestId, amount); return { text, status: commitText(text) };
  };
  // One dispatcher run with the provider adapter. Errors are returned, not thrown. The honest operator declares the
  // FIRST run of the main ledger a new ledger (cfg.newLedgerH0 = h_0, the h1 rule) only while that file is missing or
  // empty; every other run uses the plain config unless the regression passes `extra`.
  const flush = (ledgerPath = ledger, extra: any = {}): { emitted: string[]; error: string } => {
    if (ledgerPath === ledger && (!existsSync(ledger) || statSync(ledger).size === 0) && !("newLedgerH0" in extra)) extra = { newLedgerH0: genesis };
    try {
      const r = new Dispatcher(db, ledgerPath, { ...dcfg, ...extra }, emit).flush();
      return { emitted: r.emitted.map((e: any) => e.requestId), error: "" };
    } catch (e) { return { emitted: [], error: String((e as Error).message).slice(0, 140) }; }
  };
  const files = [db, ledger];
  const backup = (): void => { sink.close(); for (const f of files) if (existsSync(f)) copyFileSync(f, f + ".bak"); sink = new Sink(db, cfg); };
  const restore = (which: "ledger" | "both"): void => {
    sink.close();
    if (which === "both") { copyFileSync(db + ".bak", db); for (const x of ["-wal", "-shm", "-journal"]) if (existsSync(db + x)) rmSync(db + x); }
    copyFileSync(ledger + ".bak", ledger);
    sink = new Sink(db, cfg);   // the sink's start-up audit: a restored older store starts (documented limit X6-P1)
  };
  const atAttack = (): void => { if (mode === "d-a" || mode === "d-b") provider.advance(RETENTION); };
  const outboxIntents = (): { requestId: string; intent: any }[] =>
    sink.outbox().map((r: any) => ({ requestId: r.request_id, intent: JSON.parse(r.intent) }));
  const stop = (): void => { try { sink.close(); } catch { /* closed */ } };
  return { E, dir, db, ledger, journalPath, genesis, provider, emit, token, state, commitText, refund, flush, backup, restore,
    atAttack, outboxIntents, stop, setRetries: (n: number) => { retries = n; } };
}
/* eslint-enable @typescript-eslint/no-require-imports */

// The money check on the PROVIDER's durable state (the only place where money moves).
export function moneyCheck(provider: FakeProvider, chargeId: string, chargeAmount: string) {
  const perKey = provider.movementsPerKey();
  const twice = Object.entries(perKey).filter(([, n]) => n > 1).map(([k]) => k);
  const total = provider.totalMoved(chargeId);
  return { total: total.toString(), charge: chargeAmount, withinCharge: total <= BigInt(chargeAmount), twice, noDouble: twice.length === 0,
    movements: provider.movements().map(m => m.key + ":" + m.amount) };
}
export function verdict(safe: boolean, detail: unknown): never {
  console.log(JSON.stringify(detail));
  console.log(safe ? "SAFE" : "DEFECT");
  process.exit(safe ? 0 : 1);
}
export function guard(f: () => void): void { try { f(); } catch (e) { console.error(e); process.exit(3); } }
