// d-v5sink: copy of d-v3sink2/ts/conformance_v4.ts (copies/conformance_v4.ts), changed: the 4th sink is the v5 draft (always given cfg.initialState = the case init or S0, unless noInit).
// run; no stress, no fuzz, no kill, no race). A TEST, not a proof. Each case runs on fresh databases against FOUR sinks:
//   real      the unchanged repository ts/refund-finality/sink.ts
//   hand-v3   the hand-patched copy d-v3sink/copies/sink-patched-reqid-chargeid.ts (used in place, read-only)
//   draft-v3  d-v3sink/sink_core_backed_v3.ts with core "v3" (used in place, read-only)
//   draft-v5  ../sink_core_backed_v4.ts (compiled ShellCoreV4.StepQ; streaming bound audit; writer guard)
// A case with "prep" steps: the UNCHANGED sink creates the store and commits them first; draft-v5 then gets
// cfg.initialState = S0 (a legacy store has no meta 'initial_state' text) unless the case says noInit.
// Cases 1..28 = the d-v3sink table (unchanged). Cases 29.. are NEW (v4 only expectations).
// Run (cwd = repository): node --import tsx conformance_v4.ts <out.json>
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import * as sqlite from "node:sqlite";
import { ChargeState, DOMAIN, Intent, TokenBody, canon, sha256hex, signedBytes, stateSha256 } from "<REPO>/ts/refund-finality/encoding";

const DIR = __dirname + "/..";
const V3DIR = "<REPO>/results/night-shift-20261119/orch-B/d-v3sink";
const DB = DIR + "/db";
rmSync(DB, { recursive: true, force: true }); mkdirSync(DB, { recursive: true });
// eslint-disable-next-line @typescript-eslint/no-require-imports
const Real = require("<REPO>/ts/refund-finality/sink.ts").Sink;
// eslint-disable-next-line @typescript-eslint/no-require-imports
const Hand = require(V3DIR + "/copies/sink-patched-reqid-chargeid.ts").Sink;
// eslint-disable-next-line @typescript-eslint/no-require-imports
const Draft = require(V3DIR + "/sink_core_backed_v3.ts").Sink;
// eslint-disable-next-line @typescript-eslint/no-require-imports
const Draft5 = require(DIR + "/sink_core_backed_v5.ts").Sink;

const trusted = generateKeyPairSync("ed25519"), attacker = generateKeyPairSync("ed25519");
const SPEC = sha256hex("d-v3sink test spec lock"), CHK = sha256hex("d-v3sink test checker"), OTHER = sha256hex("other");
const pem = trusted.publicKey.export({ type: "spki", format: "pem" }) as string;

// ---- fault hook: throw at the first `INSERT INTO settled` after arming (that is, after the state UPDATE).
const P = sqlite.DatabaseSync.prototype as any, origPrepare = P.prepare;
let armed = false;
P.prepare = function (sql: string) {
  if (armed && sql.startsWith("INSERT INTO settled")) { armed = false; throw new Error("injected fault between writes"); }
  return origPrepare.call(this, sql);
};

const S0: ChargeState = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
type O = { intentRid?: string; spec?: string; chk?: string; reason?: string; chargeId?: string; postChargeId?: string };
function body(pre: ChargeState, rid: string, amount: bigint, o: O = {}): TokenBody {
  const post = { ...pre, chargeId: o.postChargeId ?? pre.chargeId, remaining: (BigInt(pre.remaining) - amount).toString() };
  const intent: Intent = { chargeId: o.chargeId ?? pre.chargeId, requestId: o.intentRid ?? rid, amount: amount.toString(), reason: o.reason ?? "returned_item" };
  return { domain: DOMAIN, specLockSha256: o.spec ?? SPEC, checkerSha256: o.chk ?? CHK, preStateSha256: stateSha256(pre), requestId: rid, post, intent };
}
function tok(b: TokenBody, key = trusted.privateKey, flip = false): string {
  const sig = sign(null, signedBytes(b), key); if (flip) sig[5] ^= 1;
  return canon({ body: b, signature: sig.toString("base64") });
}
const postOf = (b: TokenBody) => b.post;

