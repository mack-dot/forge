// Slice 1 (F2.1): the token issuer. Its own operating-system process. TESTED-UNPROVED as a whole.
// The Ed25519 private key comes ONLY from the key file argument (OWNER DECISION D-1; keyfile.ts: O_NOFOLLOW open, fstat
// of the opened descriptor, read from it). A restart with the same key file keeps the key and its key id (C-ATT-05).
// The same interface as the earlier minter.ts (arguments, ready line, one JSON message per line in, one answer
// line out), plus a REQUIRED fourth argument (the key file, D-1) and an OPTIONAL fifth: the sink's store path (read only). PRODUCTION = mode "on" WITH
// a store (the closed launch, minter-launch.sh, refuses anything else). Every other mode is a TEST mode: it does not
// give I1 (at most one valid token per (charge id, request id)); it writes a warning line on stderr and its ready line
// has "singleUse":"none" (h-minter3, owner decision D-2).
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
//   refused. The core's refusal is decided FIRST, from the call alone (h-minter3).
//   OWNER DECISION D-2 (answers B-19): a refusal closes only that attempt; it records NOTHING. A request id closes
//   only by a minted token (the memory) or by the sink's commit (Store mode: the settled table). Proved: SprayHarmless
//   and RunSeq I1, I2, I3 (IssueAuth.dfy). This closes red team C-ATT-38 (a spray of refused requests closed a victim's
//   request id). NOT closed: the squat on the REAL state with an AUTHORIZED request that the issuer mints (C-ATT-08
//   class; WSquatRealState): the issuer has no caller identity.
// WHAT THE PROOF COVERS AND WHAT IT DOES NOT: IssueAuth.Issue is proved for ANY values of its inputs. The authoritative
// state and the settled flag (the Auth value), the pre-state hash text and the memory are FREE PARAMETERS of the proof.
// That they are what the sink's store holds now (STORE-READ) and that the hash is SHA-256 of canon(pre) (G-H) rests on
// THIS file only, which is not proved. The proof gives: every signing outcome is authorized for this call and its
// bytes are the canonical body bytes, whatever the Auth value, the hash text and the memory are.
// This file signs EXACTLY the returned bytes. It builds no body. It embeds the returned body text VERBATIM.
// This file does only: line framing with a STRICT UTF-8 decode (C-ATT-15), shape decode (refuse-only), the
// pre-state hash in ONE place (glue G-H), the store read (two SELECTs in one read transaction), conversion to core
// values, ONE call of IssueAuth.Issue, refuse-only consistency checks, sign(bytes), and the answer text.
// NOT proved: this file, encoding.ts (canon, the shape checks, SHA-256 call), the Dafny JavaScript back end and
// runtime, bignumber.js, Node, SQLite and OpenSSL, process isolation, the store's contents (assumption STORE-READ).
// The memory of mode "on" is PROCESS MEMORY, except in PRODUCTION ("on" with a store): there it starts from, and every
// new minted token is first appended (fsynced) to, the DURABLE mint memory file (mintmemory.ts; REQUIRED there), so a
// restart with the same key file keeps "at most one valid token per (charge id, request id)" (D-1 with D-2).
// Arguments: <compiled IssueAuth module> <refund spec lock> <memory rule: on | off> <key file> [<sink store path> [<mint memory file>]]
//   on : the IssueAuth memory rule for the life of the process. With a store: PRODUCTION (I1, I2, I3).
//        Without a store: TEST MODE (key = (charge id, request id, pre-state hash); two tokens can exist for one request
//        id on two pre-states; the sink still commits at most one).
//   off: TEST MODE. No process memory (I1 does not hold at the issuer: two candidates for one request id can both be
//        signed; the sink commits at most one). With a store, the authority check stays, and the memory passed to IssueAuth.Issue holds
//        at most one entry: the body bytes of the token that the store has SETTLED for this request id (C-ATT-40).
//   An identical request gets a byte-identical token from the same process (Ed25519 signatures are deterministic):
//     on : always, once signed (Replayed from the memory, also after the store moved on);
//     off without a store: always (the same bytes are issued again);
//     off with a store: while its pre-state is still the stored state and its id is not settled (issued again), and
//        after the sink has settled THIS token for its id (Replayed from the settled row). EXCEPTION: when the store
//        moved on without settling this request id, the identical request is refused ("pre-state is not the
//        authoritative stored state"); its old token cannot commit at the sink anyway (stale pre-state).
//   A new process with the same key file gives the same token bytes for an identical signed request (D-1, C-ATT-05).
// Refusal reasons (fixed texts; a client may compare them): "core: Refuse" (the GENERIC text: not authorized, or not
// on the authoritative stored state; h-minter3, C-ATT-38 state oracle); "stale candidate: use a new request id";
// "other candidate: use a new request id"; "attempt closed: use a new request id" (only for a memory entry Closed,
// which this rule never writes); "attempt completed: use a new request id"; "store: the store path is gone";
// "store: ..." (the store cannot be read). The operator gets the outcome name of every refusal on stderr
// ({"refusal": ...}); the caller does not.
// What a caller can still learn about the STORED charge state: "core: Refuse" is the same text for a wrong pre-state and
// for an unauthorized request. "attempt completed" depends on the settled table for the caller's request id only;
// "stale/other candidate" on the memory for the caller's key only (the proved order checks them before the state).
// A caller without the key can still search the state with AUTHORIZED (zero-amount) requests on fresh request ids:
// the answer is a token or "core: Refuse". That search needs no refusal text and is NOT closed here (no caller
// identity; C-ATT-08 class).
// Start refusals: NODE_OPTIONS set (C-ATT-14; see the comment at the check: NOT a defence); a module without
// IssueAuth; in a CLOSED LAUNCH
// (minter-launch.sh sets FORGE_MINTER_CLOSED to the pinned manifest digest): any other environment variable, other
// node options, a manifest with another digest, a listed file with another digest, a loaded file that is not listed.
import { sign, createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { resolve } from "node:path";
import BigNumber from "bignumber.js";
import {
  ChargeState, KEYID_DOMAIN, Transition, canon, checkerSha256Of, isState, isTokenBody, isTransition, sha256hex, signedBytes, stateSha256,
} from "./encoding";
import { SigningKey, loadSigningKey } from "./keyfile";
import { MintMemory } from "./mintmemory";

const [corePath, specLockPath, memoryArg, keyPath, storePath, memoryPath] = process.argv.slice(2);
if (!corePath || !specLockPath || (memoryArg !== "on" && memoryArg !== "off") || !keyPath || process.argv.length > 8 || storePath === "" ||
    memoryPath === "" || (memoryPath !== undefined && memoryArg !== "on")) {
  process.stderr.write("usage: minter.ts <compiled IssueAuth module> <refund spec lock> <on|off> <key file> [<sink store path> [<mint memory file>]]\n" +
    "  production (on + store) needs the mint memory file; it is given only with \"on\" and a store\n");
  process.exit(2);
}
// PRODUCTION = "on" with a store (I1). Any other mode is a TEST mode (owner decision D-2; see the header).
const production = memoryArg === "on" && storePath !== undefined;
// Durable mint memory (mintmemory.ts): REQUIRED in production, so that a restart with the same key file (D-1) cannot
// sign a second valid token for a request id that this issuer minted before.
if (production && memoryPath === undefined) {
  process.stderr.write("minter.ts: refused to start: production (\"on\" with a store) needs the mint memory file (6th argument)\n");
  process.exit(2);
}
if (!production) {
  process.stderr.write("minter.ts: WARNING: TEST MODE (" + (storePath === undefined ? "no store" : "memory off") +
    "): at most one valid token per (charge id, request id) is NOT kept by this issuer; production needs \"on\" and the sink's store\n");
}
// C-ATT-14: NODE_OPTIONS can make Node load other code (--require, --import, --loader) into this key-holding
// process. The checker id does not cover such code. This check is NOT a defence: it runs after Node has already run a
// --require or --import preload of NODE_OPTIONS (or of the command line), so such code has run before this line and
// can change what this line sees. It only reports a careless launch. The defence is the CLOSED LAUNCH
// (minter-launch.sh, assumption CLOSED-LAUNCH): `env -i` and fixed node options BEFORE Node starts.
// (NODE_PATH is reported below, not refused.)
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
  if (!production) refuse("the closed launch needs mode \"on\" and the sink's store (owner decision D-2: I1)");
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

// The sink's store, read only (Store mode). OPENED AT EACH REQUEST and closed after it (C-ATT-39: a connection kept
// open follows the old inode after an operator replaces the file by `mv`, and the issuer then refused every honest
// request until a restart, which is a new key). The sink may create the file after the issuer has started (it needs
// the issuer's public key first). A path that does not exist is refused with its own reason.
function openStore(): any {
  const path = resolve(storePath as string);
  if (!existsSync(path)) throw new Error("store: the store path is gone");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const db = new (require("node:sqlite").DatabaseSync)(path, { readOnly: true });
  try { db.exec("PRAGMA busy_timeout = 5000"); } catch (error) { db.close(); throw error; }
  return db;
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
    closedLaunch, rule: "IssueAuth", production, mode: storePath === undefined ? "NoStore" : "Store", store: storePath === undefined ? null : resolve(storePath) } }) + "\n");
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
// Production: the memory starts as the DURABLE records (one per minted token): Key(chargeId, requestId, false, "") ->
// Signed(body bytes), the key that IssueAuth.KeyFor gives in Store mode. It is the `m` of the one proved call.
let durable: MintMemory | null = null;
if (memoryPath !== undefined) {
  try { durable = MintMemory.open(memoryPath); } catch (error) {
    process.stderr.write("minter.ts: refused to start: " + String((error as Error).message) + "\n");
    process.exit(2);
  }
  if (durable.cutBytes > 0) process.stderr.write(JSON.stringify({ mintMemory: { tornLastRecordCut: durable.cutBytes } }) + "\n");
  for (const r of durable.records) {
    memory = memory.update(O.Key.create_Key(text(r.chargeId), text(r.requestId), false, text("")),
      O.Rec.create_Signed(runtime.Seq.of(...Array.from(r.body))));
  }
  process.stderr.write(JSON.stringify({ mintMemory: { records: durable.records.length } }) + "\n");
}

