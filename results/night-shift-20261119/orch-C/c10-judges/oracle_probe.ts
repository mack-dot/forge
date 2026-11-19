// oracle_probe.ts <tree> <model.cjs>: hand-made histories against the spec-conformance ORACLE (B's oracle.ts in <tree>).
// Part 1 (semantics, expected verdicts from protocol.md): zero, amount == remaining, refundEnabled false, second id at 0.
// Part 2 (oracle blind spots): committed bad-signature / wrong-pin / stale / non-canonical tokens; replay answered
// "rejected"; a DIFFERENT token with a settled id answered "replayed". Exit 1 if any part-2 case gets NO violation
// (= the oracle accepts a defective sink), or if a part-1 case differs from the protocol (= oracle defect); else 0.
import { generateKeyPairSync, sign } from "node:crypto";
import { join } from "node:path";
const [tree, model] = process.argv.slice(2);
const E = require(join(tree, "ts/refund-finality/encoding.ts"));
const { Oracle } = require(join(tree, "tests/refund-finality/spec-conformance/oracle.ts"));
const o = new Oracle(model);
const k = generateKeyPairSync("ed25519"), other = generateKeyPairSync("ed25519");
const pem = k.publicKey.export({ type: "spki", format: "pem" }) as string;
const LOCK = E.sha256hex("lock"), CHK = E.sha256hex("checker");
type C = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
const c = (rem: string, en = true, orig = "100"): C => ({ chargeId: "ch_1", original: orig, remaining: rem, refundEnabled: en });
const I = (rid: string, amt: string, reason = "duplicate_charge") => ({ chargeId: "ch_1", requestId: rid, amount: amt, reason });
const tok = (pre: C, rid: string, post: C, intent: any, key = k.privateKey, lock = LOCK) => {
  const body = { domain: E.DOMAIN, specLockSha256: lock, checkerSha256: CHK, preStateSha256: E.sha256hex(E.canon(pre)), requestId: rid, post, intent };
  return E.canon({ body, signature: sign(null, E.signedBytes(body), key).toString("base64") });
};
const snap = (s: C, settled: string[], out: any[]) => ({ state: E.canon(s), settled, outbox: out.map(i => ({ request_id: i.requestId, intent: E.canon(i) })) });
const H = (c0: C, ds: any[]) => ({ initial: c0, publicKeyPem: pem, specLockSha256: LOCK, checkerSha256: CHK, start: snap(c0, [], []), deliveries: ds });
const props = (h: any) => [...new Set(o.check(h).violations.map((v: any) => v.property))].join(",") || "none";
let bad = 0;
const want = (part: string, name: string, h: any, expect: string) => {
  const got = props(h); const ok = got === expect; if (!ok) bad++;
  console.log(`${ok ? "OK  " : "MISS"} ${part} ${name}: oracle=${got} expected=${expect}`);
};
const c0 = c("100"), a30 = I("r1", "30"), t1 = tok(c0, "r1", c("70"), a30);
// ---- part 1: protocol semantics
want("P1-sem", "zero on remaining 0 committed", H(c("0"), [{ text: tok(c("0"), "z", c("0"), I("z", "0")), outcome: "committed", after: snap(c("0"), ["z"], [I("z", "0")]) }]), "none");
want("P1-sem", "zero on remaining 0 rejected", H(c("0"), [{ text: tok(c("0"), "z", c("0"), I("z", "0")), outcome: "rejected", after: snap(c("0"), [], []) }]), "P5");
want("P1-sem", "amount == remaining committed", H(c0, [{ text: tok(c0, "f", c("0"), I("f", "100")), outcome: "committed", after: snap(c("0"), ["f"], [I("f", "100")]) }]), "none");
want("P1-sem", "refundEnabled false, zero, rejected", H(c("100", false), [{ text: tok(c("100", false), "z", c("100", false), I("z", "0")), outcome: "rejected", after: snap(c("100", false), [], []) }]), "none");
want("P1-sem", "refundEnabled false, zero, committed", H(c("100", false), [{ text: tok(c("100", false), "z", c("100", false), I("z", "0")), outcome: "committed", after: snap(c("100", false), ["z"], [I("z", "0")]) }]), "P1");
want("P1-sem", "second id after 0, amount 1 rejected", H(c0, [{ text: tok(c0, "f", c("0"), I("f", "100")), outcome: "committed", after: snap(c("0"), ["f"], [I("f", "100")]) },
  { text: tok(c("0"), "g", c("0"), I("g", "1")), outcome: "rejected", after: snap(c("0"), ["f"], [I("f", "100")]) }]), "none");
want("P1-sem", "replay answered replayed", H(c0, [{ text: t1, outcome: "committed", after: snap(c("70"), ["r1"], [a30]) }, { text: t1, outcome: "replayed", after: snap(c("70"), ["r1"], [a30]) }]), "none");
// ---- part 2: defective sink behaviour that the oracle should flag (expected = some violation; "none" = blind)
const blind = (name: string, h: any) => { const got = props(h); const ok = got !== "none"; if (!ok) bad++; console.log(`${ok ? "OK  " : "BLIND"} P2-def ${name}: oracle=${got} (a defect; want a violation)`); };
blind("committed token signed by ANOTHER key", H(c0, [{ text: tok(c0, "r1", c("70"), a30, other.privateKey), outcome: "committed", after: snap(c("70"), ["r1"], [a30]) }]));
blind("committed token with a WRONG spec lock", H(c0, [{ text: tok(c0, "r1", c("70"), a30, k.privateKey, E.sha256hex("x")), outcome: "committed", after: snap(c("70"), ["r1"], [a30]) }]));
blind("committed STALE token (pre-state hash of another state)", H(c0, [{ text: tok(c("55"), "r1", c("70"), a30), outcome: "committed", after: snap(c("70"), ["r1"], [a30]) }]));
blind("committed NON-CANONICAL token text", H(c0, [{ text: " " + t1, outcome: "committed", after: snap(c("70"), ["r1"], [a30]) }]));
blind("replay of a committed token answered rejected (PR 63-64: returns its recorded decision)", H(c0, [{ text: t1, outcome: "committed", after: snap(c("70"), ["r1"], [a30]) }, { text: t1, outcome: "rejected", after: snap(c("70"), ["r1"], [a30]) }]));
blind("DIFFERENT token, settled id, answered replayed (PR 64: rejected)", H(c0, [{ text: t1, outcome: "committed", after: snap(c("70"), ["r1"], [a30]) },
  { text: tok(c("70"), "r1", c("60"), I("r1", "10")), outcome: "replayed", after: snap(c("70"), ["r1"], [a30]) }]));
console.log(`# misses/blind: ${bad}`);
process.exit(bad === 0 ? 0 : 1);
