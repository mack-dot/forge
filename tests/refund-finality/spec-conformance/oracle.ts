// Spec-conformance ORACLE for refund sinks (night shift 2026-11-19, task h-specdiff). TESTED-UNPROVED new code.
// It replays one store history and checks the properties P1-P7 of SPEC_ORACLE.md, and (task h-judges) P6R, P8, P9 and
// the dispatcher's EMITTED effects (P1, P2, P4 on emissions). P6R, P8 and P9 are properties of the Slice 1 finality
// design (sink.ts, dispatcher.ts headers) or of approved PR 63-65; SPEC_ORACLE.md names the source of each.
// The ONLY decision procedure it calls is the compiled APPROVED Refund.Assess (impl/Refund.dfy refines
// spec/refund/RefundSpec.dfy; compiled by `dafny build impl/RefundFinality.dfy --target js` as in
// scripts/exit_slice1.py). It imports no sink core (no ShellCore*, no SinkCore*, no RefundFinality function).
// encoding.ts is the TRUSTED one of the judge's own tree (../../../ts/refund-finality/encoding), never the one next
// to the sink under test. It gives canonical JSON, SHA-256, the signed bytes and the domain constant, CLASSIFIES a
// rejection as "outside the encoding.ts domain" (a spec-silent limit), and decides the token checks of P8.
// Unratified choices it relies on (PHASE2_RULES.md): OPEN-IS-UNSETTLED, POST-RULE.
// Trusted: the Dafny-to-JavaScript compiler and runtime, bignumber.js, Node (crypto, JSON), this file.
import { createPublicKey, verify, KeyObject } from "node:crypto";
import { createRequire } from "node:module";
import { resolve } from "node:path";
import { ChargeState, DOMAIN, canon, isToken, keyIdOf, sha256hex, signatureBytes, signedBytes } from "../../../ts/refund-finality/encoding";

export type OutRow = { request_id: string; intent: string };
export type Snapshot = { state: string | null; settled: string[]; outbox: OutRow[] };
export type Outcome = "committed" | "replayed" | "rejected";
// restart: not a delivery; the sink was closed and opened again (no token; outcome is ignored).
export type Delivery = { text: string; outcome: Outcome; reason?: string; faultInjected?: boolean; restart?: boolean; after: Snapshot };
// emitted: the effects that the dispatcher emitted for this store (optional; recorded by the driver's child).
export type Emitted = { requestId: string; intent: unknown };
export type History = {
  initial: ChargeState; publicKeyPem: string; specLockSha256: string; checkerSha256: string;
  start: Snapshot; deliveries: Delivery[]; emitted?: Emitted[]; startRefused?: string;
};
export type Prop = "P1" | "P2" | "P3" | "P4" | "P5" | "P5-SILENT" | "P6" | "P6R" | "P7" | "P8" | "P9";
export type Violation = { property: Prop; index: number; detail: string };
export type Verdict = { ok: boolean; first: Violation | null; violations: Violation[] };

const MAX_MONEY = 9223372036854775807n;
const DEC = /^-?(0|[1-9][0-9]*)$/;
type Money = { s: string; n: bigint };
type PState = { chargeId: string; original: bigint; remaining: bigint; refundEnabled: boolean };
type LIntent = { chargeId: string; requestId: string; amount: string; reason: string };
type LBody = { domain: unknown; specLockSha256: unknown; checkerSha256: unknown; preStateSha256: unknown;
  requestId: string; post: unknown; intent: LIntent };

const isObj = (x: unknown): x is Record<string, unknown> =>
  x !== null && typeof x === "object" && !Array.isArray(x) && Object.getPrototypeOf(x) === Object.prototype;
const keysAre = (x: Record<string, unknown>, ks: string[]) =>
  Object.keys(x).sort().join("\u0001") === [...ks].sort().join("\u0001");
const money = (v: unknown): Money | null => (typeof v === "string" && DEC.test(v) ? { s: v, n: BigInt(v) } : null);

// The persisted charge, read leniently (no length limit). null = not a charge state at all.
export function parseState(text: string | null): PState | null {
  if (text === null) return null;
  let v: unknown; try { v = JSON.parse(text); } catch { return null; }
  if (!isObj(v) || !keysAre(v, ["chargeId", "original", "remaining", "refundEnabled"])) return null;
  const o = money(v.original), r = money(v.remaining);
  if (typeof v.chargeId !== "string" || o === null || r === null || typeof v.refundEnabled !== "boolean") return null;
  return { chargeId: v.chargeId, original: o.n, remaining: r.n, refundEnabled: v.refundEnabled };
}
const stateText = (s: PState): string => canon({ chargeId: s.chargeId, original: s.original.toString(),
  remaining: s.remaining.toString(), refundEnabled: s.refundEnabled });
