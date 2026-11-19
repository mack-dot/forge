// x-bridge3 (night shift 2026-11-19, Orchestrator B). DRAFT. NOT adopted. TESTED-UNPROVED.
// TypeScript port of orch-B/x-bridge2: launcher.py (launch), frame.py (render_*, strict_parse) and decide2.py
// (in_range, decide2, bridge2). Same step order, same refusal names. The decision is modelled in
// x-bridge2/dafny/Bridge2.dfy (MODEL level). Nothing here is proved: this file is TESTED against the Python
// reference only. Node built-ins only.
//
// Every path that can return sign = true (there is exactly one: `return { sign: true, ... }` in decide2):
//   bridge2: inRange(c) -> checker(c, h) === true -> launch(...) -> decide2(c, true, r), and in decide2:
//   inRange(c) && issue === true && r.launched && !r.timedOut && !r.stdoutOverflow && r.stderrLen === 0 &&
//   r.signal === null && r.exitCode === 0 && r.stdinComplete && r.copyUnchanged && r.stdout nonempty &&
//   strictParse(r.stdout) succeeds && parsed tuple === AuthTuple(encode(pre, request)) &&
//   r.stdout equals renderFields(AuthTuple) byte for byte && post recomputed from (pre, frame) equals c.post &&
//   intent recomputed from (pre, frame) equals c.intent. Any exception refuses (INTERNAL_ERROR / CHECK_ERROR).
import { spawn } from "node:child_process";
import { createHash, timingSafeEqual } from "node:crypto";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

export const PINNED_BINARY_SHA256 = "b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8";
export const MAX_MONEY = 9223372036854775807n;
export const MAX_TEXT_UTF16 = 256;
export const TIMEOUT_MS = 10000;
// launcher.py ALLOWED_ENV: the only names passed to the native program (assumption A-ENV-HEAP). Nothing inherited.
export const ALLOWED_ENV: Readonly<Record<string, string>> = Object.freeze({ CML_HEAP_SIZE: "256", CML_STACK_SIZE: "256" });
const MAX_BINARY_BYTES = 64 * 1024 * 1024;

// ------------------------------------------------------------------------------------------- frame (frame.py)
const TAG = Buffer.from("refund-result-v1");
export const REJECTED_BYTES = Buffer.from('(refund-result-v1 False 0 "" "" "" 0)');
const isSpace = (b: number): boolean => b === 32 || (b >= 9 && b <= 13);
const isSafeChar = (b: number): boolean => b !== 40 && b !== 41 && b !== 34 && b !== 0 && !isSpace(b);
const ESC: Record<number, string> = { 9: "\\t", 10: "\\n", 92: "\\\\", 34: '\\"' };

export function makeStrSafe(s: Buffer): Buffer {
  if (s.length === 0) return Buffer.from('""');
  if (s.every(isSafeChar)) return Buffer.from(s);
  const parts: Buffer[] = [Buffer.from('"')];
  for (const b of s) parts.push(ESC[b] !== undefined ? Buffer.from(ESC[b]) : Buffer.from([b]));
  parts.push(Buffer.from('"'));
  return Buffer.concat(parts);
}
const intToString = (i: bigint): Buffer => Buffer.from((i < 0n ? "~" : "") + (i < 0n ? -i : i).toString());
const boolAtom = (v: boolean): Buffer => Buffer.from(v ? "True" : "False");
const sexp = (atoms: Buffer[]): Buffer => {
  const out: Buffer[] = [Buffer.from("(")];
  atoms.forEach((a, k) => { if (k > 0) out.push(Buffer.from(" ")); out.push(a); });
  out.push(Buffer.from(")"));
  return Buffer.concat(out);
};

