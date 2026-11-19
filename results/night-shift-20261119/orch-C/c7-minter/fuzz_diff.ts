// c7-minter: differential check of minter.ts (mode off) against an independent oracle of the approved relation
// (spec/refund/RefundSpec.dfy Eligible + impl/RefundFinality.dfy Authorizes) and of the shape/serialization rules.
// Usage: fuzz_diff.ts <cases <= 2000> <seed>. Exit 0 = no divergence; 1 = divergence; 3 = harness error.
import { Raw, bodyBytesOf, mycanon, pinnedChecker, pinnedSpec, sha, verifies } from "./raw";

const N = Math.min(2000, Number(process.argv[2] || 2000)); let seed = Number(process.argv[3] || 7) >>> 0;
const rnd = () => { seed ^= seed << 13; seed >>>= 0; seed ^= seed >>> 17; seed ^= seed << 5; seed >>>= 0; return seed / 4294967296; };
const pick = <T>(a: T[]): T => a[Math.floor(rnd() * a.length)];
const MAX = 9223372036854775807n;
const MONEYS = ["0", "1", "2", "7", "100", "60", "9223372036854775807", "9223372036854775806", "9223372036854775808",
  "9999999999999999999", "1000000000000000000"];
const BADMONEY = ["00", "+1", "1e3", " 1", "0x10", "1.0", "-0", "-1", "10000000000000000000", "", "01"];
const IDS = ["ch_1", "rq_1", "", "a", " x", "x ", "\"q\\", "\u0001\u001f\u007f", "😀", "�", "﻿b",
  "é", "é", "x".repeat(256), "x".repeat(257), "😀".repeat(128), "😀".repeat(129) , "\u0000", "\ud800",
  "a\nb", "\t", "<script>", "__proto__", "constructor"];
