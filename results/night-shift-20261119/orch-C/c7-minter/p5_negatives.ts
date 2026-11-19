// c7-minter P5: raw-protocol and value-conversion probes. Each probe names the SAFE outcome.
// A pre-state hash/value split would be the serious one: a token whose preStateSha256 names state S1 while the
// proved decision used state S2. Exit 1 = any probe is unsafe; 0 = all safe.
import { Raw, mycanon, sha } from "./raw";
const S = { chargeId: "ch_1", original: "100", remaining: "100", refundEnabled: true };
const S2 = { ...S, remaining: "10" };
const tr = (pre: any, rid: string, amount: string) => ({ request: { requestId: rid, amount, reason: "duplicate_charge" },
  post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() },
  intent: { chargeId: pre.chargeId, requestId: rid, amount, reason: "duplicate_charge" } });
const J = (x: any) => JSON.stringify(x);
// Safe for an ISSUED token: its preStateSha256 is the hash of the body's own post+amount-consistent pre, and
// equals the hash the sink would compute from the pre that drove the decision. We verify the invariant that the
// signed preStateSha256 equals sha(mycanon(pre')) where pre' = post with remaining += intent.amount, and the
// body is internally consistent. A mismatch here = hash/value split.
function consistent(b: any): boolean {
  const preRem = (BigInt(b.post.remaining) + BigInt(b.intent.amount)).toString();
  const pre = { chargeId: b.post.chargeId, original: b.post.original, remaining: preRem, refundEnabled: b.post.refundEnabled };
  return b.preStateSha256 === sha(mycanon(pre)) && b.requestId === b.intent.requestId;
}
(async () => {
  const m = await new Raw(["off"]).start();
  const res: any[] = []; let unsafe = 0;
  const probe = async (name: string, line: Buffer | string, n: number, safe: (a: any[]) => boolean) => {
    const a = (await m.send(line, n)).map(x => x.msg); const ok = safe(a); if (!ok) unsafe++;
    res.push({ name, safe: ok, ans: a.map(x => x.ok ? { id: x.id, rid: x.token.body.requestId, pre8: x.token.body.preStateSha256.slice(0, 8), amt: x.token.body.intent.amount, consistent: consistent(x.token.body) } : { id: x.id, no: x.reason }) });
  };
  const t50 = tr(S, "rq_50", "50");                         // authorized for S (remaining 100), not for S2 (remaining 10)
  // duplicate "pre" keys: JSON.parse keeps the last. Safe: any issued token is internally consistent and its hash
  // matches the pre that drove the decision (no split between hashed state and decided state).
  await probe("dup-pre first=S last=S2", `{"id":1,"pre":${J(S)},"pre":${J(S2)},"transition":${J(t50)}}`, 1, a => !a[0].ok || consistent(a[0].token.body));
  await probe("dup-pre first=S2 last=S", `{"id":2,"pre":${J(S2)},"pre":${J(S)},"transition":${J(t50)}}`, 1, a => !a[0].ok || consistent(a[0].token.body));
  // prototype key: __proto__ carrying refundEnabled. Safe: refuse (extra/own-key check), or a consistent token.
  await probe("proto refundEnabled", `{"id":3,"pre":{"chargeId":"ch_1","original":"100","remaining":"100","__proto__":{"refundEnabled":true}},"transition":${J(t50)}}`, 1, a => !a[0].ok || consistent(a[0].token.body));
  // two requests on one line: only the first (up to 0x0A here there is none) -> actually one JSON per line; a second
  // object after the first is trailing garbage. Safe: refuse (JSON.parse throws on trailing data).
  await probe("two-objects-one-line", `{"id":4,"pre":${J(S)},"transition":${J(t50)}}{"id":5,"pre":${J(S)},"transition":${J(t50)}}`, 1, a => !a[0].ok);
  // extra top-level key. Safe: refuse ([S3]).
  await probe("extra-key", `{"id":6,"pre":${J(S)},"transition":${J(t50)},"x":1}`, 1, a => !a[0].ok);
  // value conversion: amount "00","+1","1e3"," 1","0x10","1.0","-0" must all be refused (MONEY regex). Safe: refuse.
  for (const amt of ["00", "+1", "1e3", " 1", "0x10", "1.0", "-0", "01", "10000000000000000000"]) {
    const t = tr(S, "rq_cv", amt as any);
    await probe("amount=" + JSON.stringify(amt), `{"id":7,"pre":${J(S)},"transition":${J(t)}}`, 1, a => !a[0].ok);
  }
  // refundEnabled given as string "false" (truthy) or 1/null. Safe: refuse (typeof boolean required).
  for (const v of ['"false"', "1", "0", "null"]) {
    await probe("refundEnabled=" + v, `{"id":8,"pre":{"chargeId":"ch_1","original":"100","remaining":"100","refundEnabled":${v}},"transition":${J(t50)}}`, 1, a => !a[0].ok);
  }
  // 20-digit original (> MONEY_BOUND). Safe: refuse.
  await probe("original 20-digit", `{"id":9,"pre":${J({ ...S, original: "99999999999999999999" })},"transition":${J(t50)}}`, 1, a => !a[0].ok);
  m.stop();
  console.log(JSON.stringify({ unsafe, res }, null, 1));
  process.exit(unsafe ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
