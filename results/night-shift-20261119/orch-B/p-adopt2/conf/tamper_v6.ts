// p-adopt2: light probe (single short run; no race, no fuzz). It rebuilds the raw-tamper stores of the Slice 1 suite's
// dispatcher rows x1, x2, x3, x6, x7 (tests/refund-finality/suite.ts lines ~505-535) in the same way as world():
// init(state) + one commit of amount 100 + one dispatcher run. Then it applies the same raw SQL change and records:
//  - the dispatcher result (the row's own judge), and
//  - whether a NEW sink construction (pristine sink.ts vs export sink.ts v6) starts or refuses.
// Only x3 constructs a sink after the change in the suite (line 517: `w.sink()` then audit()). A TEST, not a proof.
// Usage (cwd = export): node --import tsx tamper_v6.ts <pristine root> <export root> <issuer module .cjs> <work dir>
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
const [pristine, root, corePath, work] = process.argv.slice(2);
/* eslint-disable @typescript-eslint/no-require-imports */
const Old = require(join(pristine, "ts/refund-finality/sink.ts")).Sink;
const New = require(join(root, "ts/refund-finality/sink.ts")).Sink;
const E = require(join(root, "ts/refund-finality/encoding.ts"));
const { Dispatcher } = require(join(root, "ts/refund-finality/dispatcher.ts"));
const { MinterClient, propose } = require(join(root, "ts/refund-finality/proposer.ts"));
(async () => {
  rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const m = await MinterClient.start(root, corePath, join(root, "spec/refund/spec.lock"), "off");
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const attacker = generateKeyPairSync("ed25519");
  const state = (id: string) => ({ chargeId: "ch_" + id, original: "1000", remaining: "1000", refundEnabled: true });
  const req = (id: string, amount: string) => ({ requestId: "rq_" + id, amount, reason: "duplicate_charge" });
  const mint = async (pre: any, r: any) => { const a = await m.mint(pre, propose(pre, r)); if (!a.ok) throw new Error("mint: " + a.reason); return a.token; };
  const insert = (db: DatabaseSync, rid: string, t: any) => {
    db.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, ?, ?)").run(rid, E.tokenText(t), E.sha256hex(E.tokenText(t)));
    db.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run(rid, E.canon(t.body.intent));
  };
  const out: Record<string, unknown> = {};
  for (const id of ["x1", "x2", "x3", "x6", "x7"]) {
    const s0 = state(id), db = join(work, id + ".sqlite"), cfg = { ...ids, initialState: s0 };
    const dcfg = { ...ids, initialStateSha256: E.stateSha256(s0) }, ledger = join(work, id + "-ledger.jsonl");
    let s = new New(db, cfg); s.init(s0); s.close();
    const t1 = await mint(s0, req(id + "_setup1", "100"));
    s = new New(db, cfg); const c = s.commit(E.tokenText(t1)).status; const cur = JSON.parse(s.stateBlob()); s.close();
    if (c !== "committed") throw new Error("setup commit " + id);
    new Dispatcher(db, ledger, dcfg, () => {}).flush();
    const raw = new DatabaseSync(db);
    if (id === "x1") raw.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run("rq_x1_ghost", E.canon({ chargeId: "ch_x1", requestId: "rq_x1_ghost", amount: "700", reason: "duplicate_charge" }));
    if (id === "x2") { raw.close(); const t2 = await mint(cur, req("x2_1", "100")); s = new New(db, cfg); s.commit(E.tokenText(t2)); s.close();
      const r2 = new DatabaseSync(db); r2.prepare(`UPDATE outbox SET intent = replace(intent, '"amount":"100"', '"amount":"900"') WHERE request_id = ?`).run("rq_x2_1"); r2.close(); }
    if (id === "x3") {
      const body = { domain: E.DOMAIN, ...{ specLockSha256: ids.specLockSha256, checkerSha256: ids.checkerSha256 }, preStateSha256: E.stateSha256(cur),
        requestId: "rq_x3_evil", ...(() => { const t = propose(cur, req("x3_evil", "900")); return { post: t.post, intent: t.intent }; })() };
      const ordered = { domain: body.domain, specLockSha256: body.specLockSha256, checkerSha256: body.checkerSha256, preStateSha256: body.preStateSha256, requestId: body.requestId, post: body.post, intent: body.intent };
      const evil = { body: ordered, signature: sign(null, E.signedBytes(ordered), attacker.privateKey).toString("base64") };
      insert(raw, evil.body.requestId, evil); raw.prepare("UPDATE state SET blob = ? WHERE id = 1").run(E.canon(evil.body.post));
    }
    if (id === "x6") insert(raw, "rq_x6_stale", await mint(s0, req("x6_stale", "900")));
    if (id === "x7") insert(raw, "rq_x7_copy", t1);
    if (id !== "x2") raw.close();
    let dispatch = "";
    try { dispatch = JSON.stringify(new Dispatcher(db, ledger, dcfg, () => {}).flush().refused.map((r: any) => r.reason)); } catch (e) { dispatch = "stopped: " + (e as Error).message; }
    const open = (S: any, c2: any) => { try { const x = new S(db, c2); const p = x.audit().length; x.close(); return "started; audit() problems " + p; } catch (e) { return "REFUSED: " + String((e as Error).message).slice(0, 170); } };
    out[id] = { dispatcher: dispatch, pristineSink: open(Old, ids), v6Sink: open(New, cfg) };
  }
  m.stop();
  writeFileSync(join(work, "result.json"), JSON.stringify(out, null, 1));
  for (const [k, v] of Object.entries(out)) process.stdout.write(k + " " + JSON.stringify(v) + "\n");
  process.exit(0);
})().catch(e => { process.stderr.write(String(e && e.stack) + "\n"); process.exit(3); });
