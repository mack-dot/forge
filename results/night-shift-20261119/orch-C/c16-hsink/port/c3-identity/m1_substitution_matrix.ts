// M1. Field substitution inside a validly signed token (faulty signer: throwaway key pinned in config), against
// sink.commit on the stored state s0 = (ch_M, 1000, 1000, true). One fresh store per case. Control: the honest body.
// Exit 1 = a substituted token commits OR the control is refused; 0 = safe.
import { join } from "node:path";
import { load, keys, forge, body, fresh, st, it, SPEC, CHK } from "./lib";
const [root, work] = process.argv.slice(2);
const { E, Sink } = load(root);
fresh(work);
const k = keys();
const s0 = st("ch_M", "1000", "1000"), good = st("ch_M", "1000", "900");
const cfg = { publicKeyPem: k.pub, specLockSha256: SPEC, checkerSha256: CHK, initialState: s0 };
const I = it("ch_M", "rq_1", "100");
const cases: Record<string, any> = {
  control: body(E, s0, "rq_1", good, I),
  bodyReqId: body(E, s0, "rq_X", good, I),
  intentChargeId: body(E, s0, "rq_1", good, { ...I, chargeId: "ch_OTHER" }),
  postChargeId: body(E, s0, "rq_1", { ...good, chargeId: "ch_OTHER" }, I),
  amountGtDelta: body(E, s0, "rq_1", good, { ...I, amount: "500" }),
  amountLtDelta: body(E, s0, "rq_1", st("ch_M", "1000", "100"), I),
  postOriginal: body(E, s0, "rq_1", { ...good, original: "5000" }, I),
  postRefundDisabled: body(E, s0, "rq_1", { ...good, refundEnabled: false }, I),
  badReason: body(E, s0, "rq_1", good, { ...I, reason: "goodwill" }),
  zeroWithPostChange: body(E, s0, "rq_1", good, { ...I, amount: "0" }),
  zeroPostRaisesRemaining: body(E, s0, "rq_1", { ...s0, original: "2000", remaining: "2000" }, { ...I, amount: "0" }),
  amountAboveRemaining: body(E, s0, "rq_1", st("ch_M", "1000", "0"), { ...I, amount: "1001" }),
  emptyRequestId: body(E, s0, "", good, { ...I, requestId: "" }),
  wrongSpec: body(E, s0, "rq_1", good, I, "c".repeat(64), CHK),
  wrongChecker: body(E, s0, "rq_1", good, I, SPEC, "c".repeat(64)),
};
const out: Record<string, string> = {}; let bad = false;
for (const [name, b] of Object.entries(cases)) {
  const db = join(work, name + ".sqlite"); const s = new Sink(db, cfg); s.init(s0);
  let txt: string; try { txt = forge(E, k.priv, b); } catch (e) { out[name] = "not encodable"; s.close(); continue; }
  const v = s.commit(txt); s.close();
  out[name] = v.status + (v.reason ? ": " + v.reason : "");
  if (name === "control" ? v.status !== "committed" : v.status === "committed") bad = true;
}
// domain string: a body with another domain is signed; the decoder must refuse it
{ const db = join(work, "domain.sqlite"); const s = new Sink(db, cfg); s.init(s0);
  const v = s.commit(forge(E, k.priv, { ...cases.control, domain: "OTHER" })); s.close(); out.otherDomain = v.status + ": " + v.reason; if (v.status === "committed") bad = true; }
console.log(JSON.stringify(out, null, 1));
process.exit(bad ? 1 : 0);
