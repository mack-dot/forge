// Slice 1 (F2.1): the token issuer. Its own operating-system process. TESTED-UNPROVED as a whole.
// The Ed25519 private key exists only in the memory of this process. A new test key is made at every start
// (C-ATT-05: a restart changes the key; key persistence is an open owner decision: see KEY_OPTIONS in the
// night-shift evidence h-minter).
// The same interface as the earlier minter.ts (arguments, ready line, one JSON message per line in, one answer
// line out), plus an OPTIONAL fourth argument: the path of the sink's store (read only).
// The DECISION, the TOKEN BODY and the MEMORY RULE are not written here. They come from ONE call of the compiled
// proved method IssueAuth.Issue (impl/finality-core/IssueAuth.dfy; rule 2, night shift h-minter2). It calls
// IssueBytes2.IssueTokenBytes (RefundFinality.Check, the well-formed-body guard, the UTF-8 bytes of the canonical
// body text) and applies the memory rule:
//   Store mode (a store path is given): the pre-state must EQUAL the store's current charge (owner decision B-10:
//     the governing context is the AUTHORITATIVE PERSISTED charge state); else refused, and nothing is recorded
//     (red team C-ATT-30: a caller can no longer take a request id with a token on an invented pre-state). A request
//     id that the store has settled is refused ("attempt completed"). Key = (charge id, request id).
//   NoStore mode (no store path): key = (charge id, request id, pre-state hash). A token on an invented pre-state
//     takes only its own key. The issuer cannot tell an honest retry on a new state from a call on an invented
//     state, so in this mode a request id CAN be signed again on another pre-state; the sink commits at most one
//     token per request id and only on its stored pre-state (SINGLE_USE_2.md, h-minter2).
//   Both modes: new key -> Issued; identical retry -> Replayed (the stored bytes); same key, other candidate ->
//   refused; the core refuses at the first use of a key -> refused AND the key is closed (protocol.md:61-62).
// This file signs EXACTLY the returned bytes. It builds no body. It embeds the returned body text VERBATIM.
// This file does only: line framing with a STRICT UTF-8 decode (C-ATT-15), shape decode (refuse-only), the
// pre-state hash in ONE place (glue G-H), the store read (two SELECTs in one read transaction), conversion to core
// values, ONE call of IssueAuth.Issue, refuse-only consistency checks, sign(bytes), and the answer text.
// NOT proved: this file, encoding.ts (canon, the shape checks, SHA-256 call), the Dafny JavaScript back end and
// runtime, bignumber.js, Node, SQLite and OpenSSL, process isolation, the store's contents (assumption STORE-READ).
// The memory of mode "on" is PROCESS MEMORY: it is lost at restart (and the key is lost with it).
// Arguments: <compiled IssueAuth module> <refund spec lock> <memory rule: on | off> [<sink store path>]
//   on : the IssueAuth memory rule for the life of the process.
//   off: no memory (IssueAuth.Issue with an empty memory every time). With a store, the authority check stays.
//   Either way an identical request gets a byte-identical token (Ed25519 signatures are deterministic).
// Refusal reasons (fixed texts; a client may compare them): "core: Refuse"; "stale candidate: use a new request id";
// "other candidate: use a new request id"; "attempt closed: use a new request id"; "attempt completed: use a new
// request id"; "pre-state is not the authoritative stored state"; "store: ..." (the store cannot be read).
// Start refusals: NODE_OPTIONS set (C-ATT-14); a module without IssueAuth; in a CLOSED LAUNCH
// (minter-launch.sh sets FORGE_MINTER_CLOSED to the pinned manifest digest): any other environment variable, other
// node options, a manifest with another digest, a listed file with another digest, a loaded file that is not listed.
import { generateKeyPairSync, sign, createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { resolve } from "node:path";
import BigNumber from "bignumber.js";
import {
  ChargeState, Transition, canon, checkerSha256Of, isState, isTokenBody, isTransition, sha256hex, stateSha256,
} from "./encoding";

const [corePath, specLockPath, memoryArg, storePath] = process.argv.slice(2);
if (!corePath || !specLockPath || (memoryArg !== "on" && memoryArg !== "off") || process.argv.length > 6 || storePath === "") {
  process.stderr.write("usage: minter.ts <compiled IssueAuth module> <refund spec lock> <on|off> [<sink store path>]\n");
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
if (!core || !core.IssueAuth || !core.IssueBytes2 || !core.RefundFinality) {
  process.stderr.write("minter.ts: refused to start: the module does not export IssueAuth (build impl/finality-core/IssueAuth.dfy)\n");
  process.exit(2);
}
const F = core.RefundFinality, R = core.Refund, O = core.IssueAuth, runtime = core.runtime;

// CLOSED LAUNCH (C-ATT-14, C-ATT-31). minter-launch.sh checks the manifest of the built directory with
// /usr/bin/shasum BEFORE Node starts, then starts `node <fixed options> minter.cjs` with `env -i` and
// FORGE_MINTER_CLOSED = the pinned manifest digest. Here, after every module is loaded, the process checks again:
// the environment is the allow-list, the node options are the fixed ones, the manifest has the pinned digest, every
// listed file has its digest, and every loaded module file is listed. Any difference: refuse to start. This is a
// CHECK, not a barrier against a same-user attacker (it can change the files between the checks, or attach a
// debugger): SINGLE_USE_2.md section 5, assumptions CLOSED-LAUNCH, FIXED-DEPS, SAME-UID.
// Without FORGE_MINTER_CLOSED (for example `node --import tsx minter.ts`, as the tests do) nothing is refused here:
// that launch runs code from the tsx transform cache and is NOT a closed launch (C-ATT-31).
const CLOSED_ENV = ["FORGE_MINTER_CLOSED", "HOME", "LANG", "PATH", "TZ"];
const CLOSED_EXEC_ARGV = ["--no-addons", "--disallow-code-generation-from-strings"];
const sha256File = (path: string): string => createHash("sha256").update(readFileSync(path)).digest("hex");
let closedLaunch: { manifestSha256: string; files: number } | null = null;
if (process.env.FORGE_MINTER_CLOSED !== undefined) {
  const refuse = (why: string): never => {
    process.stderr.write("minter.ts: refused to start (closed launch): " + why + "\n");
    process.exit(2);
  };
  const pin = process.env.FORGE_MINTER_CLOSED;
  for (const name of Object.keys(process.env)) {
    // macOS adds __CF_USER_TEXT_ENCODING to every process (CoreFoundation text encoding): allowed in its own format.
    if (name === "__CF_USER_TEXT_ENCODING" && /^0x[0-9A-Fa-f]+:0x[0-9A-Fa-f]+:0x[0-9A-Fa-f]+$/.test(process.env[name] ?? "")) continue;
    if (!CLOSED_ENV.includes(name)) refuse("environment variable " + name);
  }
  if (JSON.stringify(process.execArgv) !== JSON.stringify(CLOSED_EXEC_ARGV)) refuse("node options " + JSON.stringify(process.execArgv));
  const dir = __dirname;
  if (resolve(process.argv[1] ?? "") !== resolve(dir, "minter.cjs")) refuse("the started file is not minter.cjs of the built directory");
  if (resolve(corePath) !== resolve(dir, "core.cjs")) refuse("the core module is not core.cjs of the built directory");
  const manifest = resolve(dir, "MANIFEST.sha256");
  if (sha256File(manifest) !== pin) refuse("MANIFEST.sha256 does not have the pinned digest");
  const listed = new Map<string, string>();
  for (const line of readFileSync(manifest, "utf8").split("\n")) {
    if (line === "") continue;
    const m = /^([0-9a-f]{64}) {2}\.\/(.+)$/.exec(line);
    if (m === null) refuse("manifest line " + JSON.stringify(line));
    else listed.set(resolve(dir, m[2]), m[1]);
  }
  for (const [path, digest] of listed) if (sha256File(path) !== digest) refuse("a listed file has another digest: " + path);
  for (const path of Object.keys(require.cache)) if (!listed.has(path)) refuse("a loaded module is not listed: " + path);
  closedLaunch = { manifestSha256: pin, files: listed.size };
}

// The sink's store, read only (Store mode). Opened at the first request (the sink may create the file after the
// issuer has started: it needs the issuer's public key first); read in one read transaction per request.
let storeDb: any = null;
function openStore(): any {
  if (storeDb === null) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const db = new (require("node:sqlite").DatabaseSync)(resolve(storePath as string), { readOnly: true });
    db.exec("PRAGMA busy_timeout = 5000");
    storeDb = db;
  }
  return storeDb;
}
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
    node: process.version, nodePath: process.env.NODE_PATH ?? null, execArgv: process.execArgv,
    // Names (not values) of set variables that can change which code runs or how (detection only).
    codeEnv: Object.keys(process.env).filter(n => /^(NODE_|TSX_|DYLD_|LD_|OPENSSL_|SSL_)|^TMPDIR$/.test(n)).sort(),
    closedLaunch, rule: "IssueAuth", mode: storePath === undefined ? "NoStore" : "Store", store: storePath === undefined ? null : resolve(storePath) } }) + "\n");
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

