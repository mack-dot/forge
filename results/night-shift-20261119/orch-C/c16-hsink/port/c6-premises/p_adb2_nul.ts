// c6-premises F1: hypothesis A-DB2 of ShellCoreV5.AuditV5SoundRelativeToSuppliedInitial (nDistinct == |IdSet(rows)|)
// and the "settled" flag of StepQ6 (request id in the settled set) are FALSE for the real v6 shell when a stored
// request_id holds U+0000: node:sqlite returns TEXT cut at the first U+0000, but SQLite compares, counts DISTINCT and
// enforces UNIQUE on the full value. Threat model: DATABASE WRITE WITHOUT THE KEY (no signing key; tokens are honest).
// Exit 1 = defect shown (the store passes the start-up audit and holds two commits of one request id); 0 = safe.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
const [root, work] = process.argv.slice(2);
const E = require(join(root, "ts/refund-finality/encoding.ts"));
const { Sink } = require(join(root, "ts/refund-finality/sink.ts"));
const { Dispatcher } = require(join(root, "ts/refund-finality/dispatcher.ts"));
const { publicKey, privateKey } = generateKeyPairSync("ed25519");   // throwaway key = the honest issuer of this test
const pem = publicKey.export({ type: "spki", format: "pem" }).toString();
const SPEC = "a".repeat(64), CHK = "b".repeat(64);
const ids = { publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK };
const tok = (pre: any, rid: string, amount: string, reason = "duplicate_charge") => {
  const post = { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() };
  const body = { domain: E.DOMAIN, specLockSha256: SPEC, checkerSha256: CHK, preStateSha256: E.stateSha256(pre), requestId: rid,
    post, intent: { chargeId: pre.chargeId, requestId: rid, amount, reason } };
  return E.canon({ body, signature: sign(null, E.signedBytes(body), privateKey).toString("base64") });
};
rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
const db = join(work, "sink.sqlite"), s0 = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
const cfg = { ...ids, initialState: s0 };
const r: any = {};
let k = new Sink(db, cfg); k.init(s0);
const t0 = tok(s0, "rq_z", "0");                      // an honest, authorized zero-amount refund
r.c1 = k.commit(t0); r.c1again = k.commit(t0);
k.close();
// The database writer (no key): append U+0000 + "x" to the stored request id in BOTH tables. Token texts untouched.
const w = new DatabaseSync(db);
w.prepare("UPDATE settled SET request_id = ? WHERE request_id = ?").run("rq_z\u0000x", "rq_z");
w.prepare("UPDATE outbox SET request_id = ? WHERE request_id = ?").run("rq_z\u0000x", "rq_z");
w.close();
// Restart: the start-up audit (schema, meta, compiled AuditV5) decides.
let restarted = true;
try { k = new Sink(db, cfg); } catch (e) { restarted = false; r.restartError = String(e); }
r.restartAfterTamper = restarted;
if (restarted) {
  r.c2 = k.commit(t0);                                 // the SAME honest token again
  k.close();
  let restarted2 = true; try { new Sink(db, cfg).close(); } catch (e) { restarted2 = false; r.restart2Error = String(e); }
  r.restartAfterSecondCommit = restarted2;
}
const v = new DatabaseSync(db, { readOnly: true });
const ob = v.prepare("SELECT seq, request_id, length(request_id) AS len FROM outbox ORDER BY seq").all() as any[];
const st = v.prepare("SELECT seq, request_id FROM settled ORDER BY seq").all() as any[];
r.nodeVisibleOutboxIds = ob.map(o => [o.seq, o.request_id, o.len]);
r.countDistinctSettled = (v.prepare("SELECT COUNT(DISTINCT request_id) AS n FROM settled").get() as any).n;
r.nodeVisibleDistinct = new Set(st.map(s => s.request_id)).size;
v.close();
const effects: any[] = [];
const d = new Dispatcher(db, join(work, "ledger.jsonl"), { ...ids, initialStateSha256: E.stateSha256(s0) }, (e: any) => effects.push(e)).flush();
r.dispatch = { emitted: d.emitted.length, refused: d.refused, already: d.alreadyDispatched };
const twoForOne = ob.filter(o => o.request_id === "rq_z").length >= 2;
const defect = r.c2?.status === "committed" && twoForOne && r.restartAfterSecondCommit === true;
console.log(JSON.stringify(r, null, 1));
console.log(defect ? "DEFECT: the audited store holds two commits of request id rq_z (A-DB2 false for the real shell)" : "SAFE");
process.exit(defect ? 1 : 0);