export type FrameTuple = [boolean, bigint, Buffer, Buffer, Buffer, bigint];   // (ok, amount, reason, charge, request, count)
export function renderFields(ok: boolean, amount: bigint, reason: Buffer, charge: Buffer, request: Buffer, count: bigint): Buffer {
  return sexp([TAG, boolAtom(ok), intToString(amount), makeStrSafe(reason), makeStrSafe(charge), makeStrSafe(request), intToString(count)]);
}
export function renderRequest(charge: Buffer, request: Buffer, original: bigint, remaining: bigint, enabled: boolean,
  opened: boolean, candidate: boolean, amount: bigint, reason: Buffer): Buffer {
  return sexp([makeStrSafe(charge), makeStrSafe(request), intToString(original), intToString(remaining), boolAtom(enabled),
    boolAtom(opened), boolAtom(candidate), intToString(amount), makeStrSafe(reason)]);
}

class FrameErr extends Error {}
const QUOTED: Record<number, number> = { 92: 92, 34: 34, 116: 9, 110: 10 };
function strictAtom(s: Buffer, i: number): [Buffer, number] {
  let j: number, val: Buffer;
  if (i < s.length && s[i] === 34) {
    const acc: number[] = [];
    j = i + 1;
    for (;;) {
      if (j >= s.length) throw new FrameErr("strict: unterminated quoted atom");
      const c = s[j];
      if (c === 34) { j += 1; break; }
      if (c === 92) {
        if (j + 1 >= s.length || QUOTED[s[j + 1]] === undefined) throw new FrameErr("strict: escape not emitted by the printer");
        acc.push(QUOTED[s[j + 1]]); j += 2; continue;
      }
      if (c === 9 || c === 10) throw new FrameErr("strict: raw tab or newline in quoted atom");
      acc.push(c); j += 1;
    }
    val = Buffer.from(acc);
  } else {
    j = i;
    while (j < s.length && isSafeChar(s[j])) j += 1;
    if (j === i) throw new FrameErr("strict: empty bare atom");
    val = Buffer.from(s.subarray(i, j));
  }
  if (!makeStrSafe(val).equals(s.subarray(i, j))) throw new FrameErr("strict: atom spelling is not canonical");
  return [val, j];
}
function canonInt(x: Buffer): boolean {        // (0|[1-9][0-9]*), ASCII digits only
  if (x.length === 0 || !x.every(b => b >= 48 && b <= 57)) return false;
  return x.length === 1 || x[0] !== 48;
}
export function strictParse(s: unknown): FrameTuple {
  if (!Buffer.isBuffer(s)) throw new FrameErr("strict: not bytes");
  if (s[0] !== 40) throw new FrameErr("strict: no opening parenthesis");
  let i = 1;
  const vals: Buffer[] = [];
  for (let k = 0; k < 7; k++) {
    const [v, n] = strictAtom(s, i);
    vals.push(v); i = n;
    if (s[i] !== (k < 6 ? 32 : 41)) throw new FrameErr("strict: separator missing after field " + (k + 1));
    i += 1;
  }
  if (i !== s.length) throw new FrameErr("strict: bytes after the frame");
  const [tag, okb, amb, reason, charge, request, cnb] = vals;
  if (!tag.equals(TAG)) throw new FrameErr("strict: wrong tag");
  const ok = okb.toString("latin1");
  if (ok !== "True" && ok !== "False") throw new FrameErr("strict: not a boolean");
  if (!canonInt(amb) || !canonInt(cnb)) throw new FrameErr("strict: integer not canonical");
  const out: FrameTuple = [ok === "True", BigInt(amb.toString("latin1")), reason, charge, request, BigInt(cnb.toString("latin1"))];
  if (!renderFields(...out).equals(s)) throw new FrameErr("strict: re-render differs");
  return out;
}
export function strictAccepts(s: unknown): FrameTuple | null {
  try { return strictParse(s); } catch (e) { if (e instanceof FrameErr) return null; throw e; }
}

