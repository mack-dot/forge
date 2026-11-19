// Slice 3 (F3.1, F3.2): the token issuer for certified batch allocations. Its own operating-system
// process. The Ed25519 private key exists only in the memory of this process.
// The DECISION is not written here. It is BookingCertificate.Decide (impl/BookingCertificate.dfy),
// checked by the pinned Dafny against the candidate specification and compiled by
// `dafny build --target js`. This file converts values, calls Decide, and signs the token that Decide
// returns. The token fields come from the core's result, never from the caller's message.
// The proposal is the text that an untrusted optimizer wrote. This file parses it and checks its shape.
// NOT proved: this file (shape check, conversions, canonical JSON, hashing, signing call), the Dafny
// JavaScript back end and runtime, Node and OpenSSL, the operating system's process isolation.
// The board and the batch in a message are the caller's statement. This process cannot know what the
// sink stores. The sink compares the token's two hashes with its own store.
// Arguments: <compiled core module> <candidate specification file> <reference file of the specification>
import { generateKeyPairSync, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import BigNumber from "bignumber.js";
import {
  Batch, Board, DOMAIN, MAX_PROPOSAL_TEXT, Proposal, TokenBody, batchSha256, boardSha256, canon, checkerSha256Of,
  isBatch, isBoard, isProposal, isTokenBody, signedBytes, specSha256Of,
} from "./encoding";

const [corePath, specPath, referencePath] = process.argv.slice(2);
if (!corePath || !specPath || !referencePath || process.argv.length !== 5) {
  process.stderr.write("usage: issuer.ts <compiled core module> <candidate specification> <reference file>\n");
  process.exit(2);
}
const coreBytes = readFileSync(resolve(corePath));
const checkerSha256 = checkerSha256Of(coreBytes, readFileSync(resolve(__dirname, "encoding.ts")),
  readFileSync(resolve(__dirname, "issuer.ts")), readFileSync(resolve(__dirname, "../refund-finality/encoding.ts")));
const specSha256 = specSha256Of(readFileSync(resolve(specPath)), readFileSync(resolve(referencePath)));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const core = require(resolve(corePath));
const K = core.BookingCertificate, runtime = core.runtime;
const text = (s: string): unknown => runtime.Seq.UnicodeFromString(s);
const back = (s: any): string => s.toVerbatimString(false);
const num = (s: string): BigNumber => new BigNumber(s);
const dec = (n: any): string => BigInt(n.toFixed()).toString();
const seq = (values: string[]): unknown => runtime.Seq.of(...values.map(num));
const strings = (s: any): string[] => Array.from(s as ArrayLike<unknown>, dec);

// Returns the token body that the compiled core issues, or null on refusal.
function decide(pre: Board, batch: Batch, proposal: Proposal): TokenBody | null {
  const preStateSha256 = boardSha256(pre), batchHash = batchSha256(batch);
  const verdict = K.__default.Decide(
    K.Batch.create_Batch(runtime.Seq.of(...batch.needs.map(seq)), seq(pre.capacity), seq(batch.values)),
    text(preStateSha256), text(batchHash), text(batch.requestId),
    K.Proposal.create_Proposal(seq(proposal.allocation), seq(proposal.slotPrices), seq(proposal.requestPrices), num(proposal.alphaBps)));
  if (verdict.is_Issue !== true) return null;
  const token = verdict.dtor_token;
  const body: TokenBody = {
    domain: DOMAIN, specSha256, checkerSha256,
    preStateSha256: back(token.dtor_preStateHash), batchSha256: back(token.dtor_batchHash), requestId: back(token.dtor_requestId),
    allocation: strings(token.dtor_x), alphaBps: dec(token.dtor_alphaBps), value: dec(token.dtor_value),
    post: { capacity: strings(token.dtor_remaining) },
  };
  // Checks of the token as text. They can only refuse. The source proof gives these equalities for the
  // values of the core. A difference here means one of two things: a conversion in this file is wrong,
  // or a number of the token (the value, a capacity that remains) does not fit the wire format of 18
  // digits (an honest proposal with very large numbers is then refused; review finding R9).
  if (!isTokenBody(body) || body.preStateSha256 !== preStateSha256 || body.batchSha256 !== batchHash ||
      body.requestId !== batch.requestId || canon(body.allocation) !== canon(proposal.allocation) ||
      body.alphaBps !== proposal.alphaBps || body.post.capacity.length !== pre.capacity.length) throw new Error("token text check");
  return body;
}

const { publicKey, privateKey } = generateKeyPairSync("ed25519");
process.stdout.write(JSON.stringify({
  ready: true, publicKeyPem: publicKey.export({ type: "spki", format: "pem" }), specSha256, checkerSha256 }) + "\n");
function handle(line: string): void {
  let id: number | null = null;
  try {
    const msg = JSON.parse(line);
    if (msg === null || typeof msg !== "object" || Array.isArray(msg)) throw new Error("message shape");
    // Only a small integer is sent back as the id. Any other id value is answered with id null.
    if (typeof msg.id !== "number" || !Number.isSafeInteger(msg.id) || msg.id < 0) throw new Error("message id");
    id = msg.id;
    if (Object.keys(msg).sort().join(",") !== "batch,id,pre,proposalText") throw new Error("message shape");
    const pre: unknown = msg.pre, batch: unknown = msg.batch, proposalText: unknown = msg.proposalText;
    if (!isBoard(pre) || !isBatch(batch)) throw new Error("shape");
    if (typeof proposalText !== "string" || proposalText.length > MAX_PROPOSAL_TEXT) throw new Error("proposal text");
    let proposal: unknown;
    try { proposal = JSON.parse(proposalText); } catch { throw new Error("proposal is not JSON"); }
    if (!isProposal(proposal)) throw new Error("proposal shape");
    const body = decide(pre, batch, proposal);
    if (body === null) throw new Error("core: Refuse");
    process.stdout.write(JSON.stringify({ id, ok: true, token: { body, signature: sign(null, signedBytes(body), privateKey).toString("base64") } }) + "\n");
  } catch (error) {
    process.stdout.write(JSON.stringify({ id, ok: false, reason: String((error as Error).message) }) + "\n");
  }
}

// One message is one line, ended by the byte 0x0A. A line is cut out of the RAW BYTES here, with a hard
// limit, before any text is made of it (the framing of Slice 1's issuer). At most MAX_LINE_BYTES bytes
// of a line are held. A line that goes over the limit is answered once, at that moment, with id null;
// the rest of that line is dropped up to its end.
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
