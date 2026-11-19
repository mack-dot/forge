// c21-sink2 helper (red team C). Target: fix-88ae6cbf (B's second sink hardening). Own code; modelled on C's c16 h.ts.
// Throwaway Ed25519 key signed in this process (no issuer process; the fuzz uses the real minter).
// hostile(): a database WRITER WITHOUT THE KEY: drops all triggers, edits, optionally recomputes the unkeyed chain, re-creates
// the identical trigger texts (schema text check passes). One transaction.
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
export const ROOT = "<SCRATCH>/redteam-C/fix-88ae6cbf";
/* eslint-disable @typescript-eslint/no-require-imports */
export const E = require(join(ROOT, "ts/refund-finality/encoding.ts"));
export const SK = require(join(ROOT, "ts/refund-finality/sink.ts"));
export const ST = require(join(ROOT, "ts/refund-finality/core/store.ts"));
export const { Sink } = SK;
export const { Dispatcher } = require(join(ROOT, "ts/refund-finality/dispatcher.ts"));
/* eslint-enable @typescript-eslint/no-require-imports */
export type State = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export const S0: State = { chargeId: "ch_c21", original: "1000", remaining: "1000", refundEnabled: true };
export const out = (o: any) => console.log(JSON.stringify(o));
export const short = (e: unknown) => String((e as Error)?.message ?? e).replace(/\s+/g, " ").slice(0, 220);

export function kit(work: string, s0: State = S0, fresh = true) {
  if (fresh) { rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true }); }
  const { publicKey, privateKey } = generateKeyPairSync("ed25519");
  const pem = publicKey.export({ type: "spki", format: "pem" }) as string;
  const cfg: any = { publicKeyPem: pem, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: s0 };
  const h0: string = SK.genesisOf(E.canon(s0), cfg.specLockSha256, cfg.checkerSha256, pem);
  const dcfg: any = { publicKeyPem: pem, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, initialStateSha256: E.stateSha256(s0) };
  const db = join(work, "sink.sqlite"), ledger = join(work, "ledger.jsonl");
  const tok = (pre: State, rid: string, amount: string, reason = "duplicate_charge"): string => {
    const body = { domain: E.DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: E.stateSha256(pre),
      requestId: rid, post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() },
      intent: { chargeId: pre.chargeId, requestId: rid, amount, reason } };
    return E.canon({ body, signature: sign(null, E.signedBytes(body), privateKey).toString("base64") });
  };
  const effects: any[] = [];
  const flush = (extra: any = {}, path = db, led = ledger) => {
    const n0 = effects.length;
    try {
      const f = new Dispatcher(path, led, { ...dcfg, ...extra }, (e: any) => effects.push(e)).flush();
      return { emitted: f.emitted.map((e: any) => e.requestId), refused: f.refused.map((r: any) => r.requestId + ": " + String(r.reason).slice(0, 90)), already: f.alreadyDispatched };
    } catch (e) { return { alarm: short(e), emittedBeforeAlarm: effects.slice(n0).map((x: any) => x.requestId) }; }
  };
  const paid = () => effects.reduce((s, e) => s + Number(JSON.parse(e.intent).amount), 0);
  const open = (extra: any = {}, path = db) => { try { return new Sink(path, { ...cfg, ...extra }); } catch (e) { return "REFUSED: " + short(e); } };
  return { pem, privateKey, cfg, dcfg, h0, db, ledger, tok, effects, flush, paid, open, work };
}

