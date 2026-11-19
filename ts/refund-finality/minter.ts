// Slice 1 (F2.1): the token issuer. Its own operating-system process. TESTED-UNPROVED as a whole.
// The Ed25519 private key exists only in the memory of this process. A new test key is made at every start
// (C-ATT-05: a restart changes the key; key persistence is an open owner decision: see KEY_OPTIONS in the
// night-shift evidence h-minter).
// The same interface as the earlier minter.ts (arguments, ready line, one JSON message per line in, one answer
// line out).
// The DECISION, the TOKEN BODY and the MEMORY RULE are not written here. They come from ONE call of the compiled
// proved method IssueOnce.Issue (impl/finality-core/IssueOnce.dfy). It calls IssueBytes2.IssueTokenBytes
// (RefundFinality.Check, the well-formed-body guard, the UTF-8 bytes of the canonical body text) and applies the
// memory rule keyed on (charge id, request id):
//   new key -> Issued; identical retry -> Replayed (the stored bytes); same key, other candidate -> refused.
//   A different request id on the same pre-state is NOT refused (zero-amount and abandoned tokens freeze nothing:
//   red-team finding C-ATT-03 against the earlier rule "one transition per pre-state hash", U428).
// This file signs EXACTLY the returned bytes. It builds no body. It embeds the returned body text VERBATIM.
// This file does only: line framing with a STRICT UTF-8 decode (C-ATT-15), shape decode (refuse-only), the
// pre-state hash in ONE place (glue G-H), conversion to core values, ONE call of IssueOnce.Issue, refuse-only
// consistency checks, sign(bytes), and the answer text.
// NOT proved: this file, encoding.ts (canon, the shape checks, SHA-256 call), the Dafny JavaScript back end and
// runtime, bignumber.js, Node and OpenSSL, process isolation.
// The memory of mode "on" is PROCESS MEMORY: it is lost at restart (and the key is lost with it).
// Arguments: <compiled IssueOnce module> <refund spec lock> <memory rule: on | off>
//   on : the (charge id, request id) memory rule of IssueOnce.Issue for the life of the process.
//   off: no memory (IssueOnce.Issue with an empty memory every time): the decision of IssueTokenBytes only.
//   Either way an identical request gets a byte-identical token (Ed25519 signatures are deterministic).
// Start refusals: NODE_OPTIONS set (code from outside the identified files could run in this process: C-ATT-14);
// a module without IssueOnce.
import { generateKeyPairSync, sign, createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { resolve } from "node:path";
import BigNumber from "bignumber.js";
import {
  ChargeState, Transition, canon, checkerSha256Of, isState, isTokenBody, isTransition, sha256hex, stateSha256,
} from "./encoding";

const [corePath, specLockPath, memoryArg] = process.argv.slice(2);
if (!corePath || !specLockPath || (memoryArg !== "on" && memoryArg !== "off")) {
  process.stderr.write("usage: minter.ts <compiled IssueOnce module> <refund spec lock> <on|off>\n");
  process.exit(2);
}
// C-ATT-14: NODE_OPTIONS can make Node load other code (--require, --import, --loader) into this key-holding
// process. The checker id does not cover such code. Refuse to start. (NODE_PATH is reported below, not refused.)
if (process.env.NODE_OPTIONS !== undefined && process.env.NODE_OPTIONS !== "") {
  process.stderr.write("minter.ts: refused to start: NODE_OPTIONS is set\n");
  process.exit(2);
}
const memoryOn = memoryArg === "on";
const coreBytes = readFileSync(resolve(corePath));
const checkerSha256 = checkerSha256Of(coreBytes, readFileSync(resolve(__dirname, "encoding.ts")), readFileSync(resolve(__dirname, "minter.ts")));
const specLockSha256 = sha256hex(readFileSync(resolve(specLockPath)));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const core = require(resolve(corePath));
if (!core || !core.IssueOnce || !core.IssueBytes2 || !core.RefundFinality) {
  process.stderr.write("minter.ts: refused to start: the module does not export IssueOnce (build impl/finality-core/IssueOnce.dfy)\n");
  process.exit(2);
}
const F = core.RefundFinality, R = core.Refund, O = core.IssueOnce, runtime = core.runtime;
// Extra identity information (NOT part of the checker id; changing the id is the owner's decision): the resolved
// file of bignumber.js that this process and the core module use, and the Node version. Written to stderr, so the
// ready line keeps its exact key set (tests/refund-finality/suite.ts pins it).
// bignumber.js is resolved twice: once from this file and once from the core module's own directory (the core
// module requires it from there; C-ATT-14 used a copy of the core module next to another bignumber.js).
{
  const file = (from: NodeJS.Require): { path: string; sha256: string } => {
    const path = from.resolve("bignumber.js");
    return { path, sha256: createHash("sha256").update(readFileSync(path)).digest("hex") };
  };
  process.stderr.write(JSON.stringify({ issuerIdentityInfo: {
    bignumberForMinter: file(require), bignumberForCore: file(createRequire(resolve(corePath))),
    node: process.version, nodePath: process.env.NODE_PATH ?? null } }) + "\n");
}
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

// THE PRE-STATE, IN ONE PLACE (glue G-H). From ONE decoded value `pre`: its canonical text, the hash of that text,
// and the core value. Refuse-only checks: the canonical text parses back to a state with the same canonical text,
// and the core value reads back as the same canonical text. The hash and the core value then describe one state.
function preStateOf(pre: ChargeState): { corePre: any; preStateSha256: string } {
  const preText = canon(pre);
  const again: unknown = JSON.parse(preText);
  if (!isState(again) || canon(again) !== preText) throw new Error("conversion: pre round trip");
  const corePre = charge(pre);
  if (canon(stateOf(corePre)) !== preText) throw new Error("conversion: pre");
  const preStateSha256 = stateSha256(pre);
  if (preStateSha256 !== sha256hex(preText)) throw new Error("conversion: pre hash");
  return { corePre, preStateSha256 };
}

let memory: any = runtime.Map.Empty;      // IssueOnce.Memory: (charge id, request id) -> issued bytes (mode "on")

// Returns the signed body bytes and their text, or a refusal reason from the proved method.
function issue(pre: ChargeState, t: Transition): { bytes: Buffer; bodyText: string; body: any } | string {
  const { corePre, preStateSha256 } = preStateOf(pre);
  const [m2, o] = O.__default.Issue(memoryOn ? memory : runtime.Map.Empty, corePre, transition(t),
    text(specLockSha256), text(checkerSha256), text(preStateSha256));
  // [D1] the proved decision. Only Issued and Replayed can lead to a signature.
  if (o.is_RefusedByCore === true) return "core: Refuse";
  if (o.is_RefusedOtherCandidate === true) return "another candidate is already signed for this request id";
  if (o.is_Issued !== true && o.is_Replayed !== true) throw new Error("conversion: outcome");
  const raw: number[] = Array.from(o.dtor_bytes as Iterable<unknown>, (b: unknown) => Number(b));
  // [C2] conversion check (refuse-only): each element is a byte (the method proves it; this checks the runtime).
  if (!raw.every(b => Number.isInteger(b) && b >= 0 && b <= 255)) throw new Error("conversion: bytes");
  const bytes = Buffer.from(raw);
  const bodyText = utf8.decode(bytes);            // throws (refuse) on bytes that are not UTF-8
  const body: any = JSON.parse(bodyText);
  // [C3] consistency check (refuse-only): the returned text is the canonical text of a token body that
  // encoding.ts accepts, and its UTF-8 bytes are the returned bytes.
  if (!isTokenBody(body) || canon(body) !== bodyText || !Buffer.from(bodyText, "utf8").equals(bytes)) {
    throw new Error("conversion: body text");
  }
  // [C4] binding check (refuse-only): the body holds the request's values and the hash of the SAME pre.
  if (body.preStateSha256 !== preStateSha256 || body.requestId !== t.request.requestId ||
      canon(body.post) !== canon(t.post) || canon(body.intent) !== canon(t.intent)) throw new Error("conversion: token");
  // The memory changes only after every check passed (a refused or failed call leaves it as it was).
  if (memoryOn) memory = m2;
  return { bytes, bodyText, body };
}

const { publicKey, privateKey } = generateKeyPairSync("ed25519");
process.stdout.write(JSON.stringify({
  ready: true, publicKeyPem: publicKey.export({ type: "spki", format: "pem" }), specLockSha256, checkerSha256, singleUse: memoryOn }) + "\n");
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
    const issued = issue(pre, transitionMsg);
    if (typeof issued === "string") throw new Error(issued);
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

// One message is one line, ended by the byte 0x0A. A line is cut out of the RAW BYTES here, with a hard limit,
// before any text is made of it. At most MAX_LINE_BYTES bytes of a line are held. A line that goes over the limit
// is answered once, at that moment, with id null; the rest of that line is dropped up to its end.
// Each line is decoded with a FATAL UTF-8 decoder (C-ATT-15: Buffer.toString("utf8") replaced invalid bytes by
// U+FFFD, so two different byte requests became one signed request id). A line that is not valid UTF-8 is answered
// with id null and signs nothing. ignoreBOM: true keeps a leading U+FEFF in the text; JSON.parse then refuses it.
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
    else {
      const bytes = Buffer.concat(held, heldBytes); held = []; heldBytes = 0;
      let line: string | null = null;
      try { line = utf8.decode(bytes); } catch { line = null; }
      if (line === null) process.stdout.write(JSON.stringify({ id: null, ok: false, reason: "message is not UTF-8" }) + "\n");
      else handle(line);
    }
    start = newline + 1;
  }
});