// What the store says for this request: IssueAuth.Auth, and (C-ATT-40) the body bytes of the token that the store
// has settled for this request id, if any. NoStore when no store is configured.
// The state row must be a canonical state text (the sink writes canon(state)). Refuse-only.
function authOf(requestId: string): { auth: any; settledBody: Buffer | null } {
  if (storePath === undefined) return { auth: O.Auth.create_NoStore(), settledBody: null };
  let store: any;
  try { store = openStore(); } catch (error) {
    const why = String((error as Error).message);
    throw new Error(why.startsWith("store: ") ? why : "store: cannot open: " + why);
  }
  try { store.exec("BEGIN"); } catch (error) { store.close(); throw new Error("store: " + String((error as Error).message)); }
  try {
    const row = store.prepare("SELECT blob FROM state WHERE id = 1").get() as { blob: unknown } | undefined;
    if (row === undefined || typeof row.blob !== "string") throw new Error("store: no authoritative state");
    const v: unknown = JSON.parse(row.blob);
    if (!isState(v) || canon(v) !== row.blob) throw new Error("store: the state row is not a canonical state");
    const srow = store.prepare("SELECT token FROM settled WHERE request_id = ?").get(requestId) as { token: unknown } | undefined;
    const settled = srow !== undefined;
    // The body bytes of the settled token (used only in mode "off"; data, not trusted: IssueAuth.Issue returns
    // Replayed only when these bytes are exactly the bytes it computes for THIS authorized call).
    let settledBody: Buffer | null = null;
    if (settled && typeof srow.token === "string") {
      try { const tk = JSON.parse(srow.token); settledBody = Buffer.from(canon(tk.body), "utf8"); } catch { settledBody = null; }
    }
    const coreState = charge(v);
    if (canon(stateOf(coreState)) !== row.blob) throw new Error("store: conversion of the state");
    return { auth: O.Auth.create_Store(coreState, settled), settledBody };
  } catch (error) {
    const why = String((error as Error).message);
    throw new Error(why.startsWith("store: ") ? why : "store: " + why);
  } finally { try { store.exec("COMMIT"); } finally { store.close(); } }
}

