// DRAFT (night shift 2026-11-19, Orchestrator B, task d-minter). NOT adopted. TESTED-UNPROVED.
// The token issuer with the same interface as ts/refund-finality/minter.ts (arguments, ready line,
// one JSON message per line in, one answer line out).
// The DECISION and the TOKEN BODY are not written here. Both come from the compiled proved method
// IssueBytes2.IssueTokenBytes (src/IssueBytes2.dfy): it calls RefundFinality.Check, refuses a body that
// is not well-formed, and returns the UTF-8 bytes of the canonical body text. This file signs EXACTLY
// those bytes. It builds no body. It embeds the returned body text in the token text VERBATIM.
// This file does only: shape decode (refuse-only), SHA-256 of canon(pre) (glue G-H), conversion to core
// values, ONE call of IssueTokenBytes, refuse-only consistency checks, the single-use rule (unproved,
// U428), sign(bytes), and the answer text.
// NOT proved: this file, encoding.ts (canon, the shape checks, SHA-256 call), the Dafny JavaScript back end
// and runtime, Node and OpenSSL, process isolation.
// Arguments: <compiled IssueBytes2 module> <refund spec lock> <single-use: on | off>
import { generateKeyPairSync, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import BigNumber from "bignumber.js";
import {
  ChargeState, Transition, canon, checkerSha256Of, isState, isTokenBody, isTransition, sha256hex, stateSha256,
} from "../../../../ts/refund-finality/encoding";

const [corePath, specLockPath, singleUseArg] = process.argv.slice(2);
if (!corePath || !specLockPath || (singleUseArg !== "on" && singleUseArg !== "off")) {
  process.stderr.write("usage: minter_issuebytes.ts <compiled IssueBytes2 module> <refund spec lock> <on|off>\n");
  process.exit(2);
}
const singleUse = singleUseArg === "on";
const coreBytes = readFileSync(resolve(corePath));
const checkerSha256 = checkerSha256Of(coreBytes, readFileSync(resolve(__dirname, "../../../../ts/refund-finality/encoding.ts")),
  readFileSync(resolve(__dirname, "minter_issuebytes.ts")));
const specLockSha256 = sha256hex(readFileSync(resolve(specLockPath)));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const core = require(resolve(corePath));
const F = core.RefundFinality, R = core.Refund, I = core.IssueBytes2, runtime = core.runtime;
const text = (s: string): unknown => runtime.Seq.UnicodeFromString(s);
const back = (s: any): string => s.toVerbatimString(false);
const num = (s: string): BigNumber => new BigNumber(s);
const dec = (n: any): string => BigInt(n.toFixed()).toString();
const charge = (s: ChargeState): any => F.Charge.create_Charge(text(s.chargeId), num(s.original), num(s.remaining), s.refundEnabled);
const stateOf = (c: any): ChargeState =>
  ({ chargeId: back(c.dtor_chargeId), original: dec(c.dtor_original), remaining: dec(c.dtor_remaining), refundEnabled: c.dtor_refundEnabled });
const transition = (t: Transition): any => F.Transition.create_Transition(
  F.Request.create_Request(text(t.request.requestId), num(t.request.amount), text(t.request.reason)),
  charge(t.post),
  R.RefundIntent.create_Intent(text(t.intent.chargeId), text(t.intent.requestId), num(t.intent.amount), text(t.intent.reason)));
const utf8 = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });

