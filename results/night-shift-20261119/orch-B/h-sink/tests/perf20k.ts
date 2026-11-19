// h-sink perf (one short run): commit time per commit at a small store and at 20,000 committed rows; start-up audit time;
// incremental re-audit after one foreign append; dispatcher flush (full store audit) time. The 20,000 rows are loaded by
// the sink's own one-statement INSERT INTO settled (triggers active), signed with a test key, in one transaction.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
const [TREE, OUT, NS] = process.argv.slice(2); const N = Number(NS ?? 20000);
rmSync(OUT, { recursive: true, force: true }); mkdirSync(OUT, { recursive: true });
// eslint-disable-next-line @typescript-eslint/no-require-imports
const E = require(TREE + "/ts/refund-finality/encoding.ts"), HM = require(TREE + "/ts/refund-finality/sink.ts"), D = require(TREE + "/ts/refund-finality/dispatcher.ts");
const k = generateKeyPairSync("ed25519"), pem = k.publicKey.export({ type: "spki", format: "pem" }) as string;
const S0 = { chargeId: "ch_p", original: "9000000000000", remaining: "9000000000000", refundEnabled: true };
const cfg = { publicKeyPem: pem, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: S0 };
const tok = (pre: any, rid: string, amount: string) => { const body = { domain: E.DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256,
  preStateSha256: E.stateSha256(pre), requestId: rid, post: { ...pre, remaining: String(BigInt(pre.remaining) - BigInt(amount)) },
  intent: { chargeId: pre.chargeId, requestId: rid, amount, reason: "returned_item" } }; return { text: E.canon({ body, signature: sign(null, E.signedBytes(body), k.privateKey).toString("base64") }), post: body.post }; };
const ms = (t: bigint) => Number(t) / 1e6;
function timeCommits(s: any, pre: any, tag: string, n: number) {
  const ts: number[] = []; let cur = pre;
  for (let i = 0; i < n; i++) { const t = tok(cur, `${tag}_${i}`, i % 2 ? "0" : "1"); const a = process.hrtime.bigint(); const r = s.commit(t.text); ts.push(ms(process.hrtime.bigint() - a)); if (r.status !== "committed") throw new Error(tag + " " + JSON.stringify(r)); cur = t.post; }
  ts.sort((x, y) => x - y); return { cur, median: ts[n >> 1], p90: ts[Math.floor(n * 0.9)], max: ts[n - 1] };
}
const out: any = { N };
const small = `${OUT}/small.sqlite`; { const s = new HM.Sink(small, cfg); s.init(S0); const r = timeCommits(s, S0, "s", 200); out.smallStore200 = r; s.close(); delete out.smallStore200.cur; }
const big = `${OUT}/big.sqlite`; let cur: any = S0;
{ const s = new HM.Sink(big, cfg); s.init(S0); s.close();
  const db = new DatabaseSync(big); const g = (db.prepare("SELECT genesis FROM meta").get() as any).genesis; let prev = g;
  const ins = db.prepare("INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (?, ?, ?, ?, ?, ?)");
  const a = process.hrtime.bigint(); db.exec("BEGIN IMMEDIATE");
  for (let i = 1; i <= N; i++) { const t = tok(cur, "b_" + i, i % 3 ? "1" : "0"); const intent = E.canon(JSON.parse(t.text).body.intent); const self = HM.linkOf(prev, t.text, intent);
    ins.run(i, "b_" + i, t.text, E.sha256hex(t.text), prev, self); prev = self; cur = t.post; }
  db.exec("COMMIT"); out.loadMs = ms(process.hrtime.bigint() - a); db.close(); }
{ const a = process.hrtime.bigint(); const s = new HM.Sink(big, cfg); out.startAuditMs = ms(process.hrtime.bigint() - a); out.head = s.head().count;
  const r = timeCommits(s, cur, "t", 200); cur = r.cur; delete (r as any).cur; out.bigStore200 = r;
  // one foreign append (a key holder), then one commit: the incremental re-audit (integrity_check + new rows only).
  const db = new DatabaseSync(big); const last = db.prepare("SELECT seq, self FROM outbox ORDER BY seq DESC LIMIT 1").get() as any; const t = tok(cur, "f_1", "1");
  db.prepare("INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (?, ?, ?, ?, ?, ?)").run(last.seq + 1, "f_1", t.text, E.sha256hex(t.text), last.self, HM.linkOf(last.self, t.text, E.canon(JSON.parse(t.text).body.intent))); db.close(); cur = t.post;
  const t2 = tok(cur, "after_f", "1"); const b = process.hrtime.bigint(); const c = s.commit(t2.text); out.commitAfterForeignAppendMs = ms(process.hrtime.bigint() - b); out.afterForeign = c.status; out.reaudits = s.reaudits; s.close(); }
if (process.env.DISPATCH === "1") { const a = process.hrtime.bigint(); const f = new D.Dispatcher(big, `${OUT}/ledger.jsonl`, { ...cfg, initialStateSha256: E.stateSha256(S0), newLedgerH0: HM.genesisOf(E.canon(S0), cfg.specLockSha256, cfg.checkerSha256, pem) }, () => {}).flush();
  out.dispatcherFirstFlushMs = ms(process.hrtime.bigint() - a); out.emitted = f.emitted.length;
  const b = process.hrtime.bigint(); new D.Dispatcher(big, `${OUT}/ledger.jsonl`, { ...cfg, initialStateSha256: E.stateSha256(S0) }, () => {}).flush(); out.dispatcherIdleFlushMs = ms(process.hrtime.bigint() - b); }
out.rssMB = Math.round(process.memoryUsage().rss / 1e6);
console.log(JSON.stringify(out, null, 1));