function parseIntent(v: unknown): LIntent | null {
  if (!isObj(v) || !keysAre(v, ["chargeId", "requestId", "amount", "reason"])) return null;
  if (typeof v.chargeId !== "string" || typeof v.requestId !== "string" || typeof v.reason !== "string" || money(v.amount) === null) return null;
  return { chargeId: v.chargeId, requestId: v.requestId, amount: v.amount as string, reason: v.reason };
}
// Lenient token decoder: the token structure WITHOUT the encoding.ts limits (256 units, U+0000, 8192 units).
// D-1 (h-key): a token is {body, keyId, signature}; the oracle's pin is ONE key (h.publicKeyPem), its key id = keyIdOf.
export function lenientToken(text: string): { body: LBody; keyId: string; signature: string; raw: unknown } | null {
  let v: unknown; try { v = JSON.parse(text); } catch { return null; }
  if (!isObj(v) || !keysAre(v, ["body", "keyId", "signature"]) || typeof v.signature !== "string" || typeof v.keyId !== "string") return null;
  const b = v.body;
  if (!isObj(b) || !keysAre(b, ["domain", "specLockSha256", "checkerSha256", "preStateSha256", "requestId", "post", "intent"])) return null;
  const intent = parseIntent(b.intent);
  if (typeof b.requestId !== "string" || intent === null) return null;
  return { body: { ...(b as any), requestId: b.requestId, intent }, keyId: v.keyId, signature: v.signature, raw: v };
}

export class Oracle {
  private readonly R: any; private readonly rt: any; private readonly BN: any;
  readonly coreModule: string;
  constructor(coreModulePath: string) {
    this.coreModule = resolve(coreModulePath);
    const req = createRequire(this.coreModule);
    const mod = req(this.coreModule);
    if (!mod || !mod.Refund || typeof mod.Refund.__default?.Assess !== "function") throw new Error("module has no Refund.Assess");
    this.R = mod.Refund; this.rt = mod.runtime; this.BN = req("bignumber.js");
  }
  // The approved Assess on Context(chargeId, requestId, original, remaining, refundEnabled, open) and
  // Candidate(amount, reason). Returns the authorized intent (as text values) or null (Rejected or not formable:
  // a value outside the Dafny string domain, e.g. a lone surrogate, is not a Context or a Candidate).
  assess(pre: PState, requestId: string, open: boolean, amount: string, reason: string): LIntent | null {
    const R = this.R, T = (s: string) => this.rt.Seq.UnicodeFromString(s), N = (s: string) => new this.BN(s);
    let decision: any, plan: any;
    try {
      const ctx = R.Context.create_ChargeContext(T(pre.chargeId), T(requestId), N(pre.original.toString()),
        N(pre.remaining.toString()), pre.refundEnabled, open);
      [decision, plan] = R.__default.Assess(ctx, R.ModelResponse.create_Candidate(N(amount), T(reason)));
    } catch { return null; }
    if (decision.is_Authorized !== true) { if (plan.length !== 0) throw new Error("Assess: plan on Rejected"); return null; }
    if (plan.length !== 1) throw new Error("Assess: plan length");
    const i = plan[0], S = (x: any): string => x.toVerbatimString(false);
    const out = { chargeId: S(i.dtor_chargeId), requestId: S(i.dtor_requestId), amount: i.dtor_amount.toFixed(), reason: S(i.dtor_reason) };
    // R4 says Authorized(amount, reason) carries exactly the candidate; check the decision too.
    if (decision.dtor_amount.toFixed() !== amount || S(decision.dtor_reason) !== reason) return null;
    return out;
  }