// Returns the signed body bytes and their text, or null on refusal by the proved method.
function issue(pre: ChargeState, preStateSha256: string, t: Transition): { bytes: Buffer; bodyText: string; body: unknown } | null {
  const corePre = charge(pre);
  // [C1] conversion check (refuse-only): the core's pre-state reads back as the hashed pre-state (glue G-H).
  if (canon(stateOf(corePre)) !== canon(pre)) throw new Error("conversion: pre");
  const r = I.__default.IssueTokenBytes(corePre, transition(t), text(specLockSha256), text(checkerSha256), text(preStateSha256));
  // [D1] the proved decision. The only branch that can lead to a signature.
  if (r.is_Some !== true) return null;
  const raw: number[] = Array.from(r.dtor_value as Iterable<unknown>, (b: unknown) => Number(b));
  // [C2] conversion check (refuse-only): each element is a byte (the method proves it; this checks the runtime).
  if (!raw.every(b => Number.isInteger(b) && b >= 0 && b <= 255)) throw new Error("conversion: bytes");
  const bytes = Buffer.from(raw);
  const bodyText = utf8.decode(bytes);            // throws (refuse) on bytes that are not UTF-8
  const body: unknown = JSON.parse(bodyText);
  // [C3] consistency check (refuse-only): the returned text is the canonical text of a token body that
  // encoding.ts accepts, and its UTF-8 bytes are the returned bytes. Then the sink, which parses the token
  // text and computes signedBytes(token.body) = UTF-8(canon(body)), rebuilds exactly the signed bytes.
  if (!isTokenBody(body) || canon(body) !== bodyText || !Buffer.from(bodyText, "utf8").equals(bytes)) {
    throw new Error("conversion: body text");
  }
  // [C4] binding check (refuse-only): the body holds the request's values (proved for the core values;
  // a difference means that a conversion in this file is wrong).
  if (body.preStateSha256 !== preStateSha256 || body.requestId !== t.request.requestId ||
      canon(body.post) !== canon(t.post) || canon(body.intent) !== canon(t.intent)) throw new Error("conversion: token");
  return { bytes, bodyText, body };
}

const signedFor = new Map<string, string>();          // pre-state hash -> hash of the signed token body
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
process.stdout.write(JSON.stringify({
  ready: true, publicKeyPem: publicKey.export({ type: "spki", format: "pem" }), specLockSha256, checkerSha256, singleUse }) + "\n");
function handle(line: string): void {
  let id: number | null = null;
  try {
    const msg = JSON.parse(line);
    if (msg === null || typeof msg !== "object" || Array.isArray(msg)) throw new Error("message shape");     // [S1]
    if (typeof msg.id !== "number" || !Number.isSafeInteger(msg.id) || msg.id < 0) throw new Error("message id"); // [S2]
    id = msg.id;
    if (Object.keys(msg).sort().join(",") !== "id,pre,transition") throw new Error("message shape");     // [S3]
    const pre: unknown = msg.pre, transitionMsg: unknown = msg.transition;
    if (!isState(pre) || !isTransition(transitionMsg)) throw new Error("shape");                            // [S4]
    const preStateSha256 = stateSha256(pre);                                                                // glue G-H
    const issued = issue(pre, preStateSha256, transitionMsg);
    if (issued === null) throw new Error("core: Refuse");                                                   // [D1]
    const bodySha256 = sha256hex(issued.bytes);
    // [U1] single-use rule (unproved; owner decision U428), unchanged from minter.ts.
    if (singleUse && signedFor.has(preStateSha256) && signedFor.get(preStateSha256) !== bodySha256) {
      throw new Error("another transition is already signed for this pre-state");
    }
    if (singleUse) signedFor.set(preStateSha256, bodySha256);
    const signature = sign(null, issued.bytes, privateKey).toString("base64");
    // The token text embeds the returned body text verbatim. canon sorts "body" before "signature".
    const tokenText = "{\"body\":" + issued.bodyText + ",\"signature\":" + JSON.stringify(signature) + "}";
    // [C5] consistency check (refuse-only): this is the one canonical token text (encoding.ts tokenText).
    if (canon({ body: issued.body, signature }) !== tokenText) throw new Error("conversion: token text");
    process.stdout.write("{\"id\":" + String(id) + ",\"ok\":true,\"token\":" + tokenText + "}\n");
  } catch (error) {
    process.stdout.write(JSON.stringify({ id, ok: false, reason: String((error as Error).message) }) + "\n");
  }
}

// Line framing: unchanged from minter.ts (raw bytes, hard limit, one answer for an over-long line).
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
