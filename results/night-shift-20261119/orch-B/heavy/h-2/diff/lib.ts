// d-v3sink copy (night shift 2026-11-19): adds the V3 core adapter (SinkCoreV3.Step on the full token; plus a
// runtime cross-check against the compiled ShellCoreV3.StepP with preOk := (core.charge == pre)), the reason
// ChargeIdMismatch, and the sinks hand-v3, cb-v3, cb-reqid. Core file by Z4_CORE (sinkcore-v3.cjs, sinkcore-reqid.cjs).
// Z4 (M1-B wave 5) shared harness code. NOT repository code. NOT a proof. A finite differential TEST.
// Loads the compiled Dafny sink core (SinkCore.Step, compiled by the pinned Dafny into this folder) and a sink
// module by path (the repository sink.ts unchanged, or a copy in this folder).
import { generateKeyPairSync, sign, verify, KeyObject, createPublicKey } from "node:crypto";
import { readFileSync } from "node:fs";
import * as sqlite from "node:sqlite";
import { ChargeState, DOMAIN, Intent, TokenBody, canon, sha256hex, signedBytes, stateSha256 } from "<REPO>/ts/refund-finality/encoding";

export const ROOT = "<REPO>";
export const Z = __dirname;
// eslint-disable-next-line @typescript-eslint/no-require-imports
const M = require(Z + "/" + (process.env.Z4_CORE ?? "sinkcore.cjs"));
const SC = M.SinkCore, F = M.RefundFinality, R = M.Refund, rt = M.runtime;
// The V3 shell core (present only in sinkcore-v3.cjs): its StepP and AuditStart.
const SHELL = M.Shell && M.Shell.__default && M.Shell.__default.StepP && M.Shell.__default.AuditStart ? M.Shell : null;
const SHELL6 = M.Shell6 && M.Shell6.__default && M.Shell6.__default.StepQ6 ? M.Shell6 : null;   // d-v6sink
export const coreKind = SHELL6 ? "v6" : SHELL ? "v3" : "other";
export const shellChecks: any = { stepP: 0, audit: 0 };
// eslint-disable-next-line @typescript-eslint/no-require-imports
const BigNumber = require("bignumber.js");

export const SINKS: Record<string, string> = {
  real: ROOT + "/ts/refund-finality/sink.ts",
  "patched-reqid": Z + "/patched/sink-reqid.ts",
  "hand-v3": Z + "/patched/sink-reqid-chargeid.ts",
  "cb-v3": Z + "/sinks/cb-v3.ts",
  "cb-v6": Z + "/sinks/cb-v6.ts",
  "cb-h1": Z + "/sinks/cb-h1.ts",
  "cb-reqid": Z + "/sinks/cb-reqid.ts",
  nocheck: Z + "/broken/sink-nocheck.ts",
  twotx: Z + "/broken/sink-twotx.ts",
  toctou: Z + "/broken/sink-toctou.ts",
};
// eslint-disable-next-line @typescript-eslint/no-require-imports
export const loadSink = (name: string): any => require(SINKS[name]).Sink;

// ---- keys and ids (test keys: generated in this process, as tests/refund-finality/suite.ts does for its attacker key)
export const SPEC_LOCK = sha256hex(readFileSync(ROOT + "/spec/refund/spec.lock"));
export const CHECKER = sha256hex("Z4 test checker id");
export const OTHER_HEX = sha256hex("Z4 other id");
export const trusted = generateKeyPairSync("ed25519");
export const attacker = generateKeyPairSync("ed25519");
export const cfg = { publicKeyPem: trusted.publicKey.export({ type: "spki", format: "pem" }) as string, specLockSha256: SPEC_LOCK, checkerSha256: CHECKER };
const trustedPub: KeyObject = createPublicKey(cfg.publicKeyPem);

export function body(pre: ChargeState, requestId: string, post: ChargeState, intent: Intent, o: { spec?: string; chk?: string; preHash?: string } = {}): TokenBody {
  return { domain: DOMAIN, specLockSha256: o.spec ?? SPEC_LOCK, checkerSha256: o.chk ?? CHECKER,
    preStateSha256: o.preHash ?? stateSha256(pre), requestId, post, intent };
}
export function tokenText(b: TokenBody, key = trusted.privateKey, flip = false): string {
  const sig = sign(null, signedBytes(b), key);
  if (flip) sig[5] ^= 0x01;
  return canon({ body: b, signature: sig.toString("base64") });
}
export const refund = (pre: ChargeState, rid: string, amount: bigint, reason = "returned_item", intentRid = rid) => {
  const post = { ...pre, remaining: (BigInt(pre.remaining) - amount).toString() };
  return { post, intent: { chargeId: pre.chargeId, requestId: intentRid, amount: amount.toString(), reason } };
};

