// h-sink2 copy h2.ts of orch-C/c16-hsink/h.ts. Changes: flush() takes expectedHead (the dispatcher anchor); open() takes
// {committed} as cfg.outsideHead. Nothing else changed.
// c16-hsink helper (red team C). Target: the h1 sink of 608b5165 (read-only extraction fix-608b5165).
// setup(): throwaway minter process (fresh Ed25519 key, IssueOnce build), sink, dispatcher with a ledger policy.
// hostile(): the database writer WITHOUT the key, with full file powers: it drops the 14 triggers, may set
// PRAGMA ignore_check_constraints, edits, may recompute the unkeyed chain (linkOf / genesis are exported), and then
// re-creates the IDENTICAL trigger texts, so the schema text check passes. One transaction.
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
export const ROOT = process.env.H_ROOT ?? "<SCRATCH>/redteam-C/fix-608b5165";
export const CORE = process.env.H_CORE ?? "<REPO>/results/night-shift-20261119/orch-B/h-minter/build/issueonce.cjs";
/* eslint-disable @typescript-eslint/no-require-imports */
export const E = require(join(ROOT, "ts/refund-finality/encoding.ts"));
export const SK = require(join(ROOT, "ts/refund-finality/sink.ts"));
export const { Sink } = SK;
export const { Dispatcher } = require(join(ROOT, "ts/refund-finality/dispatcher.ts"));
export const ST = process.env.H_ROOT && !process.env.H_ROOT.endsWith("fix-608b5165") ? {} : require(join(ROOT, "ts/refund-finality/core/store.ts"));
const { MinterClient, propose } = require(join(ROOT, "ts/refund-finality/proposer.ts"));
/* eslint-enable @typescript-eslint/no-require-imports */
export const S0 = { chargeId: "ch_c16", original: "1000", remaining: "1000", refundEnabled: true };

export async function setup(work: string, s0: any = S0) {
  rmSync(work, { recursive: true, force: true }); mkdirSync(work, { recursive: true });
  const m = await MinterClient.start(ROOT, CORE, join(ROOT, "spec/refund/spec.lock"), (process.env.H_MEM ?? "off") as any);
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const db = join(work, "sink.sqlite"), ledger = join(work, "ledger.jsonl");
  const cfg = { ...ids, initialState: s0 };
  const h0 = SK.genesisOf === undefined ? "" : SK.genesisOf(E.canon(s0), ids.specLockSha256, ids.checkerSha256, ids.publicKeyPem);
  const dcfg = { ...ids, initialStateSha256: E.stateSha256(s0) };
  const effects: any[] = [];
  const mint = async (pre: any, rid: string, amount: string, reason = "duplicate_charge"): Promise<string> => {
    const a = await m.mint(pre, propose(pre, { requestId: rid, amount, reason }));
    if (!a.ok) throw new Error("mint refused: " + a.reason); return E.tokenText(a.token);
  };
  // newLedger: true = the host passes cfg.newLedgerH0 = h_0 for this run (it believes this is the first run).
  const flush = (opt: { ledgerPath?: string; newLedger?: boolean; expectedHead?: any } = {}) => {
    const c0 = opt.newLedger ? { ...dcfg, newLedgerH0: h0 } : dcfg, c = opt.expectedHead ? { ...c0, expectedHead: opt.expectedHead } : c0;   // h2: dispatcher anchor
    try { const f = new Dispatcher(db, opt.ledgerPath ?? ledger, c, (e: any) => effects.push(e)).flush();
      return { emitted: f.emitted.map((e: any) => e.requestId), refused: f.refused.map((r: any) => r.requestId + ": " + String(r.reason).slice(0, 90)), already: f.alreadyDispatched };
    } catch (e) { return { alarm: String((e as Error).message).slice(0, 160) }; }
  };
  const paid = () => effects.reduce((s, e) => s + Number(JSON.parse(e.intent).amount), 0);
  const open = (expectedHead?: any) => { try { return new Sink(db, expectedHead?.committed ? { ...cfg, outsideHead: expectedHead } : expectedHead ? { ...cfg, expectedHead } : cfg); } catch (e) { return String((e as Error).message).slice(0, 220); } };
  return { m, ids, db, ledger, cfg, dcfg, h0, effects, mint, flush, paid, open, stop: () => m.stop() };
}

export function recomputeChain(db: DatabaseSync): void {
  const g = (db.prepare("SELECT genesis, initial_state FROM meta").get() as any);
  const ss = db.prepare("SELECT seq, token FROM settled ORDER BY seq").all() as any[];
  const os = db.prepare("SELECT seq, intent FROM outbox ORDER BY seq").all() as any[];
  let prev = g.genesis, refunded = 0n, blob = g.initial_state, last = 0;
  for (let i = 0; i < ss.length; i++) {
    const t = ss[i].token, it = os[i]?.intent ?? E.canon(JSON.parse(t).body.intent);
    const self = SK.linkOf(prev, t, it);
    db.prepare("UPDATE settled SET prev = ?, self = ?, token_sha256 = ? WHERE seq = ?").run(prev, self, E.sha256hex(t), ss[i].seq);
    db.prepare("UPDATE outbox SET prev = ?, self = ? WHERE seq = ?").run(prev, self, ss[i].seq);
    prev = self; const b = JSON.parse(t).body; refunded += BigInt(b.intent.amount); blob = E.canon(b.post); last = ss[i].seq;
  }
  db.prepare("UPDATE state SET blob = ?, seq = ?, refunded = ? WHERE id = 1").run(blob, last, refunded);
}

export function hostile(path: string, edit: (db: DatabaseSync) => void, opt: { recompute?: boolean; ignoreChecks?: boolean } = {}): string {
  const db = new DatabaseSync(path);
  try {
    db.exec("PRAGMA busy_timeout = 10000");
    const trig = db.prepare("SELECT name, sql FROM sqlite_schema WHERE type = 'trigger' ORDER BY name").all() as any[];
    if (opt.ignoreChecks) db.exec("PRAGMA ignore_check_constraints = ON");
    db.exec("BEGIN IMMEDIATE");
    for (const t of trig) db.exec(`DROP TRIGGER ${t.name}`);
    edit(db);
    if (opt.recompute) recomputeChain(db);
    for (const t of trig) db.exec(t.sql);
    db.exec("COMMIT");
    return "ok (" + trig.length + " triggers dropped and re-created)";
  } catch (e) { try { db.exec("ROLLBACK"); } catch { /* none */ } return "ERR " + String((e as Error).message); }
  finally { db.close(); }
}
export const out = (o: any) => console.log(JSON.stringify(o));
