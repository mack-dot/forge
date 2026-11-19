// c7-minter P2 (input strictness): minter.ts:126 decodes each stdin line with Buffer.toString("utf8"), which
// replaces each invalid UTF-8 sequence with U+FFFD and never refuses. A request whose id bytes are NOT UTF-8
// (so not a JSON text, RFC 8259 section 8.1) gets a token whose signed body names a DIFFERENT id (with U+FFFD).
// Two different byte requests (0xFF vs 0xFE) map to one signed body.
// Exit 1 = a token is signed for a line that is not valid UTF-8; 0 = such lines are refused.
import { Raw, bodyBytesOf } from "./raw";
const S = { chargeId: "ch_1", original: "100", remaining: "100", refundEnabled: true };
function line(id: number, rid: Buffer): Buffer {
  const MARK = "@@RID@@";
  const t = { request: { requestId: MARK, amount: "5", reason: "duplicate_charge" }, post: { ...S, remaining: "95" },
    intent: { chargeId: "ch_1", requestId: MARK, amount: "5", reason: "duplicate_charge" } };
  const parts = JSON.stringify({ id, pre: S, transition: t }).split(MARK);
  return Buffer.concat(parts.flatMap((p, i) => i === 0 ? [Buffer.from(p)] : [rid, Buffer.from(p)]));
}
(async () => {
  const m = await new Raw(["off"]).start();
  const a = (await m.send(line(1, Buffer.from([0x72, 0x71, 0xff]))))[0];
  const b = (await m.send(line(2, Buffer.from([0x72, 0x71, 0xfe]))))[0];
  const c = (await m.send(line(3, Buffer.from([0x72, 0x71, 0xed, 0xa0, 0x80]))))[0];   // CESU surrogate bytes
  m.stop();
  const show = (x: any) => x.msg.ok ? { ok: true, requestId: x.msg.token.body.requestId, bodySha: require("node:crypto").createHash("sha256").update(bodyBytesOf(x.raw)!).digest("hex").slice(0, 16) } : x.msg;
  const out = { ff: show(a), fe: show(b), cesu: show(c) };
  console.log(JSON.stringify(out));
  process.exit(a.msg.ok || b.msg.ok || c.msg.ok ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
