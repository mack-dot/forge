// A FAKE external payment provider for the refund-finality tests (night shift 2026-11-19, task h-provider).
// A TEST double, not a model of any real provider. It exists to test the provider-anchor assumptions named in
// results/night-shift-20261119/orch-B/h-provider/PROVIDER_ANCHOR.md:
//   PROVIDER-IDEMPOTENT-KEY  same key + same parameters inside the retention window: the first result again, no money.
//   PROVIDER-PARAM-BINDING   same key + other parameters inside the window: refused, no money.
//   PROVIDER-KEY-RETENTION   the provider forgets a key `retention` logical ticks after its first use.
//   PROVIDER-CEILING         the refunds that moved money on one charge never sum above the charge amount.
// Durable state: ONE JSON file of its own (not the sink store, not the dispatcher ledger). Every call reads it and
// every change is written and synced before the call returns (or before a fault is raised).
// The call is SYNCHRONOUS because the dispatcher's emit contract (dispatcher.ts at e65f9ec8) is synchronous.
// No network, no credentials, no clock: time is the logical counter `now` in the state file.
import { closeSync, existsSync, fsyncSync, openSync, readFileSync, renameSync, writeSync } from "node:fs";

export type ProviderMode = "a" | "b" | "c" | "d-a" | "d-b";
// a: idempotent by key (no expiry). b: a + per-charge ceiling. c: NOT idempotent, no ceiling (the control).
// d-a: a with a key retention window. d-b: b with a key retention window.
export type ProviderOptions = { idempotent: boolean; ceiling: boolean; retention: number | null; refuseZero: boolean };
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
export type RefundResult = { refundId: string; chargeId: string; amount: string; replayed: boolean };
export type Movement = { refundId: string; key: string; chargeId: string; amount: string; at: number };
type KeyRecord = { params: string; result: RefundResult; at: number };
type Fault = { key: string; kind: "timeout_after_money" | "crash_before_money" | "refuse" };
type State = { now: number; charges: Record<string, string>; movements: Movement[]; keys: Record<string, KeyRecord>;
  faults: Fault[]; calls: number; options: ProviderOptions };

export class ProviderError extends Error {
  // retryable: the caller does not know whether money moved (timeout) or knows it did not (unavailable).
  constructor(readonly code: "refused" | "param_mismatch" | "ceiling" | "zero_amount" | "unknown_charge" | "timeout" | "unavailable",
              message: string) { super("provider " + code + ": " + message); }
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
  inject(key: string, kind: Fault["kind"]): void { const s = this.load(); s.faults.push({ key, kind }); this.save(s); }
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
        this.save(s);
        if (seen.params !== paramsOf(call)) throw new ProviderError("param_mismatch", "key " + call.key + " was used with other parameters");
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
    const result: RefundResult = { refundId, chargeId: call.chargeId, amount: call.amount, replayed: false };
    s.movements.push({ refundId, key: call.key, chargeId: call.chargeId, amount: call.amount, at: s.now });
    if (o.idempotent) s.keys[call.key] = { params: paramsOf(call), result, at: s.now };
    this.save(s);                                   // the money moved and is durable
    if (fault?.kind === "timeout_after_money") throw new ProviderError("timeout", "no answer (the money moved)");
    return result;
  }
}
