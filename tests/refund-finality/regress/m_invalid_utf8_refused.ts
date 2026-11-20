// Regression C-ATT-15. A stdin line that is not valid UTF-8 is refused (answer with id null) and signs nothing.
// The bytes rq\xff and rq\xfe (and CESU surrogate bytes) were decoded with replacement to "rq" U+FFFD: two different
// wire requests got ONE signed request id. Control: the same line with a valid id issues.
// Usage and exit codes: m_lib.ts.
import { argv, guard, rawIssuer, verdict } from "./m_lib";
const S = { chargeId: "ch_mu", original: "100", remaining: "100", refundEnabled: true };
function line(id: number, rid: Buffer): Buffer {
  const MARK = "@@RID@@";
  const t = { request: { requestId: MARK, amount: "5", reason: "duplicate_charge" }, post: { ...S, remaining: "95" },
    intent: { chargeId: "ch_mu", requestId: MARK, amount: "5", reason: "duplicate_charge" } };
  const parts = JSON.stringify({ id, pre: S, transition: t }).split(MARK);
  return Buffer.concat([...parts.flatMap((p, i) => i === 0 ? [Buffer.from(p)] : [rid, Buffer.from(p)]), Buffer.from("\n")]);
}
guard((async () => {
  const { root, core } = argv();
  const r = rawIssuer(root, core);
  await r.next(1);                                               // the ready line
  r.send(line(1, Buffer.from([0x72, 0x71, 0xff])));
  r.send(line(2, Buffer.from([0x72, 0x71, 0xfe])));
  r.send(line(3, Buffer.from([0x72, 0x71, 0xed, 0xa0, 0x80])));
  r.send(Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), line(4, Buffer.from("rq_bom"))]));  // a leading BOM
  r.send(line(5, Buffer.from("rq_ok")));                         // control
  const out = (await r.next(6)).slice(1);
  r.stop();
  const signed = out.filter(a => a && a.ok === true).map(a => a.token?.body?.requestId);
  verdict(out.length === 5 && signed.length === 1 && signed[0] === "rq_ok",
    { answers: out.map(a => a.ok ? { ok: true, requestId: a.token.body.requestId } : { id: a.id, reason: a.reason }) });
})());