// ------------------------------------------------------------------------------------------- launcher (launcher.py)
export type LaunchResult = {
  launched: boolean; refusal: string; stdout: Buffer; exitCode: number | null; signal: number | null; timedOut: boolean;
  stderrLen: number; stdoutOverflow: boolean; stdinComplete: boolean; copyUnchanged: boolean; elapsedMs: number;
};
export type LaunchOptions = { stderrCap?: number; timeoutMs?: number; workRoot?: string; env?: Record<string, string> };
const refused = (refusal: string): LaunchResult => ({ launched: false, refusal, stdout: Buffer.alloc(0), exitCode: null,
  signal: null, timedOut: false, stderrLen: 0, stdoutOverflow: false, stdinComplete: false, copyUnchanged: false, elapsedMs: 0 });
const sha256hex = (b: Buffer | string): string => createHash("sha256").update(b).digest("hex");
const sameHex = (a: string, b: unknown): boolean => {
  if (typeof b !== "string") return false;
  const x = Buffer.from(a, "utf8"), y = Buffer.from(b, "utf8");
  return x.length === y.length && timingSafeEqual(x, y);
};

function readPinned(p: unknown, pinned: string): [Buffer | null, string] {
  if (typeof p !== "string" || !path.isAbsolute(p)) return [null, "PATH_NOT_ABSOLUTE"];
  let fd: number;
  try { fd = fs.openSync(p, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW); } catch { return [null, "BINARY_OPEN_FAILED"]; }
  try {
    const st = fs.fstatSync(fd);
    if (!st.isFile() || st.size > MAX_BINARY_BYTES) return [null, "BINARY_NOT_REGULAR"];
    const chunks: Buffer[] = [];
    let total = 0;
    for (;;) {
      const c = Buffer.alloc(1 << 20);
      const n = fs.readSync(fd, c, 0, c.length, null);
      if (n === 0) break;
      total += n;
      if (total > MAX_BINARY_BYTES) return [null, "BINARY_NOT_REGULAR"];
      chunks.push(c.subarray(0, n));
    }
    const data = Buffer.concat(chunks);
    if (!sameHex(sha256hex(data), pinned)) return [null, "DIGEST_MISMATCH"];
    return [data, ""];
  } finally { fs.closeSync(fd); }
}
function checkEnv(env: Record<string, string>): boolean {
  for (const [k, v] of Object.entries(env)) {
    if (typeof k !== "string" || typeof v !== "string") return false;
    if (k.startsWith("DYLD_") || k.startsWith("LD_") || !Object.hasOwn(ALLOWED_ENV, k) || ALLOWED_ENV[k] !== v) return false;
  }
  return true;
}
function killGroup(pid: number | undefined): void {
  if (pid === undefined) return;
  try { process.kill(-pid, "SIGKILL"); } catch { /* ESRCH / EPERM: group gone */ }
}
function digestOf(p: string): string { try { return sha256hex(fs.readFileSync(p)); } catch { return ""; } }

