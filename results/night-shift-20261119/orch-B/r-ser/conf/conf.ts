// Night shift 2026-11-19, Orchestrator B, review r-ser. A TEST, not a proof. Own generator (not b-ser's).
// Part 1: compiled Dafny SerModel.SerBody / Utf8 / Parse(SerBody) against encoding.ts canon / signedBytes / isTokenBody
//         on boundary-biased bodies.
// Part 2: compiled Dafny Parse against the real decoder (JSON.parse + isTokenBody + canon(v) === text) on
//         non-canonical and malformed texts.
// Part 3: the longest well-formed token text against sink.ts MAX_TOKEN_TEXT (8192).
// Argument: <compiled SerModel .cjs>
import { resolve } from "node:path";
import BigNumber from "bignumber.js";
import { canon, signedBytes, isTokenBody, DOMAIN, TokenBody } from "../../../../../ts/refund-finality/encoding";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const M = require(resolve(process.argv[2]));
const SM = M.SerModel, rt = M.runtime;
const D = (s: string) => rt.Seq.UnicodeFromString(s);
const LONE = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/;
const MONEYRE = /^(0|[1-9][0-9]{0,18})$/;

function toDafny(b: TokenBody): unknown {
  return SM.TokenBody.create_TokenBody(D(b.domain), D(b.specLockSha256), D(b.checkerSha256), D(b.preStateSha256), D(b.requestId),
    SM.ChargeState.create_ChargeState(D(b.post.chargeId), new BigNumber(b.post.original), new BigNumber(b.post.remaining), b.post.refundEnabled),
    SM.Intent.create_Intent(D(b.intent.chargeId), D(b.intent.requestId), new BigNumber(b.intent.amount), D(b.intent.reason)));
}
const H0 = "0".repeat(64), H1 = "f".repeat(64), H2 = "0123456789abcdef".repeat(4);
const base: TokenBody = { domain: DOMAIN, specLockSha256: H0, checkerSha256: H1, preStateSha256: H2, requestId: "r",
  post: { chargeId: "c", original: "100", remaining: "60", refundEnabled: true },
  intent: { chargeId: "c", requestId: "r", amount: "0", reason: "duplicate_charge" } };
type F = "requestId" | "post.chargeId" | "intent.chargeId" | "intent.requestId" | "intent.reason";
const FIELDS: F[] = ["requestId", "post.chargeId", "intent.chargeId", "intent.requestId", "intent.reason"];
function withField(f: F, v: string): TokenBody {
  const b: TokenBody = JSON.parse(JSON.stringify(base));
  if (f === "requestId") b.requestId = v; else if (f === "post.chargeId") b.post.chargeId = v;
  else if (f === "intent.chargeId") b.intent.chargeId = v; else if (f === "intent.requestId") b.intent.requestId = v;
  else b.intent.reason = v;
  return b;
}
const cases: { tag: string; b: TokenBody }[] = [];
// (a) every code unit 0..0x2FF alone and embedded, in each text field
for (const f of FIELDS) for (let cu = 0; cu <= 0x2ff; cu++) {
  cases.push({ tag: `${f} cu ${cu.toString(16)}`, b: withField(f, String.fromCharCode(cu)) });
  if (cu % 7 === 0) cases.push({ tag: `${f} emb ${cu.toString(16)}`, b: withField(f, "a" + String.fromCharCode(cu) + "\\\"b") });
}
// (b) other interesting BMP units and non-BMP
const MORE = [0x7ff, 0x800, 0x2028, 0x2029, 0x200b, 0xd7ff, 0xe000, 0xfeff, 0xfffe, 0xffff];
for (const f of FIELDS) for (const cu of MORE) cases.push({ tag: `${f} more ${cu.toString(16)}`, b: withField(f, String.fromCharCode(cu)) });
for (const f of FIELDS) for (const cp of [0x10000, 0x1f600, 0x10ffff, 0xe0001])
  cases.push({ tag: `${f} astral ${cp.toString(16)}`, b: withField(f, String.fromCodePoint(cp)) });
