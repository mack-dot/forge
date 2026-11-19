// Attack 1: hot-journal planting. The attacker never opens the database file for writing. It (a) READ the database
// file at an earlier time (or holds any earlier copy), and (b) CREATES one new file "<db>-journal" in the directory.
// Modes: restart  - plant while the sink is closed; reopen.  running - plant while a sink is open; its next commit.
//        nul      - the journal carries a page edit (C-ATT-04 edit made on the attacker's OWN copy), then restart.
//        uv       - the journal carries PRAGMA user_version=77 made on the attacker's own copy (shows arbitrary page content).
// exit 1 = defect (an acknowledged commit is lost and the sink serves, or a forged store is served); 0 = safe.
import { copyFileSync, existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { fixture, fresh, EV, tryOpen, settledIds, Dispatcher } from "./common15";
import { makeJournal } from "./journal";
const mode = process.argv[2] ?? "restart";
(async () => {
  const fx = await fixture(); const T = (i: number) => fx.tokens[i].text;
  const W = join(EV, "work", "s1-" + mode); fresh(W);
  const db = join(W, "sink.sqlite"), ledger = join(W, "ledger.jsonl"), out: any = { mode };
  const effects: any[] = []; const flush = () => new Dispatcher(db, ledger, fx.dcfg, (e: any) => effects.push(e)).flush();
  let s = tryOpen(db, fx).sink; s.init(fx.cfg.initialState);
  out.c1 = s.commit(T(0)).status;
  const earlier = readFileSync(db);                     // (a) the attacker's earlier read of the file
  out.c2 = s.commit(T(1)).status;                         // r2 acknowledged
  out.c3 = s.commit(T(2)).status;                         // r3 (zero) acknowledged
  out.flush1 = flush().emitted.map((e: any) => e.requestId);
  const ino0 = statSync(db).ino;
  let target = earlier;
  if (mode === "nul" || mode === "uv") {
    const own = join(W, "attacker-own-copy.sqlite"); copyFileSync(db, own);      // attacker's own copy (read access)
    const w = new DatabaseSync(own);
    if (mode === "nul") {
      w.prepare("UPDATE settled SET request_id = ? WHERE request_id = ?").run("r3\u0000x", "r3");
      w.prepare("UPDATE outbox SET request_id = ? WHERE request_id = ?").run("r3\u0000x", "r3");
    } else w.exec("PRAGMA user_version = 77");
    w.close(); target = readFileSync(own);
  }
  if (mode !== "running") s.close();
  writeFileSync(db + "-journal", makeJournal(target));     // (b) the ONLY write: a new file in the directory
  out.journalPlanted = existsSync(db + "-journal");
  if (mode === "running") {
    out.c4_running = s.commit(T(3));                        // r4 minted on post-r3 state
    out.reaudits = s.reaudits; out.idsSeenByRunningSink = settledIds(s);
    out.c2_retry_running = s.commit(T(1));
    s.close();
  }
  const o = tryOpen(db, fx); out.restartError = o.err; out.journalAfter = existsSync(db + "-journal"); out.sameInode = statSync(db).ino === ino0;
  if (o.sink) {
    s = o.sink; out.ids = settledIds(s); out.state = JSON.parse(s.stateBlob()).remaining; out.audit = s.audit();
    out.uv = (new DatabaseSync(db, { readOnly: true }).prepare("PRAGMA user_version").get() as any).user_version;
    if (mode === "nul") out.c3_again = s.commit(T(2)).status;
    else if (mode !== "running") { out.c2_retry = s.commit(T(1)).status; out.c3_retry = s.commit(T(2)).status; out.c4 = s.commit(T(3)).status; }
    out.idsEnd = settledIds(s); s.close();
    try { out.flush2 = flush(); } catch (e) { out.flush2 = "throws: " + (e as Error).message; }
  }
  out.effects = effects.map((e: any) => e.requestId);
  let defect = false;
  if (mode === "restart" || mode === "running") defect = out.restartError === null && Array.isArray(out.ids) && !out.ids.includes("r2");
  if (mode === "running") defect = defect || (out.idsSeenByRunningSink && !out.idsSeenByRunningSink.includes("r2"));
  if (mode === "nul") defect = out.c3_again === "committed";
  if (mode === "uv") defect = out.restartError === null && out.uv === 77;
  console.log(JSON.stringify(out, null, 1));
  console.log(defect ? "DEFECT: a party that only created <db>-journal changed the audited store" : "SAFE");
  process.exit(defect ? 1 : 0);
})();
