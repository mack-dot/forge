// Self-tests of the spec-conformance oracle (task h-specdiff). Hand-made histories, no sink.
// Run: node --import tsx tests/refund-finality/spec-conformance/selftest.ts <compiledCoreModule>
// Each history has one known defect; the oracle must flag that property. The clean history must pass.
// Exit 0 when every case gives the expected result, 1 otherwise.
import { generateKeyPairSync, sign } from "node:crypto";
import { ChargeState, DOMAIN, canon, keyIdOf, sha256hex, signedBytes } from "../../../ts/refund-finality/encoding";
import { Delivery, History, Oracle, Prop, Snapshot } from "./oracle";

const core = process.argv[2];
if (!core) { process.stderr.write("usage: selftest.ts <compiledCoreModule>\n"); process.exit(2); }
const oracle = new Oracle(core);
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const other = generateKeyPairSync("ed25519").privateKey;
const pem = publicKey.export({ type: "spki", format: "pem" }) as string;
const LOCK = sha256hex("lock"), CHK = sha256hex("checker");
const c0: ChargeState = { chargeId: "ch_1", original: "100", remaining: "100", refundEnabled: true };
const S = (remaining: string, chargeId = "ch_1"): ChargeState => ({ ...c0, chargeId, remaining });
type I = { chargeId: string; requestId: string; amount: string; reason: string };
const I = (requestId: string, amount: string, reason = "duplicate_charge", chargeId = "ch_1"): I => ({ chargeId, requestId, amount, reason });
function tok(pre: ChargeState, requestId: string, post: ChargeState, intent: I, key = privateKey): string {
  const body = { domain: DOMAIN, specLockSha256: LOCK, checkerSha256: CHK, preStateSha256: sha256hex(canon(pre)), requestId, post, intent };
  const keyId = keyIdOf(publicKey);   // D-1: the pinned key id (also for a token signed by the other key)
  return canon({ body, keyId, signature: sign(null, signedBytes(body as any, keyId), key).toString("base64") });
}
const snap = (state: ChargeState, settled: string[], outbox: I[]): Snapshot =>
  ({ state: canon(state), settled, outbox: outbox.map(i => ({ request_id: i.requestId, intent: canon(i) })) });
const H = (deliveries: Delivery[]): History =>
  ({ initial: c0, publicKeyPem: pem, specLockSha256: LOCK, checkerSha256: CHK, start: snap(c0, [], []), deliveries });