// (c) length limit in UTF-16 units vs scalars
const P = "\u{1F600}";
const LEN: [string, string][] = [["a*256", "a".repeat(256)], ["a*257", "a".repeat(257)], ["pair*128", P.repeat(128)],
  ["pair*128+a", P.repeat(128) + "a"], ["a*255+pair", "a".repeat(255) + P], ["a*254+pair", "a".repeat(254) + P],
  ["pair*129", P.repeat(129)], ["e9*256", "\u00e9".repeat(256)], ["ctl1*256", "\u0001".repeat(256)], ["quote*256", "\"".repeat(256)]];
for (const f of FIELDS) for (const [t, v] of LEN) cases.push({ tag: `${f} len ${t}`, b: withField(f, v) });
// (d) each field empty
for (const f of FIELDS) cases.push({ tag: `${f} empty`, b: withField(f, "") });
for (const k of ["specLockSha256", "checkerSha256", "preStateSha256", "domain"] as const) {
  for (const v of ["", H0.toUpperCase().replace(/0/g, "A"), "a".repeat(63), "a".repeat(65), "g".repeat(64), DOMAIN + "x", DOMAIN]) {
    const b: TokenBody = JSON.parse(JSON.stringify(base)); (b as any)[k] = v; cases.push({ tag: `${k}=${v.slice(0, 8)}..${v.length}`, b });
  }
}
// (e) money edges (only canonical decimal texts map to a Dafny nat)
const MONEY = ["0", "1", "9", "10", "100", "9007199254740993", "9223372036854775807", "9223372036854775808",
  "9999999999999999999", "10000000000000000000", "99999999999999999999", "123456789012345678901234567890"];
for (const m of MONEY) for (const k of ["original", "remaining", "amount"] as const) {
  const b: TokenBody = JSON.parse(JSON.stringify(base));
  if (k === "amount") b.intent.amount = m; else (b.post as any)[k] = m;
  cases.push({ tag: `money ${k}=${m}`, b });
}
for (const e of [true, false]) { const b: TokenBody = JSON.parse(JSON.stringify(base)); b.post.refundEnabled = e; cases.push({ tag: `bool ${e}`, b }); }
// (f) random bodies over the full scalar range (own PRNG: xorshift32)
let s = 0x2b9e1d07;
const rnd = () => { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; return (s >>> 0) / 4294967296; };
const scalar = () => { const r = rnd(); let cp: number;
  if (r < 0.3) cp = Math.floor(rnd() * 0x80); else if (r < 0.5) cp = Math.floor(rnd() * 0x800);
  else if (r < 0.8) cp = Math.floor(rnd() * 0x10000); else cp = 0x10000 + Math.floor(rnd() * 0x100000);
  if (cp >= 0xd800 && cp <= 0xdfff) cp = 0x41; return String.fromCodePoint(cp); };
const rtext = () => { let t = ""; const n = rnd() < 0.1 ? 200 + Math.floor(rnd() * 80) : Math.floor(rnd() * 10); for (let i = 0; i < n; i++) t += scalar(); return t; };
const rmoney = () => rnd() < 0.3 ? MONEY[Math.floor(rnd() * MONEY.length)] : BigInt(Math.floor(rnd() * 1e15)).toString();
const rhex = () => { let t = ""; for (let i = 0; i < 64; i++) t += "0123456789abcdef"[Math.floor(rnd() * 16)]; return t; };
for (let i = 0; i < 2000; i++) cases.push({ tag: `rand ${i}`, b: { domain: DOMAIN, specLockSha256: rhex(), checkerSha256: rhex(), preStateSha256: rhex(),
  requestId: rtext(), post: { chargeId: rtext(), original: rmoney(), remaining: rmoney(), refundEnabled: rnd() < 0.5 },
  intent: { chargeId: rtext(), requestId: rtext(), amount: rmoney(), reason: rtext() } } });

