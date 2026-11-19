// Shared helper of the sink regressions s_*.ts (night shift 2026-11-19, task h-sink2). A TEST, not a proof.
// Usage of every s_*.ts file (from any directory, pinned Node 24.3.0):
//   node --import tsx tests/refund-finality/regress/s_<name>.ts <treeRoot> [<compiledIssuerModule>]
// <treeRoot>: the checkout whose ts/refund-finality/{sink,dispatcher,encoding}.ts and core/store.ts are under test. The
// second argument is accepted for the same command form as d_*.ts and m_*.ts and is not used: the s_*.ts files sign
// their tokens in this process with a throwaway Ed25519 test key (no issuer process).
// Exit 0: PASS (the safe outcome). Exit 1: FAIL (the defect). Exit 2: usage. Exit 3: the harness broke.
// Files go to a fresh temp directory (removed at exit). Attacker model of the hostile cases: a FILE writer without the
// key (drops the triggers, edits, may recompute the unkeyed chain, re-creates the identical trigger text), or a party
// that can only CREATE files next to the database (planted journal).
import { generateKeyPairSync, sign } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";

export type State = { chargeId: string; original: string; remaining: string; refundEnabled: boolean };
export function argv(): { root: string } {
  const [root] = process.argv.slice(2);
  if (!root) { console.error("usage: s_<name>.ts <treeRoot> [<compiledIssuerModule>]"); process.exit(2); }
  return { root: resolve(root) };
}
const temps: string[] = [];
process.on("exit", () => { for (const d of temps) { try { rmSync(d, { recursive: true, force: true }); } catch { /* best effort */ } } });
export function tempDir(): string { const d = mkdtempSync(join(tmpdir(), "forge-s-")); temps.push(d); return d; }

/* eslint-disable @typescript-eslint/no-require-imports */
export function load(root: string): { E: any; SK: any; Sink: any; Dispatcher: any; ST: any } {
  const E = require(join(root, "ts/refund-finality/encoding.ts"));
  const SK = require(join(root, "ts/refund-finality/sink.ts"));
  const { Dispatcher } = require(join(root, "ts/refund-finality/dispatcher.ts"));
  const ST = require(join(root, "ts/refund-finality/core/store.ts"));
  return { E, SK, Sink: SK.Sink, Dispatcher, ST };
}
/* eslint-enable @typescript-eslint/no-require-imports */

export const st = (remaining: string, chargeId = "ch_s", original = "1000"): State => ({ chargeId, original, remaining, refundEnabled: true });

// One test key, one sink config, a token maker, a dispatcher config.
export function kit(root: string, S0: State = st("1000")) {
  const L = load(root);
  const { publicKey, privateKey } = generateKeyPairSync("ed25519");
  const pem = publicKey.export({ type: "spki", format: "pem" }) as string;
  const cfg: any = { publicKeyPem: pem, specLockSha256: "1".repeat(64), checkerSha256: "2".repeat(64), initialState: S0 };
  const genesis = L.SK.genesisOf(L.E.canon(S0), cfg.specLockSha256, cfg.checkerSha256, pem);
  const dcfg: any = { publicKeyPem: pem, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, initialStateSha256: L.E.stateSha256(S0), newLedgerH0: genesis };
  const tok = (pre: State, rid: string, amount: string, reason = "duplicate_charge"): string => {
    const body = { domain: L.E.DOMAIN, specLockSha256: cfg.specLockSha256, checkerSha256: cfg.checkerSha256, preStateSha256: L.E.stateSha256(pre),
      requestId: rid, post: { ...pre, remaining: (BigInt(pre.remaining) - BigInt(amount)).toString() },
      intent: { chargeId: pre.chargeId, requestId: rid, amount, reason } };
    return L.E.canon({ body, signature: sign(null, L.E.signedBytes(body), privateKey).toString("base64") });
  };
  const postOf = (t: string): State => JSON.parse(t).body.post;
  const intentOf = (t: string): string => L.E.canon(JSON.parse(t).body.intent);
  const open = (db: string, extra: any = {}): any => { try { return new L.Sink(db, { ...cfg, ...extra }); } catch (e) { return "REFUSED: " + short(e); } };
  const flush = (db: string, ledger: string, extra: any = {}): { emitted: string[]; refused: string[]; alarm?: string; paid: number } => {
    const effects: any[] = [];
    try {
      const f = new L.Dispatcher(db, ledger, { ...dcfg, ...extra }, (e: any) => effects.push(e)).flush();
      return { emitted: f.emitted.map((e: any) => e.requestId), refused: f.refused.map((r: any) => r.requestId + ": " + String(r.reason).slice(0, 80)), paid: paid(effects) };
    } catch (e) { return { emitted: effects.map((x: any) => x.requestId), refused: [], alarm: short(e), paid: paid(effects) }; }
  };
  return { ...L, S0, pem, cfg, dcfg, genesis, tok, postOf, intentOf, open, flush };
}
export const paid = (effects: { intent: string }[]): number => effects.reduce((s, e) => s + Number(JSON.parse(e.intent).amount), 0);
export const short = (e: unknown): string => String((e as Error)?.message ?? e).replace(/\s+/g, " ").slice(0, 200);
export const ids = (p: string): string[] => {
  const d = new DatabaseSync(p, { readOnly: true });
  try { return (d.prepare("SELECT request_id FROM settled ORDER BY seq").all() as any[]).map(x => x.request_id); } finally { d.close(); }
};

