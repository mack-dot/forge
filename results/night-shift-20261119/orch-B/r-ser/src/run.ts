// Night shift 2026-11-19, b-ser, G2 + G4. A TEST, not a proof.
// G2: the Dafny SerBody / Utf8 (SerModel.dfy, compiled by `dafny translate js`) against encoding.ts canon/signedBytes
//     on generated bodies (deterministic PRNG). Any difference is printed with a minimal example.
// G4: the real Sink.commit (ts/refund-finality/sink.ts) on canonical and non-canonical texts of one token signed
//     with a TEST key generated here (no real key).
// Argument: <compiled SerModel .cjs> <scratch dir for the sqlite file>
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdtempSync } from "node:fs";
import { join, resolve } from "node:path";
import BigNumber from "bignumber.js";
import { canon, signedBytes, stateSha256, isTokenBody, DOMAIN, TokenBody, ChargeState } from "../../../../../ts/refund-finality/encoding";
import { Sink } from "../../../../../ts/refund-finality/sink";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const M = require(resolve(process.argv[2]));
const SM = M.SerModel, rt = M.runtime;
const D = (s: string) => rt.Seq.UnicodeFromString(s);
const N = (s: string) => new BigNumber(s);

function toDafny(b: TokenBody): unknown {
  return SM.TokenBody.create_TokenBody(D(b.domain), D(b.specLockSha256), D(b.checkerSha256), D(b.preStateSha256), D(b.requestId),
    SM.ChargeState.create_ChargeState(D(b.post.chargeId), N(b.post.original), N(b.post.remaining), b.post.refundEnabled),
    SM.Intent.create_Intent(D(b.intent.chargeId), D(b.intent.requestId), N(b.intent.amount), D(b.intent.reason)));
}

