// confirm.ts <case> <sink.ts> <dispatcher.ts>: shows that a mutant's defect is REAL (exit 1 = defect present) and that
// the target modules are safe for the same probe (exit 0). Throwaway Ed25519 keys; the trusted encoding of the tree.
// Cases: bad_sig noncanon skip_prestate replay_says_rejected replayed_any id_gt32 late20 wipe d_ignore_sig d_ignore_chain
//        d_emit_before_ledger d_emit_twice enc
import { generateKeyPairSync, sign } from "node:crypto";
import { existsSync, mkdtempSync, readFileSync } from "node:fs";
import { join } from "node:path";
const T = "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-f08a21c1/ts/refund-finality";
/* eslint-disable @typescript-eslint/no-require-imports */
const E = require(T + "/encoding.ts"), ST = require(T + "/core/store.ts");
const [kase, sinkP, dispP] = process.argv.slice(2);
const { Sink } = require(sinkP), { Dispatcher } = require(dispP);
const { hostile } = require("/Users/mackianni/forge/results/night-shift-20261119/orch-C/c19-dispatch2/h.ts");
/* eslint-enable @typescript-eslint/no-require-imports */
const K = generateKeyPairSync("ed25519"), F = generateKeyPairSync("ed25519");
const pem = K.publicKey.export({ type: "spki", format: "pem" }) as string;
const ids = { publicKeyPem: pem, specLockSha256: E.sha256hex("lock"), checkerSha256: E.sha256hex("checker") };
const S0 = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
const dec = (s: any, a: string) => ({ ...s, remaining: (BigInt(s.remaining) - BigInt(a)).toString() });
const body = (pre: any, rid: string, amt: string, post?: any, reason = "duplicate_charge") => ({ domain: E.DOMAIN, specLockSha256: ids.specLockSha256, checkerSha256: ids.checkerSha256,
  preStateSha256: E.stateSha256(pre), requestId: rid, post: post ?? dec(pre, amt), intent: { chargeId: pre.chargeId, requestId: rid, amount: amt, reason } });
const tok = (b: any, key = K.privateKey, bytes?: Buffer) => E.canon({ body: b, signature: sign(null, bytes ?? E.signedBytes(b), key).toString("base64") });
const dir = mkdtempSync(join(process.env.TMPDIR!, "conf-")), db = join(dir, "s.sqlite"), ledger = join(dir, "l.jsonl");
const cfg = { ...ids, initialState: S0 };
const dcfg = { ...ids, initialStateSha256: E.stateSha256(S0), newLedgerH0: ST.genesisOf(E.canon(S0), ids.specLockSha256, ids.checkerSha256, pem) };
let s = new Sink(db, cfg); s.init(S0);
const effects: any[] = [];
const flush = () => { try { return new Dispatcher(db, ledger, dcfg, (e: any) => { effects.push({ rid: e.requestId, had: existsSync(ledger) && readFileSync(ledger, "utf8").includes(JSON.stringify(e.requestId)) }); }).flush(); } catch (e) { return { error: String((e as Error).message).slice(0, 100) }; } };
const Z = "0".repeat(64);
const appendRow = (t: string) => hostile(db, (d: any) => {   // a database writer WITHOUT the key: settled + outbox row, chain recomputed
  const b = JSON.parse(t).body;
  d.prepare(`INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES ((SELECT MAX(seq)+1 FROM settled), ?, ?, ?, '${Z}', '${Z}')`).run(b.requestId, t, E.sha256hex(t));
  if ((d.prepare("SELECT COUNT(*) AS n FROM outbox WHERE request_id = ?").get(b.requestId) as any).n === 0)
    d.prepare(`INSERT INTO outbox(seq, request_id, intent, prev, self) VALUES ((SELECT MAX(seq)+1 FROM outbox), ?, ?, '${Z}', '${Z}')`).run(b.requestId, E.canon(b.intent));
}, { recompute: true });
let defect = false, why = "";
const st = (x: any) => x.status;
switch (kase) {
  case "bad_sig": { const r = s.commit(tok(body(S0, "rq_1", "100"), F.privateKey)); defect = st(r) === "committed"; why = JSON.stringify(r); break; }
  case "noncanon": { const t = tok(body(S0, "rq_1", "100")); const r = s.commit(JSON.stringify(JSON.parse(t), null, 1)); defect = st(r) === "committed"; why = JSON.stringify(r); break; }
  case "skip_prestate": { s.commit(tok(body(S0, "rq_1", "100"))); const S1 = dec(S0, "100");
    const r = s.commit(tok({ ...body(S0, "rq_2", "0", S1) })); defect = st(r) === "committed"; why = JSON.stringify(r); break; }
  case "replay_says_rejected": { const t = tok(body(S0, "rq_1", "100")); s.commit(t); const r = s.commit(t); defect = st(r) !== "replayed"; why = JSON.stringify(r); break; }
  case "replayed_any": { s.commit(tok(body(S0, "rq_1", "100"))); const r = s.commit(tok(body(dec(S0, "100"), "rq_1", "300"))); defect = st(r) === "replayed"; why = JSON.stringify(r); break; }
  case "id_gt32": { const rid = "r".repeat(40); const r = s.commit(tok(body(S0, rid, "100"), F.privateKey)); defect = st(r) === "committed"; why = JSON.stringify(r); break; }
  case "late20": { let cur: any = S0; for (let i = 0; i < 20; i++) { s.commit(tok(body(cur, "h" + i, "1"))); cur = dec(cur, "1"); }
    const r = s.commit(tok(body(cur, "x", "500"), F.privateKey)); defect = st(r) === "committed"; why = JSON.stringify(r); break; }
  case "wipe": { const t = tok(body(S0, "rq_1", "600")); s.commit(t); s.close(); s = new Sink(db, cfg); const r = s.commit(t); defect = st(r) === "committed"; why = JSON.stringify(r) + " outbox=" + s.outbox().length; break; }
  case "d_ignore_sig": case "d_ignore_chain": { s.commit(tok(body(S0, "rq_1", "100"))); flush(); s.close(); const S1 = dec(S0, "100");
    const t = kase === "d_ignore_sig" ? tok(body(S1, "rq_2", "50"), F.privateKey) : tok(body(S0, "rq_2", "50"));
    const w = appendRow(t); const f: any = flush(); defect = effects.some(e => e.rid === "rq_2"); why = w + " " + JSON.stringify(f).slice(0, 160); break; }
  case "d_emit_before_ledger": { s.commit(tok(body(S0, "rq_1", "100"))); const f: any = flush(); defect = effects.some(e => !e.had); why = JSON.stringify(effects); break; }
  case "d_emit_twice": { s.commit(tok(body(S0, "rq_1", "50"))); flush(); defect = effects.length !== 1; why = JSON.stringify(effects); break; }
  case "enc": { // a minter that shares the defective encoding signs only the REDUCED bytes; post and intent are then altered
    const b = body(S0, "rq_1", "0"); const red = Buffer.from(E.canon((({ post, intent, ...rest }: any) => rest)(b)), "utf8");
    const alt = { ...b, post: dec(S0, "900"), intent: { ...b.intent, amount: "900" } };
    const r = s.commit(E.canon({ body: alt, signature: sign(null, red, K.privateKey).toString("base64") })); defect = st(r) === "committed"; why = JSON.stringify(r); break; }
  default: console.error("unknown case"); process.exit(2);
}
console.log(kase, defect ? "DEFECT" : "safe", why.slice(0, 260)); process.exit(defect ? 1 : 0);