// Recomputes every prev/self/token_sha256 and the state row from the stored rows (the unkeyed chain; triggers dropped).
export function recomputeChain(db: DatabaseSync, linkOf: (p: string, t: string, i: string) => string, sha: (s: string) => string): void {
  const g = db.prepare("SELECT genesis, initial_state FROM meta").get() as any;
  const ss = db.prepare("SELECT seq, token FROM settled ORDER BY seq").all() as any[];
  const os = db.prepare("SELECT seq, intent FROM outbox ORDER BY seq").all() as any[];
  let prev = g.genesis, refunded = 0n, blob = g.initial_state, last = 0;
  for (let i = 0; i < ss.length; i++) {
    const t = ss[i].token, it = os[i].intent, self = linkOf(prev, t, it), b = JSON.parse(t).body;
    db.prepare("UPDATE settled SET prev = ?, self = ?, token_sha256 = ? WHERE seq = ?").run(prev, self, sha(t), ss[i].seq);
    db.prepare("UPDATE outbox SET prev = ?, self = ? WHERE seq = ?").run(prev, self, ss[i].seq);
    prev = self; refunded += BigInt(b.intent.amount); blob = canonState(b.post); last = ss[i].seq;
  }
  db.prepare("UPDATE state SET blob = ?, seq = ?, refunded = ? WHERE id = 1").run(blob, last, refunded);
}
const canonState = (s: State): string => `{"chargeId":${JSON.stringify(s.chargeId)},"original":"${s.original}","refundEnabled":${s.refundEnabled},"remaining":"${s.remaining}"}`;
// The FILE writer: drop all triggers, edit, optionally recompute the chain, re-create the identical trigger text. One
// transaction on the given file (the real database, or the attacker's own copy).
export function hostile(path: string, edit: (db: DatabaseSync) => void, chain?: { linkOf: any; sha: any }): string {
  const db = new DatabaseSync(path);
  try {
    db.exec("PRAGMA busy_timeout = 10000");
    const trig = db.prepare("SELECT name, sql FROM sqlite_schema WHERE type = 'trigger' ORDER BY name").all() as any[];
    db.exec("BEGIN IMMEDIATE");
    for (const t of trig) db.exec(`DROP TRIGGER ${t.name}`);
    edit(db);
    if (chain) recomputeChain(db, chain.linkOf, chain.sha);
    for (const t of trig) db.exec(t.sql);
    db.exec("COMMIT");
    return "ok";
  } catch (e) { try { db.exec("ROLLBACK"); } catch { /* none */ } return "ERR " + short(e); }
  finally { db.close(); }
}
// A SQLite rollback journal whose playback makes the database file equal to `target` (all pages). Copied from the
// reviewer's probe orch-B/r-harden/probes/journal.ts (file format section 3 of the SQLite documentation).
export function makeJournal(target: Buffer, sector = 512): Buffer {
  const pageSize = (() => { const p = target.readUInt16BE(16); return p === 1 ? 65536 : p; })();
  const n = target.length / pageSize; if (!Number.isInteger(n)) throw new Error("target is not whole pages");
  const nonce = 0x1b2c3d4e;
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
export function verdict(pass: boolean, detail: unknown): never {
  console.log(JSON.stringify(detail));
  console.log(pass ? "PASS" : "FAIL");
  process.exit(pass ? 0 : 1);
}
export function guard(p: Promise<void> | void): void { Promise.resolve(p).catch(e => { console.error(e); process.exit(3); }); }
