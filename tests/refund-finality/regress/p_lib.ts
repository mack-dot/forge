// Shared helper of the provider-anchor regressions p_*.ts (night shift 2026-11-19, tasks h-provider and h-provider2).
// A TEST, not a proof.
// Usage of every p_*.ts file (pinned Node 24.3.0 first in PATH):
//   node --import tsx tests/refund-finality/regress/p_<name>.ts <treeRoot> <mode> [<anchor>] [<case>]
// <treeRoot>: the checkout whose ts/refund-finality/{sink,dispatcher,encoding}.ts are under test.
// <mode>: the fake provider mode: a | b | c | d-a | d-b (tests/refund-finality/provider/fake_provider.ts).
//   d-a and d-b: the provider forgets a key after RETENTION ticks; the regression advances the clock past it at the
//   moment of the attack (a restore or a delayed retry happens AFTER the window).
// <anchor> (default none): the LOCAL anchor that the host keeps OUTSIDE the working directory (here: a JSON file in a
//   sibling folder that no restore touches):
//   none  : no outside value. Only the always-on layers act (dispatch witness, h1 new-ledger rule, ledger row check).
//   floor : dispatcher cfg.ledgerFloor = the ledgerHead of the host's last successful dispatcher run.
//   head  : sink cfg.outsideHead {committed, pending} + cfg.onHead, kept by the FRESHNESS RULE of sink.ts
//           (HARDENING_NOTES_2 section 2), and dispatcher cfg.expectedHead = committed.
//   full  : floor + head.
// WORKING DIRECTORY (<base>/local): every file that the sink, the dispatcher and the adapter write (read from the code at
// 370ff65c): sink.sqlite; sink.sqlite-journal (SQLite rollback journal, only inside a write transaction; DELETE mode);
// <realpath sink.sqlite>.dispatch-witness.json and its .tmp-<run> (dispatcher writeWitness); the ledger <x>ledger.jsonl,
// <ledger>.lock, <ledger>.lock.stale-<run> (takeover), <ledger>.torn-<run> (cutTornTail); adapter-journal.jsonl (emit
// adapter). Not written in these tests: the Sink.recover log (operator step, path chosen by the operator). The provider's
// state (<base>/provider) and the host's anchor (<base>/outside) are NOT local: no restore touches them.
// Exit codes. Attack regressions: 0 = SAFE (no request id moved money twice AND the money moved per charge <= the charge
// AND the regression's own conditions); 1 = NOT STOPPED (DEFECT); 2 = CONTROL DOES NOT BITE (mode c with anchor none
// was SAFE: the run is no evidence about the provider); 3 = the harness broke; 4 = usage.
// Positive controls: 0 = PASS, 1 = FAIL, 3, 4 as above.
// Every run prints "stopped by: <layer>" for the FIRST layer that refused something after the attack started, the list
// of all layers seen, and the verdict. Layers: dispatch witness | ledger floor | outside head | h1 new-ledger rule |
// ledger row check | claim rule (in doubt) | provider key | provider ceiling | NOT STOPPED.
// h-provider3 switches (environment, read by world()):
//   P_ADAPTER=v3 (default) the adapter of provider/emit_adapter.ts (key = providerKey(h_0, charge, request id); every
//                answer checked; answer classes). P_ADAPTER=v1: the FROZEN old adapter (provider/emit_adapter_v1.ts: key =
//                request id, any answer accepted) ONLY to show that a p3_*.ts control bites.
//   P_KEY=noamount (measurement only, with v3) the key sent to the provider is providerKey with the amount "*" for every
//                call: the variant WITHOUT the amount that owner decision D-3 did not choose. It shows what the amount in
//                the key costs (PROVIDER_ANCHOR_3.md). Never a default.
// world() options for the provider (h-provider3): providerPath (a SHARED account file: the second world attaches to it),
// providerOptions (merged into the mode's options: replay, keyText, ceiling, ...).
// Money check (h-provider3): besides "no key moved money twice" it also requires "no EFFECT (charge, request id) moved money
// twice": with the amount in the key (owner decision D-3) one request id can have two provider keys after a rebind.
// Tokens: a TEST Ed25519 key made in this process signs the body that an honest issuer would sign for the given
// pre-state (the model of tests/refund-finality/regress/harness.ts honest()). No minter process. No network.
import { generateKeyPairSync, sign } from "node:crypto";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { FakeProvider, ProviderMode, ProviderOptions, MODES, optionsOf } from "../provider/fake_provider";
import { makeEmit, providerKey } from "../provider/emit_adapter";
import { makeEmit as makeEmitV1 } from "../provider/emit_adapter_v1";

