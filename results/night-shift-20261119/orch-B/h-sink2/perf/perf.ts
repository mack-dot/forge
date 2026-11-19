// h-sink2 performance probe (evidence only; not a regression). usage: perf.ts <treeRoot> <mode: commits1000|commits200|foreign> <work dir>
// commits1000 / commits200: N commits through the sink (fresh store; amounts 0 and 1 alternate), then a restart (start-up audit).
// foreign: stores of 1,000 and 5,000 rows made by raw INSERTs in ONE transaction (triggers on); then a sink starts (audit),
// commits once (no foreign change), a second connection appends one validly signed row, and the sink commits again (the
// foreign-change path: prefixSame over all kept rows + auditFrom for the new row). Times in ms.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";
const [T0, mode, W0] = process.argv.slice(2); const TREE = resolve(T0), W = resolve(W0);
rmSync(W, { recursive: true, force: true }); mkdirSync(W, { recursive: true });
/* eslint-disable @typescript-eslint/no-require-imports */
const E = require(join(TREE, "ts/refund-finality/encoding.ts")); const SK = require(join(TREE, "ts/refund-finality/sink.ts"));
/* eslint-enable @typescript-eslint/no-require-imports */
const { publicKey, privateKey } = generateKeyPairSync("ed25519"); const pem = publicKey.export({ type: "spki", format: "pem" }) as string;
const big = "100000000";
const st = (r: string) => ({ chargeId: "ch_p", original: big, remaining: r, refundEnabled: true });
const S0 = st(big); const cfg: any = { publicKeyPem: pem, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: S0 };
const tok = (pre: any, rid: string, amount: string) => { const body = { domain: E.DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256,
  preStateSha256: E.stateSha256(pre), requestId: rid, post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() },
  intent: { chargeId: "ch_p", requestId: rid, amount, reason: "duplicate_charge" } };
  return E.canon({ body, signature: sign(null, E.signedBytes(body), privateKey).toString("base64") }); };
const ms = (t: number) => Math.round(performance.now() - t);
const out: any = { tree: TREE, mode };
if (mode.startsWith("commits")) {
  const n = mode === "commits1000" ? 1000 : 200, db = join(W, "c.sqlite");
  const s = new SK.Sink(db, cfg); s.init(S0);
  let pre = S0; const t0 = performance.now(); let bad = 0;
  for (let i = 1; i <= n; i++) { const a = i % 2 === 0 ? "0" : "1"; const t = tok(pre, "r" + i, a); if (s.commit(t).status !== "committed") bad++; pre = JSON.parse(t).body.post; }
  out.commitsMs = ms(t0); out.perCommitMs = +(out.commitsMs / n).toFixed(2); out.notCommitted = bad; s.close();
  const t1 = performance.now(); const s2 = new SK.Sink(db, cfg); out.restartAuditMs = ms(t1); out.count = s2.head().count; s2.close();
} else {
  for (const n of [1000, 5000]) {
    const db = join(W, "f" + n + ".sqlite");
    const s0 = new SK.Sink(db, cfg); s0.init(S0); s0.close();
    const d = new DatabaseSync(db); d.exec("BEGIN IMMEDIATE");
    let pre = S0, prev = (d.prepare("SELECT genesis FROM meta").get() as any).genesis;
    const t0 = performance.now();
    for (let i = 1; i <= n + 2; i++) {
      const t = tok(pre, "r" + i, i % 2 === 0 ? "0" : "1"), self = SK.linkOf(prev, t, E.canon(JSON.parse(t).body.intent));
      if (i <= n) d.prepare("INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (?, ?, ?, ?, ?, ?)").run(i, "r" + i, t, E.sha256hex(t), prev, self);
      else (out["tok" + (i - n)] = t);
      prev = self; pre = JSON.parse(t).body.post;
      if (i === n) out.buildMs = ms(t0);
    }
    d.exec("COMMIT"); d.close();
    const t1 = performance.now(); const s = new SK.Sink(db, cfg); const startMs = ms(t1);
    const t2 = performance.now(); const c1 = s.commit(out.tok1).status; const plainMs = ms(t2);
    // foreign append of row n+2 by another connection
    const d2 = new DatabaseSync(db); const last = d2.prepare("SELECT self FROM outbox ORDER BY seq DESC LIMIT 1").get() as any;
    const t = out.tok2; d2.exec("PRAGMA busy_timeout = 5000; BEGIN IMMEDIATE");
    d2.prepare("INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (?, ?, ?, ?, ?, ?)").run(n + 2, "r" + (n + 2), t, E.sha256hex(t), last.self, SK.linkOf(last.self, t, E.canon(JSON.parse(t).body.intent)));
    d2.exec("COMMIT"); d2.close();
    const pre3 = JSON.parse(t).body.post;
    const t3 = performance.now(); const c2 = s.commit(tok(pre3, "x" + n, "0")); const foreignMs = ms(t3);
    out["rows" + n] = { startAuditMs: startMs, plainCommitMs: plainMs, plainStatus: c1, foreignCommitMs: foreignMs, foreignStatus: c2.status + (c2.reason ? ": " + c2.reason.slice(0, 80) : ""), reaudits: s.reaudits };
    s.close(); delete out.tok1; delete out.tok2;
  }
}
rmSync(W, { recursive: true, force: true });
console.log(JSON.stringify(out));
