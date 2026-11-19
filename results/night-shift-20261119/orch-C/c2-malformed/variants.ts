// c2-malformed: malformed / boundary token texts, signature encodings and value conversion against the v6 sink
// and the dispatcher. A throwaway Ed25519 key plays the issuer (the sink checks only the pinned public key and
// the pinned id texts). Each check prints PASS (target safe) or FAIL (defect). Exit 1 if any FAIL, else 0.
// Usage: node --import tsx variants.ts <target root> <work dir>
import { generateKeyPairSync, sign, verify } from "node:crypto";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [root, work] = process.argv.slice(2);
// eslint-disable-next-line @typescript-eslint/no-require-imports
const E = require(join(root, "ts/refund-finality/encoding.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { Dispatcher } = require(join(root, "ts/refund-finality/dispatcher.ts"));
// eslint-disable-next-line @typescript-eslint/no-require-imports
const M = require(join(root, "ts/refund-finality/core/sinkcore-v6.cjs"));
rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const pem = publicKey.export({ type: "spki", format: "pem" }) as string;
const SPEC = "a".repeat(64), CHK = "b".repeat(64);
const cfgOf = (s0: any) => ({ publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK, initialState: s0 });
let fails = 0;
const check = (name: string, ok: boolean, info: unknown = "") => { if (!ok) fails++; console.log((ok ? "PASS " : "FAIL ") + name + (info === "" ? "" : " " + JSON.stringify(info).slice(0, 300))); };
function mint(pre: any, rid: string, amount: string, reason = "duplicate_charge", over: any = {}) {
  const body: any = { domain: E.DOMAIN, specLockSha256: SPEC, checkerSha256: CHK, preStateSha256: E.stateSha256(pre), requestId: rid,
    post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() },
    intent: { chargeId: pre.chargeId, requestId: rid, amount, reason }, ...over };
  const sig = sign(null, E.signedBytes(body), privateKey).toString("base64");
  return { body, sig, text: E.canon({ body, signature: sig }) };
}
const fresh = (s0: any) => { const s = new Sink(":memory:", cfgOf(s0)); s.init(s0); return s; };
const s0 = { chargeId: "ch_1", original: "100", remaining: "100", refundEnabled: true };

// ---- 1. Ed25519: S + L (non-canonical S) must not verify; two texts for one request id must not both commit
{
  const L = (1n << 252n) + 27742317777372353535851937790883648493n;
  const t = mint(s0, "rq_s", "0");
  const raw = Buffer.from(t.sig, "base64");
  let S = 0n; for (let i = 31; i >= 0; i--) S = (S << 8n) | BigInt(raw[32 + i]);
  const S2 = S + L; const r2 = Buffer.from(raw);
  let x = S2; for (let i = 0; i < 32; i++) { r2[32 + i] = Number(x & 0xffn); x >>= 8n; }
  const nodeAccepts = verify(null, E.signedBytes(t.body), publicKey, r2);
  check("node verify refuses S+L", !nodeAccepts, { S2bits: S2.toString(2).length });
  const sink = fresh(s0);
  const alt = E.canon({ body: t.body, signature: r2.toString("base64") });
  const a = sink.commit(alt), b = sink.commit(t.text);
  check("sink: S+L text not committed, canonical one commits", a.status === "rejected" && b.status === "committed", { a, b });
  // all-zero signature / identity tricks
  const z = sink.commit(E.canon({ body: mint(s0, "rq_z", "0").body, signature: Buffer.alloc(64).toString("base64") }));
  check("sink: all-zero signature rejected", z.status === "rejected", z);
  sink.close();
}
// ---- 2. base64 variants of the one valid signature
{
  const t = mint(s0, "rq_b64", "0");
  const v: Record<string, string> = {
    urlsafe: t.sig.replace(/\+/g, "-").replace(/\//g, "_"), nopad: t.sig.replace(/=+$/, ""), ws: t.sig.slice(0, 40) + " " + t.sig.slice(41),
    lower: t.sig.toLowerCase(),
  };
  // non-canonical trailing bits: the last data char before "==" carries 4 unused bits
  const B = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  const k = t.sig.length - 3, ci = B.indexOf(t.sig[k]);
  for (let d = 1; d < 16; d++) { const alt = t.sig.slice(0, k) + B[(ci & ~15) | ((ci + d) & 15)] + t.sig.slice(k + 1); if (Buffer.from(alt, "base64").equals(Buffer.from(t.sig, "base64"))) { v["trailbits" + d] = alt; } }
  const sink = fresh(s0); let anyCommit = false; const res: any = {};
  for (const [n, s] of Object.entries(v)) { if (s === t.sig) continue; const r = sink.commit(E.canon({ body: t.body, signature: s })); res[n] = r.status; if (r.status !== "rejected") anyCommit = true; }
  check("sink: " + Object.keys(res).length + " base64 variants of a valid signature all rejected", !anyCommit, res);
  check("sink: canonical signature commits after the variants", sink.commit(t.text).status === "committed");
  sink.close();
}
// ---- 3. token text variants (same body, same signature): only the canonical text commits
{
  const t = mint(s0, "rq_txt", "0");
  const inner = t.text.slice(1, -1);
  const variants: Record<string, string> = {
    bom: "\ufeff" + t.text, lead: " " + t.text, trail: t.text + "\n", dupKey: "{" + inner + ",\"signature\":\"" + t.sig + "\"}",
    dupBody: "{\"body\":{}," + inner + "}", proto: "{\"__proto__\":{}," + inner + "}", order: "{\"signature\":\"" + t.sig + "\",\"body\":" + E.canon(t.body) + "}",
    escA: t.text.replace("\"ch_1\"", "\"\\u0063h_1\""), slash: t.text.replace("FORGE_REFUND", "FORGE\\_REFUND"), num: t.text.replace("\"amount\":\"0\"", "\"amount\":0"),
    space: t.text.replace(",\"signature\"", ", \"signature\""), unicodeEsc: t.text.replace("\"rq_txt\"", "\"rq\\u005ftxt\""),
  };
  const sink = fresh(s0); const res: any = {}; let bad = false;
  for (const [n, s] of Object.entries(variants)) { const r = sink.commit(s); res[n] = r.reason ?? r.status; if (r.status !== "rejected") bad = true; }
  check("sink: 12 non-canonical texts of one valid token all rejected", !bad, res);
  check("sink: canonical text commits; then replayed", sink.commit(t.text).status === "committed" && sink.commit(t.text).status === "replayed");
  const again = sink.commit(variants.lead);
  check("sink: non-canonical text after commit is rejected (not replayed, not committed)", again.status === "rejected", again);
  sink.close();
}
// ---- 4. MAX_TOKEN_TEXT (8192) vs the longest legitimate token
{
  const id = "\u0001".repeat(256);
  const big = { chargeId: id, original: "9223372036854775807", remaining: "9223372036854775807", refundEnabled: true };
  const t = mint(big, id, "1000000000000000000", "service_not_delivered");
  check("longest legitimate token text fits 8192 (len " + t.text.length + ")", t.text.length <= 8192);
  const sink = fresh(big); const r = sink.commit(t.text); check("sink commits the longest legitimate token", r.status === "committed", r); sink.close();
}
// ---- 5. value conversion: text and money round trips through the compiled core runtime
{
  const T = (s: string) => M.rt.Seq.UnicodeFromString(s), S = (x: any) => x.toVerbatimString(false);
  const strs = ["", "0", "007", "1e3", "-0", "NaN", "Infinity", "\u{1F600}", "\u{10FFFF}a\u{10000}", "\uffff\ufffe", "\u2028\u2029", "\u007f", "e\u0301", "\u00e9", "a\"b\\c", "__proto__", "x".repeat(256), "\u{1F600}".repeat(128)];
  const badS = strs.filter(s => S(T(s)) !== s);
  check("core text round trip back(text(s)) == s on " + strs.length + " strings", badS.length === 0, badS);
  const lenOk = strs.every(s => T(s).length === [...s].length);
  check("core text length is the code-point count", lenOk);
  const ms = ["0", "1", "9223372036854775807", "9223372036854775808", "9999999999999999999", "1000000000000000001", "123456789012345678"];
  const badM = ms.filter(m => new M.BigNumber(m).toFixed() !== m);
  check("BigNumber round trip on 19-digit money and 0", badM.length === 0, badM);
}
// ---- 6. money above MaxMoney (regex accepts, approved spec refuses): sink must refuse, never commit
{
  const hi = { chargeId: "ch_hi", original: "9999999999999999999", remaining: "9999999999999999999", refundEnabled: true };
  const sink = fresh(hi);
  const r0 = sink.commit(mint(hi, "rq_hi0", "0").text), r1 = sink.commit(mint(hi, "rq_hi1", "9999999999999999999").text);
  check("original > MaxMoney: zero and full refund not committed (spec: invalid context)", r0.status === "rejected" && r1.status === "rejected", { r0, r1 });
  sink.close();
  const mx = { chargeId: "ch_mx", original: "9223372036854775807", remaining: "9223372036854775807", refundEnabled: true };
  const s2 = fresh(mx); const r2 = s2.commit(mint(mx, "rq_mx", "9223372036854775807").text);
  check("original == MaxMoney, full refund commits", r2.status === "committed", r2); s2.close();
}
// ---- 7. reasons: approved commit, others rejected even when signed (key holder / faulty issuer)
{
  const res: any = {}; let bad = false;
  for (const reason of ["duplicate_charge", "service_not_delivered", "returned_item", "Duplicate_charge", "duplicate_charge ", " returned_item", "returned_item\u0000", "returned\u2028item", "", "fraud"]) {
    let r: any;
    try { const sink = fresh(s0); r = sink.commit(mint(s0, "rq_r", "0", reason).text); sink.close(); } catch (e) { r = { status: "exception" }; }
    res[JSON.stringify(reason)] = r.status;
    const approved = ["duplicate_charge", "service_not_delivered", "returned_item"].includes(reason);
    if ((r.status === "committed") !== approved) bad = true;
  }
  check("reason: exactly the 3 approved labels commit (amount 0)", !bad, res);
}
// ---- 8. zero amount: remaining 0 and remaining > 0 commit and are dispatched; refundEnabled false is refused (spec)
{
  const cases = [{ chargeId: "ch_z0", original: "100", remaining: "0", refundEnabled: true }, { chargeId: "ch_z5", original: "100", remaining: "5", refundEnabled: true },
    { chargeId: "ch_z00", original: "0", remaining: "0", refundEnabled: true }];
  for (const c of cases) {
    const db = join(work, c.chargeId + ".sqlite"); const sink = new Sink(db, cfgOf(c)); sink.init(c);
    const r1 = sink.commit(mint(c, "rq_a", "0").text), r2 = sink.commit(mint(c, "rq_b", "0").text); sink.close();
    const effects: any[] = [];
    const d = new Dispatcher(db, join(work, c.chargeId + ".ledger"), { publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK, initialStateSha256: E.stateSha256(c) }, (e: any) => effects.push(e)).flush();
    check("zero refund x2 on " + JSON.stringify(c) + ": commit + dispatch", r1.status === "committed" && r2.status === "committed" && d.emitted.length === 2 && d.refused.length === 0, { r1, r2, emitted: d.emitted.length, refused: d.refused });
  }
  const off = { chargeId: "ch_off", original: "100", remaining: "100", refundEnabled: false };
  const sink = fresh(off); const r = sink.commit(mint(off, "rq_off", "0").text); sink.close();
  check("refundEnabled false, amount 0: rejected (approved spec ValidContext requires the flag)", r.status === "rejected", r);
}
// ---- 9. request ids that differ by normalisation / case / trailing space: distinct requests (exact compare, as the spec)
{
  const sink = fresh(s0); const st: string[] = [];
  let pre: any = s0;
  for (const rid of ["caf\u00e9", "cafe\u0301", "CAF\u00c9", "caf\u00e9 "]) { const r = sink.commit(mint(pre, rid, "1").text); st.push(r.status); pre = JSON.parse(sink.stateBlob()); }
  console.log("INFO four request ids equal after NFC/case/trim each commit as separate refunds: " + JSON.stringify(st) + " (spec: no normalisation; exact match)");
  sink.close();
}
// ---- 10. dispatcher ledger parser: hostile lines fail closed (throw), never emit
{
  const c = { chargeId: "ch_l", original: "100", remaining: "100", refundEnabled: true };
  const db = join(work, "l.sqlite"); const sink = new Sink(db, cfgOf(c)); sink.init(c); sink.commit(mint(c, "rq_l", "1").text); sink.close();
  const res: any = {}; let bad = false;
  for (const [n, line] of Object.entries({ nul: "null", num: "5", arr: "[]", str: "\"x\"", dup: JSON.stringify({ requestId: "zz", postStateSha256: "q", preStateSha256: "w" }).replace("{", "{\"preStateSha256\":\"" + E.stateSha256(c) + "\",") })) {
    const lp = join(work, "ledger_" + n); writeFileSync(lp, line + "\n");
    const effects: any[] = []; let out: string;
    try { const d = new Dispatcher(db, lp, { publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK, initialStateSha256: E.stateSha256(c) }, (e: any) => effects.push(e)).flush(); out = "emitted " + d.emitted.length; }
    catch (e) { out = "throw: " + String((e as Error).message).slice(0, 60); }
    res[n] = out; if (effects.length !== 0) bad = true;
  }
  check("dispatcher: hostile ledger first lines emit nothing", !bad, res);
}
console.log("FAILS " + fails);
process.exit(fails === 0 ? 0 : 1);