// One call = one process = one request. Never rejects for a process outcome.
export async function launch(binaryPath: string, pinnedSha256: string, stdinBytes: Buffer, stdoutCap: number,
  opts: LaunchOptions = {}): Promise<LaunchResult> {
  const stderrCap = opts.stderrCap ?? 4096, timeoutMs = opts.timeoutMs ?? TIMEOUT_MS;
  const env: Record<string, string> = opts.env === undefined ? { ...ALLOWED_ENV } : { ...opts.env };
  if (!checkEnv(env)) return refused("ENV_NOT_ALLOWED");
  const [data, why] = readPinned(binaryPath, pinnedSha256);
  if (data === null) return refused(why);
  const root = opts.workRoot ?? os.tmpdir();
  const priv = fs.mkdtempSync(path.join(root, "bin-"));      // mode 0700
  const cwd = fs.mkdtempSync(path.join(root, "cwd-"));       // mode 0700, stays empty
  const copy = path.join(priv, "refund");
  const t0 = performance.now();
  try {
    const fd = fs.openSync(copy, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | fs.constants.O_NOFOLLOW, 0o500);
    try {
      let off = 0;
      while (off < data.length) off += fs.writeSync(fd, data, off, data.length - off);
      fs.fsyncSync(fd);
    } finally { fs.closeSync(fd); }
    return await new Promise<LaunchResult>((done) => {
      let out = Buffer.alloc(0), errLen = 0, outOver = false, stdinComplete = false, timedOut = false, finished = false;
      let exitCode: number | null = null, sig: number | null = null;
      const child = spawn(copy, [], { cwd, env: { ...process.env, ...env }, stdio: ["pipe", "pipe", "pipe"], shell: false, detached: true });
      const finish = (launchFailed: boolean) => {
        if (finished) return;
        finished = true;
        clearTimeout(timer); clearTimeout(backstop);
        killGroup(child.pid);                                  // any leftover member of the group
        if (launchFailed) { done(refused("LAUNCH_FAILED")); return; }
        done({ launched: true, refusal: "", stdout: out.subarray(0, stdoutCap), exitCode, signal: sig, timedOut, stderrLen: errLen,
          stdoutOverflow: outOver, stdinComplete, copyUnchanged: digestOf(copy) === pinnedSha256, elapsedMs: performance.now() - t0 });
      };
      const stop = () => {                                     // kill the group; stop reading
        killGroup(child.pid);
        child.stdout.destroy(); child.stderr.destroy(); child.stdin.destroy();
        backstop = setTimeout(() => { timedOut = true; finish(false); }, 1000);
      };
      let backstop: NodeJS.Timeout | undefined;
      const timer = setTimeout(() => { timedOut = true; stop(); }, timeoutMs);
      child.on("error", () => { if (child.pid === undefined) finish(true); });
      child.stdin.on("error", () => { /* EPIPE: stdinComplete stays false */ });
      child.stdin.on("finish", () => { stdinComplete = true; });    // every byte handed to the OS, then EOF
      child.stdout.on("error", () => {}); child.stderr.on("error", () => {});
      child.stdout.on("data", (chunk: Buffer) => {
        const room = stdoutCap + 1 - out.length;
        out = Buffer.concat([out, chunk.subarray(0, Math.max(room, 0))]);
        if (out.length > stdoutCap && !outOver) { outOver = true; stop(); }
      });
      child.stderr.on("data", (chunk: Buffer) => {
        const before = errLen;
        errLen = Math.min(errLen + chunk.length, stderrCap + 1);
        if (errLen > stderrCap && before <= stderrCap) stop();
      });
      child.on("exit", (code, signal) => {
        exitCode = code;
        sig = signal === null ? null : (os.constants.signals[signal] ?? -1);
      });
      child.on("close", () => finish(child.pid === undefined));
      if (child.pid !== undefined) child.stdin.end(stdinBytes);
    });
  } finally {
    fs.rmSync(priv, { recursive: true, force: true });
    fs.rmSync(cwd, { recursive: true, force: true });
  }
}

// ------------------------------------------------------------------------------------------- decision (decide2.py)
export type Charge = { chargeId: string; original: bigint; remaining: bigint; enabled: boolean };
export type Request = { requestId: string; amount: bigint; reason: string };
export type Intent = { chargeId: string; requestId: string; amount: bigint; reason: string };
export type Candidate = { pre: Charge; request: Request; post: Charge; intent: Intent };
export type StateJson = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export type IntentJson = { chargeId: string; requestId: string; amount: string; reason: string };
export type Token = { preStateSha256: string; requestId: string; post: StateJson; intent: IntentJson };
export type Decision = { sign: boolean; reason: string; detail: string; token: Token | null };
type FlatIn = [Buffer, Buffer, bigint, bigint, boolean, boolean, boolean, bigint, Buffer];