type Case = { name: string; init?: ChargeState | null; prep?: string[]; auditFail?: boolean; v5Refuse?: boolean; noInit?: boolean; steps: Step[] };
type Step = { input: unknown; fault?: boolean };
const t1 = body(S0, "rq_1", 100n);
const big: ChargeState = { chargeId: "ch_big", original: "9999999999999999999", remaining: "9999999999999999999", refundEnabled: true };
const z1 = body(S0, "rq_z1", 0n), z2 = body(S0, "rq_z2", 0n);
const u1 = body(S0, "rq_\u{1F600}", 10n);
const S900 = { ...S0, remaining: "900" };
const fpost = body(S0, "rq_fp", 100n, { postChargeId: "ch_other" });
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
  { name: "request-id mismatch, then the victim id", steps: [{ input: tok(body(S0, "rq_body", 100n, { intentRid: "rq_victim" })) }, { input: tok(body(S900, "rq_victim", 100n)) }] },
  { name: "NEW intent for a foreign charge", steps: [{ input: tok(body(S0, "rq_1", 100n, { chargeId: "ch_other" })) }] },
  { name: "NEW post-state with a foreign charge id, then honest ch_1 token", steps: [{ input: tok(fpost) }, { input: tok(t1) }] },
  { name: "NEW intent and post for a foreign charge", steps: [{ input: tok(body(S0, "rq_1", 100n, { chargeId: "ch_other", postChargeId: "ch_other" })) }] },
  { name: "zero amount commits (right charge)", steps: [{ input: tok(z1) }] },
  { name: "two zero amounts, distinct ids, same pre-state", steps: [{ input: tok(z1) }, { input: tok(z2) }] },
  { name: "NEW zero amount for a foreign charge, then zero for ch_1", steps: [{ input: tok(body(S0, "rq_zf", 0n, { chargeId: "ch_other" })) }, { input: tok(z1) }] },
  { name: "fault between writes, then retry", steps: [{ input: tok(t1), fault: true }, { input: tok(t1) }] },
  { name: "fault between writes only (store must stay S0)", steps: [{ input: tok(t1), fault: true }] },
  { name: "non-canonical text", steps: [{ input: tok(t1) + " " }] },
  { name: "not a text", steps: [{ input: JSON.parse(tok(t1)) }] },
  { name: "no stored state", init: null, steps: [{ input: tok(t1) }] },
  { name: "no stored state, bad signature", init: null, steps: [{ input: tok(t1, attacker.privateKey) }] },
  { name: "amount 2^63 on a 19-digit charge", init: big, steps: [{ input: tok(body(big, "rq_big", 2n ** 63n)) }] },
  { name: "non-BMP request ids", steps: [{ input: tok(u1) }, { input: tok(body(postOf(u1), "rq_\u{1F601}", 10n)) }, { input: tok(u1) }] },
  { name: "lone surrogate request id (decoder refuses)", steps: [{ input: tok({ ...body(S0, "rq_\uD83D", 10n) }) }] },
  // Stores that FAIL AuditStart, written by the UNCHANGED sink (prep), then the victim's honest token.
  { name: "NEW audit-fail store: outbox row rq_victim not settled (old gap), then honest rq_victim", auditFail: true,
    prep: [tok(body(S0, "rq_body", 100n, { intentRid: "rq_victim" }))], steps: [{ input: tok(body(S900, "rq_victim", 100n)) }] },
  { name: "NEW audit-fail store: outbox row for foreign charge ch_other, then honest ch_1 token", auditFail: true,
    prep: [tok(body(S0, "rq_f", 100n, { chargeId: "ch_other" }))], steps: [{ input: tok(body(S900, "rq_2", 50n)) }] },
  // NEW (d-v3sink2). Legacy stores written by the unchanged sink.
  { name: "NEW v4: legacy honest store (prep), initialState given, then the next honest token",
    prep: [tok(t1)], steps: [{ input: tok(body(S900, "rq_2", 50n)) }] },
  { name: "NEW v4: legacy honest store (prep), NO initialState: v4 refuses (no initial text)", noInit: true, v5Refuse: true,
    prep: [tok(t1)], steps: [{ input: tok(body(S900, "rq_2", 50n)) }] },
  { name: "NEW v4: D-b store: prep commits a foreign post AND intent (ch_2) on ch_1; then a ch_2 token", v5Refuse: true,
    prep: [tok(body(S0, "rq_f", 100n, { chargeId: "ch_2", postChargeId: "ch_2" }))],
    steps: [{ input: tok(body({ ...S900, chargeId: "ch_2" }, "rq_g", 10n)) }] },
];

