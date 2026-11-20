// A FAKE external payment provider for the refund-finality tests (night shift 2026-11-19, tasks h-provider, h-provider3).
// A TEST double, not a model of any real provider. It exists to test the provider-anchor assumptions named in
// results/night-shift-20261119/orch-B/h-provider3/PROVIDER_ANCHOR_3.md (earlier: h-provider/PROVIDER_ANCHOR.md):
//   PROVIDER-IDEMPOTENT-KEY  same key + same parameters inside the retention window: the first result again, no money.
//   PROVIDER-PARAM-BINDING   same key + other parameters inside the window: refused, no money (option replay "error").
//   PROVIDER-KEY-RETENTION   the provider forgets a key `retention` logical ticks after its first use.
//   PROVIDER-CEILING         the refunds that moved money on one charge never sum above the charge amount.
// Durable state: ONE JSON file of its own (not the sink store, not the dispatcher ledger). Every call reads it and
// every change is written and synced before the call returns (or before a fault is raised).
// The call is SYNCHRONOUS because the dispatcher's emit contract (dispatcher.ts at e65f9ec8) is synchronous.
// No network, no credentials, no clock: time is the logical counter `now` in the state file.
// h-provider3 options (red team C-ATT-41..44; defaults keep the five modes of h-provider exactly as they were):
//   replay  "error" (default): a remembered key with other parameters -> param_mismatch, no money.
//           "first": a remembered key -> the FIRST result again, whatever the parameters (no body comparison; common).
//   keyText null (default): any key text. {max, asciiOnly}: a key longer than `max` or not printable ASCII (an HTTP
//           header value) -> invalid_request, no money.
//   Shared account: FakeProvider.attach(path, charges) adds charges to an EXISTING state file, so two stores (two
//           worlds) use ONE account and ONE key space (keys are scoped per account, not per charge).
//   Faults (inject): "in_progress_after_money" moves the money, then answers in_progress; the next `answers - 1`
//           calls with that key also answer in_progress (a request still being processed); later calls replay.
//   Another party's call: any caller may call refund() with any key (the test calls it directly).
import { closeSync, existsSync, fsyncSync, openSync, readFileSync, renameSync, writeSync } from "node:fs";

export type ProviderMode = "a" | "b" | "c" | "d-a" | "d-b";
// a: idempotent by key (no expiry). b: a + per-charge ceiling. c: NOT idempotent, no ceiling (the control).
// d-a: a with a key retention window. d-b: b with a key retention window.
export type ProviderOptions = { idempotent: boolean; ceiling: boolean; retention: number | null; refuseZero: boolean;
  replay?: "error" | "first"; keyText?: { max: number; asciiOnly: boolean } | null };
export function optionsOf(mode: ProviderMode, retention = 24): ProviderOptions {
  switch (mode) {
    case "a": return { idempotent: true, ceiling: false, retention: null, refuseZero: true };
    case "b": return { idempotent: true, ceiling: true, retention: null, refuseZero: true };
    case "c": return { idempotent: false, ceiling: false, retention: null, refuseZero: true };
    case "d-a": return { idempotent: true, ceiling: false, retention, refuseZero: true };
    case "d-b": return { idempotent: true, ceiling: true, retention, refuseZero: true };
  }
}
export const MODES: ProviderMode[] = ["a", "b", "c", "d-a", "d-b"];

export type RefundCall = { key: string; chargeId: string; amount: string; reason: string };
// The answer. A real provider returns the refund object; the adapter needs chargeId and amount in it (see the anchor).
export type RefundResult = { refundId: string; chargeId: string; amount: string; reason?: string; replayed: boolean };
export type Movement = { refundId: string; key: string; chargeId: string; amount: string; at: number };
type KeyRecord = { params: string; result: RefundResult; at: number; inProgress?: number };
type Fault = { key: string; kind: "timeout_after_money" | "crash_before_money" | "refuse" | "in_progress_after_money"; answers?: number };
type State = { now: number; charges: Record<string, string>; movements: Movement[]; keys: Record<string, KeyRecord>;
  faults: Fault[]; calls: number; options: ProviderOptions };

export class ProviderError extends Error {
  // retryable: the caller does not know whether money moved (timeout) or knows it did not (unavailable).
  // (The h-provider3 adapter does NOT use this getter: it has its own answer-class table. Kept for the frozen v1 adapter.)
  constructor(readonly code: "refused" | "param_mismatch" | "ceiling" | "zero_amount" | "unknown_charge" | "timeout" | "unavailable" |
              "in_progress" | "invalid_request", message: string) { super("provider " + code + ": " + message); }
  get retryable(): boolean { return this.code === "timeout" || this.code === "unavailable"; }
}

const MONEY = /^(0|[1-9][0-9]{0,18})$/;
const paramsOf = (c: RefundCall): string => JSON.stringify([c.chargeId, c.amount, c.reason]);