// The refusal text for an outcome of IssueAuth.Issue that does not sign.
function refusalOf(o: any, key: any, preStateSha256: string, m0: any): string {
  if (o.is_RefusedByCore === true) return "core: Refuse";
  // One generic text for "not on the authoritative state" and "not authorized" (the C-ATT-38 state oracle).
  if (o.is_RefusedNotAuthoritative === true) return "core: Refuse";
  if (o.is_RefusedCompleted === true) return "attempt completed: use a new request id";
  if (o.is_RefusedClosed === true) return "attempt closed: use a new request id";
  if (o.is_RefusedOtherCandidate === true) {
    // Wording only: "stale" when the signed candidate of this key is for another pre-state (C-ATT-29).
    let stale = false;
    try {
      const rec = m0.get(key);
      const old = JSON.parse(utf8.decode(Buffer.from(Array.from(rec.dtor_bytes as Iterable<unknown>, (b: unknown) => Number(b)))));
      stale = old.preStateSha256 !== preStateSha256;
    } catch { stale = false; }
    return stale ? "stale candidate: use a new request id" : "other candidate: use a new request id";
  }
  throw new Error("conversion: outcome");
}

const OUTCOMES = ["RefusedByCore", "RefusedOtherCandidate", "RefusedClosed", "RefusedNotAuthoritative", "RefusedCompleted"];
// Returns the signed body bytes and their text, or a refusal reason from the proved method.
function issue(pre: ChargeState, t: Transition): { bytes: Buffer; bodyText: string; body: any } | string {
  const { corePre, preStateSha256 } = preStateOf(pre);
  const { auth: a, settledBody } = authOf(t.request.requestId);
  const coreT = transition(t);
  const key = O.__default.KeyFor(a, corePre, coreT, text(preStateSha256));
  // Mode "off" with a store (C-ATT-40): the memory holds only the settled token's body for this key, if any.
  const m0 = memoryOn ? memory
    : settledBody !== null ? runtime.Map.Empty.update(key, O.Rec.create_Signed(runtime.Seq.of(...Array.from(settledBody))))
    : runtime.Map.Empty;
  // ONE call of the proved step.
  const [m2, o] = O.__default.Issue(m0, a, corePre, coreT, text(specLockSha256), text(checkerSha256), text(preStateSha256));
  // [D1] the proved decision. Only Issued and Replayed can lead to a signature.
  if (o.is_Issued !== true && o.is_Replayed !== true) {
    const reason = refusalOf(o, key, preStateSha256, m0);
    // Operator detail (stderr only; the caller gets the fixed text).
    process.stderr.write(JSON.stringify({ refusal: { outcome: OUTCOMES.find(n => o["is_" + n] === true) ?? "unknown",
      requestId: t.request.requestId, reason } }) + "\n");
    // A refusal records nothing (D-2; proved: Issue ensures m2 == After(m, k, o) == m for a refusal). The memory is
    // left as it was; m2 is not used.
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
  // DURABLE first (production): a NEW minted token is appended and fsynced BEFORE the memory changes and BEFORE the
  // answer is written (handle). A failed append throws: the caller gets a refusal, no token; the memory is unchanged.
  if (durable !== null && o.is_Issued === true) {
    if (key.dtor_scoped !== false || back(key.dtor_requestId) !== t.request.requestId) throw new Error("conversion: memory key");
    try { durable.append({ chargeId: back(key.dtor_chargeId), requestId: back(key.dtor_requestId), body: bytes }); }
    catch (error) { throw new Error("mint memory: the record was not written: " + String((error as Error).message)); }
  }
  // The memory changes only after every check passed (a failed check leaves it as it was).
  if (memoryOn) memory = m2;
  return { bytes, bodyText, body };
}

let signingKey: SigningKey;
try { signingKey = loadSigningKey(keyPath as string); } catch (error) {
  process.stderr.write("minter.ts: refused to start: " + String((error as Error).message) + "\n");
  process.exit(2);
}
const { privateKey, keyId } = signingKey;
process.stdout.write(JSON.stringify({
  ready: true, publicKeyPem: signingKey.publicKeyPem, keyId, specLockSha256, checkerSha256, singleUse: production ? true : "none" }) + "\n");
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
    // D-1 (KEYID-GLUE): the signed message holds the returned body bytes VERBATIM and the key id (encoding.ts signedBytes).
    const envelope = Buffer.concat([Buffer.from("{\"body\":", "utf8"), issued.bytes,
      Buffer.from(",\"keyId\":" + JSON.stringify(keyId) + ",\"sigDomain\":" + JSON.stringify(KEYID_DOMAIN) + "}", "utf8")]);
    if (!envelope.equals(signedBytes(issued.body, keyId))) throw new Error("conversion: signed bytes");
    const signature = sign(null, envelope, privateKey).toString("base64");
    // The token text embeds the returned body text verbatim. canon sorts "body", "keyId", "signature".
    const tokenText = "{\"body\":" + issued.bodyText + ",\"keyId\":" + JSON.stringify(keyId) + ",\"signature\":" + JSON.stringify(signature) + "}";
    // [C5] consistency check (refuse-only): this is the one canonical token text (encoding.ts tokenText).
    if (canon({ body: issued.body, keyId, signature }) !== tokenText) throw new Error("conversion: token text");
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