const REASONS = ["duplicate_charge", "service_not_delivered", "returned_item", "Duplicate_charge", "", "duplicate_charge ", "other"];
const okText = (v: any) => typeof v === "string" && v.length <= 256 && !v.includes("\u0000") &&
  !/[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/.test(v);
const okMoney = (v: any) => typeof v === "string" && /^(0|[1-9][0-9]{0,18})$/.test(v);

function gen(): { pre: any; t: any } {
  const original = rnd() < 0.05 ? pick(BADMONEY) : pick(MONEYS.concat([String(Math.floor(rnd() * 1000))]));
  let remaining = rnd() < 0.05 ? pick(BADMONEY) : pick([original, "0", pick(MONEYS), String(Math.floor(rnd() * 1000))]);
  if (okMoney(original) && okMoney(remaining) && BigInt(remaining) > BigInt(original) && rnd() < 0.7) remaining = original;
  const pre: any = { chargeId: rnd() < 0.8 ? "ch_1" : pick(IDS), original, remaining, refundEnabled: rnd() < 0.85 ? true : pick<any>([false, "false", 1, null]) };
  const rem = okMoney(remaining) ? BigInt(remaining) : 0n;
  const amount = rnd() < 0.05 ? pick(BADMONEY) : pick(["0", rem.toString(), (rem + 1n).toString(), (rem > 0n ? rem - 1n : 0n).toString(),
    String(Math.floor(rnd() * 200))]);
  const request = { requestId: rnd() < 0.7 ? "rq_" + Math.floor(rnd() * 1e6) : pick(IDS), amount, reason: rnd() < 0.75 ? pick(REASONS.slice(0, 3)) : pick(REASONS) };
  let postRem: string; try { postRem = (BigInt(remaining) - BigInt(amount)).toString(); } catch { postRem = "0"; }
  const post: any = { ...pre, remaining: postRem };
  const intent: any = { chargeId: pre.chargeId, requestId: request.requestId, amount, reason: request.reason };
  const m = rnd();
  if (m < 0.04) post.original = pick(MONEYS); else if (m < 0.08) post.chargeId = pick(IDS);
  else if (m < 0.10) post.refundEnabled = !pre.refundEnabled; else if (m < 0.13) post.remaining = pick(MONEYS);
  else if (m < 0.15) intent.amount = pick(MONEYS); else if (m < 0.17) intent.requestId = pick(IDS);
  else if (m < 0.19) intent.chargeId = pick(IDS); else if (m < 0.21) intent.reason = pick(REASONS);
  return { pre, t: { request, post, intent } };
}
function oracle(pre: any, t: any): boolean {
  const st = (s: any) => okText(s.chargeId) && okMoney(s.original) && okMoney(s.remaining) && typeof s.refundEnabled === "boolean";
  if (!st(pre) || !st(t.post) || !okText(t.request.requestId) || !okMoney(t.request.amount) || !okText(t.request.reason)) return false;
  if (!okText(t.intent.chargeId) || !okText(t.intent.requestId) || !okMoney(t.intent.amount) || !okText(t.intent.reason)) return false;
  const o = BigInt(pre.original), r = BigInt(pre.remaining), a = BigInt(t.request.amount);
  const valid = pre.chargeId !== "" && t.request.requestId !== "" && pre.refundEnabled === true && 0n <= o && o <= MAX && 0n <= r && r <= o;
  const elig = valid && 0n <= a && a <= r && ["duplicate_charge", "service_not_delivered", "returned_item"].includes(t.request.reason);
  const postOk = t.post.chargeId === pre.chargeId && t.post.original === pre.original && t.post.refundEnabled === pre.refundEnabled &&
    BigInt(t.post.remaining) === r - a;
  const intentOk = t.intent.chargeId === pre.chargeId && t.intent.requestId === t.request.requestId &&
    BigInt(t.intent.amount) === a && t.intent.reason === t.request.reason;
  return elig && postOk && intentOk;
}
(async () => {
  const m = await new Raw(["off"]).start();
  const checker = pinnedChecker(), spec = pinnedSpec();
  let issued = 0, zero = 0, full = 0, refused = 0; const bad: any[] = [];
  if (m.ready.checkerSha256 !== checker || m.ready.specLockSha256 !== spec) bad.push({ ready: m.ready, checker, spec });
  for (let i = 0; i < N; i++) {
    const { pre, t } = gen(); const line = Buffer.from(JSON.stringify({ id: i, pre, transition: t }), "utf8");
    let ans;
    if (rnd() < 0.1) { // split over two chunks
      const cut = Math.floor(rnd() * line.length); m.write(line.subarray(0, cut)); await new Promise(r => setTimeout(r, 2));
      ans = (await m.send(line.subarray(cut)))[0];
    } else ans = (await m.send(line))[0];
    const want = oracle(pre, t), got = ans.msg.ok === true;
    if (ans.msg.id !== i) bad.push({ i, why: "id", ans: ans.msg });
    if (want !== got) { bad.push({ i, why: "decision", want, got, pre, t, reason: ans.msg.reason }); continue; }
    if (!got) { refused++; continue; }
    issued++; if (t.request.amount === "0") zero++; if (t.request.amount === pre.remaining) full++;
    const body = { domain: "FORGE_REFUND_FINALITY_SLICE1_V1", specLockSha256: spec, checkerSha256: checker, preStateSha256: sha(mycanon(pre)),
      requestId: t.request.requestId, post: t.post, intent: t.intent };
    const bb = bodyBytesOf(ans.raw);
    if (!bb || !bb.equals(Buffer.from(mycanon(body), "utf8"))) bad.push({ i, why: "body bytes", got: bb?.toString(), want: mycanon(body) });
    else if (!verifies(m.ready, bb, ans.msg.token.signature)) bad.push({ i, why: "signature" });
  }
  m.stop();
  console.log(JSON.stringify({ cases: N, issued, zero, full, refused, divergences: bad.length, first: bad.slice(0, 5) }));
  process.exit(bad.length ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
