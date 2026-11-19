// Availability / repair (reviewer, h-sink2 item 8): one INSERT that the triggers accept but the audit refuses halts the
// store for good. SQLite has no hash function (node:sqlite 3.50.1: no sha3/sha256), so no trigger can refuse a wrong
// `self`, and no trigger can verify Ed25519 (an unsigned token). Required: an explicit repair that never edits in place.
// Cases: wrong-self = a writer that KEEPS the schema inserts the next row with a wrong `self` (validly signed);
//        unsigned   = the same writer inserts a row whose token carries another key's signature (right prev and self).
// Each: the running sink halts, a restart is refused; Sink.validPrefix returns the 3 audited tokens and their head; a NEW
// store (new path, same cfg) gets init + the prefix commits (all "committed"; zero amount included); its head equals the
// prefix head; the old file is unchanged; the new store serves the next commit and refuses the old request ids again.
// Usage: node --import tsx tests/refund-finality/regress/s_repair_prefix.ts <treeRoot> [<compiledIssuerModule>]
import { createHash, generateKeyPairSync, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { argv, guard, kit, short, st, tempDir, verdict } from "./s_lib";

guard((() => {
  const { root } = argv();
  const K = kit(root);
  const out: any = {};
  let pass = true;
  const other = generateKeyPairSync("ed25519");
  for (const kase of ["wrong-self", "unsigned"]) {
    const dir = tempDir(), db = join(dir, "old.sqlite"), fresh = join(dir, "new.sqlite");
    const r: any = {};
    try {
      const s = K.open(db); if (typeof s === "string") throw new Error(s);
      s.init(K.S0);
      r.commits = [K.tok(K.S0, "r1", "100"), K.tok(st("900"), "z", "0"), K.tok(st("900"), "r2", "100")].map(t => s.commit(t).status);
      let bad = K.tok(st("800"), "r3", "50");
      if (kase === "unsigned") { const o = JSON.parse(bad); o.signature = sign(null, K.E.signedBytes(o.body, o.keyId), other.privateKey).toString("base64"); bad = K.E.canon(o); }
      const d = new DatabaseSync(db); d.exec("PRAGMA busy_timeout = 5000");
      const last = d.prepare("SELECT self FROM outbox ORDER BY seq DESC LIMIT 1").get() as any;
      const self = kase === "wrong-self" ? "e".repeat(64) : K.SK.linkOf(last.self, bad, K.intentOf(bad));
      d.exec("BEGIN IMMEDIATE");
      d.prepare("INSERT INTO settled(seq, request_id, token, token_sha256, prev, self) VALUES (4, 'r3', ?, ?, ?, ?)").run(bad, K.E.sha256hex(bad), last.self, self);
      d.exec("COMMIT"); d.close(); r.insert = "accepted by the triggers";
      const n = s.commit(K.tok(st("750"), "r4", "0")); r.running = n.status + ": " + String(n.reason).slice(0, 60); s.close();
      const again = K.open(db); r.restart = typeof again === "string" ? again.slice(0, 90) : "STARTED"; if (typeof again !== "string") again.close();
      const oldSha = createHash("sha256").update(readFileSync(db)).digest("hex");
      if (typeof K.SK.Sink.validPrefix !== "function") throw new Error("no Sink.validPrefix");
      const p = K.SK.Sink.validPrefix(db, K.cfg); r.prefix = { n: p.tokens.length, head: p.prefixHead.count, complete: p.complete, problem: String(p.problem).slice(0, 80) };
      const ns = K.open(fresh); if (typeof ns === "string") throw new Error(ns);
      ns.init(K.S0);
      r.replay = p.tokens.map((t: string) => ns.commit(t).status);
      const h = ns.head(); r.sameHead = h.count === p.prefixHead.count && h.chainHash === p.prefixHead.chainHash;
      r.next = ns.commit(K.tok(st("800"), "r3", "50")).status; r.oldIdAgain = ns.commit(K.tok(st("750"), "r1", "10")).status;
      ns.close();
      r.oldUnchanged = createHash("sha256").update(readFileSync(db)).digest("hex") === oldSha;
      r.ok = r.commits.every((x: string) => x === "committed") && /sink halted/.test(r.running) && r.restart !== "STARTED" && p.tokens.length === 3 && !p.complete &&
        r.replay.every((x: string) => x === "committed") && r.sameHead && r.next === "committed" && r.oldIdAgain === "rejected" && r.oldUnchanged;
    } catch (e) { r.err = short(e); r.ok = false; }
    out[kase] = r; if (!r.ok) pass = false;
  }
  verdict(pass, out);
})());
