// d-corebacked: LIGHT conformance cases (single short runs; no stress, no fuzz, no kill, no race).
// Runs every case on fresh databases against: the unchanged ts/refund-finality/sink.ts ("real"), the draft
// sink_core_backed.ts with the request-id-patched core ("draft-reqid"), and with the unpatched core ("draft-orig").
// Compares results and final stores. Test keys only (generated here; written to ../keys).
// Run: node --import tsx conformance.ts <out.json>
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import * as sqlite from "node:sqlite";
import { ChargeState, DOMAIN, Intent, TokenBody, canon, sha256hex, signedBytes, stateSha256 } from "../../../../../ts/refund-finality/encoding";

const DIR = __dirname + "/..";
const DB = DIR + "/db";
rmSync(DB, { recursive: true, force: true }); mkdirSync(DB, { recursive: true }); mkdirSync(DIR + "/keys", { recursive: true });
// eslint-disable-next-line @typescript-eslint/no-require-imports
const Real = require(DIR + "/../../../../ts/refund-finality/sink.ts").Sink;
// eslint-disable-next-line @typescript-eslint/no-require-imports
const Draft = require(DIR + "/sink_core_backed.ts").Sink;

const trusted = generateKeyPairSync("ed25519"), attacker = generateKeyPairSync("ed25519");
writeFileSync(DIR + "/keys/test-trusted-public.pem", trusted.publicKey.export({ type: "spki", format: "pem" }) as string);
writeFileSync(DIR + "/keys/test-trusted-private.pem", trusted.privateKey.export({ type: "pkcs8", format: "pem" }) as string);
const SPEC = sha256hex("d-corebacked test spec lock"), CHK = sha256hex("d-corebacked test checker"), OTHER = sha256hex("other");
const pem = trusted.publicKey.export({ type: "spki", format: "pem" }) as string;

// ---- fault hook: throw at the first `INSERT INTO settled` after arming (that is, after the state UPDATE).
const P = sqlite.DatabaseSync.prototype as any, origPrepare = P.prepare;
let armed = false;
P.prepare = function (sql: string) {
  if (armed && sql.startsWith("INSERT INTO settled")) { armed = false; throw new Error("injected fault between writes"); }
  return origPrepare.call(this, sql);
};

const S0: ChargeState = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
function body(pre: ChargeState, rid: string, amount: bigint, o: { intentRid?: string; spec?: string; chk?: string; reason?: string; chargeId?: string } = {}): TokenBody {
  const post = { ...pre, remaining: (BigInt(pre.remaining) - amount).toString() };
  const intent: Intent = { chargeId: o.chargeId ?? pre.chargeId, requestId: o.intentRid ?? rid, amount: amount.toString(), reason: o.reason ?? "returned_item" };
  return { domain: DOMAIN, specLockSha256: o.spec ?? SPEC, checkerSha256: o.chk ?? CHK, preStateSha256: stateSha256(pre), requestId: rid, post, intent };
}
function tok(b: TokenBody, key = trusted.privateKey, flip = false): string {
  const sig = sign(null, signedBytes(b), key); if (flip) sig[5] ^= 1;
  return canon({ body: b, signature: sig.toString("base64") });
}
const postOf = (b: TokenBody) => b.post;

