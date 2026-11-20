// An `emit` for the refund dispatcher that calls a payment provider (here: the FAKE provider). A TEST adapter, NOT proved.
// Night shift 2026-11-19: task h-provider (first version), task h-provider3 (key derivation, answer check, answer classes;
// red team C-ATT-41, 42, 44 and the worker reports on key text and "in progress"). Contract: PROVIDER_ANCHOR_3.md.
// Emit contract used (dispatcher.ts): emit(effect: { requestId; intent: <outbox intent text> }, intent: Intent), synchronous,
// called AFTER the dispatcher's claim line is synced. A throw makes the dispatcher write its "failed" line and stop the run;
// the row is then IN DOUBT for the dispatcher (never counted as dispatched) until a person calls resolveInDoubt.
//
// KEY (providerKey below; OWNER DECISION D-3: the key binds charge_id, request_id and amount). key = lower-case hex
// SHA-256 (64 ASCII characters) of the bytes
//   F(namespace) || F(chargeId) || F(requestId) || F(amount),   F(x) = uint32 big-endian byte length of UTF-8(x) || UTF-8(x),
//   namespace = "forge-refund-provider-key/v1/" + storeH0, storeH0 = a CONFIGURED CONSTANT of the deployment: the store's
//   registered genesis h_0 (core/store.ts genesisOf; the `genesis` column of the meta row; 64 lower-case hex) in
//   AdapterOptions.storeH0. It is part of the namespace, not a free field. amount = the canonical decimal text of the intent.
// - Valid key text at any provider that accepts 64 printable ASCII characters: fixed length, [0-9a-f] (worker report 5).
// - Scope (C-ATT-41): two stores on one provider account share a key only if they have the same h_0 (the same initial
//   charge state under the same spec lock, checker and issuer key) AND the same charge, request id and amount.
// - A legitimate retry of the same effect (an adapter retry, or the operator's resolveInDoubt(id, "retry")) derives the
//   SAME key: the provider deduplicates it inside its key window (PROVIDER-KEY-WINDOW).
// - CONSEQUENCE (measured, PROVIDER_ANCHOR_3.md): the same request id with ANOTHER amount (only after a rollback or a
//   rebind: the sink binds one amount per request id) is a NEW key for the provider. The provider key then gives nothing;
//   layer 1 (ledger floor + outside head) or the provider ceiling must stop it (p_full_param_rebind, mode a, anchor none).
// - Currency: the intent has no currency field. The key and the call carry none; the charge's own currency applies.
// - Reason: not in the key; it is sent and, if the answer carries it, compared.
//
// ANSWER CLASSES (every answer, the replayed one included; never another class):
// The answer is compared with the CALL, and the call is built from the committed outbox row the dispatcher handed over
// (the adapter first refuses unless effect.intent is exactly the canonical text of that intent).
//   PAID          new result whose chargeId, amount (and reason, refund key if present) equal the call -> "paid", return.
//   PAID-BEFORE   replayed result that equals the call in the same fields                           -> "replayed", return.
//   ALARM         any result that does NOT equal the call, or misses chargeId/amount/refundId; or the
//                 provider's param_mismatch (the key was used with other parameters)                 -> "alarm:<why>", THROW.
//                 Money may have moved for the key under OTHER parameters: never "paid"; in doubt; a person reconciles.
//   IN DOUBT      timeout, unavailable, in_progress: retried with the same key and call while attempts remain
//                 ("unknown:<code>" per attempt); after the last one -> "in-doubt:<code>", THROW. Also any other error
//                 code, a non-provider exception or a malformed answer -> "in-doubt:<what>", THROW. Never "refused".
//   REFUSED       refused, ceiling, zero_amount, unknown_charge, invalid_request: the provider refused BEFORE any money
//                 moved for this call -> "refused:<code>", THROW. A new attempt only through the documented operator step
//                 (dispatcher resolveInDoubt(id, "retry")); it uses the same key.
// Amount "0": NO provider call (real providers often refuse a zero amount). Journal "zero-recorded" and return: the
// zero-amount refund succeeds end to end and moves no money.
// The journal (own file, one synced JSON line per outcome) holds the call side and the answer side of each outcome.
import { createHash } from "node:crypto";
import { closeSync, fsyncSync, openSync, writeSync } from "node:fs";
import { FakeProvider, ProviderError, RefundCall } from "./fake_provider";

export type EffectArg = { requestId: string; intent: string };
export type IntentArg = { chargeId: string; requestId: string; amount: string; reason: string };
// observe (optional; h-provider2): called with every journal line after it was written (test attribution only).
export type AdapterOptions = { retries: number; journalPath: string; storeH0: string; observe?: (line: Record<string, unknown>) => void };
export type OutcomeClass = "alarm" | "in-doubt" | "refused";
export class AdapterOutcome extends Error {
  constructor(readonly cls: OutcomeClass, readonly outcome: string, message: string) {
    super("emit adapter " + (cls === "alarm" ? "ALARM" : cls === "in-doubt" ? "IN DOUBT" : "REFUSED") + " (" + outcome + "): " + message);
  }
}

