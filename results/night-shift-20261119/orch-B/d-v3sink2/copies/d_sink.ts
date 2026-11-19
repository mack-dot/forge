// r-drafts attack D (adversarial review of d-v3sink). One short run. Test keys made in this process.
// The v3 draft (d-v3sink/sink_core_backed_v3.ts, used in place, read-only) and the unchanged ts/refund-finality/sink.ts
// on the SAME database files in this directory. Usage (cwd = repository root): node --import tsx d_sink.ts <dir>
import { generateKeyPairSync, sign } from "node:crypto";
import { copyFileSync, rmSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { canon, sha256hex, signedBytes, stateSha256, DOMAIN, ChargeState } from "/Users/mackianni/forge/ts/refund-finality/encoding";
import { Sink as OldSink } from "/Users/mackianni/forge/ts/refund-finality/sink";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const V3 = require("/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-v3sink/sink_core_backed_v3.ts").Sink;

const dir = process.argv[2]; mkdirSync(dir, { recursive: true });
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
const cfg = { publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64) };
const st = (remaining: string, chargeId = "ch_1"): ChargeState => ({ chargeId, original: "1000", remaining, refundEnabled: true });
function tok(pre: ChargeState, requestId: string, amount: string, o: { intentReq?: string; intentCharge?: string; postCharge?: string } = {}): string {
  const post = { ...pre, chargeId: o.postCharge ?? pre.chargeId, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
  const body = { domain: DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: stateSha256(pre),
    requestId, post, intent: { chargeId: o.intentCharge ?? pre.chargeId, requestId: o.intentReq ?? requestId, amount, reason: "duplicate_charge" } };
  return canon({ body, signature: sign(null, signedBytes(body as any), privateKey).toString("base64") });
}
const fresh = (n: string) => { const p = dir + "/" + n + ".sqlite"; for (const s of ["", "-wal", "-shm", "-journal"]) if (existsSync(p + s)) rmSync(p + s); return p; };
const out: Record<string, unknown> = {};
const tryNew = (p: string, c: any = cfg) => { try { const s = new V3(p, c); return { s, err: "" }; } catch (e) { return { s: null, err: String((e as Error).message).slice(0, 140) }; } };
const S0 = st("1000");

// D1: old sink commits between two v3 commits on one file (honest tokens). Expect: all commit; v3 reloads each time.
{
  const p = fresh("d1"); const v = new V3(p, cfg); v.init(S0); const o = new OldSink(p, cfg);
  const t1 = tok(S0, "rq_1", "100"), t2 = tok(st("900"), "rq_2", "50"), t3 = tok(st("850"), "rq_3", "0");
  out.D1 = { v3_1: v.commit(t1), old_2: o.commit(t2), v3_3: v.commit(t3), v3_replay_old: v.commit(t2), outbox: v.outbox().length, audit: v.audit(),
    restart: tryNew(p).err || "starts" };
  v.close(); o.close();
}
// D2: the old sink commits a token that v3 would reject (intent.requestId != requestId; signed with the pinned key).
// The running v3 instance does not re-audit: does its next commit succeed? A NEW v3 instance must refuse to start.
{
  const p = fresh("d2"); const v = new V3(p, cfg); v.init(S0); const o = new OldSink(p, cfg);
  const bad = tok(S0, "rq_a", "100", { intentReq: "rq_OTHER" });
  const v3direct = (() => { const p2 = fresh("d2b"); const w = new V3(p2, cfg); w.init(S0); const r = w.commit(bad); w.close(); return r; })();
  const r1 = o.commit(bad);
  const r2 = v.commit(tok(st("900"), "rq_b", "10"));
  out.D2 = { v3_on_bad_token: v3direct, old_commits_bad: r1, running_v3_next_commit: r2, restart: tryNew(p).err || "starts" };
  v.close(); o.close();
}
// D2c: the old sink commits a FOREIGN-charge token (post and intent chargeId ch_2; pre is the stored ch_1 state).
{
  const p = fresh("d2c"); const v = new V3(p, cfg); v.init(S0); const o = new OldSink(p, cfg);
  const r1 = o.commit(tok(S0, "rq_f", "100", { intentCharge: "ch_2", postCharge: "ch_2" }));
  const r2 = v.commit(tok(st("900", "ch_2"), "rq_g", "10"));
  out.D2c = { old_commits_foreign: r1, running_v3_commit_on_ch_2: r2, stored: v.storedBlob(), restart: tryNew(p).err || "starts" };
  v.close(); o.close();
}
// D3: rollback. Copy after commit 1; commit 2; restore the older copy (a) after close + restart, (b) in place under an open connection.
{
  const p = fresh("d3"), bak = dir + "/d3-after-1.sqlite";
  let v = new V3(p, cfg); v.init(S0);
  const t1 = tok(S0, "rq_1", "100"), t2 = tok(st("900"), "rq_2", "100");
  const c1 = v.commit(t1); v.close(); copyFileSync(p, bak);
  v = new V3(p, cfg); const c2 = v.commit(t2); v.close();
  copyFileSync(bak, p);
  const r = tryNew(p); const again = r.s ? r.s.commit(t2) : null;
  const outboxRows = r.s ? r.s.outbox().length : -1; r.s?.close();
  // (b) under an open connection
  const p2 = fresh("d3b"), bak2 = dir + "/d3b-after-1.sqlite";
  const w = new V3(p2, cfg); w.init(S0); w.commit(t1); copyFileSync(p2, bak2); const d2 = w.commit(t2);
  copyFileSync(bak2, p2); let inplace: unknown; try { inplace = w.commit(t2); } catch (e) { inplace = "throws: " + String(e).slice(0, 80); }
  out.D3 = { c1, c2, restart_on_older_copy: r.err || "starts", recommit_t2_after_rollback: again, outbox_after: outboxRows,
             open_conn: { first_t2: d2, after_inplace_restore: inplace, outbox: w.outbox().length } };
  w.close();
}
// D4: cfg.core = "reqid" on a store that the v3 audit refuses: does the sink start? (the audit is off for "reqid")
{
  const p = fresh("d4"); const o = new OldSink(p, cfg); o.init(S0);
  o.commit(tok(S0, "rq_x", "1", { intentCharge: "ch_9" })); o.close();
  out.D4 = { v3_default: tryNew(p).err || "starts", reqid: (() => { const r = tryNew(p, { ...cfg, core: "reqid" }); r.s?.close(); return r.err || "starts (no audit)"; })(),
             orig: (() => { const r = tryNew(p, { ...cfg, core: "orig" }); r.s?.close(); return r.err || "starts (no audit)"; })() };
}
// D5: the audit throws (stored state blob does not decode) -> fail closed? D6: empty database.
{
  const p = fresh("d5"); const o = new OldSink(p, cfg); o.init(S0); o.close();
  const db = new DatabaseSync(p); db.exec("UPDATE state SET blob = '{' WHERE id = 1"); db.close();
  out.D5 = tryNew(p).err || "starts";
  const p6 = fresh("d6"); const r = tryNew(p6);
  out.D6 = { start: r.err || "starts", commit_no_state: r.s ? r.s.commit(tok(S0, "rq_1", "1")) : null };
  r.s?.close();
}
// D7: settled row with token text and hash: the draft writes the input text and its hash (not modelled by the core).
{
  const p = fresh("d7"); const v = new V3(p, cfg); v.init(S0); const t1 = tok(S0, "rq_1", "100"); v.commit(t1);
  const row = v.settled()[0]; out.D7 = { tokenEqual: row.token === t1, hashEqual: row.token_sha256 === sha256hex(t1), outboxIntent: v.outbox()[0].intent };
  v.close();
}
writeFileSync(dir + "/d_result.json", JSON.stringify(out, null, 1));
console.log(JSON.stringify(out, null, 1));