export const ADAPTER: "v3" | "v1" = process.env.P_ADAPTER === "v1" ? "v1" : "v3";
const KEY_NO_AMOUNT = process.env.P_KEY === "noamount";
if (process.env.P_ADAPTER !== undefined && !["v1", "v3"].includes(process.env.P_ADAPTER)) { console.error("P_ADAPTER must be v1 or v3"); process.exit(4); }
if (KEY_NO_AMOUNT && ADAPTER !== "v3") { console.error("P_KEY=noamount needs P_ADAPTER=v3"); process.exit(4); }
if (process.env.P_KEY !== undefined && process.env.P_KEY !== "noamount") { console.error("P_KEY must be noamount"); process.exit(4); }
// provider refund id -> the effect identity (store h_0 / charge / request id) of the adapter call during which that money
// moved (a movement that no adapter call made, e.g. another party's call, has none). The money check counts per effect.
const effectOfRefund = new Map<string, string>();

export const RETENTION = 24;
export type Anchor = "none" | "floor" | "head" | "full";
export const ANCHORS: Anchor[] = ["none", "floor", "head", "full"];
export type State = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export function argv(): { root: string; mode: ProviderMode; anchor: Anchor; rest: string[] } {
  const [root, mode, anchor = "none", ...rest] = process.argv.slice(2);
  if (!root || !MODES.includes(mode as ProviderMode) || !ANCHORS.includes(anchor as Anchor)) {
    console.error("usage: p_<name>.ts <treeRoot> a|b|c|d-a|d-b [none|floor|head|full] [case]"); process.exit(4);
  }
  return { root: resolve(root), mode: mode as ProviderMode, anchor: anchor as Anchor, rest };
}
const temps: string[] = [];
process.on("exit", () => { for (const d of temps) { try { rmSync(d, { recursive: true, force: true }); } catch { /* best effort */ } } });

// The names that the code may write in the working directory (see the header). A snapshot with any other name stops the
// harness (exit 3): then this list is out of date and the "full restore" would not be full.
const LOCAL_NAME = /^(sink\.sqlite(-journal|\.dispatch-witness\.json(\.tmp-[0-9a-f]{32})?)?|[A-Za-z0-9-]*ledger\.jsonl(\.lock(\.stale-[0-9a-f]{32})?|\.torn-[0-9a-f]{32})?|adapter-journal\.jsonl)$/;

