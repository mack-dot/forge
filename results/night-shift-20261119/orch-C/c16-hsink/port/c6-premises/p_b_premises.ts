// c6-premises: test the hypotheses of ShellCoreV6.V6ConformanceNoAssumption against the REAL v6 shell (target-v6 sink.ts).
// Threat model: a faulty or hostile signer (the lemma claims NO signature hypothesis), so a throwaway key signs anything.
// Exit 1 if the real shell commits something the lemma's conclusion forbids (defect); 0 if every probe is safe.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
const [root, work] = process.argv.slice(2);
const E = require(join(root, "ts/refund-finality/encoding.ts"));
const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const pem = publicKey.export({ type: "spki", format: "pem" }).toString();
const SPEC = "a".repeat(64), CHK = "b".repeat(64);
const ids = { publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK };
const tok = (pre: any, rid: string, amount: string, post: any, reason = "duplicate_charge") => {
  const body = { domain: E.DOMAIN, specLockSha256: SPEC, checkerSha256: CHK, preStateSha256: E.stateSha256(pre), requestId: rid,
    post, intent: { chargeId: pre.chargeId, requestId: rid, amount, reason } };
  return E.canon({ body, signature: sign(null, E.signedBytes(body), privateKey).toString("base64") });
};
rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
const out: any = {}; let violation = false;
let n = 0;
const fresh = (s0: any) => { const db = join(work, `p${n++}.sqlite`); const k = new Sink(db, { ...ids, initialState: s0 }); return { k, db }; };
const sub = (a: string, b: string) => (BigInt(a) - BigInt(b)).toString();
// P1: InitOk false (remaining > original). The lemma assumes InitOk; the shell does not check it.
{ const s0 = { chargeId: "ch_1", original: "100", remaining: "1000", refundEnabled: true };
  let started = true, initOk = true; let k: any;
  try { k = fresh(s0).k; } catch (e) { started = false; out.P1start = String(e); }
  if (started) { try { k.init(s0); } catch (e) { initOk = false; out.P1init = String(e); } }
  if (started && initOk) {
    const r = k.commit(tok(s0, "rq_1", "500", { ...s0, remaining: "500" }));
    out.P1 = { started, initOk, commit: r, state: k.stateBlob() };
    if (r.status === "committed") violation = true;   // money above original would leave
    k.close();
  } else out.P1 = { started, initOk };
}
// P2: original above MaxMoney (MONEY regex admits 19 digits up to 9999999999999999999).
{ const s0 = { chargeId: "ch_1", original: "9999999999999999999", remaining: "9999999999999999999", refundEnabled: true };
  const { k } = fresh(s0); k.init(s0);
  const r = k.commit(tok(s0, "rq_1", "9999999999999999999", { ...s0, remaining: "0" }));
  out.P2 = r; if (r.status === "committed") violation = true; k.close(); }
// P3: commit before init (no state row; the shell gives Charge.Default() to StepQ6).
{ const s0 = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
  const { k } = fresh(s0);
  const dflt = { chargeId: "", original: "0", remaining: "0", refundEnabled: false };
  const r1 = k.commit(tok(dflt, "rq_1", "0", dflt));
  const r2 = k.commit(tok(s0, "rq_2", "0", s0));
  out.P3 = { onDefault: r1, onS0: r2 }; if (r1.status === "committed" || r2.status === "committed") violation = true; k.close(); }
// P4: "settled" = SQL lookup vs model membership: astral / combining / NFC-NFD request ids, zero amounts.
{ const s0 = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
  const { k, db } = fresh(s0); k.init(s0);
  const ridA = "rq_\u{1F600}", ridNFC = "rq_é", ridNFD = "rq_é";
  const a1 = k.commit(tok(s0, ridA, "0", s0));
  const a2 = k.commit(tok(s0, ridA, "0", s0, "returned_item"));   // same id, another token: must be refused
  const c1 = k.commit(tok(s0, ridNFC, "0", s0));
  const c2 = k.commit(tok(s0, ridNFD, "0", s0));                  // distinct code points: the model also treats them as two ids
  const ids2 = k.settled().map((r: any) => r.request_id);
  out.P4 = { a1, a2, c1, c2, settledIds: ids2.map((s: string) => [...s].map(c => c.codePointAt(0)!.toString(16))) };
  if (a2.status === "committed") violation = true;
  if (!ids2.includes(ridA)) violation = true;                     // stored id did not read back
  k.close();
  let restart = true; try { new Sink(db, { ...ids, initialState: s0 }).close(); } catch (e) { restart = false; out.P4restart = String(e); }
  out.P4.restartOk = restart; }
// P5: amount above remaining, wrong post, unapproved reason with a VALID signature: must be refused (claim "any sigOk").
{ const s0 = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
  const { k } = fresh(s0); k.init(s0);
  const r1 = k.commit(tok(s0, "rq_1", "2000", { ...s0, remaining: sub("1000", "2000").replace("-", "") }));
  const r2 = k.commit(tok(s0, "rq_2", "100", { ...s0, remaining: "950" }));
  const r3 = k.commit(tok(s0, "rq_3", "100", { ...s0, remaining: "900" }, "goodwill"));
  const r4 = k.commit(tok(s0, "rq_4", "100", { ...s0, remaining: "900", original: "900" }));
  out.P5 = { r1, r2, r3, r4, state: k.stateBlob() };
  if ([r1, r2, r3, r4].some(r => r.status === "committed")) violation = true; k.close(); }
console.log(JSON.stringify(out, null, 1));
console.log(violation ? "VIOLATION" : "SAFE: no probe committed outside the lemma's conclusion");
process.exit(violation ? 1 : 0);
