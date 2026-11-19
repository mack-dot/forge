// E2 (own repro). Threat: a faulty signer (throwaway key, one key for two charges). No DB write.
// Two stores: A (ch_A) and B (ch_B). Token F is valid for B's stored pre-state but its intent refunds ch_A / rq_1.
// Then an honest-shaped token for ch_A / rq_1 on store A. Each store has its own dispatcher ledger.
// Defect = two external refunds for (ch_A, rq_1). Exit 1 = defect present; 0 = safe.
// Usage: node --import tsx e2_cross_charge.ts <root> <workdir>
import { join } from "node:path";
import { load, keys, forge, body, fresh, st, it, SPEC, CHK } from "./lib";
const [root, work] = process.argv.slice(2);
const { E, Sink, Dispatcher } = load(root);
fresh(work);
const k = keys();
const a0 = st("ch_A", "1000", "1000"), a1 = st("ch_A", "1000", "900");
const b0 = st("ch_B", "1000", "1000"), b1 = st("ch_B", "1000", "900");
const base = { publicKeyPem: k.pub, specLockSha256: SPEC, checkerSha256: CHK };
const dbA = join(work, "a.sqlite"), dbB = join(work, "b.sqlite");
const sA = new Sink(dbA, { ...base, initialState: a0 }); sA.init(a0);
const sB = new Sink(dbB, { ...base, initialState: b0 }); sB.init(b0);
const Fb = forge(E, k.priv, body(E, b0, "rq_1", b1, it("ch_A", "rq_1", "100")));   // foreign intent on store B
const Ta = forge(E, k.priv, body(E, a0, "rq_1", a1, it("ch_A", "rq_1", "100")));   // the real one on store A
const cB = sB.commit(Fb), cA = sA.commit(Ta);
sA.close(); sB.close();
const effects: any[] = [];
const run = (db: string, led: string, s0: any) => new Dispatcher(db, join(work, led), { ...base, initialStateSha256: E.stateSha256(s0) },
  (_e: any, intent: any) => effects.push(intent)).flush();
const dA = run(dbA, "ledA.jsonl", a0), dB = run(dbB, "ledB.jsonl", b0);
const n = effects.filter(i => i.chargeId === "ch_A" && i.requestId === "rq_1").length;
console.log(JSON.stringify({ root, commitOnB: cB, commitOnA: cA, emitted: effects, refusedA: dA.refused, refusedB: dB.refused, refundsChA_rq1: n }));
process.exit(n >= 2 ? 1 : 0);