const refuse = (reason: string, detail = ""): Decision => ({ sign: false, reason, detail, token: null });
const isRecord = (v: unknown, keys: string[]): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v) && Object.getPrototypeOf(v) === Object.prototype &&
  Object.keys(v).sort().join(",") === [...keys].sort().join(",");
const textOk = (s: unknown): boolean => typeof s === "string" && !s.includes("\u0000") && s.isWellFormed() && s.length <= MAX_TEXT_UTF16;
const intOk = (v: unknown): boolean => typeof v === "bigint" && v >= 0n && v <= MAX_MONEY;
const typedCharge = (c: unknown): c is Charge => isRecord(c, ["chargeId", "original", "remaining", "enabled"]) &&
  typeof c.chargeId === "string" && typeof c.original === "bigint" && typeof c.remaining === "bigint" && typeof c.enabled === "boolean";

// Strict types everywhere; range on the values sent to the native program.
export function inRange(c: unknown): c is Candidate {
  if (!isRecord(c, ["pre", "request", "post", "intent"])) return false;
  if (!isRecord(c.request, ["requestId", "amount", "reason"]) || !isRecord(c.intent, ["chargeId", "requestId", "amount", "reason"])) return false;
  if (!typedCharge(c.pre) || !typedCharge(c.post)) return false;
  const i = c.intent, q = c.request;
  if (!(typeof i.chargeId === "string" && typeof i.requestId === "string" && typeof i.amount === "bigint" && typeof i.reason === "string")) return false;
  return textOk(c.pre.chargeId) && textOk(q.requestId) && textOk(q.reason) && intOk(c.pre.original) && intOk(c.pre.remaining) && intOk(q.amount);
}

// Copy of ts/refund-finality/encoding.ts canon for string/boolean/plain object (the sink's canon).
export function canon(v: unknown): string {
  if (typeof v === "string") return JSON.stringify(v);
  if (typeof v === "boolean") return v ? "true" : "false";
  if (typeof v === "object" && v !== null && !Array.isArray(v) && Object.getPrototypeOf(v) === Object.prototype) {
    const o = v as Record<string, unknown>;
    return "{" + Object.keys(o).sort().map(k => JSON.stringify(k) + ":" + canon(o[k])).join(",") + "}";
  }
  throw new Error("non-canonical value");
}
export const stateJson = (c: Charge): StateJson =>
  ({ chargeId: c.chargeId, original: c.original.toString(), remaining: c.remaining.toString(), refundEnabled: c.enabled });
export const intentJson = (i: Intent): IntentJson =>
  ({ chargeId: i.chargeId, requestId: i.requestId, amount: i.amount.toString(), reason: i.reason });
export const preStateSha256 = (pre: Charge): string => sha256hex(Buffer.from(canon(stateJson(pre)), "utf8"));

function u8(s: string): Buffer {                       // strict UTF-8 (a lone surrogate throws)
  if (!s.isWellFormed()) throw new Error("u8: not well-formed");
  return Buffer.from(s, "utf8");
}
const utf8 = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });

// Bridge2.Encode: flat inputs from (pre, request) only. opened = candidate = True.
export const encode = (pre: Charge, q: Request): FlatIn =>
  [u8(pre.chargeId), u8(q.requestId), pre.original, pre.remaining, pre.enabled, true, true, q.amount, u8(q.reason)];
export const nativeWire = (x: FlatIn): Buffer => renderRequest(...x);
// Bridge2.AuthTuple: (ok, amount, reason, charge, request, count)
export const authTuple = (x: FlatIn): FrameTuple => [true, x[7], x[8], x[0], x[1], 1n];
export const stdoutCap = (x: FlatIn): number => Math.max(renderFields(...authTuple(x)).length, REJECTED_BYTES.length);