const hasLone = (b: TokenBody) => [b.requestId, b.post.chargeId, b.intent.chargeId, b.intent.requestId, b.intent.reason].some(x => LONE.test(x));
const moneyOk = (b: TokenBody) => [b.post.original, b.post.remaining, b.intent.amount].every(x => MONEYRE.test(x));
let total = 0, textDiff = 0, byteDiff = 0, wfDiff = 0, rtDiff = 0, loneRefusedTs = 0, loneNotRefused = 0, wfTrue = 0;
const diffs: string[] = [];
for (const { tag, b } of cases) {
  if (hasLone(b)) { if (isTokenBody(b)) loneNotRefused++; else loneRefusedTs++; continue; } // not representable in the model
  total++;
  const d = toDafny(b);
  const ser = SM.__default.SerBody(d);
  const dText: string = ser.toVerbatimString(false);
  const tsText = canon(b);
  if (dText !== tsText) { textDiff++; if (diffs.length < 8) diffs.push(JSON.stringify({ tag, dText, tsText })); }
  const dBytes = Buffer.from(Array.from(SM.__default.Utf8(ser) as BigNumber[]).map((x: BigNumber) => x.toNumber()));
  if (Buffer.compare(dBytes, signedBytes(b)) !== 0) { byteDiff++; if (diffs.length < 8) diffs.push("BYTES " + tag); }
  const wfTs = isTokenBody(b); if (wfTs) wfTrue++;
  const parsed = SM.__default.Parse(ser);
  if (parsed.is_Some !== wfTs) { wfDiff++; if (diffs.length < 8) diffs.push("WF " + tag + " ts=" + wfTs); }
  if (parsed.is_Some && !rt.areEqual(parsed.dtor_value, d)) { rtDiff++; if (diffs.length < 8) diffs.push("RT " + tag); }
  if (!moneyOk(b) && parsed.is_Some) { wfDiff++; diffs.push("MONEY " + tag); }
}

