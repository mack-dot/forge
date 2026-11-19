// r-v6 (night shift 2026-11-19, Orchestrator B): 12 cases against the DRAFT d-v6sink/sink_core_backed_v6.ts (used
// in place, read-only). Test keys are generated in this process. A TEST, not a proof. EXPECTED outcomes are written
// below BEFORE the run, from the model (ShellCoreV6.StepQ6Exact): commit IFF pinned, signed, fresh, current, and
// F.Authorizes(stored, token).
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { ChargeState, DOMAIN, Intent, TokenBody, canon, sha256hex, signedBytes, stateSha256 } from "/Users/mackianni/forge/ts/refund-finality/encoding";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const Draft6 = require("/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-v6sink/sink_core_backed_v6.ts").Sink;

const OUT = process.argv[2], DB = process.argv[3];
rmSync(DB, { recursive: true, force: true }); mkdirSync(DB, { recursive: true });
const k = generateKeyPairSync("ed25519");
const SPEC = sha256hex("r-v6 test spec"), CHK = sha256hex("r-v6 test checker");
const pem = k.publicKey.export({ type: "spki", format: "pem" }) as string;
const MAXM = 9223372036854775807n;

type P = { post?: Partial<ChargeState>; reason?: string; amount?: bigint };
function tok(pre: ChargeState, rid: string, amount: bigint, p: P = {}): string {
  const post = { ...pre, remaining: (BigInt(pre.remaining) - amount).toString(), ...(p.post ?? {}) };
  const intent: Intent = { chargeId: pre.chargeId, requestId: rid, amount: (p.amount ?? amount).toString(), reason: p.reason ?? "returned_item" };
  const b: TokenBody = { domain: DOMAIN, specLockSha256: SPEC, checkerSha256: CHK, preStateSha256: stateSha256(pre), requestId: rid, post, intent };
  return canon({ body: b, signature: sign(null, signedBytes(b), k.privateKey).toString("base64") });
}
const S = (orig: string, rem: string): ChargeState => ({ chargeId: "ch_1", original: orig, remaining: rem, refundEnabled: true });
const NA = "rejected:not authorized by the approved relation for the stored state";
const res: any[] = [];
let fails = 0;
function open(name: string, init: ChargeState) {
  const s = new Draft6(DB + "/" + name + ".sqlite", { publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK, initialState: init });
  s.init(init); return s;
}
function check(id: number, what: string, s: any, t: string, expect: string, expRem: string) {
  const r = s.commit(t);
  const got = r.status + (r.reason ? ":" + r.reason : "");
  const rem = JSON.parse(s.stateBlob()).remaining;
  const ok = got === expect && rem === expRem;
  if (!ok) fails++;
  res.push({ id, what, expect, got, expRem, rem, ok });
}
// Store A: original 1000.
const A = open("A", S("1000", "1000"));
const t1 = tok(S("1000", "1000"), "rq_1", 0n);
check(1, "zero amount, authorized", A, t1, "committed", "1000");
check(2, "second zero amount, other id", A, tok(S("1000", "1000"), "rq_2", 0n), "committed", "1000");
check(3, "replay of case 1 token", A, t1, "replayed", "1000");
check(4, "boundary amount == remaining (1000)", A, tok(S("1000", "1000"), "rq_3", 1000n), "committed", "0");
// Run 1 predicted NA for 5 and 6; the result was "token shape": a negative post remaining is not encodable (MONEY
// regex), so the DECODER refuses before the core. Run 2 keeps them with that expectation and adds 5b/6b.
check(5, "amount 1 on remaining 0, post remaining -1 (not encodable)", A, tok(S("1000", "0"), "rq_4", 1n), "rejected:token shape", "0");
check(51, "amount 1 on remaining 0, post remaining 0", A, tok(S("1000", "0"), "rq_4b", 1n, { post: { remaining: "0" } }), NA, "0");
// Store B: original 1000.
const B = open("B", S("1000", "1000"));
check(6, "amount 1001 > remaining, post -1 (not encodable)", B, tok(S("1000", "1000"), "rq_5", 1001n), "rejected:token shape", "1000");
check(61, "amount 1001 > remaining, post remaining 0", B, tok(S("1000", "1000"), "rq_5b", 1001n, { post: { remaining: "0" } }), NA, "1000");
check(7, "post sets refundEnabled false", B, tok(S("1000", "1000"), "rq_6", 100n, { post: { refundEnabled: false } }), NA, "1000");
check(8, "post remaining 950 with intent 100", B, tok(S("1000", "1000"), "rq_7", 100n, { post: { remaining: "950" } }), NA, "1000");
check(9, "unapproved reason goodwill", B, tok(S("1000", "1000"), "rq_8", 100n, { reason: "goodwill" }), NA, "1000");
check(10, "intent amount 100, post decreases 0 (request built from intent)", B, tok(S("1000", "1000"), "rq_9", 0n, { amount: 100n }), NA, "1000");
// Store C: original = MaxMoney; amount MaxMoney commits.
const C = open("C", S(MAXM.toString(), MAXM.toString()));
check(11, "MaxMoney charge, amount MaxMoney", C, tok(S(MAXM.toString(), MAXM.toString()), "rq_m", MAXM), "committed", "0");
// Store D: original = MaxMoney + 1 (case 24 style): nothing commits.
const D = open("D", S((MAXM + 1n).toString(), (MAXM + 1n).toString()));
check(12, "original MaxMoney+1, amount 0", D, tok(S((MAXM + 1n).toString(), (MAXM + 1n).toString()), "rq_z", 0n), NA, (MAXM + 1n).toString());
const outbox = { A: A.outbox().length, B: B.outbox().length, C: C.outbox().length, D: D.outbox().length };
for (const s of [A, B, C, D]) s.close();
// Restart: each store must reopen (start-up audit true).
const restart: Record<string, string> = {};
for (const [n, init] of [["A", S("1000", "1000")], ["B", S("1000", "1000")], ["C", S(MAXM.toString(), MAXM.toString())], ["D", S((MAXM + 1n).toString(), (MAXM + 1n).toString())]] as [string, ChargeState][]) {
  try { new Draft6(DB + "/" + n + ".sqlite", { publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK, initialState: init }).close(); restart[n] = "ok"; }
  catch (e) { restart[n] = "REFUSED: " + String((e as Error).message).slice(0, 100); }
}
const expOutbox = { A: 3, B: 0, C: 1, D: 0 };
const outOk = JSON.stringify(outbox) === JSON.stringify(expOutbox);
writeFileSync(OUT, JSON.stringify({ res, outbox, expOutbox, restart }, null, 1));
for (const r of res) console.log(`${r.ok ? "PASS" : "FAIL"} ${r.id} ${r.what}: got ${r.got} rem ${r.rem}`);
console.log("outbox", JSON.stringify(outbox), outOk ? "PASS" : "FAIL", "restart", JSON.stringify(restart));
process.exit(fails === 0 && outOk ? 0 : 1);
