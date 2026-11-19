// c7-minter P1 (liveness): in mode "on", the single-use map is keyed by the pre-state hash only. A zero-amount
// refund has post == pre, so after it the CURRENT state still hashes to the same key: every later legitimate refund
// on that charge state is refused for the life of the minter process. Also: any caller can burn a pre-state by
// minting one token and withholding it.
// Exit 1 = defect present (a legitimate request is refused); 0 = every legitimate request got a token.
import { Raw } from "./raw";
const S = { chargeId: "ch_1", original: "100", remaining: "100", refundEnabled: true };
const tr = (pre: any, rid: string, amount: string) => ({ request: { requestId: rid, amount, reason: "duplicate_charge" },
  post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() },
  intent: { chargeId: pre.chargeId, requestId: rid, amount, reason: "duplicate_charge" } });
(async () => {
  const m = await new Raw(["on"]).start();
  const ask = async (id: number, pre: any, rid: string, amt: string) =>
    (await m.send(JSON.stringify({ id, pre, transition: tr(pre, rid, amt) })))[0].msg;
  const r: any = {};
  // Case A: zero-amount refund, committed by the sink: state stays S. Then a real refund on S.
  r.zero = await ask(1, S, "rq_zero", "0");
  r.afterZero = await ask(2, S, "rq_real", "10");
  // Case B (fresh pre-state S2): caller X mints and withholds; honest Y asks for the same current state.
  const S2 = { ...S, chargeId: "ch_2" };
  r.withheld = await ask(3, S2, "rq_attacker", "1");
  r.honest = await ask(4, S2, "rq_honest", "5");
  m.stop();
  const out = { zeroOk: r.zero.ok, afterZero: r.afterZero.ok ? "token" : r.afterZero.reason,
    withheldOk: r.withheld.ok, honest: r.honest.ok ? "token" : r.honest.reason };
  console.log(JSON.stringify(out));
  process.exit(r.zero.ok && r.withheld.ok && (!r.afterZero.ok || !r.honest.ok) ? 1 : 0);
})().catch(e => { console.error(e); process.exit(3); });