  check(h: History): Verdict {
    const vs: Violation[] = [];
    const flag = (property: Prop, index: number, detail: string) => vs.push({ property, index, detail });
    const key: KeyObject = createPublicKey(h.publicKeyPem), pinnedKeyId = keyIdOf(key);
    const c0Text = canon(h.initial), c0 = parseState(c0Text);
    if (c0 === null) throw new Error("initial charge is not a charge state");
    // A sink that refuses to start on an initial charge that is an approved ValidContext (RS 27-31: charge id
    // nonempty, refundEnabled, Money(original), 0 <= remaining <= original) rejects every authorized token of that
    // charge: P5. Refusing a charge with refundEnabled false (no token for it can be authorized) is not flagged.
    if (h.startRefused !== undefined) {
      const c = parseState(canon(h.initial));
      const validCtx = c !== null && c.chargeId !== "" && c.refundEnabled && 0n <= c.remaining && c.remaining <= c.original && c.original <= MAX_MONEY;
      if (validCtx) flag("P5", -1, "sink refused to start or to init on a valid initial charge: " + h.startRefused);
      return { ok: vs.length === 0, first: vs[0] ?? null, violations: vs };
    }
    if (h.start.state !== c0Text || h.start.settled.length !== 0 || h.start.outbox.length !== 0) flag("P3", -1, "store after init is not the initial charge");
    const committedTexts = new Set<string>();      // token texts that a delivery committed (P6R)
    const effects = new Set<string>();             // (charge id, request id) of every effect so far
    const sum = new Map<string, bigint>();         // charge id -> sum of effect amounts
    const valid = (s: PState) => 0n <= s.remaining && s.remaining <= s.original && s.original <= MAX_MONEY;
    if (!valid(c0)) flag("P3", -1, "initial charge violates 0 <= remaining <= original <= MaxMoney");
    let prev = h.start;
    h.deliveries.forEach((d, i) => {
      const after = d.after, pre = parseState(prev.state);
      const sameSnap = (a: Snapshot, b: Snapshot) => a.state === b.state && canon(a.settled) === canon(b.settled) &&
        canon(a.outbox.map(r => [r.request_id, r.intent])) === canon(b.outbox.map(r => [r.request_id, r.intent]));
      if (d.restart) {                               // P9: a restart changes no durable state
        if (!sameSnap(after, prev)) flag("P9", i, `durable state changed across a restart (settled ${prev.settled.length} -> ${after.settled.length}, outbox ${prev.outbox.length} -> ${after.outbox.length})`);
        prev = after; return;
      }
      const same = after.state === prev.state && canon(after.settled) === canon(prev.settled) &&
        canon(after.outbox.map(r => [r.request_id, r.intent])) === canon(prev.outbox.map(r => [r.request_id, r.intent]));
      const tok = lenientToken(d.text);
      if (d.outcome !== "committed") {
        if (!same) flag("P6", i, `${d.outcome} delivery changed durable state`);
        // P6R (PR 63-65): an identical repeat of a COMMITTED token answers "replayed"; "replayed" is only for that.
        if (d.outcome === "replayed" && !committedTexts.has(d.text)) flag("P6R", i, "answered replayed for a token that was never committed (another token for a settled id must be rejected)");
        if (d.outcome === "rejected" && !d.faultInjected && committedTexts.has(d.text)) flag("P6R", i, "identical repeat of a committed token answered rejected, not replayed");
        // P5: would the approved spec (with OPEN-IS-UNSETTLED and POST-RULE) authorize exactly this token?
        if (!d.faultInjected && tok !== null && pre !== null) {
          const b = tok.body;
          const pinned = b.domain === DOMAIN && b.specLockSha256 === h.specLockSha256 && b.checkerSha256 === h.checkerSha256;
          let sigOk = false;
          try { const raw = Buffer.from(tok.signature, "base64");
            sigOk = raw.length === 64 && tok.keyId === pinnedKeyId && verify(null, signedBytes(b as any, tok.keyId), key, raw); } catch { sigOk = false; }
          const fresh = !prev.settled.includes(b.requestId);
          const current = prev.state !== null && b.preStateSha256 === sha256hex(prev.state);
          const auth = pinned && sigOk && fresh && current ? this.assess(pre, b.requestId, fresh, b.intent.amount, b.intent.reason) : null;
          const postOk = auth !== null && canon(b.post) === stateText({ ...pre, remaining: pre.remaining - BigInt(b.intent.amount) });
          if (auth !== null && postOk && canon(auth) === canon(b.intent)) {
            const inDomain = d.text.length <= 8192 && isToken(tok.raw) && canon(tok.raw) === d.text;
            flag(inDomain ? "P5" : "P5-SILENT", i, `authorized, validly signed, fresh, current token was ${d.outcome}: ${d.reason ?? ""}` +
              (inDomain ? "" : " (token outside the encoding.ts domain: length, U+0000 or non-canonical text)"));
          }
        }
      } else {
        committedTexts.add(d.text);
        // P8 AUTHENTICITY OF COMMITS (Slice 1 finality design; the approved protocol.md is SILENT on tokens): the
        // committed delivery is the ONE canonical text of a token (trusted encoding.ts) with the pinned domain and ids,
        // whose Ed25519 signature verifies under the PINNED key over the TRUSTED signed bytes, whose pre-state hash is
        // the hash of the persisted state immediately before, and whose signed request id, intent and post are what
        // the store records.
        let parsed: unknown = null; try { parsed = JSON.parse(d.text); } catch { parsed = null; }
        const p8: string[] = [];
        if (!isToken(parsed)) p8.push("not a token of the encoding.ts domain");
        else {
          const b = parsed.body;
          if (canon(parsed) !== d.text) p8.push("token text is not canonical");
          if (b.domain !== DOMAIN || b.specLockSha256 !== h.specLockSha256 || b.checkerSha256 !== h.checkerSha256) p8.push("domain or ids are not the pinned ones");
          let sigOk = false;
          try { const raw = signatureBytes(parsed.signature); sigOk = raw !== null && parsed.keyId === pinnedKeyId && verify(null, signedBytes(b, parsed.keyId), key, raw); } catch { sigOk = false; }
          if (!sigOk) p8.push("signature does not verify under the pinned key over the trusted signed bytes");
          if (prev.state === null || b.preStateSha256 !== sha256hex(prev.state)) p8.push("pre-state hash is not the hash of the persisted state");
          const newRows = after.outbox.slice(prev.outbox.length);
          if (newRows.length !== 1 || newRows[0].request_id !== b.requestId || newRows[0].intent !== canon(b.intent)) p8.push("recorded outbox row is not the signed request id and intent");
          if (after.state !== canon(b.post)) p8.push("persisted state is not the signed post state");
        }
        if (p8.length) flag("P8", i, p8.join("; "));
        const isPrefix = after.outbox.length >= prev.outbox.length && prev.outbox.every((r, k) =>
          after.outbox[k].request_id === r.request_id && after.outbox[k].intent === r.intent);
        if (!isPrefix) flag("P1", i, "outbox is not an extension of the previous outbox (an effect changed or vanished)");
        const added = isPrefix ? after.outbox.slice(prev.outbox.length) : [];
        if (isPrefix && added.length !== 1) flag("P1", i, `committed delivery released ${added.length} effects, not exactly one`);
        // The request id of the commit: the token's body.requestId (the id the sink settles).
        const reqId = tok?.body.requestId;
        let total = 0n;
        for (const row of added) {
          let iv: unknown; try { iv = JSON.parse(row.intent); } catch { iv = null; }
          const e = parseIntent(iv);
          if (e === null) { flag("P1", i, "effect is not an intent"); continue; }
          const rid = reqId ?? row.request_id;
          if (pre === null || e.chargeId !== pre.chargeId) flag("P7", i, `effect charge id ${JSON.stringify(e.chargeId)} is not the persisted charge id`);
          const k = canon([e.chargeId, e.requestId]);
          if (effects.has(k)) flag("P2", i, `second effect for (charge id, request id) ${k}`);
          effects.add(k);
          const open = !prev.settled.includes(rid);                       // OPEN-IS-UNSETTLED
          const auth = pre === null ? null : this.assess(pre, rid, open, e.amount, e.reason);
          if (auth === null || canon(auth) !== canon(e) || row.request_id !== e.requestId)
            flag("P1", i, `effect ${row.intent} is not the one intent that Assess authorizes (request ${JSON.stringify(rid)}, open=${open})`);
          const s = (sum.get(e.chargeId) ?? 0n) + BigInt(e.amount);
          sum.set(e.chargeId, s);
          if (e.chargeId === c0.chargeId && s > c0.original) flag("P4", i, `sum of effects ${s} exceeds original ${c0.original}`);
          total += BigInt(e.amount);
        }
        // P3: POST-RULE (unratified): remaining decreases by the amount; nothing else changes.
        if (pre !== null && added.length >= 1) {
          const expected = stateText({ ...pre, remaining: pre.remaining - total });
          if (after.state !== expected) flag("P3", i, `post state ${after.state} is not POST-RULE ${expected}`);
        }
      }
      // Validity is flagged where the persisted state CHANGES to an invalid one (not again at each later step).
      const ps = parseState(after.state);
      if (after.state === prev.state) { /* unchanged: judged where it changed */ }
      else if (ps === null) flag("P3", i, "persisted state is not a charge state");
      else if (!valid(ps)) flag("P3", i, "persisted state violates 0 <= remaining <= original <= MaxMoney");
      prev = after;
    });
    // Dispatcher EMISSIONS (when recorded): P2 at most one emitted effect per (charge id, request id); P4 the sum
    // emitted for the charge <= its original; P1 every emitted intent is an intent of the final outbox.
    if (h.emitted !== undefined) {
      const seen = new Set<string>(); let total = 0n;
      const rows = new Set(prev.outbox.map(r => canon([r.request_id, r.intent])));
      for (const e of h.emitted) {
        const iv = parseIntent(e.intent);
        if (iv === null) { flag("P1", -2, "emitted effect is not an intent"); continue; }
        const k = canon([iv.chargeId, iv.requestId]);
        if (seen.has(k)) flag("P2", -2, `dispatcher emitted a second effect for ${k}`);
        seen.add(k);
        if (!rows.has(canon([e.requestId, canon(iv)]))) flag("P1", -2, `emitted effect ${canon(iv)} is not an outbox intent of the store`);
        if (iv.chargeId === c0.chargeId) { total += BigInt(iv.amount); }
      }
      if (total > c0.original) flag("P4", -2, `dispatcher emitted ${total} for a charge of ${c0.original}`);
    }
    return { ok: vs.length === 0, first: vs[0] ?? null, violations: vs };
  }
}
