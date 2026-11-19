// Z2. The minter in single-use mode ("on", an owner option, U428) after a zero-amount refund.
// A zero-amount refund keeps the state, so the next refund has the SAME pre-state hash; the single-use rule
// (signedFor: pre-state hash -> body) then refuses every later transition for that charge for the life of the key.
// Threat: none (honest flow; false rejection). Also: any minter caller (no key) can freeze a charge by asking for
// one zero-amount token at the current state, whether or not it is ever committed.
// Exit 1 = a legitimate, authorized refund on the stored state is refused by the minter; 0 = safe.
import { join } from "node:path";
import { load, fresh, st, MINTER_CORE } from "./lib";
const [root, work] = process.argv.slice(2);
const { E, Sink, P } = load(root);
fresh(work);
(async () => {
  const m = await P.MinterClient.start(root, MINTER_CORE, join(root, "spec/refund/spec.lock"), "on");
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const s0 = st("ch_S", "1000", "1000"), db = join(work, "s.sqlite");
  const sink = new Sink(db, { ...ids, initialState: s0 }); sink.init(s0);
  const mint = async (pre: any, rid: string, amount: string) =>
    m.mint(pre, P.propose(pre, { requestId: rid, amount, reason: "duplicate_charge" }));
  const z = await mint(s0, "rq_zero", "0");
  const cz = z.ok ? sink.commit(E.tokenText(z.token)) : { status: "mint refused: " + z.reason };
  const pre = JSON.parse(sink.stateBlob());
  const real = await mint(pre, "rq_real", "100");
  const creal = real.ok ? sink.commit(E.tokenText(real.token)) : null;
  // second charge: the zero token is only MINTED (never committed) by a minter caller
  const t0 = st("ch_T", "500", "500");
  const zt = await mint(t0, "rq_squat", "0");
  const realT = await mint(t0, "rq_realT", "50");
  m.stop(); sink.close();
  console.log(JSON.stringify({ zeroMint: z.ok, zeroCommit: cz, realMint: real.ok ? "signed" : "REFUSED: " + real.reason, realCommit: creal,
    chargeT: { zeroMintedOnly: zt.ok, realMint: realT.ok ? "signed" : "REFUSED: " + realT.reason } }));
  process.exit(real.ok && creal?.status === "committed" && realT.ok ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