// ---- the map from a token text to the core's input (the decoder is NOT modelled: shape failures do not step)
export const known = new Map<string, ChargeState>();      // preStateSha256 -> state VALUE (A4 in the harness)
export const remember = (s: ChargeState) => { known.set(stateSha256(s), s); return s; };
const T = (s: string) => rt.Seq.UnicodeFromString(s);
const N = (s: string) => new BigNumber(s);
export const dCharge = (s: ChargeState) => F.Charge.create_Charge(T(s.chargeId), N(s.original), N(s.remaining), s.refundEnabled);
const dIntent = (i: Intent) => R.RefundIntent.create_Intent(T(i.chargeId), T(i.requestId), N(i.amount), T(i.reason));
const back = (s: any): string => s.toVerbatimString(false);
const dec = (n: any): string => BigInt(n.toFixed()).toString();
const UNKNOWN = (h: string) => F.Charge.create_Charge(T("\u0001unknown-pre:" + h), N("-1"), N("-1"), false);

export type Decoded = { tok: any; sigOk: boolean } | null;
export function decode(text: string): Decoded {
  let t: any;
  try { t = JSON.parse(text); } catch { return null; }
  if (canon(t) !== text) return null;        // the core has no decoder: non-canonical text is out of its domain
  const b = t.body as TokenBody;
  let sigOk = false;
  try { sigOk = verify(null, signedBytes(b), trustedPub, Buffer.from(t.signature, "base64")); } catch { sigOk = false; }
  const pre = known.has(b.preStateSha256) ? dCharge(known.get(b.preStateSha256)!) : UNKNOWN(b.preStateSha256);
  const tok = SC.SinkToken.create_SinkToken(N(b.specLockSha256 === SPEC_LOCK ? "1" : "0"), N(b.checkerSha256 === CHECKER ? "2" : "0"),
    pre, T(b.requestId), dCharge(b.post), dIntent(b.intent), T(""));
  return { tok, sigOk };
}
export const coreInit = (s: ChargeState) => SC.Core.create_Core(dCharge(s), rt.Set.Empty, rt.Seq.of());
export function coreStep(core: any, text: string): { core: any; out: string } {
  const d = decode(text);
  if (d === null) return { core, out: "rejected:Decode" };
  const r = SC.__default.Step(core, d.tok, d.sigOk);
  if (SHELL) {
    // The V3 adapter: map the full core token to the shell token (pre dropped; preOk := stored == pre, the A4'
    // form) and check that the compiled StepP gives the same result as the compiled Step (StepPAgrees, at runtime),
    // and that AuditStart holds on every core state reached from a fresh start (StepPKeepsGoodV3, at runtime).
    const t = d.tok;
    const st = SHELL.ShellToken.create_ShellToken(t.dtor_specId, t.dtor_checkerId, t.dtor_requestId, t.dtor_post, t.dtor_intent, t.dtor_sig);
    const rp = SHELL.__default.StepP(core, st, d.sigOk, rt.areEqual(core.dtor_charge, t.dtor_pre));
    shellChecks.stepP++;
    if (!rt.areEqual(rp, r)) throw new Error("V3 adapter: compiled StepP differs from compiled Step");
    shellChecks.audit++;
    if (SHELL.__default.AuditStart(r.dtor_core) !== true) throw new Error("V3 adapter: AuditStart false on a reached core state");
  }
  const o = r.dtor_out;
  if (SHELL6) {
    // d-v6sink: the V6 reference. StepQ6 on the stored charge; preOk := stored == pre (A4' form); settled lookup.
    const t = d.tok;
    const st6 = M.Shell.ShellToken.create_ShellToken(t.dtor_specId, t.dtor_checkerId, t.dtor_requestId, t.dtor_post, t.dtor_intent, t.dtor_sig);
    const q = SHELL6.__default.StepQ6(core.dtor_charge, st6, d.sigOk, rt.areEqual(core.dtor_charge, t.dtor_pre), core.dtor_settled.contains(t.dtor_requestId));
    shellChecks.stepQ6 = (shellChecks.stepQ6 ?? 0) + 1;
    if (q.is_Commit) {
      if (!o.is_Committed) throw new Error("V6 adapter: StepQ6 commits where V3 Step rejects");
      return { core: r.dtor_core, out: "committed" };
    }
    if (q.is_Reject) {
      if (o.is_Committed || whyName(o.dtor_why) !== whyName(q.dtor_why)) throw new Error("V6 adapter: StepQ6 reason differs from V3 Step");
      return { core: r.dtor_core, out: "rejected:" + whyName(q.dtor_why) };
    }
    if (!o.is_Committed) throw new Error("V6 adapter: RejectNotAuthorized where V3 Step rejects");
    return { core, out: "rejected:NotAuthorized" };
  }
  return { core: r.dtor_core, out: o.is_Committed ? "committed" : "rejected:" + whyName(o.dtor_why) };
}
function whyName(w: any): string {
  for (const n of ["ReqIdMismatch", "IdsNotPinned", "SignatureInvalid", "RequestSettled", "PreStateMismatch", "ChargeIdMismatch", "NoSuchCharge"]) if (w["is_" + n]) return n;
  return "?";
}
export const enc = (s: string): string => SC.__default.Enc(T(s)).toFixed();
// The concrete part of Rel: store == charge; EncSet(settled ids) == EncSet(core settled); outbox == core outbox.
export function coreView(core: any) {
  const c = core.dtor_charge;
  return {
    charge: canon({ chargeId: back(c.dtor_chargeId), original: dec(c.dtor_original), remaining: dec(c.dtor_remaining), refundEnabled: c.dtor_refundEnabled }),
    settledEnc: Array.from(core.dtor_settled as any[]).map(s => SC.__default.Enc(s).toFixed()).sort(),
    outbox: Array.from(core.dtor_outbox as any[]).map(i => canon({ chargeId: back(i.dtor_chargeId), requestId: back(i.dtor_requestId), amount: dec(i.dtor_amount), reason: back(i.dtor_reason) })),
  };
}
export function sinkView(sink: any) {
  const blob = sink.storedBlob();
  return {
    charge: blob === undefined ? "<none>" : canon(JSON.parse(blob)),
    settledEnc: sink.settled().map((r: any) => enc(r.request_id)).sort(),
    outbox: sink.outbox().map((r: any) => r.intent as string),
  };
}
export function sinkOut(r: { status: string; reason?: string }): string {
  if (r.status === "committed") return "committed";
  if (r.status === "replayed") return "rejected:RequestSettled";
  const m: Record<string, string> = {
    "spec lock is not the pinned one": "IdsNotPinned", "checker is not the pinned one": "IdsNotPinned",
    "signature does not verify": "SignatureInvalid", "request id is already settled with another token": "RequestSettled",
    "stored state is not the token's pre-state": "PreStateMismatch", "token shape": "Decode", "token text is not canonical": "Decode",
    "token is not a text": "Decode", "request id is not the intent's request id": "ReqIdMismatch",
    "charge id is not the stored charge id": "ChargeIdMismatch",
    "not authorized by the approved relation for the stored state": "NotAuthorized",
  };
  return "rejected:" + (m[r.reason ?? ""] ?? ("OTHER(" + r.reason + ")"));
}

// ---- fault and interleaving hooks on node:sqlite (in THIS process only)
export const hook: { faultAt: number; commits: number; beforeBegin: null | ((db: any) => void); conn: any } = { faultAt: 0, commits: 0, beforeBegin: null, conn: null };
const D = sqlite.DatabaseSync.prototype as any, origExec = D.exec;
D.exec = function (sql: string) {
  const tag = sql.trim().split(/\s+/)[0].toUpperCase();
  if (this === hook.conn && tag === "BEGIN" && hook.beforeBegin) { const f = hook.beforeBegin; hook.beforeBegin = null; f(this); }
  if (this === hook.conn && tag === "COMMIT" && hook.faultAt > 0) {
    hook.commits++;
    if (hook.commits === hook.faultAt) throw new Error("Z4 injected fault at COMMIT #" + hook.commits);
  }
  return origExec.call(this, sql);
};

// ---- seeded random numbers (mulberry32)
export function rng(seed: number) {
  let a = seed >>> 0;
  const next = () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  return { next, int: (n: number) => Math.floor(next() * n), pick: <X>(xs: X[]) => xs[Math.floor(next() * xs.length)] };
}