let memory: any = runtime.Map.Empty;      // IssueAuth.Memory: key -> Signed(bytes) | Closed (mode "on")

// What the store says for this request: IssueAuth.Auth. NoStore when no store is configured.
// The state row must be a canonical state text (the sink writes canon(state)). Refuse-only.
function authOf(requestId: string): any {
  if (storePath === undefined) return O.Auth.create_NoStore();
  let store: any;
  try { store = openStore(); } catch (error) { throw new Error("store: cannot open: " + String((error as Error).message)); }
  store.exec("BEGIN");
  try {
    const row = store.prepare("SELECT blob FROM state WHERE id = 1").get() as { blob: unknown } | undefined;
    if (row === undefined || typeof row.blob !== "string") throw new Error("store: no authoritative state");
    const v: unknown = JSON.parse(row.blob);
    if (!isState(v) || canon(v) !== row.blob) throw new Error("store: the state row is not a canonical state");
    const settled = store.prepare("SELECT 1 AS x FROM settled WHERE request_id = ?").get(requestId) !== undefined;
    const coreState = charge(v);
    if (canon(stateOf(coreState)) !== row.blob) throw new Error("store: conversion of the state");
    return O.Auth.create_Store(coreState, settled);
  } catch (error) {
    const why = String((error as Error).message);
    throw new Error(why.startsWith("store: ") ? why : "store: " + why);
  } finally { store.exec("COMMIT"); }
}