const SINKS: [string, any, any][] = [
  ["real", Real, {}], ["hand-v3", Hand, {}], ["draft-v3", Draft, { core: "v3" }], ["draft-v5", Draft5, {}],
];
let n = 0;
const cfg = { publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK };
function runCase(c: Case, which: [string, any, any]) {
  const path = `${DB}/${++n}-${which[0]}.sqlite`;
  let prep: any[] = [];
  if (c.prep) { const r = new Real(path, cfg); r.init(S0); prep = c.prep.map(x => r.commit(x)); r.close(); }
  const extra = which[0] === "draft-v5" && !c.noInit ? { initialState: c.init ?? S0 } : {};
  let s: any;
  try { s = new which[1](path, { ...cfg, ...which[2], ...extra }); } catch (e) { return { prep, refused: String((e as Error).message) }; }
  if (c.init !== null) s.init(c.init ?? S0);
  const results = c.steps.map(st => { armed = !!st.fault; const r = s.commit(st.input); armed = false; return r; });
  const store = { state: s.storedBlob() ?? "<none>", settled: s.settled().map((r: any) => [r.request_id, r.token_sha256]),
    outbox: s.outbox().map((r: any) => [r.request_id, r.intent]), audit: c.init === null ? "<no state>" : s.audit() };
  s.close();
  return { prep, results, store };
}
const short = (x: any) => x.refused !== undefined ? "REFUSED-TO-START(" + x.refused.split(": ").slice(-1)[0].slice(0, 70) + ")" :
  x.results.map((r: any) => r.status === "rejected" ? "rej:" + r.reason : r.status).join(" ; ") + `  [outbox=${x.store.outbox.length}]`;
const report: any[] = [];
let bad = 0, idx = 0;
for (const c of cases) {
  idx++;
  const per: Record<string, any> = {};
  for (const w of SINKS) per[w[0]] = runCase(c, w);
  const eq = (a: string, b: string) => JSON.stringify(per[a]) === JSON.stringify(per[b]);
  const eqNoRefusalText = (a: string, b: string) => (per[a].refused !== undefined && per[b].refused !== undefined) || eq(a, b);
  const row: any = { idx, case: c.name, v5EqualsHand: eq("hand-v3", "draft-v5"), v5EqualsV3: eqNoRefusalText("draft-v3", "draft-v5"), v3EqualsHand: eq("hand-v3", "draft-v3"), per };
  // Expectations stated before the run (task text): old table: v4 == hand-v3 except the audit-fail stores, where
  // v4 must refuse to start (as v3 did) and the other three serve. NEW cases: v5Refuse says v4 must refuse.
  if (c.auditFail) {
    row.expect = per["draft-v5"].refused !== undefined && per["draft-v3"].refused !== undefined && ["real", "hand-v3"].every(k => per[k].refused === undefined);
  } else if (c.v5Refuse) {
    row.expect = per["draft-v5"].refused !== undefined && ["real", "hand-v3", "draft-v3"].every(k => per[k].refused === undefined);
  } else {
    row.expect = row.v5EqualsHand;
  }
  if (c.name.startsWith("fault between writes only")) for (const k of Object.keys(per)) {
    const st = per[k].store, ok = st.state === canon(S0) && st.settled.length === 0 && st.outbox.length === 0;
    if (!ok) row.expect = false;
  }
  if (c.name.includes("zero amount commits") || c.name.startsWith("two zero")) row.expect = row.expect && Object.values(per).every((p: any) => p.results.every((r: any) => r.status === "committed"));
  if (!row.expect) bad++;
  report.push(row);
  console.log(`${row.expect ? "OK " : "BAD"} #${idx} v5==hand:${row.v5EqualsHand ? "Y" : "N"} v5==v3:${row.v5EqualsV3 ? "Y" : "N"} v3==hand:${row.v3EqualsHand ? "Y" : "N"} | ${c.name}`);
  for (const w of SINKS) console.log(`     ${w[0].padEnd(9)} ${c.prep ? "prep(real)=" + per[w[0]].prep.map((r: any) => r.status).join(",") + " | " : ""}${short(per[w[0]])}`);
}
writeFileSync(process.argv[2], JSON.stringify({ unexpected: bad, report }, null, 1));
console.log(`cases ${cases.length}; unexpected ${bad}`);
process.exitCode = bad === 0 ? 0 : 1;
