var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));

// ../../../../../../..<SCRATCH>/redteam-C/fix-370ff65c/ts/refund-finality/minter.ts
var import_node_crypto2 = require("node:crypto");
var import_node_fs = require("node:fs");
var import_node_module = require("node:module");
var import_node_path = require("node:path");
var import_bignumber = __toESM(require("bignumber.js"));

// ../../../../../../..<SCRATCH>/redteam-C/fix-370ff65c/ts/refund-finality/encoding.ts
var import_node_crypto = require("node:crypto");
var DOMAIN = "FORGE_REFUND_FINALITY_SLICE1_V1";
var MAX_TEXT = 256;
var MONEY = /^(0|[1-9][0-9]{0,18})$/;
var HEX64 = /^[0-9a-f]{64}$/;
var LONE_SURROGATE = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/;
function canon(value) {
  if (typeof value === "string") return JSON.stringify(value);
  if (typeof value === "boolean") return value ? "true" : "false";
  if (Array.isArray(value)) return "[" + value.map(canon).join(",") + "]";
  if (value !== null && typeof value === "object" && Object.getPrototypeOf(value) === Object.prototype) {
    const keys = Object.keys(value).sort();
    return "{" + keys.map((k) => JSON.stringify(k) + ":" + canon(value[k])).join(",") + "}";
  }
  throw new Error("non-canonical value");
}
var sha256hex = (data) => (0, import_node_crypto.createHash)("sha256").update(data).digest("hex");
function exact(x, keys) {
  if (x === null || typeof x !== "object" || Array.isArray(x) || Object.getPrototypeOf(x) !== Object.prototype) return false;
  const own = Object.keys(x).sort();
  return own.length === keys.length && [...keys].sort().every((k, i) => own[i] === k);
}
var text = (v) => typeof v === "string" && v.length <= MAX_TEXT && !LONE_SURROGATE.test(v) && !v.includes("\0");
var money = (v) => typeof v === "string" && MONEY.test(v);
var hex64 = (v) => typeof v === "string" && HEX64.test(v);
function isState(x) {
  return exact(x, ["chargeId", "original", "remaining", "refundEnabled"]) && text(x.chargeId) && money(x.original) && money(x.remaining) && typeof x.refundEnabled === "boolean";
}
function isRequest(x) {
  return exact(x, ["requestId", "amount", "reason"]) && text(x.requestId) && money(x.amount) && text(x.reason);
}
function isIntent(x) {
  return exact(x, ["chargeId", "requestId", "amount", "reason"]) && text(x.chargeId) && text(x.requestId) && money(x.amount) && text(x.reason);
}
function isTransition(x) {
  return exact(x, ["request", "post", "intent"]) && isRequest(x.request) && isState(x.post) && isIntent(x.intent);
}
function isTokenBody(x) {
  return exact(x, ["domain", "specLockSha256", "checkerSha256", "preStateSha256", "requestId", "post", "intent"]) && x.domain === DOMAIN && hex64(x.specLockSha256) && hex64(x.checkerSha256) && hex64(x.preStateSha256) && text(x.requestId) && isState(x.post) && isIntent(x.intent);
}
var stateSha256 = (state) => sha256hex(canon(state));
function checkerSha256Of(coreModule, encodingSource, minterSource) {
  return sha256hex(canon({
    coreModuleSha256: sha256hex(coreModule),
    encodingSha256: sha256hex(encodingSource),
    minterSha256: sha256hex(minterSource)
  }));
}

