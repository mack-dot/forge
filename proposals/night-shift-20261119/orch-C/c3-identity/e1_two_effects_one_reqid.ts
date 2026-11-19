// E1 (own repro). Threat: a faulty signer (throwaway key pinned in config). No DB write.
// Token X: body.requestId = "rq_X", intent.requestId = "rq_1" (amount 100). Then an honest-shaped token for rq_1.
// Defect = the dispatcher emits two refunds whose intent.requestId is rq_1. Exit 1 = defect present; 0 = safe.
// Usage: node --import tsx e1_two_effects_one_reqid.ts <root> <workdir>
import { join } from "node:path";
import { load, keys, forge, body, fresh, st, it, SPEC, CHK } from "./lib";
const [root, work] = process.argv.slice(2);
const { E, Sink, Dispatcher } = load(root);
fresh(work);
const k = keys();
const s0 = st("ch_A", "1000", "1000"), s1 = st("ch_A", "1000", "900");
const cfg = { publicKeyPem: k.pub, specLockSha256: SPEC, checkerSha256: CHK, initialState: s0 };
const db = join(work, "a.sqlite");
const sink = new Sink(db, cfg); sink.init(s0);
const X = forge(E, k.priv, body(E, s0, "rq_X", s1, it("ch_A", "rq_1", "100")));
const cx = sink.commit(X);
// Y is built on the CURRENT stored state, so it is a valid token whatever happened to X.
const cur = JSON.parse(sink.stateBlob()), nxt = { ...cur, remaining: String(BigInt(cur.remaining) - 100n) };
const Y = forge(E, k.priv, body(E, cur, "rq_1", nxt, it("ch_A", "rq_1", "100")));
const cy = sink.commit(Y);
sink.close();
const effects: any[] = [];
const d = new Dispatcher(db, join(work, "ledger.jsonl"), { publicKeyPem: k.pub, specLockSha256: SPEC, checkerSha256: CHK, initialStateSha256: E.stateSha256(s0) },
  (_e: any, intent: any) => effects.push(intent)).flush();
const forRq1 = effects.filter(i => i.requestId === "rq_1").length;
console.log(JSON.stringify({ root, commitX: cx, commitY: cy, emitted: effects, refused: d.refused, effectsForRq1: forRq1 }));
process.exit(forRq1 >= 2 ? 1 : 0);