type Step = { input: unknown; fault?: boolean };
type Case = { name: string; init?: ChargeState | null; steps: Step[] };
const t1 = body(S0, "rq_1", 100n);
const big: ChargeState = { chargeId: "ch_big", original: "9999999999999999999", remaining: "9999999999999999999", refundEnabled: true };
const z1 = body(S0, "rq_z1", 0n), z2 = body(S0, "rq_z2", 0n);
const u1 = body(S0, "rq_\u{1F600}", 10n);
const cases: Case[] = [
  { name: "honest commit", steps: [{ input: tok(t1) }] },
  { name: "replay of the same text", steps: [{ input: tok(t1) }, { input: tok(t1) }] },
  { name: "same request id, other token", steps: [{ input: tok(t1) }, { input: tok(body(postOf(t1), "rq_1", 5n)) }] },
  { name: "stale pre-state", steps: [{ input: tok(t1) }, { input: tok(body(S0, "rq_2", 50n)) }] },
  { name: "chain of two", steps: [{ input: tok(t1) }, { input: tok(body(postOf(t1), "rq_2", 50n)) }] },
  { name: "bad signature (flipped byte)", steps: [{ input: tok(t1, trusted.privateKey, true) }] },
  { name: "attacker key", steps: [{ input: tok(t1, attacker.privateKey) }] },
  { name: "wrong spec lock id", steps: [{ input: tok(body(S0, "rq_1", 100n, { spec: OTHER })) }] },
  { name: "wrong checker id", steps: [{ input: tok(body(S0, "rq_1", 100n, { chk: OTHER })) }] },
  { name: "wrong spec and checker ids", steps: [{ input: tok(body(S0, "rq_1", 100n, { spec: OTHER, chk: OTHER })) }] },
  { name: "request-id mismatch, then the victim id", steps: [{ input: tok(body(S0, "rq_body", 100n, { intentRid: "rq_victim" })) }, { input: tok(body({ ...S0, remaining: "900" }, "rq_victim", 100n)) }] },
  { name: "intent charge id is another charge (known gap ChargeIdNotBound)", steps: [{ input: tok(body(S0, "rq_1", 100n, { chargeId: "ch_other" })) }] },
  { name: "zero amount commits", steps: [{ input: tok(z1) }] },
  { name: "two zero amounts, distinct ids, same pre-state", steps: [{ input: tok(z1) }, { input: tok(z2) }] },
  { name: "fault between writes, then retry", steps: [{ input: tok(t1), fault: true }, { input: tok(t1) }] },
  { name: "fault between writes only (store must stay S0)", steps: [{ input: tok(t1), fault: true }] },
  { name: "non-canonical text", steps: [{ input: tok(t1) + " " }] },
  { name: "not a text", steps: [{ input: JSON.parse(tok(t1)) }] },
  { name: "no stored state", init: null, steps: [{ input: tok(t1) }] },
  { name: "no stored state, bad signature", init: null, steps: [{ input: tok(t1, attacker.privateKey) }] },
  { name: "amount 2^63 on a 19-digit charge", init: big, steps: [{ input: tok(body(big, "rq_big", 2n ** 63n)) }] },
  { name: "non-BMP request ids", steps: [{ input: tok(u1) }, { input: tok(body(postOf(u1), "rq_\u{1F601}", 10n)) }, { input: tok(u1) }] },
  { name: "lone surrogate request id (decoder refuses)", steps: [{ input: tok({ ...body(S0, "rq_\uD83D", 10n) }) }] },
];

const SINKS: [string, () => any, any][] = [
  ["real", () => Real, {}], ["draft-reqid", () => Draft, { core: "reqid" }], ["draft-orig", () => Draft, { core: "orig" }],
];
let n = 0;
function runCase(c: Case, which: [string, () => any, any]) {
  const path = `${DB}/${++n}-${which[0]}.sqlite`;
  const s = new (which[1]())(path, { publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK, ...which[2] });
  if (c.init !== null) s.init(c.init ?? S0);
  const results = c.steps.map(st => { armed = !!st.fault; const r = s.commit(st.input); armed = false; return r; });
  const store = { state: s.storedBlob() ?? "<none>", settled: s.settled().map((r: any) => [r.request_id, r.token_sha256]),
    outbox: s.outbox().map((r: any) => [r.request_id, r.intent]), audit: c.init === null ? "<no state>" : s.audit() };
  s.close();
  return { results, store };
}
const report: any[] = [];
let divergences = 0;
for (const c of cases) {
  const per: Record<string, any> = {};
  for (const w of SINKS) per[w[0]] = runCase(c, w);
  const eq = (a: string, b: string) => JSON.stringify(per[a]) === JSON.stringify(per[b]);
  const row = { case: c.name, reqidEqualsReal: eq("real", "draft-reqid"), origEqualsReal: eq("real", "draft-orig"), per };
  if (!row.origEqualsReal) divergences++;
  if (c.name.startsWith("fault between writes only")) for (const k of Object.keys(per)) {
    const st = per[k].store, ok = st.state === canon(S0) && st.settled.length === 0 && st.outbox.length === 0;
    console.log(`fault-only store unchanged for ${k}: ${ok}`); if (!ok) divergences++;
  }
  report.push(row);
  console.log(`${row.reqidEqualsReal ? "EQ " : "DIF"} ${row.origEqualsReal ? "EQ " : "DIF"}  ${c.name}  real=${JSON.stringify(per.real.results.map((r: any) => r.status + (r.reason ? ":" + r.reason : "")))}` +
    (row.reqidEqualsReal ? "" : `  draft-reqid=${JSON.stringify(per["draft-reqid"].results.map((r: any) => r.status + (r.reason ? ":" + r.reason : "")))}`));
}
writeFileSync(process.argv[2], JSON.stringify({ divergencesOrigVsReal: divergences, report }, null, 1));
console.log(`columns: draft-reqid vs real, draft-orig vs real. draft-orig divergences from real: ${divergences} of ${cases.length}`);
process.exitCode = divergences === 0 ? 0 : 1;
