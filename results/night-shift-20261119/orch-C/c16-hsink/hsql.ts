// c16 hsql: trigger coverage with the triggers INTACT (a buggy or hostile writer that does not drop them).
// A store with honest rows r1 600, z 0; then raw statements: conflict clauses, REPLACE (recursive_triggers off),
// UPSERT, no-op updates, seq updates, non-canonical money in forged rows, MaxMoney+1, invalid UTF-8, an unsigned row.
// A statement is a GAP when it succeeds AND it changes or removes a committed row, or it appends a row that breaks
// S1/S4 (money rule). An appended row that only fails the signature is NOT a gap here (the audit's job; checked below).
// Usage: hsql.ts <work>   Exit 1 = at least one gap; 0 = none.
import { DatabaseSync } from "node:sqlite";
import { setup, out, S0, E } from "./h";
const [work] = process.argv.slice(2);
(async () => {
  const h = await setup(work); const sink: any = h.open(); sink.init(S0);
  sink.commit(await h.mint(S0, "r1", "600")); const zt = await h.mint(JSON.parse(sink.stateBlob()), "z", "0"); sink.commit(zt);
  sink.close();
  const snap = () => { const d = new DatabaseSync(h.db); const s = JSON.stringify([d.prepare("SELECT * FROM settled ORDER BY rowid").all(), d.prepare("SELECT * FROM outbox ORDER BY rowid").all(), d.prepare("SELECT * FROM state").all(), d.prepare("SELECT * FROM meta").all()]); d.close(); return s; };
  const row1 = (() => { const d = new DatabaseSync(h.db); const r = d.prepare("SELECT * FROM settled WHERE seq = 1").get() as any; const o = d.prepare("SELECT * FROM outbox WHERE seq = 1").get() as any; const m = d.prepare("SELECT * FROM meta").get() as any; const st = d.prepare("SELECT * FROM state").get() as any; const last = d.prepare("SELECT self FROM outbox WHERE seq = 2").get() as any; d.close(); return { r, o, m, st, last: last.self }; })();
  const pre = JSON.parse(row1.st.blob);
  const forged = (amount: string, rid: string, post?: any) => {   // unsigned (garbage signature), otherwise trigger-shaped
    const body = { checkerSha256: "b".repeat(64), domain: E.DOMAIN, intent: { amount, chargeId: S0.chargeId, reason: "duplicate_charge", requestId: rid },
      post: post ?? { ...pre, remaining: (BigInt(pre.remaining) - (/^[0-9]+$/.test(amount) ? BigInt(amount) : 0n)).toString() }, preStateSha256: E.stateSha256(pre), requestId: rid, specLockSha256: "a".repeat(64) };
    return '{"body":' + E.canon(body).replace('"amount":"' + amount + '"', '"amount":"' + amount + '"') + ',"signature":"' + "A".repeat(86) + '=="}';
  };
  const ins = (tok: string, rid: string) => `INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (3, '${rid.replace(/'/g, "''")}', '${tok.replace(/'/g, "''")}', '${"c".repeat(64)}', '${row1.last}', '${"d".repeat(64)}')`;
  const q = (s: string) => "'" + String(s).replace(/'/g, "''") + "'";
  const T: [string, string, "change" | "append-money" | "append-sig"][] = [
    ["REPLACE INTO settled (same seq 1, same values)", `REPLACE INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (1, ${q(row1.r.request_id)}, ${q(row1.r.token)}, ${q(row1.r.token_sha256)}, ${q(row1.r.prev)}, ${q(row1.r.self)})`, "change"],
    ["REPLACE INTO outbox (seq 1)", `REPLACE INTO outbox(seq, request_id, intent, prev, self) VALUES (1, ${q(row1.o.request_id)}, ${q(row1.o.intent)}, ${q(row1.o.prev)}, ${q(row1.o.self)})`, "change"],
    ["INSERT OR REPLACE INTO settled (seq 3, request_id r1)", `INSERT OR REPLACE INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (3, 'r1', ${q(row1.r.token)}, ${q(row1.r.token_sha256)}, ${q(row1.last)}, ${q("e".repeat(64))})`, "change"],
    ["UPSERT settled ON CONFLICT(seq) DO UPDATE", `INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (1, 'q', 'x', ${q("c".repeat(64))}, ${q("c".repeat(64))}, ${q("c".repeat(64))}) ON CONFLICT(seq) DO UPDATE SET request_id = 'q'`, "change"],
    ["INSERT OR IGNORE settled dup request id", `INSERT OR IGNORE INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (3, 'r1', ${q(row1.r.token)}, ${q(row1.r.token_sha256)}, ${q(row1.last)}, ${q("e".repeat(64))})`, "change"],
    ["REPLACE INTO state (back to initial)", `REPLACE INTO state(id, blob, seq, refunded) VALUES (1, ${q(row1.m.initial_state)}, 0, 0)`, "change"],
    ["REPLACE INTO meta", `REPLACE INTO meta(id, format, charge_id, initial_state, initial_state_sha256, genesis) VALUES (1, ${q(row1.m.format)}, ${q(row1.m.charge_id)}, ${q(row1.m.initial_state)}, ${q(row1.m.initial_state_sha256)}, ${q(row1.m.genesis)})`, "change"],
    ["UPDATE settled SET seq = seq", "UPDATE settled SET seq = seq", "change"],
    ["UPDATE state SET seq = seq", "UPDATE state SET seq = seq", "change"],
    ["UPDATE outbox SET rowid = rowid + 10", "UPDATE outbox SET rowid = rowid + 10", "change"],
    ["DELETE FROM settled WHERE seq = 2", "DELETE FROM settled WHERE seq = 2", "change"],
    ["DROP TABLE outbox", "DROP TABLE outbox", "schema" as any],
    ["ALTER TABLE settled RENAME TO s2", "ALTER TABLE settled RENAME TO s2", "schema" as any],
    ...["1e3", " 5", "5 ", "+5", "05", "0x10", "9223372036854775808", "18446744073709551616", "-1", "5.0"].map(a => [`forged append amount '${a}'`, ins(forged(a, "f" + a), "f" + a), "append-money"] as [string, string, "append-money"]),
    ["forged append amount 401 > remaining 400", ins(forged("401", "f401"), "f401"), "append-money"],
    ["forged append amount 0 with post.remaining raised", ins(forged("0", "fz", { ...pre, remaining: "900" }), "fz"), "append-money"],
    ["forged append amount 100 (well-formed, unsigned)", ins(forged("100", "fok"), "fok"), "append-sig"],
  ];
  const res: any[] = []; let gaps = 0;
  for (const [name, sql, kind] of T) {
    const before = snap(); const d = new DatabaseSync(h.db); let r = "";
    try { d.exec("BEGIN"); d.exec(sql); r = "SUCCEEDED"; } catch (e) { r = "refused: " + String((e as Error).message).slice(0, 80); }
    const changed = r === "SUCCEEDED" && (kind as string) !== "schema" && (() => { const a = JSON.stringify([d.prepare("SELECT * FROM settled WHERE seq <= 2 ORDER BY rowid").all(), d.prepare("SELECT * FROM outbox WHERE seq <= 2 ORDER BY rowid").all()]); return a !== JSON.stringify([JSON.parse(before)[0].slice(0, 2), JSON.parse(before)[1].slice(0, 2)]) || before.length === 0; })();
    try { d.exec("ROLLBACK"); } catch { /* none */ } d.close();
    const gap = r === "SUCCEEDED" && (kind === "append-money" || (kind === "change" && changed));
    if (gap) gaps++; res.push({ name, r, changed, gap });
  }
  for (const x of res) out(x);
  // the one statement that should succeed (unsigned but trigger-shaped): commit it for real and audit
  const d = new DatabaseSync(h.db); let applied = ""; try { d.exec(ins(forged("100", "fok"), "fok")); applied = "committed raw"; } catch (e) { applied = "refused " + String(e); } d.close();
  const s2 = h.open(); const f = h.flush({ newLedger: true });
  out({ unsignedAppend: applied, restart: typeof s2 === "string" ? s2.slice(0, 160) : "serves", flush: f, effects: h.effects.map((e: any) => e.requestId) });
  if (typeof s2 !== "string") s2.close();
  h.stop(); out({ statements: T.length, gaps });
  process.exit(gaps > 0 || h.effects.some((e: any) => e.requestId === "fok") ? 1 : 0);
})().catch(e => { console.error(String(e && e.stack)); process.exit(3); });