export function recomputeChain(db: DatabaseSync): void {
  const g = db.prepare("SELECT genesis, initial_state FROM meta").get() as any;
  const ss = db.prepare("SELECT seq, token FROM settled ORDER BY seq").all() as any[];
  const os = db.prepare("SELECT seq, intent FROM outbox ORDER BY seq").all() as any[];
  let prev = g.genesis, refunded = 0n, blob = g.initial_state, last = 0;
  for (let i = 0; i < ss.length; i++) {
    const t = ss[i].token, it = os[i].intent, self = SK.linkOf(prev, t, it), b = JSON.parse(t).body;
    db.prepare("UPDATE settled SET prev = ?, self = ?, token_sha256 = ? WHERE seq = ?").run(prev, self, E.sha256hex(t), ss[i].seq);
    db.prepare("UPDATE outbox SET prev = ?, self = ? WHERE seq = ?").run(prev, self, ss[i].seq);
    prev = self; refunded += BigInt(b.intent.amount); blob = E.canon(b.post); last = ss[i].seq;
  }
  db.prepare("UPDATE state SET blob = ?, seq = ?, refunded = ? WHERE id = 1").run(blob, last, refunded);
}
export function hostile(path: string, edit: (db: DatabaseSync) => void, recompute = true): string {
  const db = new DatabaseSync(path);
  try {
    db.exec("PRAGMA busy_timeout = 10000");
    const trig = db.prepare("SELECT name, sql FROM sqlite_schema WHERE type = 'trigger' ORDER BY name").all() as any[];
    db.exec("BEGIN IMMEDIATE");
    for (const t of trig) db.exec(`DROP TRIGGER ${t.name}`);
    edit(db);
    if (recompute) recomputeChain(db);
    for (const t of trig) db.exec(t.sql);
    db.exec("COMMIT");
    return "ok";
  } catch (e) { try { db.exec("ROLLBACK"); } catch { /* none */ } return "ERR " + short(e); }
  finally { db.close(); }
}
// Swap the row of request id `from` for the signed token `alt` (another request id on the same pre-state).
export const swapRow = (from: string, alt: string) => (d: DatabaseSync) => {
  const b = JSON.parse(alt).body;
  d.prepare("UPDATE settled SET request_id = ?, token = ? WHERE request_id = ?").run(b.requestId, alt, from);
  d.prepare("UPDATE outbox SET request_id = ?, intent = ? WHERE request_id = ?").run(b.requestId, E.canon(b.intent), from);
};
// Delete the row of request id `rid` and shift later rows down (zero-amount deletion keeps a valid log).
export const delRow = (rid: string) => (d: DatabaseSync) => {
  const s = (d.prepare("SELECT seq FROM settled WHERE request_id = ?").get(rid) as any).seq;
  d.prepare("DELETE FROM settled WHERE seq = ?").run(s); d.prepare("DELETE FROM outbox WHERE seq = ?").run(s);
  d.prepare("UPDATE settled SET seq = seq - 1 WHERE seq > ?").run(s); d.prepare("UPDATE outbox SET seq = seq - 1 WHERE seq > ?").run(s);
};
// A rollback journal whose playback makes the database file equal to `target` (SQLite file format, section 3).
export function makeJournal(target: Buffer, sector = 512): Buffer {
  const pageSize = (() => { const p = target.readUInt16BE(16); return p === 1 ? 65536 : p; })();
  const n = target.length / pageSize; if (!Number.isInteger(n)) throw new Error("target is not whole pages");
  const nonce = 0x2b3c4d5e;
  const hdr = Buffer.alloc(sector);
  Buffer.from("d9d505f920a163d7", "hex").copy(hdr, 0);
  hdr.writeUInt32BE(n, 8); hdr.writeUInt32BE(nonce, 12); hdr.writeUInt32BE(n, 16); hdr.writeUInt32BE(sector, 20); hdr.writeUInt32BE(pageSize, 24);
  const recs: Buffer[] = [hdr];
  for (let p = 1; p <= n; p++) {
    const data = target.subarray((p - 1) * pageSize, p * pageSize);
    let ck = nonce >>> 0; for (let i = pageSize - 200; i > 0; i -= 200) ck = (ck + data[i]) >>> 0;
    const r = Buffer.alloc(4 + pageSize + 4); r.writeUInt32BE(p, 0); data.copy(r, 4); r.writeUInt32BE(ck, 4 + pageSize); recs.push(r);
  }
  return Buffer.concat(recs);
}
export const ids = (p: string): string[] => {
  const d = new DatabaseSync(p, { readOnly: true });
  try { return (d.prepare("SELECT request_id FROM outbox ORDER BY seq").all() as any[]).map(x => x.request_id); } finally { d.close(); }
};
export const st = (sink: any): State => JSON.parse(sink.stateBlob());