const a30 = I("r1", "30"), a0 = I("r2", "0");
const t1 = tok(c0, "r1", S("70"), a30);
const clean = H([
  { text: t1, outcome: "committed", after: snap(S("70"), ["r1"], [a30]) },
  { text: tok(S("70"), "r2", S("70"), a0), outcome: "committed", after: snap(S("70"), ["r1", "r2"], [a30, a0]) },   // zero amount
  { text: t1, outcome: "replayed", after: snap(S("70"), ["r1", "r2"], [a30, a0]) },
  { text: tok(S("70"), "r3", S("0"), I("r3", "70"), other), outcome: "rejected", after: snap(S("70"), ["r1", "r2"], [a30, a0]) },
  { text: tok(c0, "r4", S("90"), I("r4", "10")), outcome: "rejected", after: snap(S("70"), ["r1", "r2"], [a30, a0]) },   // stale
]);
const bad = I("r1", "30", "fraud");
const cases: [string, History, Prop | null][] = [
  ["clean history (incl. zero amount, replay, wrong key, stale)", clean, null],
  ["P1: unapproved reason committed", H([{ text: tok(c0, "r1", S("70"), bad), outcome: "committed", after: snap(S("70"), ["r1"], [bad]) }]), "P1"],
  ["P2: second effect for (ch_1, r1)", H([
    { text: t1, outcome: "committed", after: snap(S("70"), ["r1"], [a30]) },
    { text: tok(S("70"), "r9", S("60"), I("r1", "10")), outcome: "committed", after: snap(S("60"), ["r1", "r9"], [a30, I("r1", "10")]) }]), "P2"],
  ["P3: post state not POST-RULE (remaining unchanged)", H([{ text: tok(c0, "r1", c0, a30), outcome: "committed", after: snap(c0, ["r1"], [a30]) }]), "P3"],
  ["P4: sum of effects above original", H([
    { text: tok(c0, "r1", c0, I("r1", "100")), outcome: "committed", after: snap(c0, ["r1"], [I("r1", "100")]) },
    { text: tok(c0, "r2", c0, I("r2", "100")), outcome: "committed", after: snap(c0, ["r1", "r2"], [I("r1", "100"), I("r2", "100")]) }]), "P4"],
  ["P6: rejected delivery released an effect", H([{ text: t1, outcome: "rejected", after: snap(c0, [], [a30]) }]), "P6"],
  ["P7: effect carries a foreign charge id", H([{ text: tok(c0, "r1", S("70"), I("r1", "30", "duplicate_charge", "ch_x")), outcome: "committed",
    after: snap(S("70"), ["r1"], [I("r1", "30", "duplicate_charge", "ch_x")]) }]), "P7"],
  ["P5 (extra): authorized zero-amount token rejected", H([{ text: tok(c0, "r1", c0, I("r1", "0")), outcome: "rejected", after: snap(c0, [], []) }]), "P5"],
  // task h-judges: P8 (authenticity of commits), P6R (replay answers), P9 (restart), dispatcher emissions, start refusal.
  ["P8: commit of a token signed by a foreign key", H([{ text: tok(c0, "r1", S("70"), a30, other), outcome: "committed", after: snap(S("70"), ["r1"], [a30]) }]), "P8"],
  ["P8: commit of a non-canonical token text", H([{ text: JSON.stringify(JSON.parse(t1), null, 1), outcome: "committed", after: snap(S("70"), ["r1"], [a30]) }]), "P8"],
  ["P8: commit of a stale pre-state token (zero amount)", H([
    { text: t1, outcome: "committed", after: snap(S("70"), ["r1"], [a30]) },
    { text: tok(c0, "r2", S("70"), a0), outcome: "committed", after: snap(S("70"), ["r1", "r2"], [a30, a0]) }]), "P8"],
  ["P6R: identical repeat of a committed token answered rejected", H([
    { text: t1, outcome: "committed", after: snap(S("70"), ["r1"], [a30]) },
    { text: t1, outcome: "rejected", after: snap(S("70"), ["r1"], [a30]) }]), "P6R"],
  ["P6R: another token for a settled id answered replayed", H([
    { text: t1, outcome: "committed", after: snap(S("70"), ["r1"], [a30]) },
    { text: tok(S("70"), "r1", S("60"), I("r1", "10")), outcome: "replayed", after: snap(S("70"), ["r1"], [a30]) }]), "P6R"],
  ["P9: a restart wiped the store", H([
    { text: t1, outcome: "committed", after: snap(S("70"), ["r1"], [a30]) },
    { text: "", outcome: "rejected", restart: true, after: snap(c0, [], []) }]), "P9"],
  ["clean restart (nothing changes)", H([
    { text: t1, outcome: "committed", after: snap(S("70"), ["r1"], [a30]) },
    { text: "", outcome: "rejected", restart: true, after: snap(S("70"), ["r1"], [a30]) }]), null],
  ["P2 (emitted): the dispatcher emitted r1 twice", { ...H([{ text: t1, outcome: "committed", after: snap(S("70"), ["r1"], [a30]) }]),
    emitted: [{ requestId: "r1", intent: a30 }, { requestId: "r1", intent: a30 }] }, "P2"],
  ["P1 (emitted): the dispatcher emitted an intent that is not in the outbox", { ...H([{ text: t1, outcome: "committed", after: snap(S("70"), ["r1"], [a30]) }]),
    emitted: [{ requestId: "r1", intent: I("r1", "31") }] }, "P1"],
  ["P4 (emitted): the dispatcher emitted more than the original", { ...H([{ text: t1, outcome: "committed", after: snap(S("70"), ["r1"], [a30]) }]),
    emitted: [{ requestId: "r1", intent: a30 }, { requestId: "rx", intent: I("rx", "71") }] }, "P4"],
  ["clean emissions (each committed intent once)", { ...H([{ text: t1, outcome: "committed", after: snap(S("70"), ["r1"], [a30]) }]),
    emitted: [{ requestId: "r1", intent: a30 }] }, null],
  ["P5: sink refused to start on a valid charge", { ...H([]), startRefused: "refused" }, "P5"],
  ["no violation: sink refused a charge with refundEnabled false", { ...H([]), initial: { ...c0, refundEnabled: false }, startRefused: "refused" }, null],
];
let failed = 0;
for (const [name, h, want] of cases) {
  const v = oracle.check(h);
  const got = [...new Set(v.violations.map(x => x.property))];
  const pass = want === null ? v.ok : got.includes(want);
  if (!pass) failed++;
  process.stdout.write(JSON.stringify({ case: name, expected: want ?? "no violation", flagged: got, first: v.first, pass }) + "\n");
}
process.stdout.write(JSON.stringify({ selftests: cases.length, failed }) + "\n");
process.exit(failed === 0 ? 0 : 1);
