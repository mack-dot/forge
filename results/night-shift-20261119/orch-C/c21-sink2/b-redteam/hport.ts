// c16 hport: the confirmed attacks ported to the h1 sink as a REAL database writer without the key does them now
// (h.ts hostile(): DROP the triggers, edit, optionally recompute the unkeyed chain, re-CREATE the identical triggers).
// Usage: hport.ts <work> <case> <where: restart|running> <anchor: none|head|stale>
//   history: r1 600 (dispatched), z 0 (dispatched), r2 100 (committed, NOT yet dispatched); alt = r2b 300 minted for the
//   same pre-state as r2 and never committed (honest minter, memory off). anchor head = sink.head() after r2 (count 3);
//   stale = sink.head() after r1 (count 1). The dispatcher ledger stays intact (lines n=1, n=2 with rowHead).
// cases: z1del | d14 | nul | ff | blob | rollback | oldrow   (see SUCCESS below)
// Exit 1 = the attack SUCCEEDS (defect present); 0 = safe; 3 = harness error.
import { copyFileSync } from "node:fs";
import { join } from "node:path";
import { setup, hostile, out, S0, E } from "./h";
const [work, kase, where, anc] = process.argv.slice(2);
(async () => {
  const h = await setup(work);
  const L: any = { kase, where, anc };
  let sink: any = h.open(); sink.init(S0);
  const st = () => JSON.parse(sink.stateBlob());
  L.c1 = sink.commit(await h.mint(S0, "r1", "600")).status; const stale = sink.head();
  const snap = join(work, "snap-after-r1.sqlite"); copyFileSync(h.db, snap);
  L.f1 = h.flush({ newLedger: true });                          // first run: the host passes newLedgerH0
  const zt = await h.mint(st(), "z", "0"); L.c2 = sink.commit(zt).status; L.f2 = h.flush();
  const pre3 = st(); const r2t = await h.mint(pre3, "r2", "100"), alt = await h.mint(pre3, "r2b", "300");
  L.c3 = sink.commit(r2t).status; const head = sink.head();
  const anchor = anc === "head" ? head : anc === "stale" ? stale : anc === "genesis" ? { count: 0, chainHash: h.h0 } : undefined;
  if (where === "restart") sink.close();
  let applied = "";
  const altB = JSON.parse(alt);
  switch (kase) {
    case "z1del": applied = hostile(h.db, d => { d.exec("DELETE FROM settled WHERE request_id = 'z'; DELETE FROM outbox WHERE request_id = 'z'; UPDATE settled SET seq = seq - 1 WHERE seq > 2; UPDATE outbox SET seq = seq - 1 WHERE seq > 2;"); }, { recompute: true }); break;
    case "d14": applied = hostile(h.db, d => {
      d.prepare("UPDATE settled SET request_id = 'r2b', token = ? WHERE request_id = 'r2'").run(alt);
      d.prepare("UPDATE outbox SET request_id = 'r2b', intent = ? WHERE request_id = 'r2'").run(E.canon(altB.body.intent)); }, { recompute: true }); break;
    case "nul": applied = hostile(h.db, d => { d.exec("UPDATE settled SET request_id = 'z' || char(0) || 'x' WHERE request_id = 'z'; UPDATE outbox SET request_id = 'z' || char(0) || 'x' WHERE request_id = 'z';"); }, { ignoreChecks: true }); break;
    case "ff": applied = hostile(h.db, d => { d.exec("UPDATE settled SET request_id = CAST(x'7aff' AS TEXT) WHERE request_id = 'z'; UPDATE outbox SET request_id = CAST(x'7aff' AS TEXT) WHERE request_id = 'z';"); }, { ignoreChecks: true }); break;
    case "blob": applied = hostile(h.db, d => { d.exec("UPDATE outbox SET request_id = CAST('r2' AS BLOB) WHERE request_id = 'r2';"); }, { ignoreChecks: true }); break;
    case "rollback": copyFileSync(snap, h.db); applied = "file replaced by the copy taken after r1"; break;
    case "oldrow": applied = hostile(h.db, d => {   // rename OLD row r1 -> r1x (token and intent texts too); chain NOT recomputed
      const t = (d.prepare("SELECT token FROM settled WHERE request_id = 'r1'").get() as any).token as string;
      const i = (d.prepare("SELECT intent FROM outbox WHERE request_id = 'r1'").get() as any).intent as string;
      d.prepare("UPDATE settled SET request_id = 'r1x', token = ? WHERE request_id = 'r1'").run(t.split('"requestId":"r1"').join('"requestId":"r1x"'));
      d.prepare("UPDATE outbox SET request_id = 'r1x', intent = ? WHERE request_id = 'r1'").run(i.split('"requestId":"r1"').join('"requestId":"r1x"')); }); break;
    default: throw new Error("unknown case");
  }
  L.applied = applied;
  if (where === "restart") { sink = h.open(anchor); L.start = typeof sink === "string" ? sink : "serves"; }
  else L.start = "running (opened before the tamper)";
  const serving = typeof sink !== "string";
  if (serving) {
    let next = "";
    try {
      if (kase === "z1del" || kase === "nul" || kase === "ff") next = JSON.stringify(sink.commit(await h.mint(st(), "z", "0")));   // host retry of z (zero) at the current state
      else if (kase === "oldrow") next = JSON.stringify(sink.commit(await h.mint(st(), "r1", "100")));                   // host retry of r1
      else next = JSON.stringify(sink.commit(await h.mint(st(), "r3", "50")));                                          // next honest refund
    } catch (e) { next = "ERR " + String((e as Error).message).slice(0, 160); }
    L.next = next; L.reaudits = sink.reaudits; L.audit = sink.audit();
    try { L.outbox = sink.outbox().map((o: any) => o.request_id); } catch (e) { L.outbox = String(e); }
  }
  L.flush = h.flush(); L.paid = h.paid(); L.effects = h.effects.map((e: any) => e.requestId);
  if (serving) sink.close();
  const later = h.open(anchor); L.laterRestart = typeof later === "string" ? later : "serves"; if (typeof later !== "string") later.close();
  h.stop();
  // SUCCESS (attack works):
  const committedNext = serving && /"committed"/.test(L.next);
  let success = false;
  if (kase === "z1del" || kase === "nul" || kase === "ff") success = committedNext;                 // z committed twice
  if (kase === "oldrow") success = committedNext;                                                    // r1 committed twice
  if (kase === "d14") success = h.effects.some((e: any) => e.requestId === "r2b");                   // uncommitted effect sent
  if (kase === "blob") success = !("alarm" in L.flush) && L.flush.emitted.length + L.flush.refused.length + L.flush.already < 3;   // a committed row neither sent, refused nor counted
  if (kase === "rollback") success = (committedNext && !L.flush.alarm) || h.paid() > 1000;          // acked, no alarm; or overpaid
  L.success = success; out(L);
  process.exit(success ? 1 : 0);
})().catch(e => { console.error(String(e && e.stack)); process.exit(3); });
