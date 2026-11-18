// Slice 1 (F2.1): the token issuer. Its own operating-system process. The Ed25519 private key exists
// only in the memory of this process.
// The DECISION is not written here. It is RefundFinality.Check (impl/RefundFinality.dfy), proved with
// the pinned Dafny and compiled by `dafny build --target js`. This file converts values, calls Check,
// and signs the token that Check returns. The token fields come from the core's result, never from
// the caller's message.
// NOT proved: this file (shape check, conversions, canonical JSON, signing call), the Dafny JavaScript
// back end and runtime, Node and OpenSSL, the operating system's process isolation.
// The pre-state in a message is the caller's statement. This process cannot know the stored state.
// The sink compares the token's pre-state hash with its own store.
// Arguments: <compiled core module> <refund spec lock> <single-use: on | off>
//   single-use on: at most one transition is signed per pre-state hash for the life of the key.
//   That rule is unproved code. Which mode a deployment uses is an open owner decision (U428).
import { generateKeyPairSync, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import BigNumber from "bignumber.js";
import {
  ChargeState, DOMAIN, Intent, TokenBody, Transition, canon, checkerSha256Of, isState, isTokenBody, isTransition,
  sha256hex, signedBytes, stateSha256,
} from "./encoding";

const [corePath, specLockPath, singleUseArg] = process.argv.slice(2);
if (!corePath || !specLockPath || (singleUseArg !== "on" && singleUseArg !== "off")) {
  process.stderr.write("usage: minter.ts <compiled core module> <refund spec lock> <on|off>\n");
  process.exit(2);
}
const singleUse = singleUseArg === "on";
const coreBytes = readFileSync(resolve(corePath));
const checkerSha256 = checkerSha256Of(coreBytes, readFileSync(resolve(__dirname, "encoding.ts")), readFileSync(resolve(__dirname, "minter.ts")));
const specLockSha256 = sha256hex(readFileSync(resolve(specLockPath)));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const core = require(resolve(corePath));
const F = core.RefundFinality, R = core.Refund, runtime = core.runtime;
const text = (s: string): unknown => runtime.Seq.UnicodeFromString(s);
const back = (s: any): string => s.toVerbatimString(false);
const num = (s: string): BigNumber => new BigNumber(s);
const dec = (n: any): string => BigInt(n.toFixed()).toString();
const charge = (s: ChargeState): unknown => F.Charge.create_Charge(text(s.chargeId), num(s.original), num(s.remaining), s.refundEnabled);
const stateOf = (c: any): ChargeState =>
  ({ chargeId: back(c.dtor_chargeId), original: dec(c.dtor_original), remaining: dec(c.dtor_remaining), refundEnabled: c.dtor_refundEnabled });
const intentOf = (i: any): Intent =>
  ({ chargeId: back(i.dtor_chargeId), requestId: back(i.dtor_requestId), amount: dec(i.dtor_amount), reason: back(i.dtor_reason) });

// Returns the token body that the proved core issues, or null on refusal.
function check(pre: ChargeState, preStateSha256: string, t: Transition): TokenBody | null {
  const [verdict, plan] = F.__default.Check(charge(pre), text(preStateSha256), F.Transition.create_Transition(
    F.Request.create_Request(text(t.request.requestId), num(t.request.amount), text(t.request.reason)),
    charge(t.post),
    R.RefundIntent.create_Intent(text(t.intent.chargeId), text(t.intent.requestId), num(t.intent.amount), text(t.intent.reason))));
  if (verdict.is_Issue !== true) return null;
  const token = verdict.dtor_token;
  const body: TokenBody = {
    domain: DOMAIN, specLockSha256, checkerSha256,
    preStateSha256: back(token.dtor_preStateHash), requestId: back(token.dtor_requestId),
    post: stateOf(token.dtor_post), intent: intentOf(token.dtor_intent),
  };
  // Conversion checks. They can only refuse. The core proves these equalities for its own values;
  // a difference here means that a conversion in this file is wrong.
  if (plan.length !== 1 || canon(intentOf(plan[0])) !== canon(body.intent)) throw new Error("conversion: plan");
  if (!isTokenBody(body) || body.preStateSha256 !== preStateSha256 || body.requestId !== t.request.requestId ||
      canon(body.post) !== canon(t.post) || canon(body.intent) !== canon(t.intent)) throw new Error("conversion: token");
  return body;
}

const signedFor = new Map<string, string>();          // pre-state hash -> hash of the signed token body
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
process.stdout.write(JSON.stringify({
  ready: true, publicKeyPem: publicKey.export({ type: "spki", format: "pem" }), specLockSha256, checkerSha256, singleUse }) + "\n");
function handle(line: string): void {
  let id: number | null = null;
  try {
    const msg = JSON.parse(line);
    if (msg === null || typeof msg !== "object" || Array.isArray(msg)) throw new Error("message shape");
    // Only a small integer is sent back as the id. Any other id value is answered with id null.
    // (Review finding F4: a deeply nested id value ended this process when the answer was written.)
    if (typeof msg.id !== "number" || !Number.isSafeInteger(msg.id) || msg.id < 0) throw new Error("message id");
    id = msg.id;
    if (Object.keys(msg).sort().join(",") !== "id,pre,transition") throw new Error("message shape");
    const pre: unknown = msg.pre, transition: unknown = msg.transition;
    if (!isState(pre) || !isTransition(transition)) throw new Error("shape");
    const preStateSha256 = stateSha256(pre);
    const body = check(pre, preStateSha256, transition);
    if (body === null) throw new Error("core: Refuse");
    const bodySha256 = sha256hex(signedBytes(body));
    if (singleUse && signedFor.has(preStateSha256) && signedFor.get(preStateSha256) !== bodySha256) {
      throw new Error("another transition is already signed for this pre-state");
    }
    if (singleUse) signedFor.set(preStateSha256, bodySha256);
    process.stdout.write(JSON.stringify({ id, ok: true, token: { body, signature: sign(null, signedBytes(body), privateKey).toString("base64") } }) + "\n");
  } catch (error) {
    process.stdout.write(JSON.stringify({ id, ok: false, reason: String((error as Error).message) }) + "\n");
  }
}

// One message is one line, ended by the byte 0x0A. A line is cut out of the RAW BYTES here, with a hard
// limit, before any text is made of it. At most MAX_LINE_BYTES bytes of a line are held. A line that goes
// over the limit is answered once, at that moment, with id null; the rest of that line is dropped up to
// its end. (Node's readline collects a line of any length: a line of more than about 537 million
// characters with no end ended the earlier version of this process. Finding of the repair check.)
const MAX_LINE_BYTES = 65536;
let held: Buffer[] = [], heldBytes = 0, dropping = false;
process.stdin.on("data", (chunk: Buffer) => {
  let start = 0;
  while (start < chunk.length) {
    const newline = chunk.indexOf(0x0a, start), end = newline === -1 ? chunk.length : newline;
    if (!dropping) {
      if (heldBytes + (end - start) > MAX_LINE_BYTES) {
        held = []; heldBytes = 0; dropping = true;
        process.stdout.write(JSON.stringify({ id: null, ok: false, reason: "message too long" }) + "\n");
      } else if (end > start) {
        held.push(Buffer.from(chunk.subarray(start, end))); heldBytes += end - start;
      }
    }
    if (newline === -1) break;
    if (dropping) dropping = false;
    else { const line = Buffer.concat(held, heldBytes).toString("utf8"); held = []; heldBytes = 0; handle(line); }
    start = newline + 1;
  }
});
