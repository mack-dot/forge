// An `emit` for the refund dispatcher that calls a payment provider (here: the FAKE provider) with
// idempotency key = request id (night shift 2026-11-19, task h-provider). A TEST adapter, NOT proved.
// Emit contract used (dispatcher.ts at e65f9ec8): emit(effect: { requestId; intent: <outbox intent text> }, intent: Intent),
// synchronous, called AFTER the dispatcher's ledger line is synced. The adapter takes the key from the intent it
// receives today. CONTRACT CHANGE POINT: if the dispatcher later passes an explicit idempotency key (task h-dispatch),
// replace keyOf() below by that argument; the checks stay the same.
// Behaviour:
//   - Refuses (throws, no provider call) if effect.requestId, intent.requestId and the outbox text disagree.
//   - Amount "0": NO provider call (real providers often refuse a zero amount). The adapter writes a journal line
//     {outcome: "zero-recorded"} and returns: the zero-amount refund succeeds end to end and moves no money.
//   - Otherwise: one provider call with key = request id and the exact parameters (charge id, amount, reason). The
//     intent has no currency field: the currency is the charge's own (ASSUMPTION; see PROVIDER_ANCHOR.md).
//   - A retryable error (timeout, unavailable) is retried with the SAME key and SAME parameters, up to `retries`
//     times. This is safe ONLY under PROVIDER-IDEMPOTENT-KEY inside the retention window.
//   - Result truth: returns only after the provider confirmed (new or replayed). Any other outcome THROWS, so the
//     dispatcher run stops and the row is not in FlushResult.emitted. The dispatcher's ledger line is written BEFORE
//     emit, so a ledger line means "attempt started", not "paid". The adapter journal (its own file) holds the
//     outcome per attempt: paid | replayed | zero-recorded | refused:<code> | unknown:<code>.
import { closeSync, fsyncSync, openSync, writeSync } from "node:fs";
import { FakeProvider, ProviderError } from "./fake_provider";

export type EffectArg = { requestId: string; intent: string };
export type IntentArg = { chargeId: string; requestId: string; amount: string; reason: string };
// observe (optional; h-provider2): called with every journal line after it was written (test attribution only).
export type AdapterOptions = { retries: number; journalPath: string; observe?: (line: Record<string, unknown>) => void };

const keyOf = (intent: IntentArg): string => intent.requestId;   // CONTRACT CHANGE POINT (see the header)
const canonIntent = (i: IntentArg): string =>
  "{" + ["amount", "chargeId", "reason", "requestId"].map(k => JSON.stringify(k) + ":" + JSON.stringify((i as any)[k])).join(",") + "}";

function journalTo(path: string, line: Record<string, unknown>): void {
  const fd = openSync(path, "a");
  try { writeSync(fd, JSON.stringify(line) + "\n"); fsyncSync(fd); } finally { closeSync(fd); }
}

export function makeEmit(provider: FakeProvider, opt: AdapterOptions): (effect: EffectArg, intent: IntentArg) => void {
  const journal = (path: string, line: Record<string, unknown>): void => { journalTo(path, line); opt.observe?.(line); };
  return (effect: EffectArg, intent: IntentArg): void => {
    if (effect === null || intent === null || typeof effect !== "object" || typeof intent !== "object" ||
        effect.requestId !== intent.requestId || effect.intent !== canonIntent(intent)) {
      journal(opt.journalPath, { requestId: String(effect?.requestId), outcome: "refused:inconsistent-effect" });
      throw new Error("emit adapter: the effect, the intent and the outbox text disagree; no provider call");
    }
    const key = keyOf(intent);
    if (intent.amount === "0") {
      journal(opt.journalPath, { requestId: intent.requestId, key, chargeId: intent.chargeId, outcome: "zero-recorded" });
      return;
    }
    const call = { key, chargeId: intent.chargeId, amount: intent.amount, reason: intent.reason };
    let last: ProviderError | null = null;
    for (let attempt = 0; attempt <= opt.retries; attempt++) {
      try {
        const r = provider.refund(call);
        journal(opt.journalPath, { requestId: intent.requestId, key, attempt, outcome: r.replayed ? "replayed" : "paid", refundId: r.refundId });
        return;
      } catch (e) {
        if (!(e instanceof ProviderError)) throw e;
        last = e;
        if (!e.retryable) {
          journal(opt.journalPath, { requestId: intent.requestId, key, attempt, outcome: "refused:" + e.code });
          throw e;
        }
        journal(opt.journalPath, { requestId: intent.requestId, key, attempt, outcome: "unknown:" + e.code });
      }
    }
    throw last ?? new Error("emit adapter: no attempt");
  };
}
