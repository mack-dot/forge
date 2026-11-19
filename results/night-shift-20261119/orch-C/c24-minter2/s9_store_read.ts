// S9: assumption STORE-READ. Attacker: a database FILE writer WITHOUT the signing key (drops triggers, edits rows,
// copies an old file back in place) plus any minter caller. The issuer runs in Store mode, mode "on".
// Modes:
//   inflate : after a full refund (1000 of 1000, dispatched), the writer sets the state row back to remaining 1000;
//             the minter is asked for a NEW refund of 1000 on that state. Then: the running sink, a restarted sink,
//             the dispatcher on that store.
//   rollback: after rq_1 (1000) is committed and dispatched, the writer copies the init-time file back IN PLACE; the
//             minter signs rq_2 (1000) on the initial state; a restarted sink (no outside head) commits it; the dispatcher
//             (same ledger and witness) runs.
//   noaudit : the writer replaces the CONTENT of the store with a minimal two-table file it made itself (no meta, no
//             triggers, no settled history); the minter is asked to sign on the writer's state.
//   nul     : the writer appends U+0000 and junk to the state blob (node:sqlite cuts TEXT at U+0000).
// Exit 1 = the external effects total more than the charge's original (1000), i.e. the token led to money out.
// Exit 0 = no second effect. The script prints what the minter signed and which control refused.
// Usage: s9_store_read.ts <work dir> <mode>
import { copyFileSync, existsSync, rmSync, writeFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { join } from "node:path";
import { DISP, E, STORE, Raw, done, fresh, guard, mint, newSink, propose, st } from "./lib";
const [work, mode] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const path = join(work, "s.sqlite"), ledger = join(work, "ledger.jsonl"), backup = join(work, "init-backup.sqlite");
  const m = await new Raw(["on", path]).start();
  const s0 = st("ch_S9", "1000", "1000");
  const ids = { publicKeyPem: m.ready.publicKeyPem, specLockSha256: m.ready.specLockSha256, checkerSha256: m.ready.checkerSha256 };
  const effects: any[] = [];
  let first = true;
  const flush = () => { try { const h0 = first ? { newLedgerH0: STORE.genesisOf(E.canon(s0), ids.specLockSha256, ids.checkerSha256, ids.publicKeyPem) } : {}; first = false;
    const d = new DISP.Dispatcher(path, ledger, { ...ids, initialStateSha256: E.sha256hex(E.canon(s0)), ...h0 }, (e: any) => effects.push(e));
    const f = d.flush(); return { emitted: f.emitted.map((e: any) => e.requestId), refused: f.refused.map((x: any) => x.reason.slice(0, 140)) }; }
    catch (e) { return "dispatcher threw: " + String((e as Error).message).slice(0, 200); } };
  const sink = newSink(m, path, s0); sink.init(s0); sink.close();
  copyFileSync(backup.replace("init-backup", "s") , backup);
  const sk = newSink(m, path, s0);
  const r: any = { mode };
  const t1 = await mint(m, s0, propose(s0, "rq_1", "1000"));
  r.rq1 = sk.commit(t1.text).status; r.flush1 = flush();
  const writer = () => { const w = new DatabaseSync(path); w.exec("PRAGMA journal_mode = DELETE; PRAGMA ignore_check_constraints = ON"); return w; };
  // edit the state row with the trigger dropped and then re-created with its EXACT text (schema text unchanged)
  const editState = (blob: string) => { const w = writer();
    const sql = (w.prepare("SELECT sql FROM sqlite_schema WHERE name = 'h_state_bu'").get() as any).sql;
    w.exec("BEGIN; DROP TRIGGER h_state_bu;"); w.prepare("UPDATE state SET blob = ? WHERE id = 1").run(blob); w.exec(sql + "; COMMIT;"); w.close(); };
  let pre: any = null;
  if (mode === "inflate") {
    pre = st("ch_S9", "1000", "1000"); editState(E.canon(pre));
  } else if (mode === "rollback") {
    sk.close(); writeFileSync(path, require("node:fs").readFileSync(backup)); pre = s0;   // in place: same inode
  } else if (mode === "noaudit") {
    sk.close(); writeFileSync(path, ""); const w = new DatabaseSync(path);
    pre = st("ch_S9", "1000", "1000");
    w.exec("CREATE TABLE state(id INTEGER PRIMARY KEY, blob TEXT); CREATE TABLE settled(request_id TEXT)");
    w.prepare("INSERT INTO state VALUES (1, ?)").run(E.canon(pre)); w.close();
  } else if (mode === "nul") {
    pre = JSON.parse(sk.stateBlob()); editState(E.canon(pre) + "\u0000junk");
  }
  const t2 = await mint(m, pre, propose(pre, "rq_2", pre.remaining === "0" ? "0" : "1000"));
  r.minterOnWritersState = t2.ok ? "SIGNED rq_2 amount " + JSON.parse(t2.text).body.intent.amount + " on remaining " + pre.remaining : "refused: " + t2.reason;
  if (t2.ok) {
    if (mode === "inflate" || mode === "nul") r.runningSinkCommit = sk.commit(t2.text);
    try { sk.close(); } catch { /* closed */ }
    try { const s2 = newSink(m, path, s0); r.restartedSink = "started"; r.restartedCommit = s2.commit(t2.text); s2.close(); }
    catch (e) { r.restartedSink = String((e as Error).message).slice(0, 220); }
    r.flush2 = flush();
  }
  m.stop();
  const total = effects.reduce((a, e) => a + Number(JSON.parse(e.intent).amount), 0);
  r.effects = effects.map(e => e.requestId); r.totalOut = total;
  done(total > 1000, r);
})());