function sameTuple(a: FrameTuple, b: FrameTuple): boolean {
  return a.length === 6 && a.every((v, k) => {
    const w = b[k];
    if (Buffer.isBuffer(v)) return Buffer.isBuffer(w) && v.equals(w);
    return typeof v === typeof w && v === w;
  });
}
const sameCharge = (a: Charge, b: Charge): boolean =>
  a.chargeId === b.chargeId && a.original === b.original && a.remaining === b.remaining && a.enabled === b.enabled;
const sameIntent = (a: Intent, b: Intent): boolean =>
  a.chargeId === b.chargeId && a.requestId === b.requestId && a.amount === b.amount && a.reason === b.reason;

// c: candidate; issue: the checker's answer; r: the result of ONE launch on encode(c.pre, c.request).
export function decide2(c: unknown, issue: unknown, r: LaunchResult | null): Decision {
  try {
    if (!inRange(c)) return refuse("OUT_OF_RANGE");
    if (issue !== true) return refuse("CHECK_REFUSE");
    if (r === null || r.launched !== true) return refuse((r && r.refusal) || "NOT_LAUNCHED");
    if (r.timedOut) return refuse("TIMEOUT");
    if (r.stdoutOverflow) return refuse("STDOUT_OVERFLOW");
    if (r.stderrLen !== 0) return refuse("STDERR_NONEMPTY");
    if (r.signal !== null) return refuse("SIGNAL");
    if (r.exitCode !== 0) return refuse("EXIT_NONZERO");
    if (r.stdinComplete !== true) return refuse("STDIN_INCOMPLETE");
    if (r.copyUnchanged !== true) return refuse("BINARY_CHANGED");
    const out = r.stdout;
    if (!Buffer.isBuffer(out) || out.length === 0) return refuse("NO_FRAME");
    const nat = strictAccepts(out);
    if (nat === null) return refuse("NO_FRAME");
    const x = encode(c.pre, c.request);
    const exp = authTuple(x);
    if (!sameTuple(nat, exp) || !out.equals(renderFields(...exp))) return refuse("FRAME_NOT_AUTHORIZED_TUPLE");
    const amount = nat[1];
    const post: Charge = { chargeId: c.pre.chargeId, original: c.pre.original, remaining: c.pre.remaining - amount, enabled: c.pre.enabled };
    const intent: Intent = { chargeId: c.pre.chargeId, requestId: utf8.decode(nat[4]), amount, reason: utf8.decode(nat[2]) };
    if (!sameCharge(c.post, post)) return refuse("POST_MISMATCH");
    if (!sameIntent(c.intent, intent)) return refuse("INTENT_MISMATCH");
    const token: Token = { preStateSha256: preStateSha256(c.pre), requestId: intent.requestId, post: stateJson(post), intent: intentJson(intent) };
    return { sign: true, reason: "SIGN", detail: "", token };
  } catch (e) {
    return refuse("INTERNAL_ERROR", String(e));
  }
}

export type BridgeConfig = {
  checker: (c: Candidate, preStateSha256: string) => unknown;   // the compiled Check (configuration)
  binaryPath: string; pinnedSha256?: string; timeoutMs?: number; workRoot?: string;
};
// The only data input is `candidate`. Returns the decision and the launch result (null: no launch).
export async function bridge2(candidate: unknown, cfg: BridgeConfig): Promise<[Decision, LaunchResult | null]> {
  if (!inRange(candidate)) return [refuse("OUT_OF_RANGE"), null];
  let issue: unknown;
  try { issue = await cfg.checker(candidate, preStateSha256(candidate.pre)); } catch (e) { return [refuse("CHECK_ERROR", String(e)), null]; }
  if (issue !== true) return [refuse("CHECK_REFUSE"), null];
  const x = encode(candidate.pre, candidate.request);
  const r = await launch(cfg.binaryPath, cfg.pinnedSha256 ?? PINNED_BINARY_SHA256, nativeWire(x), stdoutCap(x),
    { timeoutMs: cfg.timeoutMs ?? TIMEOUT_MS, workRoot: cfg.workRoot });
  return [decide2(candidate, issue, r), r];
}