// Deterministic PRNG (mulberry32).
let seed = 0x5eed1119;
const rnd = () => { seed |= 0; seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const pick = <T>(xs: T[]): T => xs[Math.floor(rnd() * xs.length)];
const POOL: string[] = ["a", "Z", "0", "_", " ", "\"", "\\", "/", "\u0001", "\u0008", "\t", "\n", "\u000b", "\u000c", "\r", "\u001f",
  "\u007f", "\u0080", "\u00e9", "\u07ff", "\u0800", "\u2028", "\u2029", "\ud7ff", "\ue000", "\uffff", "\u{10000}", "\u{1F600}", "\u{10FFFF}",
  "{", "}", ",", ":", "u", "\u0000"];
const text = (max: number) => { let s = ""; const n = Math.floor(rnd() * max); for (let i = 0; i < n; i++) s += pick(POOL); return s; };
const hex = () => { let s = ""; for (let i = 0; i < 64; i++) s += "0123456789abcdef"[Math.floor(rnd() * 16)]; return s; };
const MONEY_EDGE = ["0", "1", "9", "10", "99", "100", "9223372036854775807", "9223372036854775808", "9999999999999999999"];
const money = () => rnd() < 0.4 ? pick(MONEY_EDGE) : BigInt(Math.floor(rnd() * 2 ** 53)).toString();
const body = (): TokenBody => ({ domain: DOMAIN, specLockSha256: hex(), checkerSha256: hex(), preStateSha256: hex(), requestId: text(12),
  post: { chargeId: text(12), original: money(), remaining: money(), refundEnabled: rnd() < 0.5 },
  intent: { chargeId: text(12), requestId: text(12), amount: money(), reason: text(12) } });

const cases: TokenBody[] = [];
const base: TokenBody = { domain: DOMAIN, specLockSha256: "0".repeat(64), checkerSha256: "f".repeat(64), preStateSha256: "a".repeat(64),
  requestId: "rq_1", post: { chargeId: "ch_1", original: "100", remaining: "60", refundEnabled: true },
  intent: { chargeId: "ch_1", requestId: "rq_1", amount: "0", reason: "duplicate_charge" } };
cases.push(base);
const edgeTexts = ["", "\"", "\\", "\\\"", "\"\\", "\u0001\u001f", "\b\f\n\r\t", "\u007f\u2028\u2029", "\u{1F600}", "x\",\"requestId\":\"y",
  "a".repeat(256), "\u{1F600}".repeat(128), "\u00e9".repeat(256), "\u0000", "\\u0041", "</script>"];
for (const t of edgeTexts) {
  cases.push({ ...base, requestId: t, intent: { ...base.intent, reason: t } });
  cases.push({ ...base, post: { ...base.post, chargeId: t }, intent: { ...base.intent, chargeId: t, requestId: t } });
}
for (const m of MONEY_EDGE) cases.push({ ...base, post: { ...base.post, original: m, remaining: m }, intent: { ...base.intent, amount: m } });
cases.push({ ...base, post: { ...base.post, refundEnabled: false } });
for (let i = 0; i < 400; i++) cases.push(body());

let same = 0, diff = 0, wfCount = 0, rtOk = 0, rtBad = 0, utf8Same = 0;
const firstDiffs: string[] = [];
for (const b of cases) {
  const d = toDafny(b);
  const dText: string = SM.__default.SerBody(d).toVerbatimString(false);
  const tsText = canon(b);
  const tsBytes = signedBytes(b);
  const dBytes = Buffer.from(Array.from(SM.__default.Utf8(SM.__default.SerBody(d)) as BigNumber[]).map((x: BigNumber) => x.toNumber()));
  if (dText === tsText && Buffer.compare(dBytes, tsBytes) === 0) same++;
  else { diff++; if (firstDiffs.length < 3) firstDiffs.push(JSON.stringify({ b, dText, tsText })); }
  if (Buffer.compare(dBytes, tsBytes) === 0) utf8Same++;
  // The Dafny decoder Parse and isTokenBody agree on acceptance; Parse round-trips accepted bodies.
  const wfTs = isTokenBody(b);
  const parsed = SM.__default.Parse(SM.__default.SerBody(d));
  if (wfTs) wfCount++;
  if (parsed.is_Some === wfTs && (!wfTs || rt.areEqual(parsed.dtor_value, d))) rtOk++; else { rtBad++; if (firstDiffs.length < 6) firstDiffs.push("WF/PARSE " + JSON.stringify(b)); }
}

// G4: the real sink on canonical and non-canonical texts of one signed token (TEST key).
const dir = mkdtempSync(join(resolve(process.argv[3]), "sink-"));
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const pre: ChargeState = { chargeId: "ch_1", original: "100", remaining: "60", refundEnabled: true };
const tb: TokenBody = { ...base, preStateSha256: stateSha256(pre), post: { ...pre, remaining: "60" },
  intent: { chargeId: "ch_1", requestId: "rq_1", amount: "0", reason: "duplicate_charge" } };
const token = { body: tb, signature: sign(null, signedBytes(tb), privateKey).toString("base64") };
const good = canon(token);
const variants: [string, string][] = [
  ["whitespace after first brace", good.replace("{", "{ ")],
  ["\\u0072 escape inside a request id", good.replace("\"requestId\":\"rq_1\"", "\"requestId\":\"\\u0072q_1\"")],
  ["\\/ escape of a slash-free text (escaped 'd' is not JSON; use \\u0064)", good.replace("\"duplicate_charge\"", "\"\\u0064uplicate_charge\"")],
  ["keys of body reordered (signature first)", JSON.stringify({ signature: token.signature, body: JSON.parse(canon(tb)) })],
  ["duplicate key requestId in body", good.replace("\"requestId\":\"rq_1\",\"specLockSha256\"", "\"requestId\":\"zz\",\"requestId\":\"rq_1\",\"specLockSha256\"")],
];
const results: Record<string, unknown> = {};
for (const [label, text] of variants) {
  const s = new Sink(join(dir, "v" + Object.keys(results).length + ".sqlite"), { publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string,
    specLockSha256: tb.specLockSha256, checkerSha256: tb.checkerSha256 });
  s.init(pre);
  // what the signature check alone would say for this text: verify over the REBUILT bytes of the parsed body
  let parsedBodySame = false; try { parsedBodySame = canon(JSON.parse(text).body) === canon(tb); } catch { /* not JSON */ }
  results[label] = { commit: s.commit(text), parsedBodyEqualsSignedBody: parsedBodySame };
  s.close();
}
const s0 = new Sink(join(dir, "good.sqlite"), { publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string,
  specLockSha256: tb.specLockSha256, checkerSha256: tb.checkerSha256 });
s0.init(pre);
results["canonical text (amount 0)"] = { commit: s0.commit(good) };
s0.close();
// The Dafny decoder on the same non-canonical body texts (Parse accepts exactly SerBody of a WF body).
const dParse: Record<string, boolean> = {};
for (const [label, text] of variants) {
  let bodyText = ""; try { const o = JSON.parse(text); bodyText = text.includes("\"body\":") ? text.slice(text.indexOf("\"body\":") + 7, text.lastIndexOf(",\"signature\"")) : ""; } catch { /* */ }
  if (bodyText) dParse[label] = SM.__default.Parse(D(bodyText)).is_Some;
}
dParse["canonical body text"] = SM.__default.Parse(D(canon(tb))).is_Some;

process.stdout.write(JSON.stringify({ node: process.version, total: cases.length, textAndBytesEqual: same, different: diff, utf8BytesEqual: utf8Same,
  wellFormedByIsTokenBody: wfCount, parseAgreesWithIsTokenBodyAndRoundTrips: rtOk, parseDisagrees: rtBad, firstDiffs,
  sink: results, dafnyParseOnBodyText: dParse }, null, 1) + "\n");
process.exit(diff === 0 && rtBad === 0 ? 0 : 1);
