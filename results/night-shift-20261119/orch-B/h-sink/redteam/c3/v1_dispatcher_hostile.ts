// V1. E1/E2-class tokens through the DISPATCHER of the v6 tree (the v6 fix is in the sink only).
// Threat: a faulty signer has issued bad tokens (throwaway key pinned in config) AND a database writer WITHOUT the
// key inserts them as rows. The sink never commits them (the script shows the v6 sink refuses each at commit).
// (a) zero-hash-chain amplification: pre = s0, post = s0 (unchanged), intent amount 1000, three request ids.
//     The dispatcher chain rule: pre == head and head := hash(post) == head, so every such row continues the chain.
// (b) cross charge: a token on store B's chain whose intent refunds ch_A / rq_1, plus the honest ch_A / rq_1 on A.
// Exit 1 = defect present (emitted sum on ch_A > original 1000, or two refunds for (ch_A, rq_1)); 0 = safe.
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { load, keys, forge, body, fresh, st, it, SPEC, CHK } from "./lib";
const [root, work] = process.argv.slice(2);
const { E, Sink, Dispatcher } = load(root);
fresh(work);
const k = keys();
const base = { publicKeyPem: k.pub, specLockSha256: SPEC, checkerSha256: CHK };
const a0 = st("ch_A", "1000", "1000"), a1 = st("ch_A", "1000", "900"), b0 = st("ch_B", "1000", "1000");
const dbA = join(work, "a.sqlite"), dbB = join(work, "b.sqlite");
let sA = new Sink(dbA, { ...base, initialState: a0 }); sA.init(a0);
let sB = new Sink(dbB, { ...base, initialState: b0 }); sB.init(b0);
const amp = ["rq_z1", "rq_z2", "rq_z3"].map(r => forge(E, k.priv, body(E, a0, r, a0, it("ch_A", r, "1000"))));
const cross = forge(E, k.priv, body(E, b0, "rq_1", b0, it("ch_A", "rq_1", "100")));
const sinkVerdicts = { amp: amp.map(t => sA.commit(t)), cross: sB.commit(cross) };
sA.close(); sB.close();
// the database writer (no key): plain INSERTs of the signed rows; the state row is untouched (post == pre).
const ins = (path: string, tok: string) => {
  // h-sink HOSTILE variant: triggers dropped and CHECKs ignored; full h1 rows with the (unkeyed) chain recomputed; triggers restored.
  const db = new DatabaseSync(path), t = JSON.parse(tok), HS = require(join(root, "ts/refund-finality/sink.ts"));
  const trig = db.prepare("SELECT name, sql FROM sqlite_schema WHERE type = 'trigger'").all() as any[];
  db.exec("PRAGMA ignore_check_constraints = ON"); for (const tr of trig) db.exec(`DROP TRIGGER ${tr.name}`);
  const last = db.prepare("SELECT seq, self FROM outbox ORDER BY seq DESC LIMIT 1").get() as any, g = (db.prepare("SELECT genesis FROM meta").get() as any).genesis;
  const seq = last ? last.seq + 1 : 1, prev = last ? last.self : g, intent = E.canon(t.body.intent), self = HS.linkOf(prev, tok, intent);
  db.prepare("INSERT OR IGNORE INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (?, ?, ?, ?, ?, ?)").run(seq, t.body.requestId, tok, E.sha256hex(tok), prev, self);
  db.prepare("INSERT OR IGNORE INTO outbox(seq, request_id, intent, prev, self) VALUES (?, ?, ?, ?, ?)").run(seq, t.body.requestId, intent, prev, self);
  db.prepare("UPDATE state SET seq = ? WHERE id = 1").run(seq);
  for (const tr of trig) db.exec(tr.sql);
  db.close();
};
amp.forEach(t => ins(dbA, t)); ins(dbB, cross);
const effects: any[] = [];
const run = (db: string, led: string, s0: any) => new Dispatcher(db, join(work, led), { ...base, initialStateSha256: E.stateSha256(s0), newLedgerH0: require(join(root, "ts/refund-finality/sink.ts")).genesisOf(E.canon(s0), SPEC, CHK, k.pub) },
  (_e: any, intent: any) => effects.push(intent)).flush();
const dA1 = run(dbA, "ledA.jsonl", a0), dB1 = run(dbB, "ledB.jsonl", b0);
// the honest refund for ch_A / rq_1 on A afterwards (a new sink process: the start-up audit decides whether A serves)
let restartA = "served";
try { sA = new Sink(dbA, { ...base, initialState: a0 }); const tA = forge(E, k.priv, body(E, a0, "rq_1", a1, it("ch_A", "rq_1", "100")));
  restartA = "served: " + JSON.stringify(sA.commit(tA)); sA.close(); } catch (e) { restartA = "refused: " + String((e as Error).message).slice(0, 120); }
const dA2 = run(dbA, "ledA.jsonl", a0);
const sumA = effects.filter(i => i.chargeId === "ch_A").reduce((s, i) => s + BigInt(i.amount), 0n);
const rq1 = effects.filter(i => i.chargeId === "ch_A" && i.requestId === "rq_1").length;
console.log(JSON.stringify({ sinkVerdicts, emitted: effects, refusedA: dA1.refused, refusedB: dB1.refused, restartA, secondFlushA: dA2.emitted.length,
  emittedSumOnChA: String(sumA), refundsChA_rq1: rq1 }));
process.exit(sumA > 1000n || rq1 >= 2 ? 1 : 0);
