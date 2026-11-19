// Research integration only. The caller supplies the compiled, checked Assess
// function and a recording executor. This file contains no payment client.
import ts from "typescript";

export type Context = {
  chargeId: string; requestId: string; original: bigint; remaining: bigint;
  refundEnabled: boolean; requestOpen: boolean;
};
export type ErrorKind = "Missing" | "TimedOut" | "Failed" | "Malformed" | "Oversized" | "Unsupported";
export type Response = { kind: "Candidate"; amount: bigint; reason: string } | { kind: ErrorKind };
export type Intent = { chargeId: string; requestId: string; amount: bigint; reason: string };
export type Outcome = {
  decision: { kind: "Rejected" } | { kind: "Authorized"; amount: bigint; reason: string };
  plan: Intent[];
};
export type Assess = (context: Context, response: Response) => Outcome;
export type Host = {
  begin(context: Context): Promise<Outcome | null>;
  chunk(context: Context, bytes: Uint8Array, final: boolean): Promise<Outcome | null>;
  fail(context: Context): Promise<Outcome | null>;
  tick(context: Context): Promise<Outcome | null>;
};

const MAX_BYTES = 4096;
const MAX_MONEY = 9223372036854775807n;
const DEADLINE_MS = 5000;
const fallback = (): Outcome => ({ decision: { kind: "Rejected" }, plan: [] });

function decodeNow(bytes: Uint8Array): Response {
  if (bytes.byteLength > MAX_BYTES) return { kind: "Oversized" };
  try {
    // Keep BOM characters visible so that JSON.parse rejects a leading BOM.
    const text = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(bytes);
    const value: unknown = JSON.parse(text);
    if (value === null || typeof value !== "object" || Array.isArray(value)) return { kind: "Unsupported" };
    // JSON.parse enforces JSON grammar. The established TypeScript JSON parser
    // preserves duplicate members and decodes escaped key spellings for this
    // structural check. No handwritten JSON grammar or parser is used.
    const syntax = ts.parseJsonText("response.json", text);
    if (syntax.statements.length !== 1 || !ts.isExpressionStatement(syntax.statements[0])) {
      return { kind: "Malformed" };
    }
    const object = syntax.statements[0].expression;
    if (!ts.isObjectLiteralExpression(object) || object.properties.length !== 2) return { kind: "Unsupported" };
    const keys: string[] = [];
    for (const member of object.properties) {
      if (!ts.isPropertyAssignment(member) || !ts.isStringLiteral(member.name)) return { kind: "Unsupported" };
      keys.push(member.name.text);
    }
    if (new Set(keys).size !== 2 || !keys.includes("amount_minor") || !keys.includes("reason")) {
      return { kind: "Unsupported" };
    }
    const record = value as Record<string, unknown>;
    if (typeof record.amount_minor !== "string" || typeof record.reason !== "string" ||
        !/^(0|[1-9][0-9]{0,18})$/.test(record.amount_minor)) return { kind: "Unsupported" };
    const amount = BigInt(record.amount_minor);
    if (amount > MAX_MONEY) return { kind: "Unsupported" };
    return { kind: "Candidate", amount, reason: record.reason };
  } catch {
    return { kind: "Malformed" };
  }
}

export async function decode(bytes: Uint8Array): Promise<Response> {
  return decodeNow(bytes);
}

type Attempt = {
  context: Context;
  deadline: number;
  chunks: Uint8Array[];
  size: number;
  outcome: Outcome | null;
};

const key = (c: Context): string => JSON.stringify([c.chargeId, c.requestId]);
const same = (a: Context, b: Context): boolean =>
  a.chargeId === b.chargeId && a.requestId === b.requestId &&
  a.original === b.original && a.remaining === b.remaining &&
  a.refundEnabled === b.refundEnabled && a.requestOpen === b.requestOpen;

export function createHost(options: {
  assess: Assess; execute: (intent: Intent) => void; now: () => number;
}): Host {
  // Capture capabilities once. Neither is exposed to the model-byte supplier.
  const { assess, execute, now } = options;
  const attempts = new Map<string, Attempt>();
  const result = (attempt: Attempt): Outcome | null =>
    attempt.outcome === null ? null : structuredClone(attempt.outcome);
  const lookup = (context: Context): Attempt | undefined => {
    const attempt = attempts.get(key(context));
    return attempt && same(attempt.context, context) ? attempt : undefined;
  };
  const finish = (attempt: Attempt, response: Response): Outcome => {
    if (attempt.outcome !== null) return structuredClone(attempt.outcome);
    let outcome: Outcome;
    try { outcome = assess(attempt.context, response); }
    catch { outcome = fallback(); } // A host/bridge fault cannot dispatch a plan.
    // Commit terminal state before calling any external executor. Reentry,
    // duplicates, late responses and executor failure cannot repeat dispatch.
    attempt.outcome = structuredClone(outcome);
    Object.freeze(attempt.outcome.decision);
    for (const intent of attempt.outcome.plan) Object.freeze(intent);
    Object.freeze(attempt.outcome.plan);
    Object.freeze(attempt.outcome);
    attempt.chunks = [];
    attempt.size = 0;
    for (const intent of attempt.outcome.plan) {
      try { execute(Object.freeze({ ...intent })); }
      catch { /* External success is unknown. Never retry this intent here. */ }
    }
    return structuredClone(attempt.outcome);
  };
  const expired = (attempt: Attempt): boolean => now() >= attempt.deadline;
  return {
    async begin(context) {
      const existing = attempts.get(key(context));
      if (existing) {
        if (!same(existing.context, context)) return fallback();
        if (existing.outcome === null && expired(existing)) return finish(existing, { kind: "TimedOut" });
        return result(existing);
      }
      attempts.set(key(context), { context: Object.freeze({ ...context }),
        deadline: now() + DEADLINE_MS, chunks: [], size: 0, outcome: null });
      return null;
    },
    async chunk(context, bytes, final) {
      const attempt = lookup(context);
      if (!attempt) return fallback();
      if (attempt.outcome !== null) return result(attempt);
      if (expired(attempt)) return finish(attempt, { kind: "TimedOut" });
      if (bytes.byteLength > MAX_BYTES - attempt.size) return finish(attempt, { kind: "Oversized" });
      attempt.chunks.push(new Uint8Array(bytes));
      attempt.size += bytes.byteLength;
      if (!final) return null;
      const complete = new Uint8Array(attempt.size);
      let offset = 0;
      for (const part of attempt.chunks) { complete.set(part, offset); offset += part.byteLength; }
      // This event runs synchronously through terminal-state commit. The async
      // API introduces no await between receipt, decoding and dispatch. A
      // complete timely response cannot race a later timer event here.
      return finish(attempt, decodeNow(complete));
    },
    async fail(context) {
      const attempt = lookup(context);
      if (!attempt) return fallback();
      if (attempt.outcome !== null) return result(attempt);
      return finish(attempt, { kind: expired(attempt) ? "TimedOut" : "Failed" });
    },
    async tick(context) {
      const attempt = lookup(context);
      if (!attempt) return fallback();
      if (attempt.outcome !== null) return result(attempt);
      return expired(attempt) ? finish(attempt, { kind: "TimedOut" }) : null;
    },
  };
}
