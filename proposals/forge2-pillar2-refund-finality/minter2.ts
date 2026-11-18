// Round 3 task 3 (U428): minter version 2. Own operating-system process; the Ed25519 private key exists only in this
// process's memory. The DECISION is not written here: it is RefundMinterCore.Decide, proved with the pinned Dafny
// against the approved refund specification (core/RefundMinterCore.dfy) and compiled by `dafny build --target js`.
// The caller sends only (pre-state, request). Post-state and intent come from the core, never from the caller.
// NOT proved: this wrapper (shape check, conversions, canonical JSON, signing call), the Dafny JavaScript back end
// and runtime, Node and OpenSSL, the operating system's process isolation.
// Rule added here (unproved): at most one request is signed per pre-state hash for the life of the key, so two
// different signed claims for the same state cannot exist. Set FORGE_TEST_STATELESS=1 to switch the rule off (control).
import { generateKeyPairSync, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { createInterface } from "node:readline";
import { resolve } from "node:path";
import BigNumber from "bignumber.js";
import { ChargeState, Claim, RefundRequest, canon, isClaim, payload, sha256hex } from "./common";

const [corePath, specLockPath] = process.argv.slice(2);
export const MINTER2_FILES = ["minter2.ts", "common.ts"];
const minterSha256 = sha256hex(Buffer.concat([
  ...MINTER2_FILES.map(f => readFileSync(resolve(__dirname, f))), readFileSync(resolve(corePath))]));
const specLockSha256 = sha256hex(readFileSync(resolve(specLockPath)));
const { RefundMinterCore: C, runtime } = require(resolve(corePath));
const text = (s: string) => runtime.Seq.UnicodeFromString(s);
const back = (s: any): string => s.toVerbatimString(false);
const num = (s: string) => new BigNumber(s);
const dec = (n: any): string => BigInt(n.toFixed()).toString();

function decide(pre: ChargeState, request: RefundRequest): Claim | null {
  const r = C.__default.Decide(C.Charge.create_Charge(text(pre.chargeId), num(pre.original), num(pre.remaining), pre.refundEnabled),
    C.Request.create_Request(text(request.requestId), num(request.amount), text(request.reason)));
  if (!r.is_Sign) return null;
  const p = r.dtor_post, i = r.dtor_intent;
  return {
    specLockSha256, minterSha256, pre, reqId: request.requestId, request,
    post: { chargeId: back(p.dtor_chargeId), original: dec(p.dtor_original), remaining: dec(p.dtor_remaining), refundEnabled: p.dtor_refundEnabled },
    intent: { chargeId: back(i.dtor_chargeId), requestId: back(i.dtor_requestId), amount: dec(i.dtor_amount), reason: back(i.dtor_reason) },
  };
}

const singleUse = process.env.FORGE_TEST_STATELESS !== "1";
const signedFor = new Map<string, string>();          // pre-state hash -> request hash
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
process.stdout.write(JSON.stringify({
  ready: true, publicKeyPem: publicKey.export({ type: "spki", format: "pem" }), specLockSha256, minterSha256, singleUse }) + "\n");
createInterface({ input: process.stdin }).on("line", line => {
  let id: unknown = null;
  try {
    const msg = JSON.parse(line);
    id = msg.id;
    const pre = msg.pre, request = msg.request;
    // Shape check of pre and request through the claim validator (post and intent slots are filled with shaped dummies).
    const probe = { specLockSha256, minterSha256, pre, reqId: request?.requestId, request, post: pre,
      intent: { chargeId: pre?.chargeId, requestId: request?.requestId, amount: request?.amount, reason: request?.reason } };
    if (!isClaim(probe)) throw new Error("shape");
    const claim = decide(pre, request);
    if (claim === null) throw new Error("core: Refuse");
    if (!isClaim(claim)) throw new Error("core output shape");
    const preSha = sha256hex(canon(pre)), reqSha = sha256hex(canon(request));
    if (singleUse && signedFor.has(preSha) && signedFor.get(preSha) !== reqSha) throw new Error("another request is already signed for this pre-state");
    signedFor.set(preSha, reqSha);
    process.stdout.write(JSON.stringify({ id, ok: true, claim, sig: sign(null, payload(claim), privateKey).toString("base64") }) + "\n");
  } catch (error) {
    process.stdout.write(JSON.stringify({ id, ok: false, reason: String((error as Error).message) }) + "\n");
  }
});
