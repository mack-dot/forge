// Z1. Zero-amount and boundary refunds with the HONEST minter (single-use off). Threat: none (false-rejection check).
// Legit flow: three zero-amount tokens for s0 committed in reverse mint order; a 100 refund; a zero-amount token
// minted for s0 BEFORE the 100 refund (stale: must be refused, not a defect); a full refund of the rest; a
// zero-amount refund on remaining 0; a restart; the dispatcher. Also a charge with refundEnabled false (the spec refuses).
// Exit 1 = a legitimate token is refused or not dispatched, or a stale one commits; 0 = safe.
import { join } from "node:path";
import { load, fresh, st, MINTER_CORE } from "./lib";
const [root, work] = process.argv.slice(2);
const { E, Sink, Dispatcher, P } = load(root);
fresh(work);
(async () => {
  const m = await P.MinterClient.start(root, MINTER_CORE, join(root, "spec/refund/spec.lock"), "off");
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const s0 = st("ch_Z", "1000", "1000"), db = join(work, "z.sqlite");
  let sink = new Sink(db, { ...ids, initialState: s0 }); sink.init(s0);
  const cur = () => JSON.parse(sink.stateBlob());
  const mint = async (pre: any, rid: string, amount: string) => {
    const a = await m.mint(pre, P.propose(pre, { requestId: rid, amount, reason: "duplicate_charge" }));
    return a.ok ? E.tokenText(a.token) : "REFUSED:" + a.reason;
  };
  const r: Record<string, any> = {};
  const zs = [await mint(s0, "rq_0a", "0"), await mint(s0, "rq_0b", "0"), await mint(s0, "rq_0c", "0")];
  const stale0 = await mint(s0, "rq_0stale", "0");
  r.zeros = zs.reverse().map(t => sink.commit(t).status);
  r.sameStateAfterZeros = sink.stateBlob() === E.canon(s0);
  r.r100 = sink.commit(await mint(cur(), "rq_100", "100")).status;
  r.staleZero = sink.commit(stale0);
  r.full = sink.commit(await mint(cur(), "rq_full", "900")).status;
  r.zeroAtRemaining0 = sink.commit(await mint(cur(), "rq_0end", "0")).status;
  r.tooMuchAt0 = await mint(cur(), "rq_more", "1");
  sink.close();
  try { sink = new Sink(db, { ...ids, initialState: s0 }); r.restart = "served"; sink.close(); } catch (e) { r.restart = "REFUSED " + (e as Error).message; }
  const effects: any[] = [];
  const d = new Dispatcher(db, join(work, "led.jsonl"), { ...ids, initialStateSha256: E.stateSha256(s0) }, (_e: any, i: any) => effects.push(i)).flush();
  r.emitted = effects.map(i => i.requestId + ":" + i.amount); r.refused = d.refused;
  const off = st("ch_off", "1000", "1000", false);
  r.disabledZero = await mint(off, "rq_off", "0");
  m.stop();
  const ok = r.zeros.every((s: string) => s === "committed") && r.sameStateAfterZeros && r.r100 === "committed" &&
    r.staleZero.status === "rejected" && r.full === "committed" && r.zeroAtRemaining0 === "committed" &&
    String(r.tooMuchAt0).startsWith("REFUSED") && r.restart === "served" && effects.length === 6 && d.refused.length === 0;
  console.log(JSON.stringify(r));
  process.exit(ok ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
