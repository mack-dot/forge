// C-ATT-24 (red team, MEDIUM): the RUNNING sink must not commit a second effect for a request id whose OLD row was
// changed behind it. Store: r1 (100), z (0), r2 (100), committed by one running sink. A FILE writer then renames the OLD
// row r1 -> r1x (token text, intent text and both request_id columns; token_sha256 recomputed; the links kept, so the head
// row is unchanged). The host retries r1 with a new token on the current state.
// Variants: sql = the writer edits the database through SQLite (triggers dropped and re-created);
//           journal = the writer only CREATES <db>-journal (its edit made on its own copy); the running sink's next lock
//           applies it (data_version may not change: the kept id map is the line that matters here).
// PASS: in every variant the retry of r1 is NOT committed (rejected or "sink halted"), and the outbox holds r1 at most once.
// Positive controls (no tamper): r1, z (0), r2 commit; z replay -> replayed; a second zero-amount refund z2 on the same
// pre-state as... the current state commits; a retry of r1 with a new token -> rejected (already settled).
// Usage: node --import tsx tests/refund-finality/regress/s_att24_old_row_running.ts <treeRoot> [<compiledIssuerModule>]
import { copyFileSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { argv, guard, hostile, kit, makeJournal, short, st, tempDir, verdict } from "./s_lib";

guard((() => {
  const { root } = argv();
  const K = kit(root);
  const out: any = {};
  let pass = true;
  const rename = (d: DatabaseSync) => {
    const t = (d.prepare("SELECT token FROM settled WHERE request_id = 'r1'").get() as any).token as string;
    const i = (d.prepare("SELECT intent FROM outbox WHERE request_id = 'r1'").get() as any).intent as string;
    const t2 = t.split('"requestId":"r1"').join('"requestId":"r1x"'), i2 = i.split('"requestId":"r1"').join('"requestId":"r1x"');
    d.prepare("UPDATE settled SET request_id = 'r1x', token = ?, token_sha256 = ? WHERE request_id = 'r1'").run(t2, K.E.sha256hex(t2));
    d.prepare("UPDATE outbox SET request_id = 'r1x', intent = ? WHERE request_id = 'r1'").run(i2);
  };
  for (const variant of ["sql", "journal"]) {
    const dir = tempDir(), db = join(dir, "sink.sqlite");
    const s = K.open(db); if (typeof s === "string") throw new Error(s);
    s.init(K.S0);
    const T1 = K.tok(K.S0, "r1", "100"), Z = K.tok(st("900"), "z", "0"), T2 = K.tok(st("900"), "r2", "100");
    const c = [T1, Z, T2].map(t => s.commit(t).status);
    let applied = "";
    if (variant === "sql") applied = hostile(db, rename);
    else {
      const own = join(dir, "own.sqlite"); copyFileSync(db, own);
      applied = hostile(own, rename);
      writeFileSync(db + "-journal", makeJournal(readFileSync(own)));
    }
    const retry = s.commit(K.tok(st("800"), "r1", "100"));
    let outbox: string[] = [];
    try { outbox = s.outbox().map((o: any) => o.request_id); } catch (e) { outbox = ["read failed: " + short(e)]; }
    s.close();
    const ok = c.every(x => x === "committed") && applied === "ok" && retry.status !== "committed" && outbox.filter(x => x === "r1").length <= 1;
    out[variant] = { commits: c, applied, retry: retry.status + (retry.reason ? ": " + String(retry.reason).slice(0, 120) : ""), outbox, ok };
    if (!ok) pass = false;
  }
  { // positive controls (no tamper)
    const dir = tempDir(), db = join(dir, "sink.sqlite");
    const s = K.open(db); s.init(K.S0);
    const Z = K.tok(st("900"), "z", "0");
    const c = [K.tok(K.S0, "r1", "100"), Z, K.tok(st("900"), "z2", "0"), K.tok(st("900"), "r2", "100")].map(t => s.commit(t).status);
    const replay = s.commit(Z).status, retry = s.commit(K.tok(st("800"), "r1", "100"));
    s.close();
    const ok = c.every(x => x === "committed") && replay === "replayed" && retry.status === "rejected";
    out.controls = { commits: c, replay, retry: retry.status + ": " + retry.reason, ok };
    if (!ok) pass = false;
  }
  verdict(pass, out);
})());