// ../../../../../../..<SCRATCH>/redteam-C/fix-370ff65c/ts/refund-finality/minter.ts
var [corePath, specLockPath, memoryArg, storePath] = process.argv.slice(2);
if (!corePath || !specLockPath || memoryArg !== "on" && memoryArg !== "off" || process.argv.length > 6 || storePath === "") {
  process.stderr.write("usage: minter.ts <compiled IssueAuth module> <refund spec lock> <on|off> [<sink store path>]\n");
  process.exit(2);
}
if (process.env.NODE_OPTIONS !== void 0 && process.env.NODE_OPTIONS !== "") {
  process.stderr.write("minter.ts: refused to start: NODE_OPTIONS is set\n");
  process.exit(2);
}
var memoryOn = memoryArg === "on";
var coreBytes = (0, import_node_fs.readFileSync)((0, import_node_path.resolve)(corePath));
var checkerSha256 = checkerSha256Of(coreBytes, (0, import_node_fs.readFileSync)((0, import_node_path.resolve)(__dirname, "encoding.ts")), (0, import_node_fs.readFileSync)((0, import_node_path.resolve)(__dirname, "minter.ts")));
var specLockSha256 = sha256hex((0, import_node_fs.readFileSync)((0, import_node_path.resolve)(specLockPath)));
var core = require((0, import_node_path.resolve)(corePath));
if (!core || !core.IssueAuth || !core.IssueBytes2 || !core.RefundFinality) {
  process.stderr.write("minter.ts: refused to start: the module does not export IssueAuth (build impl/finality-core/IssueAuth.dfy)\n");
  process.exit(2);
}
var F = core.RefundFinality;
var R = core.Refund;
var O = core.IssueAuth;
var runtime = core.runtime;
var CLOSED_ENV = ["FORGE_MINTER_CLOSED", "HOME", "LANG", "PATH", "TZ"];
var CLOSED_EXEC_ARGV = ["--no-addons", "--disallow-code-generation-from-strings"];
var sha256File = (path) => (0, import_node_crypto2.createHash)("sha256").update((0, import_node_fs.readFileSync)(path)).digest("hex");
var closedLaunch = null;
if (process.env.FORGE_MINTER_CLOSED !== void 0) {
  const refuse = (why) => {
    process.stderr.write("minter.ts: refused to start (closed launch): " + why + "\n");
    process.exit(2);
  };
  const pin = process.env.FORGE_MINTER_CLOSED;
  for (const name of Object.keys(process.env)) {
    if (name === "__CF_USER_TEXT_ENCODING" && /^0x[0-9A-Fa-f]+:0x[0-9A-Fa-f]+:0x[0-9A-Fa-f]+$/.test(process.env[name] ?? "")) continue;
    if (!CLOSED_ENV.includes(name)) refuse("environment variable " + name);
  }
  if (JSON.stringify(process.execArgv) !== JSON.stringify(CLOSED_EXEC_ARGV)) refuse("node options " + JSON.stringify(process.execArgv));
  const dir = __dirname;
  if ((0, import_node_path.resolve)(process.argv[1] ?? "") !== (0, import_node_path.resolve)(dir, "minter.cjs")) refuse("the started file is not minter.cjs of the built directory");
  if ((0, import_node_path.resolve)(corePath) !== (0, import_node_path.resolve)(dir, "core.cjs")) refuse("the core module is not core.cjs of the built directory");
  const manifest = (0, import_node_path.resolve)(dir, "MANIFEST.sha256");
  if (sha256File(manifest) !== pin) refuse("MANIFEST.sha256 does not have the pinned digest");
  const listed = /* @__PURE__ */ new Map();
  for (const line of (0, import_node_fs.readFileSync)(manifest, "utf8").split("\n")) {
    if (line === "") continue;
    const m = /^([0-9a-f]{64}) {2}\.\/(.+)$/.exec(line);
    if (m === null) refuse("manifest line " + JSON.stringify(line));
    else listed.set((0, import_node_path.resolve)(dir, m[2]), m[1]);
  }
  for (const [path, digest] of listed) if (sha256File(path) !== digest) refuse("a listed file has another digest: " + path);
  for (const path of Object.keys(require.cache)) if (!listed.has(path)) refuse("a loaded module is not listed: " + path);
  closedLaunch = { manifestSha256: pin, files: listed.size };
}
var storeDb = null;
function openStore() {
  if (storeDb === null) {
    const db = new (require("node:sqlite")).DatabaseSync((0, import_node_path.resolve)(storePath), { readOnly: true });
    db.exec("PRAGMA busy_timeout = 5000");
    storeDb = db;
  }
  return storeDb;
}
{
  const file = (from) => {
    const path = from.resolve("bignumber.js");
    return { path, sha256: (0, import_node_crypto2.createHash)("sha256").update((0, import_node_fs.readFileSync)(path)).digest("hex") };
  };
  process.stderr.write(JSON.stringify({ issuerIdentityInfo: {
    bignumberForMinter: file(require),
    bignumberForCore: file((0, import_node_module.createRequire)((0, import_node_path.resolve)(corePath))),
    node: process.version,
    nodePath: process.env.NODE_PATH ?? null,
    execArgv: process.execArgv,
    // Names (not values) of set variables that can change which code runs or how (detection only).
    codeEnv: Object.keys(process.env).filter((n) => /^(NODE_|TSX_|DYLD_|LD_|OPENSSL_|SSL_)|^TMPDIR$/.test(n)).sort(),
    closedLaunch,
    rule: "IssueAuth",
    mode: storePath === void 0 ? "NoStore" : "Store",
    store: storePath === void 0 ? null : (0, import_node_path.resolve)(storePath)
  } }) + "\n");
}
var text2 = (s) => runtime.Seq.UnicodeFromString(s);
var back = (s) => s.toVerbatimString(false);
var num = (s) => new import_bignumber.default(s);
var dec = (n) => BigInt(n.toFixed()).toString();
var charge = (s) => F.Charge.create_Charge(text2(s.chargeId), num(s.original), num(s.remaining), s.refundEnabled);
var stateOf = (c) => ({ chargeId: back(c.dtor_chargeId), original: dec(c.dtor_original), remaining: dec(c.dtor_remaining), refundEnabled: c.dtor_refundEnabled });
var transition = (t) => F.Transition.create_Transition(
  F.Request.create_Request(text2(t.request.requestId), num(t.request.amount), text2(t.request.reason)),
  charge(t.post),
  R.RefundIntent.create_Intent(text2(t.intent.chargeId), text2(t.intent.requestId), num(t.intent.amount), text2(t.intent.reason))
);
var utf8 = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });
function preStateOf(pre) {
  const preText = canon(pre);
  const again = JSON.parse(preText);
  if (!isState(again) || canon(again) !== preText) throw new Error("conversion: pre round trip");
  const corePre = charge(pre);
  if (canon(stateOf(corePre)) !== preText) throw new Error("conversion: pre");
  const preStateSha256 = stateSha256(pre);
  if (preStateSha256 !== sha256hex(preText)) throw new Error("conversion: pre hash");
  return { corePre, preStateSha256 };
}
var memory = runtime.Map.Empty;
function authOf(requestId) {
  if (storePath === void 0) return O.Auth.create_NoStore();
  let store;
  try {
    store = openStore();
  } catch (error) {
    throw new Error("store: cannot open: " + String(error.message));
  }
  store.exec("BEGIN");
  try {
    const row = store.prepare("SELECT blob FROM state WHERE id = 1").get();
    if (row === void 0 || typeof row.blob !== "string") throw new Error("store: no authoritative state");
    const v = JSON.parse(row.blob);
    if (!isState(v) || canon(v) !== row.blob) throw new Error("store: the state row is not a canonical state");
    const settled = store.prepare("SELECT 1 AS x FROM settled WHERE request_id = ?").get(requestId) !== void 0;
    const coreState = charge(v);
    if (canon(stateOf(coreState)) !== row.blob) throw new Error("store: conversion of the state");
    return O.Auth.create_Store(coreState, settled);
  } catch (error) {
    const why = String(error.message);
    throw new Error(why.startsWith("store: ") ? why : "store: " + why);
  } finally {
    store.exec("COMMIT");
  }
}
function refusalOf(o, key, preStateSha256) {
  if (o.is_RefusedByCore === true) return "core: Refuse";
  if (o.is_RefusedNotAuthoritative === true) return "pre-state is not the authoritative stored state";
  if (o.is_RefusedCompleted === true) return "attempt completed: use a new request id";
  if (o.is_RefusedClosed === true) return "attempt closed: use a new request id";
  if (o.is_RefusedOtherCandidate === true) {
    let stale = false;
    try {
      const rec = memory.get(key);
      const old = JSON.parse(utf8.decode(Buffer.from(Array.from(rec.dtor_bytes, (b) => Number(b)))));
      stale = old.preStateSha256 !== preStateSha256;
    } catch {
      stale = false;
    }
    return stale ? "stale candidate: use a new request id" : "other candidate: use a new request id";
  }
  throw new Error("conversion: outcome");
}
function issue(pre, t) {
  const { corePre, preStateSha256 } = preStateOf(pre);
  const a = authOf(t.request.requestId);
  const coreT = transition(t);
  const m0 = memoryOn ? memory : runtime.Map.Empty;
  const [m2, o] = O.__default.Issue(m0, a, corePre, coreT, text2(specLockSha256), text2(checkerSha256), text2(preStateSha256));
  if (o.is_Issued !== true && o.is_Replayed !== true) {
    const reason = refusalOf(o, O.__default.KeyFor(a, corePre, coreT, text2(preStateSha256)), preStateSha256);
    if (memoryOn) memory = m2;
    return reason;
  }
  const raw = Array.from(o.dtor_bytes, (b) => Number(b));
  if (!raw.every((b) => Number.isInteger(b) && b >= 0 && b <= 255)) throw new Error("conversion: bytes");
  const bytes = Buffer.from(raw);
  const bodyText = utf8.decode(bytes);
  const body = JSON.parse(bodyText);
  if (!isTokenBody(body) || canon(body) !== bodyText || !Buffer.from(bodyText, "utf8").equals(bytes)) {
    throw new Error("conversion: body text");
  }
  if (body.preStateSha256 !== preStateSha256 || body.requestId !== t.request.requestId || canon(body.post) !== canon(t.post) || canon(body.intent) !== canon(t.intent)) throw new Error("conversion: token");
  if (memoryOn) memory = m2;
  return { bytes, bodyText, body };
}
var { publicKey, privateKey } = (0, import_node_crypto2.generateKeyPairSync)("ed25519");
process.stdout.write(JSON.stringify({
  ready: true,
  publicKeyPem: publicKey.export({ type: "spki", format: "pem" }),
  specLockSha256,
  checkerSha256,
  singleUse: memoryOn
}) + "\n");
function handle(line) {
  let id = null;
  try {
    const msg = JSON.parse(line);
    if (msg === null || typeof msg !== "object" || Array.isArray(msg)) throw new Error("message shape");
    if (typeof msg.id !== "number" || !Number.isSafeInteger(msg.id) || msg.id < 0) throw new Error("message id");
    id = msg.id;
    if (Object.keys(msg).sort().join(",") !== "id,pre,transition") throw new Error("message shape");
    const pre = msg.pre, transitionMsg = msg.transition;
    if (!isState(pre) || !isTransition(transitionMsg)) throw new Error("shape");
    const issued = issue(pre, transitionMsg);
    if (typeof issued === "string") throw new Error(issued);
    const signature = (0, import_node_crypto2.sign)(null, issued.bytes, privateKey).toString("base64");
    const tokenText = '{"body":' + issued.bodyText + ',"signature":' + JSON.stringify(signature) + "}";
    if (canon({ body: issued.body, signature }) !== tokenText) throw new Error("conversion: token text");
    process.stdout.write('{"id":' + String(id) + ',"ok":true,"token":' + tokenText + "}\n");
  } catch (error) {
    process.stdout.write(JSON.stringify({ id, ok: false, reason: String(error.message) }) + "\n");
  }
}
var MAX_LINE_BYTES = 65536;
var held = [];
var heldBytes = 0;
var dropping = false;
process.stdin.on("data", (chunk) => {
  let start = 0;
  while (start < chunk.length) {
    const newline = chunk.indexOf(10, start), end = newline === -1 ? chunk.length : newline;
    if (!dropping) {
      if (heldBytes + (end - start) > MAX_LINE_BYTES) {
        held = [];
        heldBytes = 0;
        dropping = true;
        process.stdout.write(JSON.stringify({ id: null, ok: false, reason: "message too long" }) + "\n");
      } else if (end > start) {
        held.push(Buffer.from(chunk.subarray(start, end)));
        heldBytes += end - start;
      }
    }
    if (newline === -1) break;
    if (dropping) dropping = false;
    else {
      const bytes = Buffer.concat(held, heldBytes);
      held = [];
      heldBytes = 0;
      let line = null;
      try {
        line = utf8.decode(bytes);
      } catch {
        line = null;
      }
      if (line === null) process.stdout.write(JSON.stringify({ id: null, ok: false, reason: "message is not UTF-8" }) + "\n");
      else handle(line);
    }
    start = newline + 1;
  }
});