// The layer that a refusal text names. The texts are those of dispatcher.ts and sink.ts at 370ff65c.
export function layerOf(text: string): string {
  if (/dispatch witness|the store is bound to the ledger/.test(text)) return "dispatch witness";
  if (/does not reach the outside anchor/.test(text)) return "ledger floor";
  if (/cfg\.expectedHead|beyond the outside head|is not the outside head|SINK-OUTSIDE-HEAD/.test(text)) return "outside head";
  if (/ledger is missing or empty/.test(text)) return "h1 new-ledger rule";
  if (/do not chain to the ledger's claims/.test(text)) return "ledger row check";
  if (/^in doubt/.test(text)) return "claim rule (in doubt)";
  return "other: " + text.slice(0, 80);
}

/* eslint-disable @typescript-eslint/no-require-imports */
export function world(root: string, mode: ProviderMode, anchor: Anchor, S0: State,
  opts: { retries?: number; keepNewLedgerH0?: boolean; providerPath?: string; providerOptions?: Partial<ProviderOptions> } = {}) {
  const E = require(join(root, "ts/refund-finality/encoding.ts"));
  const { Sink, genesisOf } = require(join(root, "ts/refund-finality/sink.ts"));
  const { Dispatcher } = require(join(root, "ts/refund-finality/dispatcher.ts"));
  const base = mkdtempSync(join(tmpdir(), "forge-p-")); temps.push(base);
  const dir = join(base, "local"), outsideDir = join(base, "outside"), snapDir = join(base, "snapshot"), bakDir = join(base, "bak");
  for (const d of [dir, outsideDir, join(base, "provider"), bakDir]) mkdirSync(d);
  const useHead = anchor === "head" || anchor === "full", useFloor = anchor === "floor" || anchor === "full";
  const keys = generateKeyPairSync("ed25519");
  const ids = { publicKeyPem: keys.publicKey.export({ type: "spki", format: "pem" }) as string,
    specLockSha256: E.sha256hex("h-provider test spec lock"), checkerSha256: E.sha256hex("h-provider test checker") };
  const cfg = { ...ids, initialState: S0 };
  const dcfg: any = { ...ids, initialStateSha256: E.stateSha256(S0) };
  const genesis: string = genesisOf(E.canon(S0), ids.specLockSha256, ids.checkerSha256, ids.publicKeyPem);
  const db = join(dir, "sink.sqlite"), ledger = join(dir, "dispatch-ledger.jsonl"), journalPath = join(dir, "adapter-journal.jsonl");
  const providerPath = opts.providerPath ?? join(base, "provider", "provider-state.json");
  const provider = opts.providerPath !== undefined && existsSync(providerPath) ? FakeProvider.attach(providerPath, { [S0.chargeId]: S0.original }) :
    FakeProvider.create(providerPath, { ...optionsOf(mode, RETENTION), ...(opts.providerOptions ?? {}) }, { [S0.chargeId]: S0.original });
  // The key that the adapter in use sends for a request id of THIS store (tests inject faults and check money with it).
  const keyOf = (requestId: string, amount: string): string => ADAPTER === "v1" ? requestId :
    providerKey(genesis, S0.chargeId, requestId, KEY_NO_AMOUNT ? "*" : amount);
  // The provider as the adapter sees it (P_KEY=noamount rewrites the key; every sent key is mapped to its effect).
  const client = { refund: (call: any) => {
    const k = KEY_NO_AMOUNT ? providerKey(genesis, call.chargeId, effectRid(call), "*") : call.key;
    const before = provider.movements().length;
    try { return provider.refund({ ...call, key: k }); } finally {
      for (const m of provider.movements().slice(before)) effectOfRefund.set(m.refundId, genesis + "/" + call.chargeId + "/" + effectRid(call)); } } };
  const effectId = (requestId: string): string => genesis + "/" + S0.chargeId + "/" + requestId;
  // The host's outside record (ANCHOR-OUTSIDE: never restored with the working directory).
  const outsidePath = join(outsideDir, "anchor.json");
  const outside = { read: (): any => JSON.parse(readFileSync(outsidePath, "utf8")), write: (o: any): void => writeFileSync(outsidePath, JSON.stringify(o)) };
  outside.write({ committed: { count: 0, chainHash: genesis } });
  // Events: every refusal by any layer, with the phase. Attribution uses the events after the attack started.
  let phase: "setup" | "attack" = "setup";
  const events: { phase: string; layer: string; detail: string }[] = [];
  const note = (layer: string, detail: string): void => { events.push({ phase, layer, detail: detail.slice(0, 160) }); };
  const markAttack = (): void => { phase = "attack"; };
  const sinkCfg = (): any => {
    if (!useHead) return cfg;
    const o = outside.read();
    return { ...cfg, outsideHead: { committed: o.committed, ...(o.pending ? { pending: o.pending } : {}) },
      onHead: (h: any) => { const x = outside.read(); x.pending = h; outside.write(x); } };   // FRESHNESS RULE (1)
  };
  let sink: any = null, sinkRefusal = "";
  const openSink = (): void => {
    try { sink = new Sink(db, sinkCfg()); sinkRefusal = ""; } catch (e) {
      sink = null; sinkRefusal = String((e as Error).message);
      let layer = layerOf(sinkRefusal);
      // The sink's text does not always name the outside head (a store that does not EXTEND committed gives the plain
      // "start-up audit ... is false"). Probe: the same file opens WITHOUT outsideHead -> the outside head refused it.
      if (useHead && layer.startsWith("other")) {
        try { const p = new Sink(db, cfg); p.close(); layer = "outside head"; sinkRefusal += " [SINK-OUTSIDE-HEAD: the store opens without cfg.outsideHead]"; } catch { /* another cause */ }
      }
      note(layer, "sink start: " + sinkRefusal);
    }
  };
  openSink(); sink.init(S0);
  let retries = opts.retries ?? 0;
  let current = "";
  const effectRid = (call: any): string => current !== "" ? current : "(direct call, key " + String(call.key).slice(0, 16) + ")";
  const observe = (line: any): void => {
    const o = String(line.outcome);
    if (o === "replayed" || o === "refused:param_mismatch" || o === "alarm:param_mismatch") note("provider key", line.requestId + " " + o);
    else if (o === "refused:ceiling") note("provider ceiling", line.requestId + " " + o);
    else if (o === "alarm:answer-mismatch") note("adapter answer check", line.requestId + " " + o);
  };
  const emitRaw = ADAPTER === "v1" ? makeEmitV1(client as any, { get retries() { return retries; }, journalPath, observe } as any) :
    makeEmit(client as any, { get retries() { return retries; }, journalPath, storeH0: genesis, observe } as any);
  // The request id of the call in flight (the provider call carries no request id; the test needs it for the money check).
  const emit = (effect: any, intent: any): void => { current = String(intent?.requestId); try { emitRaw(effect, intent); } finally { current = ""; } };
  const token = (pre: State, requestId: string, amount: string, reason = "returned_item"): string => {
    const post = { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
    const body = { domain: E.DOMAIN, ...{ specLockSha256: ids.specLockSha256, checkerSha256: ids.checkerSha256 },
      preStateSha256: E.stateSha256(pre), requestId, post, intent: { chargeId: pre.chargeId, requestId, amount, reason } };
    return E.canon({ body, signature: sign(null, E.signedBytes(body), keys.privateKey).toString("base64") });
  };
  const state = (): State | null => sink === null ? null : JSON.parse(sink.stateBlob());
  const commitText = (text: string): string => {
    if (sink === null) return "no sink (start refused)";
    try {
      const r = sink.commit(text);
      if (r.status === "committed" && useHead) { const o = outside.read(); o.committed = r.head; delete o.pending; outside.write(o); }   // FRESHNESS RULE (2)
      return String(r.status) + (r.status === "rejected" ? ": " + String(r.reason).slice(0, 80) : "");
    } catch (e) { return "threw: " + (e as Error).message; }
  };
  // An honest refund on the CURRENT stored state (the issuer signs whatever pre-state the store supplies).
  const refund = (requestId: string, amount: string): { text: string; status: string } => {
    const s = state();
    if (s === null) return { text: "", status: "no sink (start refused)" };
    const text = token(s, requestId, amount); return { text, status: commitText(text) };
  };
  // One dispatcher run with the provider adapter. Errors are returned, not thrown. The honest operator declares the
  // FIRST run of the main ledger a new ledger (cfg.newLedgerH0 = h_0, the h1 rule) only while that file is missing or
  // empty, unless opts.keepNewLedgerH0 (C-ATT-28: the field is left set on every run). The anchor fields come from the
  // host's outside record; after a run that returns, the host stores result.ledgerHead (main ledger only).
  const flush = (ledgerPath = ledger, extra: any = {}): { emitted: string[]; refused: string[]; error: string } => {
    const o = outside.read(), c: any = { ...dcfg };
    if (opts.keepNewLedgerH0) c.newLedgerH0 = genesis;
    else if (ledgerPath === ledger && (!existsSync(ledger) || statSync(ledger).size === 0) && !("newLedgerH0" in extra)) c.newLedgerH0 = genesis;
    if (useHead) c.expectedHead = o.committed;                     // FRESHNESS RULE (4)
    if (useFloor && o.ledgerHead !== undefined) c.ledgerFloor = o.ledgerHead;
    try {
      const r = new Dispatcher(db, ledgerPath, { ...c, ...extra }, emit).flush();
      for (const x of r.refused) note(layerOf(x.reason), "dispatcher refused " + x.requestId + ": " + x.reason);
      if (ledgerPath === ledger && r.ledgerHead !== undefined) { const p = outside.read(); p.ledgerHead = r.ledgerHead; outside.write(p); }
      return { emitted: r.emitted.map((e: any) => e.requestId), refused: r.refused.map((x: any) => x.requestId + ": " + String(x.reason).slice(0, 60)), error: "" };
    } catch (e) {
      const m = String((e as Error).message);
      // A provider answer or an adapter outcome is attributed by `observe` (journal lines), not here.
      if (!/^provider /.test(m) && !/^emit adapter (ALARM|IN DOUBT|REFUSED) \((?!refused:inconsistent-effect)/.test(m)) note(layerOf(m), "dispatcher stopped: " + m);
      return { emitted: [], refused: [], error: m.slice(0, 140) };
    }
  };
  const closeSink = (): void => { if (sink !== null) { try { sink.close(); } catch { /* closed */ } } sink = null; };
  const localFiles = (): string[] => readdirSync(dir).sort();
  // FULL snapshot: every file in the working directory (checked against LOCAL_NAME), with the sink closed.
  const snapshotAll = (): string[] => {
    closeSink();
    const names = localFiles(), unknown = names.filter(n => !LOCAL_NAME.test(n));
    if (unknown.length > 0) throw new Error("unknown local file(s): " + unknown.join(", ") + " (the full-restore list is out of date)");
    rmSync(snapDir, { recursive: true, force: true }); mkdirSync(snapDir);
    for (const n of names) copyFileSync(join(dir, n), join(snapDir, n));
    openSink();
    return names;
  };
  // FULL restore: delete EVERY file in the working directory, copy the snapshot back, start the sink again.
  const restoreAll = (): string[] => {
    closeSink(); markAttack();
    for (const n of localFiles()) rmSync(join(dir, n), { force: true });
    for (const n of readdirSync(snapDir)) copyFileSync(join(snapDir, n), join(dir, n));
    openSink();
    return localFiles();
  };
  // PARTIAL backup/restore (the h-provider regressions): the database and the main ledger only, NOT the witness.
  const backup = (): void => { closeSink(); for (const f of [db, ledger]) if (existsSync(f)) copyFileSync(f, join(bakDir, f === db ? "db" : "ledger")); openSink(); };
  const restore = (which: "ledger" | "both"): void => {
    closeSink(); markAttack();
    if (which === "both") { copyFileSync(join(bakDir, "db"), db); for (const x of ["-wal", "-shm", "-journal"]) if (existsSync(db + x)) rmSync(db + x); }
    copyFileSync(join(bakDir, "ledger"), ledger);
    openSink();   // without an outside head a restored older store starts (documented limit X6-P1)
  };
  const atAttack = (): void => { markAttack(); if (mode === "d-a" || mode === "d-b") provider.advance(RETENTION); };
  const outboxIntents = (): { requestId: string; intent: any }[] =>
    sink === null ? [] : sink.outbox().map((r: any) => ({ requestId: r.request_id, intent: JSON.parse(r.intent) }));
  const reopen = (): void => { closeSink(); openSink(); };
  return { E, dir, base, db, ledger, journalPath, genesis, provider, providerPath, keyOf, effectId, emit, token, state, commitText, refund, flush, backup, restore,
    snapshotAll, restoreAll, atAttack, markAttack, outboxIntents, reopen, outside, events,
    sinkRefusal: () => sinkRefusal, sinkUp: () => sink !== null, stop: closeSink, setRetries: (n: number) => { retries = n; } };
}
/* eslint-enable @typescript-eslint/no-require-imports */

// Movements per EFFECT (store h_0 / charge / request id of the adapter call during which the money moved).
export function effectMoves(movements: { refundId: string }[]): Record<string, number> {
  const n: Record<string, number> = {};
  for (const m of movements) { const e = effectOf(m.refundId); n[e] = (n[e] ?? 0) + 1; }
  return n;
}
export const effectOf = (refundId: string): string => effectOfRefund.get(refundId) ?? "no adapter call (refund " + refundId + ")";
// The money check on the PROVIDER's durable state (the only place where money moves).
export function moneyCheck(provider: FakeProvider, chargeId: string, chargeAmount: string) {
  const perKey = provider.movementsPerKey();
  const twice = Object.entries(perKey).filter(([, n]) => n > 1).map(([k]) => k);
  for (const [e, n] of Object.entries(effectMoves(provider.movements()))) if (n > 1) twice.push("effect " + e);
  const total = provider.totalMoved(chargeId);
  return { total: total.toString(), charge: chargeAmount, withinCharge: total <= BigInt(chargeAmount), twice, noDouble: twice.length === 0,
    movements: provider.movements().map(m => m.key + ":" + m.amount) };
}
// Attack verdict with the layer attribution and the control rule (see the header).
export function attackVerdict(mode: ProviderMode, anchor: Anchor, safe: boolean, events: { phase: string; layer: string; detail: string }[], detail: unknown): never {
  const seen: string[] = [];
  for (const e of events) if (e.phase === "attack" && !seen.includes(e.layer)) seen.push(e.layer);
  console.log(JSON.stringify({ ...(detail as object), attackEvents: events.filter(e => e.phase === "attack") }));
  console.log("mode " + mode + ", anchor " + anchor);
  console.log("layers seen after the attack started: " + (seen.length > 0 ? seen.join(" | ") : "(none)"));
  if (!safe) { console.log("stopped by: NOT STOPPED" + (seen.length > 0 ? " (partial refusals: " + seen.join(" | ") + ")" : "")); console.log("DEFECT"); process.exit(1); }
  console.log("stopped by: " + (seen.length > 0 ? seen[0] : "NO LAYER SEEN (the attack did not reach any layer)"));
  if (mode === "c" && anchor === "none") { console.log("CONTROL DOES NOT BITE"); process.exit(2); }
  console.log("SAFE"); process.exit(0);
}
export function positiveVerdict(ok: boolean, detail: unknown): never {
  console.log(JSON.stringify(detail));
  console.log(ok ? "positive control: PASS" : "positive control: FAIL");
  process.exit(ok ? 0 : 1);
}
export function setupFail(detail: unknown): never { console.error("SETUP FAILED " + JSON.stringify(detail)); process.exit(3); }
export function guard(f: () => void): void { try { f(); } catch (e) { console.error(e); process.exit(3); } }
