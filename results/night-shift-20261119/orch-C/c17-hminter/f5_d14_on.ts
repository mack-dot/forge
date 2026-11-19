// F5: D14 in mode "on" against the HARDENED sink (h1 triggers + row-log chain). Attacker: a database writer WITHOUT the key.
// Honest part: minter mode "on" signs rq_a (100) and rq_b (700) on ONE pre-state S0 (different request ids: allowed by the
// new rule; the OLD rule refused rq_b). rq_a commits; rq_b is refused by the sink as stale (never committed).
// Writer: drops the h1 triggers, replaces row 1 (settled + outbox) by rq_b's token, recomputes the UNKEYED chain from the
// genesis in meta, sets the state row to rq_b's post, re-creates the triggers with the exact DDL text.
// Then: (1) a restart of the sink WITHOUT cfg.expectedHead; (2) a restart WITH expectedHead = the head after rq_a;
// (3) a dispatcher with a NEW ledger (cfg.newLedgerH0 = the store's genesis, the documented first-run config).
// Exit 1 = the swapped store passes the sink restart without an anchor AND the dispatcher emits rq_b (700, never committed).
// Usage: f5_d14_on.ts <work dir> [on|off]
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { DISP, E, Raw, STORE, done, fresh, guard, ids, mint, newSink, propose, st } from "./lib";
const [work, memo = "on"] = process.argv.slice(2);
guard((async () => {
  fresh(work);
  const m = await new Raw([memo]).start();
  const s0 = st("ch_D", "1000", "1000"), db = join(work, "d.sqlite");
  const sink = newSink(m, db, s0); sink.init(s0);
  const ta = await mint(m, s0, propose(s0, "rq_a", "100")), tb = await mint(m, s0, propose(s0, "rq_b", "700"));
  const r: any = { memo, signedA: ta.ok, signedB: tb.ok };
  if (!tb.ok) { sink.close(); m.stop(); r.note = "minter refused the second token on S0: D14 has no second signed token"; done(false, r); }
  r.ca = sink.commit(ta.text).status; r.cb = sink.commit(tb.text);
  const headA = sink.head(); sink.close();
  // ---- the writer (no key) ----
  const w = new DatabaseSync(db);
  const meta = w.prepare("SELECT genesis FROM meta WHERE id = 1").get() as any;
  const trig = w.prepare("SELECT name FROM sqlite_schema WHERE type = 'trigger'").all() as any[];
  const bTok = JSON.parse(tb.text!), intent = E.canon(bTok.body.intent), self = STORE.linkOf(meta.genesis, tb.text, intent);
  w.exec("BEGIN");
  for (const t of trig) w.exec(`DROP TRIGGER ${t.name}`);
  w.exec("DELETE FROM outbox; DELETE FROM settled;");
  w.prepare("INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (1, ?, ?, ?, ?, ?)").run("rq_b", tb.text, E.sha256hex(tb.text), meta.genesis, self);
  w.prepare("INSERT INTO outbox(seq, request_id, intent, prev, self) VALUES (1, ?, ?, ?, ?)").run("rq_b", intent, meta.genesis, self);
  w.prepare("UPDATE state SET blob = ?, seq = 1, refunded = 700 WHERE id = 1").run(E.canon(bTok.body.post));
  for (const s of STORE.DDL_STATEMENTS.filter((x: string) => x.startsWith("CREATE TRIGGER"))) w.exec(s);
  w.exec("COMMIT"); w.close();
  r.droppedTriggers = trig.length;
  // ---- after the swap ----
  try { const s = newSink(m, db, s0); r.restartNoAnchor = "served; audit()=" + JSON.stringify(s.audit()) + "; state=" + s.stateBlob(); s.close(); }
  catch (e) { r.restartNoAnchor = "REFUSED: " + String((e as Error).message).slice(0, 160); }
  try { const s = newSink(m, db, s0, { expectedHead: headA }); r.restartWithAnchor = "served"; s.close(); }
  catch (e) { r.restartWithAnchor = "REFUSED: " + String((e as Error).message).slice(0, 160); }
  const effects: string[] = [];
  try {
    const d = new DISP.Dispatcher(db, join(work, "ledger.jsonl"),
      { ...ids(m), initialStateSha256: E.stateSha256(s0), newLedgerH0: meta.genesis }, (_e: any, i: any) => effects.push(i.requestId + ":" + i.amount));
    const f = d.flush(); r.refused = f.refused;
  } catch (e) { r.dispatcher = "STOPPED: " + String((e as Error).message).slice(0, 160); }
  r.emitted = effects;
  m.stop();
  done(String(r.restartNoAnchor).startsWith("served") && effects.includes("rq_b:700"), r);
})());