export const KEY_DOMAIN = "forge-refund-provider-key/v1";
const HEX64 = /^[0-9a-f]{64}$/;
const LONE_SURROGATE = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/;
const field = (x: string): Buffer => {
  if (typeof x !== "string" || LONE_SURROGATE.test(x)) throw new Error("emit adapter: a key field is not well-formed text");
  const b = Buffer.from(x, "utf8"), n = Buffer.alloc(4);
  n.writeUInt32BE(b.length, 0);
  return Buffer.concat([n, b]);
};
export function providerKey(storeH0: string, chargeId: string, requestId: string, amount: string): string {
  if (!HEX64.test(storeH0)) throw new Error("emit adapter: storeH0 is not 64 lower-case hex characters");
  return createHash("sha256").update(Buffer.concat([field(KEY_DOMAIN + "/" + storeH0), field(chargeId), field(requestId), field(amount)])).digest("hex");
}
const canonIntent = (i: IntentArg): string =>
  "{" + ["amount", "chargeId", "reason", "requestId"].map(k => JSON.stringify(k) + ":" + JSON.stringify((i as any)[k])).join(",") + "}";

function journalTo(path: string, line: Record<string, unknown>): void {
  const fd = openSync(path, "a");
  try { writeSync(fd, JSON.stringify(line) + "\n"); fsyncSync(fd); } finally { closeSync(fd); }
}
// The answer check. "" = the answer equals the call; otherwise the reason.
function answerMismatch(call: RefundCall, r: unknown): string {
  if (r === null || typeof r !== "object") return "answer is not an object";
  const a = r as Record<string, unknown>;
  if (typeof a.refundId !== "string" || a.refundId === "") return "answer has no refund id";
  if (typeof a.chargeId !== "string" || typeof a.amount !== "string") return "answer has no charge id or amount: the check is impossible";
  if (a.chargeId !== call.chargeId) return "charge differs";
  if (a.amount !== call.amount) return "amount differs";
  if ("reason" in a && a.reason !== undefined && a.reason !== call.reason) return "reason differs";
  if ("key" in a && a.key !== undefined && a.key !== call.key) return "key differs";
  if (typeof a.replayed !== "boolean") return "answer does not say whether it is a replay";
  return "";
}
const REFUSED_CODES = new Set(["refused", "ceiling", "zero_amount", "unknown_charge", "invalid_request"]);
const RETRY_CODES = new Set(["timeout", "unavailable", "in_progress"]);

export function makeEmit(provider: FakeProvider, opt: AdapterOptions): (effect: EffectArg, intent: IntentArg) => void {
  if (!HEX64.test(String(opt.storeH0))) throw new Error("emit adapter: configure storeH0 = the store's registered h_0 (64 lower-case hex)");
  const journal = (line: Record<string, unknown>): void => { journalTo(opt.journalPath, line); opt.observe?.(line); };
  return (effect: EffectArg, intent: IntentArg): void => {
    if (effect === null || intent === null || typeof effect !== "object" || typeof intent !== "object" ||
        effect.requestId !== intent.requestId || effect.intent !== canonIntent(intent)) {
      journal({ requestId: String(effect?.requestId), outcome: "refused:inconsistent-effect" });
      throw new AdapterOutcome("refused", "refused:inconsistent-effect", "the effect, the intent and the outbox text disagree; no provider call");
    }
    const key = providerKey(opt.storeH0, intent.chargeId, intent.requestId, intent.amount);
    const sent = { requestId: intent.requestId, key, chargeId: intent.chargeId, amount: intent.amount, reason: intent.reason };
    if (intent.amount === "0") { journal({ ...sent, outcome: "zero-recorded" }); return; }
    const call: RefundCall = { key, chargeId: intent.chargeId, amount: intent.amount, reason: intent.reason };
    const stop = (cls: OutcomeClass, outcome: string, attempt: number, answer: unknown, why: string): never => {
      journal({ ...sent, attempt, outcome, answer });
      throw new AdapterOutcome(cls, outcome, intent.requestId + ": " + why);
    };
    for (let attempt = 0; ; attempt++) {
      let r: unknown;
      try { r = provider.refund(call); } catch (e) {
        if (!(e instanceof ProviderError)) stop("in-doubt", "in-doubt:exception", attempt, { error: String((e as Error)?.message ?? e).slice(0, 200) }, "the provider client threw; money may have moved");
        const pe = e as ProviderError, answer = { code: pe.code, message: pe.message.slice(0, 200) };
        if (pe.code === "param_mismatch") stop("alarm", "alarm:param_mismatch", attempt, answer, "the provider holds this key with other parameters; never paid; money may have moved for the key");
        if (REFUSED_CODES.has(pe.code)) stop("refused", "refused:" + pe.code, attempt, answer, "the provider refused before any money moved for this call");
        if (!RETRY_CODES.has(pe.code)) stop("in-doubt", "in-doubt:unknown-code", attempt, answer, "unknown provider answer; money may have moved");
        if (attempt >= opt.retries) stop("in-doubt", "in-doubt:" + pe.code, attempt, answer, "no final answer; money may have moved");
        journal({ ...sent, attempt, outcome: "unknown:" + pe.code, answer });
        continue;
      }
      const why = answerMismatch(call, r);
      if (why !== "") stop("alarm", "alarm:answer-mismatch", attempt, r, why + "; never paid; money may have moved under other parameters");
      const res = r as { refundId: string; replayed: boolean };
      journal({ ...sent, attempt, outcome: res.replayed ? "replayed" : "paid", refundId: res.refundId, answer: r });
      return;
    }
  };
}
