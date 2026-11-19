// K1. Key / pin rotation. The minter makes a NEW Ed25519 key at every process start (minter.ts line 76) and the
// sink config holds ONE publicKeyPem. Honest flow: minter M1 signs rq_1, the sink commits it, M1 ends; minter M2
// starts (new key). The operator pins M2's key in the sink config and restarts the sink.
// Threat: none (false rejection). Also: old token under new pin; new-key token against the old-pin running sink.
// Exit 1 = the legitimate store cannot take any further legitimate refund after the minter restart; 0 = safe.
// With argument "faulty" the two keys are throwaway keys (for the merged tree, whose minter needs its own core).
import { join } from "node:path";
import { load, fresh, st, keys, forge, body, it, SPEC, CHK, MINTER_CORE } from "./lib";
const [root, work, mode] = process.argv.slice(2);
const { E, Sink, P } = load(root);
fresh(work);
(async () => {
  const s0 = st("ch_K", "1000", "1000"), db = join(work, "k.sqlite");
  type Ids = { publicKeyPem: string; specLockSha256: string; checkerSha256: string };
  let ids1: Ids, ids2: Ids, mintTok: (n: 1 | 2, pre: any, rid: string, amt: string) => Promise<string>;
  const m: any[] = [];
  if (mode === "faulty") {
    const k1 = keys(), k2 = keys();
    ids1 = { publicKeyPem: k1.pub, specLockSha256: SPEC, checkerSha256: CHK }; ids2 = { ...ids1, publicKeyPem: k2.pub };
    mintTok = async (n, pre, rid, amt) => forge(E, (n === 1 ? k1 : k2).priv,
      body(E, pre, rid, { ...pre, remaining: String(BigInt(pre.remaining) - BigInt(amt)) }, it(pre.chargeId, rid, amt)));
  } else {
    m[1] = await P.MinterClient.start(root, MINTER_CORE, join(root, "spec/refund/spec.lock"), "off");
    ids1 = { publicKeyPem: m[1].ready.publicKeyPem, specLockSha256: m[1].ready.specLockSha256, checkerSha256: m[1].ready.checkerSha256 };
    mintTok = async (n, pre, rid, amt) => { const a = await m[n].mint(pre, P.propose(pre, { requestId: rid, amount: amt, reason: "duplicate_charge" }));
      if (!a.ok) throw new Error("mint refused " + a.reason); return E.tokenText(a.token); };
    ids2 = ids1; // set below
  }
  const r: Record<string, any> = {};
  let sink = new Sink(db, { ...ids1, initialState: s0 }); sink.init(s0);
  r.c1 = sink.commit(await mintTok(1, s0, "rq_1", "100")).status;
  const s1 = JSON.parse(sink.stateBlob());
  if (mode !== "faulty") {
    m[1].stop();
    m[2] = await P.MinterClient.start(root, MINTER_CORE, join(root, "spec/refund/spec.lock"), "off");
    ids2 = { publicKeyPem: m[2].ready.publicKeyPem, specLockSha256: m[2].ready.specLockSha256, checkerSha256: m[2].ready.checkerSha256 };
  }
  r.newKeyAfterMinterRestart = ids2.publicKeyPem !== ids1.publicKeyPem;
  const t2 = await mintTok(2, s1, "rq_2", "100");
  r.newTokenOnOldPinRunningSink = sink.commit(t2);   // the running sink keeps the old key
  sink.close();
  let served = false;
  try { sink = new Sink(db, { ...ids2, initialState: s0 }); served = true; r.restartNewPin = "served";
    r.newTokenAfterRestart = sink.commit(t2); sink.close(); }
  catch (e) { r.restartNewPin = "REFUSED: " + String((e as Error).message).slice(0, 110); }
  if (m[2]) m[2].stop();
  console.log(JSON.stringify(r));
  process.exit(served && r.newTokenAfterRestart?.status === "committed" ? 0 : 1);
})().catch(e => { console.error(e); process.exit(3); });