// The refusal text for an outcome of IssueAuth.Issue that does not sign.
function refusalOf(o: any, key: any, preStateSha256: string): string {
  if (o.is_RefusedByCore === true) return "core: Refuse";
  if (o.is_RefusedNotAuthoritative === true) return "pre-state is not the authoritative stored state";
  if (o.is_RefusedCompleted === true) return "attempt completed: use a new request id";
  if (o.is_RefusedClosed === true) return "attempt closed: use a new request id";
  if (o.is_RefusedOtherCandidate === true) {
    // Wording only: "stale" when the signed candidate of this key is for another pre-state (C-ATT-29).
    let stale = false;
    try {
      const rec = memory.get(key);
      const old = JSON.parse(utf8.decode(Buffer.from(Array.from(rec.dtor_bytes as Iterable<unknown>, (b: unknown) => Number(b)))));
      stale = old.preStateSha256 !== preStateSha256;
    } catch { stale = false; }
    return stale ? "stale candidate: use a new request id" : "other candidate: use a new request id";
  }
  throw new Error("conversion: outcome");
}

// Returns the signed body bytes and their text, or a refusal reason from the proved method.
function issue(pre: ChargeState, t: Transition): { bytes: Buffer; bodyText: string; body: any } | string {
  const { corePre, preStateSha256 } = preStateOf(pre);
  const a = authOf(t.request.requestId);
  const coreT = transition(t);
  const m0 = memoryOn ? memory : runtime.Map.Empty;
  const [m2, o] = O.__default.Issue(m0, a, corePre, coreT, text(specLockSha256), text(checkerSha256), text(preStateSha256));
  // [D1] the proved decision. Only Issued and Replayed can lead to a signature.
  if (o.is_Issued !== true && o.is_Replayed !== true) {
    const reason = refusalOf(o, O.__default.KeyFor(a, corePre, coreT, text(preStateSha256)), preStateSha256);
    // A core refusal closes the key (the proved memory rule); other refusals leave the memory as it was.
    if (memoryOn) memory = m2;
    return reason;
  }
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
  // The memory changes only after every check passed (a failed check leaves it as it was).
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
