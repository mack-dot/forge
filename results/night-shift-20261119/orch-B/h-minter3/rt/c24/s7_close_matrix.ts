// S7: Store mode; which refusals CLOSE a (charge id, request id) pair. For each kind, one request with a victim id
// V_k, then the victim's honest request (V_k, real state, 250, duplicate_charge). Attacker: a minter caller without the key.
// Exit 1 = at least one request from a caller WITHOUT the key makes the victim's later honest request fail (for the
// life of the process). Exit 0 = no such request. Usage: s7_close_matrix.ts <work dir>
import { join } from "node:path";
import { Raw, done, fresh, guard, mint, newSink, propose, st } from "./lib";
const [work] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const path = join(work, "s.sqlite");
  const m = await new Raw(["on", path]).start();
  const s0 = st("ch_S7", "1000", "600");     // stored state: remaining 600 (not the original)
  const sink = newSink(m, path, s0); sink.init(s0);
  const bogusPre = st("ch_S7", "1000", "1000"), other = st("ch_OTHER", "1000", "600");
  const kinds: Record<string, (v: string) => Promise<any>> = {
    shape_missing_field: async v => (await m.send(JSON.stringify({ id: 9000, pre: s0, transition: { request: { requestId: v, amount: "1", reason: "duplicate_charge" } } })))[0].msg,
    non_utf8: async v => (await m.send(Buffer.concat([Buffer.from(JSON.stringify({ id: 9001, pre: s0, transition: propose(s0, v, "1") }).slice(0, -2)), Buffer.from([0xff]), Buffer.from("}}")])))[0].msg,
    unknown_charge: async v => mint(m, other, propose(other, v, "1")),
    pre_mismatch_invented: async v => mint(m, bogusPre, propose(bogusPre, v, "0")),
    refund_disabled_pre: async v => { const d = { ...s0, refundEnabled: false }; return mint(m, d, propose(d, v, "1")); },
    core_amount_above_remaining: async v => { const t: any = propose(s0, v, "601"); t.post.remaining = "0"; return mint(m, s0, t); },
    core_unapproved_reason: async v => mint(m, s0, propose(s0, v, "1", "free_money")),
    core_wrong_post: async v => { const t: any = propose(s0, v, "100"); t.post.remaining = "550"; return mint(m, s0, t); },
    core_intent_id_differs: async v => { const t: any = propose(s0, v, "100"); t.intent.requestId = "x"; return mint(m, s0, t); },
    core_negative_amount: async v => mint(m, s0, propose(s0, v, "-1")),
    zero_amount_real_state: async v => mint(m, s0, propose(s0, v, "0")),
    other_amount_real_state: async v => mint(m, s0, propose(s0, v, "1")),
  };
  const res: Record<string, any> = {}; const closing: string[] = [];
  for (const [k, f] of Object.entries(kinds)) {
    const v = "V_" + k;
    const a = await f(v);
    const h = await mint(m, s0, propose(s0, v, "250"));
    res[k] = { attacker: a.ok ? "SIGNED" : a.reason, victim: h.ok ? "issued" : h.reason };
    if (!h.ok) closing.push(k);
  }
  sink.close(); m.stop();
  done(closing.length > 0, { closing, res });
})());
