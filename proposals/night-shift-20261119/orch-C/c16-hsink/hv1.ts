// C-ATT-06 ported: rows signed by a faulty signer (throwaway key pinned in config) that the sink refuses, written by a
// database writer WITHOUT the key with full file powers (triggers dropped, chain recomputed, refunded column fixed,
// triggers re-created). Does the h1 dispatcher refuse them? Usage: hv1.ts <work>
// Exit 1 = an effect for a sink-refused row is emitted (defect present); 0 = safe; 3 = harness error.
import { generateKeyPairSync, sign } from "node:crypto";
import { join } from "node:path";
import { mkdirSync, rmSync } from "node:fs";
import { E, SK, Sink, Dispatcher, hostile, out } from "./h";
const [work] = process.argv.slice(2);
rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
const k = generateKeyPairSync("ed25519"), pem = k.publicKey.export({ type: "spki", format: "pem" }) as string;
const SPEC = "a".repeat(64), CHK = "b".repeat(64), ids = { publicKeyPem: pem, specLockSha256: SPEC, checkerSha256: CHK };
const a0 = { chargeId: "ch_A", original: "1000", remaining: "1000", refundEnabled: true };
const forge = (body: any) => E.canon({ body, signature: sign(null, Buffer.from(E.canon(body), "utf8"), k.privateKey).toString("base64") });
const bodyOf = (pre: any, rid: string, post: any, amount: string) => ({ domain: E.DOMAIN, specLockSha256: SPEC, checkerSha256: CHK,
  preStateSha256: E.stateSha256(pre), requestId: rid, post, intent: { chargeId: "ch_A", requestId: rid, amount, reason: "duplicate_charge" } });
const db = join(work, "a.sqlite");
const s = new Sink(db, { ...ids, initialState: a0 }); s.init(a0);
const amp = ["rq_z1", "rq_z2", "rq_z3"].map(r => forge(bodyOf(a0, r, a0, "1000")));
const verdicts = amp.map(t => s.commit(t).status + ":" + (s.commit(t).reason ?? ""));
s.close();
const ap = hostile(db, d => { amp.forEach((t, i) => { const b = JSON.parse(t).body;
  d.prepare("INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (?, ?, ?, ?, ?, ?)").run(i + 1, b.requestId, t, E.sha256hex(t), "0".repeat(64), "0".repeat(64));
  d.prepare("INSERT INTO outbox(seq, request_id, intent, prev, self) VALUES (?, ?, ?, ?, ?)").run(i + 1, b.requestId, E.canon(b.intent), "0".repeat(64), "0".repeat(64)); }); }, { recompute: true });
const ap2 = hostile(db, d => d.exec("UPDATE state SET refunded = 0 WHERE id = 1"));
const effects: any[] = [];
const h0 = SK.genesisOf(E.canon(a0), SPEC, CHK, pem);
let f: any;
try { f = new Dispatcher(db, join(work, "led.jsonl"), { ...ids, initialStateSha256: E.stateSha256(a0), newLedgerH0: h0 }, (e: any) => effects.push(e)).flush(); }
catch (e) { f = { alarm: String((e as Error).message) }; }
let restart = "serves"; try { new Sink(db, { ...ids, initialState: a0 }).close(); } catch (e) { restart = String((e as Error).message).slice(0, 200); }
out({ verdicts, applied: [ap, ap2], flush: f.alarm ?? { emitted: f.emitted.length, refused: f.refused.map((r: any) => r.requestId + ": " + String(r.reason).slice(0, 120)) }, restart, effects: effects.length });
process.exit(effects.length > 0 ? 1 : 0);
