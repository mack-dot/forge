// confirm.ts <sink.ts> <dispatcher.ts> <case>: shows that a mutant that the judges pass is REALLY defective.
// Exit 1 = the defective behaviour happened (unsafe/contract-breaking outcome); 0 = the safe outcome. Run it on the
// plain v6 sink/dispatcher as the control (expected 0). Threat model per case in the comment of each case.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";
const [sinkP, dispP, kase] = process.argv.slice(2);
const { Sink } = require(resolve(sinkP)); const { Dispatcher } = require(resolve(dispP));
const E = require(join(dirname(resolve(sinkP)), "encoding.ts"));
const k = generateKeyPairSync("ed25519"), other = generateKeyPairSync("ed25519");
const pem = k.publicKey.export({ type: "spki", format: "pem" }) as string;
const LOCK = E.sha256hex("l"), CHK = E.sha256hex("c");
type C = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
const S0: C = { chargeId: "ch_1", original: "1000", remaining: "1000", refundEnabled: true };
const cfg = (s: C = S0) => ({ publicKeyPem: pem, specLockSha256: LOCK, checkerSha256: CHK, initialState: s });
const dir = mkdtempSync(join(process.env.TMPDIR ?? "/tmp", "confirm-")); process.on("exit", () => rmSync(dir, { recursive: true, force: true }));
const db = join(dir, "s.sqlite"), ledger = join(dir, "ledger.jsonl");
const dec = (s: C, a: string): C => ({ ...s, remaining: (BigInt(s.remaining) - BigInt(a)).toString() });
const tokB = (pre: C, rid: string, post: C, intent: any, key = k.privateKey) => {
  const body = { domain: E.DOMAIN, specLockSha256: LOCK, checkerSha256: CHK, preStateSha256: E.stateSha256(pre), requestId: rid, post, intent };
  return E.canon({ body, signature: sign(null, E.signedBytes(body), key).toString("base64") });
};
const honest = (pre: C, rid: string, a: string, key = k.privateKey) => tokB(pre, rid, dec(pre, a), { chargeId: pre.chargeId, requestId: rid, amount: a, reason: "returned_item" }, key);
const open = () => { const s = new Sink(db, cfg()); return s; };
const stored = (): C => { const d = new DatabaseSync(db, { readOnly: true }); try { return JSON.parse((d.prepare("SELECT blob FROM state").get() as any).blob); } finally { d.close(); } };
const effects: any[] = [];
const flush = (thr = false) => { try { new Dispatcher(db, ledger, { publicKeyPem: pem, specLockSha256: LOCK, checkerSha256: CHK, initialStateSha256: E.stateSha256(S0) },
  (e: any, i: any) => { effects.push(i); if (thr) throw new Error("crash after the effect"); }).flush(); } catch (e) { return String((e as Error).message); } return ""; };
const out = (bad: boolean, msg: string) => { console.log(`${bad ? "DEFECT" : "SAFE"} ${kase}: ${msg}`); process.exit(bad ? 1 : 0); };
let s = open(); s.init(S0);
switch (kase) {
  case "bad_sig": { // attacker: none with the key; any client that delivers a token signed by ANOTHER key
    const r = s.commit(honest(S0, "rq_1", "1000", other.privateKey)); out(r.status === "committed", "token signed by a foreign key -> " + r.status); }
  case "noncanon": { // attacker: token transport (no key) re-spaces the JSON text
    const t = honest(S0, "rq_1", "10"); const r = s.commit(JSON.stringify(JSON.parse(t), null, 1)); out(r.status === "committed", "non-canonical text of a valid token -> " + r.status); }
  case "stale": { // attacker: none (a stale token for an older pre-state)
    s.commit(honest(S0, "rq_1", "10")); const r = s.commit(tokB(S0, "rq_2", dec(stored(), "10"), { chargeId: "ch_1", requestId: "rq_2", amount: "10", reason: "returned_item" }));
    out(r.status === "committed", "token whose pre-state hash names the OLD state -> " + r.status); }
  case "replay_rejected": { // attacker: none; host retries a committed token
    const t = honest(S0, "rq_1", "10"); s.commit(t); const r = s.commit(t); out(r.status !== "replayed", "identical retry of a committed token -> " + r.status + " (PR 63: returns its recorded decision)"); }
  case "replayed_any": { // attacker: any client with a different token for a settled request id
    s.commit(honest(S0, "rq_1", "10")); const r = s.commit(honest(stored(), "rq_1", "500")); out(r.status === "replayed", "DIFFERENT token for settled rq_1 -> " + r.status + " (PR 64: rejected)"); }
  case "id_gt32": { // attacker: faulty signer (as X4) + chooses a 33-char request id
    const rid = "r".repeat(33); const r = s.commit(tokB(S0, rid, { ...S0, remaining: "0" }, { chargeId: "ch_1", requestId: rid, amount: "1001", reason: "returned_item" }));
    out(r.status === "committed", "amount 1001 > remaining 1000 with a 33-unit request id -> " + r.status); }
  case "late20": { // attacker: faulty signer after 20 honest commits on one store
    for (let i = 0; i < 20; i++) s.commit(honest(stored(), "rq_" + i, "0"));
    const r = s.commit(tokB(stored(), "rq_x", { ...stored(), remaining: "0" }, { chargeId: "ch_1", requestId: "rq_x", amount: "5000", reason: "returned_item" }));
    out(r.status === "committed", "21st delivery: amount 5000 on a 1000 charge -> " + r.status); }
  case "wipe": { // attacker: none (a restart)
    const r1 = s.commit(honest(S0, "rq_1", "1000")); s.close(); s = open(); const r2 = s.commit(honest(stored(), "rq_2", "1000"));
    out(r1.status === "committed" && r2.status === "committed", `refund 1000 (${r1.status}), restart, refund 1000 again (${r2.status}) on a 1000 charge`); }
  case "d_ignore_sig": { // attacker: database writer WITHOUT the key; forges a settled+outbox row signed by another key
    s.commit(honest(S0, "rq_1", "100")); flush(); s.close();
    const t = honest(dec(S0, "100"), "rq_f", "900", other.privateKey); const b = JSON.parse(t).body;
    const d = new DatabaseSync(db); d.prepare("INSERT INTO settled(request_id, token, token_sha256) VALUES (?, ?, ?)").run("rq_f", t, E.sha256hex(t));
    d.prepare("INSERT INTO outbox(request_id, intent) VALUES (?, ?)").run("rq_f", E.canon(b.intent)); d.close();
    flush(); out(effects.some(i => i.requestId === "rq_f"), "forged row (foreign key) emitted: " + effects.some(i => i.requestId === "rq_f")); }
  case "d_ignore_chain": { // attacker: database writer WITHOUT the key; prefix rollback to genesis (X6-P1 limit), ledger intact
    s.commit(honest(S0, "rq_1", "1000")); flush(); s.close();
    const d = new DatabaseSync(db); d.exec("DELETE FROM settled; DELETE FROM outbox"); d.prepare("UPDATE state SET blob = ? WHERE id = 1").run(E.canon(S0)); d.close();
    s = open(); s.commit(honest(S0, "rq_2", "1000")); flush();
    const tot = effects.reduce((a, i) => a + BigInt(i.amount), 0n); out(tot > 1000n, `emitted total ${tot} on a 1000 charge`); }
  case "d_emit_before_ledger": { // attacker: none (a crash right after the external effect)
    s.commit(honest(S0, "rq_1", "100")); flush(true); flush(); out(effects.length > 1, `effects for rq_1 over crash + retry: ${effects.length}`); }
  default: console.error("unknown case"); process.exit(2);
}