// Part 2: Parse vs the real decoder on texts.
function realAccept(x: string): TokenBody | null {
  let v: unknown; try { v = JSON.parse(x); } catch { return null; }
  if (!isTokenBody(v)) return null;
  return canon(v) === x ? v : null;
}
const good = canon(base);
const goodU = canon(withField("intent.reason", "\u0001\u00e9\u{1F600}\"\\\n"));
const texts: { tag: string; x: string }[] = [{ tag: "canonical", x: good }, { tag: "canonical unicode", x: goodU }];
const named: [string, string][] = [
  ["ws after {", good.replace("{", "{ ")], ["ws before }", good.slice(0, -1) + " }"], ["newline end", good + "\n"],
  ["trailing x", good + "x"], ["trailing NUL", good + "\u0000"], ["BOM", "\ufeff" + good], ["two bodies", good + good],
  ["keys reordered", good.replace(/^\{("checkerSha256":"[0-9a-f]{64}"),("domain":"[A-Z0-9_]+")/, "{$2,$1")],
  ["dup requestId", good.slice(0, -1) + ",\"requestId\":\"r\"}"], ["extra field", good.slice(0, -1) + ",\"zzz\":\"1\"}"],
  ["extra field nested", good.replace("\"refundEnabled\":true", "\"refundEnabled\":true,\"x\":\"1\"")],
  ["money as number", good.replace("\"original\":\"100\"", "\"original\":100")],
  ["bool as string", good.replace("\"refundEnabled\":true", "\"refundEnabled\":\"true\"")],
  ["\\u0072 for r", good.replace("\"requestId\":\"r\"", "\"requestId\":\"\\u0072\"")],
  ["\\/ escape", canon(withField("intent.reason", "a/b")).replace("a/b", "a\\/b")],
  ["upper \\u001F", canon(withField("intent.reason", "\u001f")).replace("\\u001f", "\\u001F")],
  ["\\u0009 for tab", canon(withField("intent.reason", "\t")).replace("\\t", "\\u0009")],
  ["\\u007f escaped", canon(withField("intent.reason", "\u007f")).replace("\u007f", "\\u007f")],
  ["\\u00e9 escaped", canon(withField("intent.reason", "\u00e9")).replace("\u00e9", "\\u00e9")],
  ["raw control in string", canon(withField("intent.reason", "\u0001")).replace("\\u0001", "\u0001")],
  ["\\u2028 escaped", canon(withField("intent.reason", "\u2028")).replace("\u2028", "\\u2028")],
  ["surrogate pair escaped", canon(withField("intent.reason", P)).replace(P, "\\ud83d\\ude00")],
  ["money leading zero", good.replace("\"original\":\"100\"", "\"original\":\"0100\"")],
  ["money -0", good.replace("\"amount\":\"0\"", "\"amount\":\"-0\"")],
  ["money 1e2", good.replace("\"original\":\"100\"", "\"original\":\"1e2\"")],
  ["money 20 digits", good.replace("\"original\":\"100\"", "\"original\":\"10000000000000000000\"")],
  ["money +1", good.replace("\"amount\":\"0\"", "\"amount\":\"+1\"")],
  ["money empty", good.replace("\"amount\":\"0\"", "\"amount\":\"\"")],
  ["\\u0000 in reason", canon(withField("intent.reason", "a")).replace("\"reason\":\"a\"", "\"reason\":\"\\u0000\"")],
  ["upper hex", good.replace(H2, H2.toUpperCase())], ["null field", good.replace("\"requestId\":\"r\"}", "\"requestId\":null}")],
  ["array body", "[" + good + "]"], ["empty", ""], ["true", "true"],
];
for (const [t, x] of named) texts.push({ tag: t, x });
// single-character deletions, duplications and replacements at every position of the canonical text
for (let i = 0; i < goodU.length; i++) {
  texts.push({ tag: `del ${i}`, x: goodU.slice(0, i) + goodU.slice(i + 1) });
  texts.push({ tag: `dup ${i}`, x: goodU.slice(0, i) + goodU[i] + goodU.slice(i) });
  for (const r of [" ", "\"", "\\", "0", "a", "A", "}", ","]) texts.push({ tag: `rep ${i} ${r}`, x: goodU.slice(0, i) + r + goodU.slice(i + 1) });
}
let tTotal = 0, tAgree = 0, tSkipLone = 0, bothAccept = 0, tDis = 0; const tDiffs: string[] = [];
for (const { tag, x } of texts) {
  if (LONE.test(x)) { tSkipLone++; continue; }
  tTotal++;
  const real = realAccept(x);
  const p = SM.__default.Parse(D(x));
  const agree = (real === null) === !p.is_Some && (real === null || rt.areEqual(p.dtor_value, toDafny(real)));
  if (agree) { tAgree++; if (real) bothAccept++; } else { tDis++; if (tDiffs.length < 10) tDiffs.push(JSON.stringify({ tag, x: x.slice(0, 120), real: real !== null, model: p.is_Some })); }
}

// Part 3: the longest well-formed token text.
const W = "\u0001".repeat(256);
const big: TokenBody = { domain: DOMAIN, specLockSha256: H1, checkerSha256: H1, preStateSha256: H1, requestId: W,
  post: { chargeId: W, original: "9999999999999999999", remaining: "9999999999999999999", refundEnabled: false },
  intent: { chargeId: W, requestId: W, amount: "9999999999999999999", reason: W } };
const bigTok = canon({ body: big, signature: "A".repeat(86) + "==" });
// the real minter path: Check (RefundSpec.AllowedReason) fixes the reason to a short text; requestId = intent.requestId.
const big2: TokenBody = { ...big, post: { ...big.post, original: "9223372036854775807", remaining: "9223372036854775807" },
  intent: { ...big.intent, amount: "0", reason: "service_not_delivered" } };
const bigTok2 = canon({ body: big2, signature: "A".repeat(86) + "==" });

console.log(JSON.stringify({ node: process.version, part1: { cases: cases.length, compared: total, wellFormed: wfTrue, textDiff, byteDiff, wfDiff, rtDiff,
  loneSurrogateCasesRefusedByIsTokenBody: loneRefusedTs, loneSurrogateCasesAccepted: loneNotRefused },
  part2: { texts: texts.length, compared: tTotal, agree: tAgree, bothAccept, disagree: tDis, skippedLone: tSkipLone },
  part3: { wfBig: isTokenBody(big), bigTokenTextLength: bigTok.length, wfBig2: isTokenBody(big2), mintablePathTokenTextLength: bigTok2.length, MAX_TOKEN_TEXT: 8192 },
  diffs, tDiffs }, null, 1));