export class FakeProvider {
  constructor(readonly statePath: string) {}
  // Creates the state file. Charges: charge id -> captured amount (decimal string).
  static create(statePath: string, options: ProviderOptions, charges: Record<string, string>): FakeProvider {
    const p = new FakeProvider(statePath);
    p.save({ now: 0, charges: { ...charges }, movements: [], keys: {}, faults: [], calls: 0, options });
    return p;
  }
  // A second store on the SAME account: adds its charges; keeps keys, movements and options.
  static attach(statePath: string, charges: Record<string, string>): FakeProvider {
    const p = new FakeProvider(statePath), s = p.load();
    for (const [c, a] of Object.entries(charges)) { if (s.charges[c] !== undefined && s.charges[c] !== a) throw new Error("fake provider: charge " + c + " exists with another amount"); s.charges[c] = a; }
    p.save(s);
    return p;
  }
  private load(): State {
    if (!existsSync(this.statePath)) throw new Error("fake provider: no state file");
    return JSON.parse(readFileSync(this.statePath, "utf8")) as State;
  }
  private save(s: State): void {
    const tmp = this.statePath + ".tmp";
    const fd = openSync(tmp, "w");
    try { writeSync(fd, JSON.stringify(s)); fsyncSync(fd); } finally { closeSync(fd); }
    renameSync(tmp, this.statePath);
  }
  // ---- test controls (not part of the provider API)
  advance(ticks: number): void { const s = this.load(); s.now += ticks; this.save(s); }
  inject(key: string, kind: Fault["kind"], answers = 1): void { const s = this.load(); s.faults.push({ key, kind, answers }); this.save(s); }
  movements(): Movement[] { return this.load().movements; }
  calls(): number { return this.load().calls; }
  totalMoved(chargeId: string): bigint {
    return this.load().movements.filter(m => m.chargeId === chargeId).reduce((t, m) => t + BigInt(m.amount), 0n);
  }
  movementsPerKey(): Record<string, number> {
    const n: Record<string, number> = {};
    for (const m of this.load().movements) n[m.key] = (n[m.key] ?? 0) + 1;
    return n;
  }
  // ---- the provider API: one refund call.
  refund(call: RefundCall): RefundResult {
    const s = this.load();
    s.calls++;
    const o = s.options;
    if (o.keyText) {
      if (typeof call.key !== "string" || (o.keyText.asciiOnly && !/^[\x20-\x7e]*$/.test(call.key))) { this.save(s); throw new ProviderError("invalid_request", "the idempotency key is not printable ASCII"); }
      if (call.key.length > o.keyText.max) { this.save(s); throw new ProviderError("invalid_request", "the idempotency key is longer than " + o.keyText.max); }
    }
    // Retention: a key older than the window is forgotten (PROVIDER-KEY-RETENTION).
    if (o.retention !== null) {
      for (const [k, r] of Object.entries(s.keys)) if (s.now - r.at >= o.retention) delete s.keys[k];
    }
    const fi = s.faults.findIndex(f => f.key === call.key);
    const fault = fi >= 0 ? s.faults.splice(fi, 1)[0] : undefined;
    if (fault?.kind === "crash_before_money") { this.save(s); throw new ProviderError("unavailable", "crashed before any money moved"); }
    if (fault?.kind === "refuse") { this.save(s); throw new ProviderError("refused", "declined by the provider"); }
    if (o.idempotent) {
      const seen = s.keys[call.key];
      if (seen !== undefined) {
        if (seen.inProgress !== undefined && seen.inProgress > 0) { seen.inProgress--; this.save(s); throw new ProviderError("in_progress", "a request with this key is still in progress"); }
        this.save(s);
        if ((o.replay ?? "error") === "error" && seen.params !== paramsOf(call)) throw new ProviderError("param_mismatch", "key " + call.key + " was used with other parameters");
        return { ...seen.result, replayed: true };
      }
    }
    if (typeof call.amount !== "string" || !MONEY.test(call.amount)) { this.save(s); throw new ProviderError("refused", "amount is not a decimal string"); }
    if (o.refuseZero && call.amount === "0") { this.save(s); throw new ProviderError("zero_amount", "a zero amount is refused"); }
    const charge = s.charges[call.chargeId];
    if (charge === undefined) { this.save(s); throw new ProviderError("unknown_charge", call.chargeId); }
    if (o.ceiling) {
      const moved = s.movements.filter(m => m.chargeId === call.chargeId).reduce((t, m) => t + BigInt(m.amount), 0n);
      if (moved + BigInt(call.amount) > BigInt(charge)) { this.save(s); throw new ProviderError("ceiling", "refunds would exceed the charge amount"); }
    }
    const refundId = "re_" + (s.movements.length + 1);
    const result: RefundResult = { refundId, chargeId: call.chargeId, amount: call.amount, reason: call.reason, replayed: false };
    s.movements.push({ refundId, key: call.key, chargeId: call.chargeId, amount: call.amount, at: s.now });
    if (o.idempotent) s.keys[call.key] = { params: paramsOf(call), result, at: s.now,
      ...(fault?.kind === "in_progress_after_money" && (fault.answers ?? 1) > 1 ? { inProgress: (fault.answers ?? 1) - 1 } : {}) };
    this.save(s);                                   // the money moved and is durable
    if (fault?.kind === "timeout_after_money") throw new ProviderError("timeout", "no answer (the money moved)");
    if (fault?.kind === "in_progress_after_money") throw new ProviderError("in_progress", "the request is still in progress (the money moved)");
    return result;
  }
}
